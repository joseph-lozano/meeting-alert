import AppKit
import EventKit
import MeetingAlertCore
import ServiceManagement
import SwiftUI

struct CalendarOption: Identifiable, Hashable {
    let id: String
    let title: String
    let source: String
    let color: Color
}

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AlertSettings {
        didSet {
            guard settings != oldValue else { return }
            guard !isDemo else { return }
            save()
            refresh()
        }
    }
    @Published private(set) var authStatus = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var calendars: [CalendarOption] = []
    /// Events from the selected calendar that haven't ended yet, soonest first.
    @Published private(set) var upcoming: [Meeting] = []
    @Published private(set) var pausedUntil: Date?
    /// Text next to the menu bar icon, e.g. "Standup in 12m". Nil when nothing else is on today.
    @Published private(set) var menuBarTitle: String?

    private let store = EKEventStore()
    private lazy var alerts = AlertController(
        onJoin: { url in NSWorkspace.shared.open(url) },
        onSnooze: { [weak self] meetings, fireAt in self?.snooze(meetings, until: fireAt) }
    )
    /// Meeting ids that have already alerted, with their start time for pruning.
    private var alerted: [String: Date] = [:]
    private var snoozed: [String: (meeting: Meeting, fireAt: Date)] = [:]
    private var timers: [Timer] = []
    private let calendarPicker = CalendarPickerController()
    /// Auto-open the picker once per launch; calendar syncs call loadCalendars repeatedly.
    private var didPromptForCalendar = false

    /// Set by `loadDemo` for snapshots: no EventKit, no persistence.
    private var isDemo = false

    private static let settingsKey = "settings"
    /// Alerts missed while asleep or before launch still show if we're within this long after the start.
    private static let lateAlertWindow: TimeInterval = 5 * 60

    /// Pass `connectToCalendar: false` for snapshots, which must not touch EventKit or timers.
    init(connectToCalendar: Bool = true) {
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode(AlertSettings.self, from: data) {
            settings = saved
        } else {
            settings = AlertSettings()
        }
        // Earlier builds could save empty rules.
        settings.excludeRules.removeAll { $0.pattern.trimmingCharacters(in: .whitespaces).isEmpty }

        guard connectToCalendar else { return }

        timers = [
            Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            },
            Timer(timeInterval: 60, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
        ]
        // .common so timers keep firing while the menu is open.
        timers.forEach { RunLoop.main.add($0, forMode: .common) }

        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.loadCalendars()
                self?.refresh()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }

        Task { await requestAccess() }

        if CommandLine.arguments.contains("--test-alert") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.testAlert() }
        }
    }

    // MARK: Calendar access

    var hasAccess: Bool { authStatus == .fullAccess }

    var selectedCalendar: CalendarOption? {
        calendars.first { $0.id == settings.calendarID }
    }

    func requestAccess() async {
        if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
            _ = try? await store.requestFullAccessToEvents()
        }
        authStatus = EKEventStore.authorizationStatus(for: .event)
        loadCalendars()
        refresh()
    }

    func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
        NSWorkspace.shared.open(url)
    }

    private func loadCalendars() {
        guard hasAccess else { calendars = []; return }
        let ekCalendars = store.calendars(for: .event)
        calendars = ekCalendars
            .map { CalendarOption(
                id: $0.calendarIdentifier,
                title: $0.title,
                source: $0.source.title,
                color: Color(nsColor: $0.color)
            ) }
            .sorted { ($0.source, $0.title) < ($1.source, $1.title) }

        // Forget a calendar that no longer exists (e.g. the account was removed). Skip when the list
        // is empty, since that can be a transient state while accounts sync.
        if let id = settings.calendarID, !calendars.isEmpty, !calendars.contains(where: { $0.id == id }) {
            settings.calendarID = nil
        }
        if settings.calendarID == nil && !didPromptForCalendar {
            didPromptForCalendar = true
            showCalendarPicker()
        }
    }

    var calendarGroups: [(source: String, calendars: [CalendarOption])] {
        Dictionary(grouping: calendars, by: \.source)
            .map { ($0.key, $0.value) }
            .sorted { $0.source < $1.source }
    }

    func showCalendarPicker() {
        calendarPicker.show(model: self)
    }

    // MARK: Scheduling

    func refresh() {
        guard !isDemo else { return }
        guard hasAccess,
              let id = settings.calendarID,
              let calendar = store.calendar(withIdentifier: id)
        else {
            upcoming = []
            return
        }
        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-3600),
            end: now.addingTimeInterval(24 * 3600),
            calendars: [calendar]
        )
        upcoming = store.events(matching: predicate)
            .filter { $0.endDate > now }
            .map(Meeting.init(event:))
            .sorted { $0.start < $1.start }
    }

    private func tick() {
        let now = Date()
        var due: [Meeting] = []

        for (id, entry) in snoozed where now >= entry.fireAt {
            snoozed[id] = nil
            due.append(entry.meeting)
        }

        if !isPaused {
            for meeting in upcoming where alerted[meeting.id] == nil {
                guard now >= meeting.start.addingTimeInterval(-settings.leadTime) else { continue }
                alerted[meeting.id] = meeting.start
                guard now < meeting.start.addingTimeInterval(Self.lateAlertWindow), now < meeting.end,
                      exclusionReason(for: meeting) == nil
                else { continue }
                due.append(meeting)
            }
        }

        if !due.isEmpty {
            alerts.show(due, settings: settings)
        }

        let cutoff = now.addingTimeInterval(-24 * 3600)
        alerted = alerted.filter { $0.value > cutoff }
        if let pausedUntil, pausedUntil <= now {
            self.pausedUntil = nil
        }

        let title = nextMeeting(at: now).map { Self.menuBarTitle(for: $0, now: now) }
        if title != menuBarTitle {
            menuBarTitle = title
        }
    }

    /// Meetings that will alert and haven't ended, through the end of today.
    func todaysMeetings(at now: Date = Date()) -> [Meeting] {
        let endOfDay = Calendar.current.startOfDay(for: now.addingTimeInterval(24 * 3600))
        return upcoming.filter { $0.end > now && $0.start < endOfDay && exclusionReason(for: $0) == nil }
    }

    /// The next meeting to show in the menu bar. A meeting stays "next" for a few minutes after it starts.
    func nextMeeting(at now: Date = Date()) -> Meeting? {
        todaysMeetings(at: now).first { $0.start > now.addingTimeInterval(-Self.lateAlertWindow) }
    }

    private static func menuBarTitle(for meeting: Meeting, now: Date) -> String {
        let title = meeting.title.count > 24 ? String(meeting.title.prefix(23)) + "…" : meeting.title
        let seconds = meeting.start.timeIntervalSince(now)
        let when: String
        if seconds <= 0 {
            when = "now"
        } else if seconds < 3600 {
            when = "in \(Int((seconds / 60).rounded(.up)))m"
        } else {
            when = "at \(meeting.start.formatted(date: .omitted, time: .shortened))"
        }
        return "\(title) \(when)"
    }

    func exclusionReason(for meeting: Meeting) -> ExclusionReason? {
        MeetingFilter.exclusionReason(for: meeting, settings: settings)
    }

    private func snooze(_ meetings: [Meeting], until fireAt: Date) {
        for meeting in meetings {
            snoozed[meeting.id] = (meeting, fireAt)
        }
    }

    func testAlert() {
        let start = Date().addingTimeInterval(settings.leadTime)
        let meeting = Meeting(
            id: "test-\(UUID())",
            title: "Test Meeting",
            start: start,
            end: start.addingTimeInterval(1800),
            joinURLOverride: URL(string: "https://github.com/joseph-lozano/meeting-alert")
        )
        alerts.show([meeting], settings: settings)
    }

    // MARK: Pause

    var isPaused: Bool { pausedUntil.map { $0 > Date() } ?? false }

    func pause(for interval: TimeInterval) {
        pausedUntil = Date().addingTimeInterval(interval)
    }

    func pauseUntilTomorrow() {
        pausedUntil = Calendar.current.startOfDay(for: Date().addingTimeInterval(24 * 3600))
    }

    func resume() {
        pausedUntil = nil
    }

    // MARK: Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("Launch at login change failed: \(error)")
            }
            objectWillChange.send()
        }
    }

    // MARK: Demo

    /// Populates the model with fixed data and detaches it from EventKit, for rendering snapshots.
    func loadDemo(settings: AlertSettings, calendars: [CalendarOption], meetings: [Meeting]) {
        isDemo = true
        authStatus = .fullAccess
        self.settings = settings
        self.calendars = calendars
        upcoming = meetings
    }

    // MARK: Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }
}

extension Meeting {
    init(event: EKEvent) {
        let me = event.attendees?.first(where: \.isCurrentUser)
        self.init(
            // Recurring occurrences share an identifier, so include the start time.
            id: "\(event.calendarItemIdentifier)|\(event.startDate.timeIntervalSince1970)",
            title: event.title ?? "Untitled",
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            location: event.location,
            notes: event.notes,
            url: event.url,
            isDeclined: me?.participantStatus == .declined,
            attendeeCount: event.attendees?.count ?? 0
        )
    }
}
