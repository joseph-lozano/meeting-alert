import AppKit
import MeetingAlertCore
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, alert, filters, upcoming

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .alert: "Alert"
        case .filters: "Filters"
        case .upcoming: "Upcoming"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .alert: "bell.badge.fill"
        case .filters: "line.3.horizontal.decrease"
        case .upcoming: "calendar"
        }
    }

    var color: Color {
        switch self {
        case .general: .gray
        case .alert: .orange
        case .filters: .indigo
        case .upcoming: .red
        }
    }
}

struct SettingsView: View {
    @State private var pane: SettingsPane? = .general

    init(pane: SettingsPane = .general) {
        _pane = State(initialValue: pane)
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $pane) { pane in
                Label {
                    Text(pane.title)
                } icon: {
                    IconTile(symbol: pane.symbol, color: pane.color)
                }
                .padding(.vertical, 2)
            }
            .navigationSplitViewColumnWidth(180)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch pane ?? .general {
                case .general: GeneralPane()
                case .alert: AlertPane()
                case .filters: FiltersPane()
                case .upcoming: UpcomingPane()
                }
            }
            .formStyle(.grouped)
            .navigationTitle((pane ?? .general).title)
        }
        .frame(width: 700, height: 540)
    }
}

// MARK: - General

private struct GeneralPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                if model.hasAccess {
                    HStack(spacing: 12) {
                        if let calendar = model.selectedCalendar {
                            IconTile(symbol: "calendar", color: calendar.color, size: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(calendar.title)
                                    .font(.headline)
                                Text(calendar.source)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            IconTile(symbol: "calendar.badge.plus", color: .gray, size: 34)
                            Text("No calendar selected")
                                .font(.headline)
                        }
                        Spacer()
                        Button(model.selectedCalendar == nil ? "Choose…" : "Change…") {
                            model.showCalendarPicker()
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack(spacing: 12) {
                        IconTile(symbol: "lock.fill", color: .gray, size: 34)
                        Text("Calendar access is off")
                            .font(.headline)
                        Spacer()
                        Button("Grant Access…") {
                            if model.authStatus == .notDetermined {
                                Task { await model.requestAccess() }
                            } else {
                                model.openPrivacySettings()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Calendar")
            } footer: {
                Text("To see your Google calendars, add your Google account in System Settings › Internet Accounts.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Launch at login", isOn: $model.launchAtLogin)
            }
        }
    }
}

// MARK: - Alert

private struct AlertPane: View {
    @EnvironmentObject private var model: AppModel

    private static let sounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    var body: some View {
        Form {
            Section("When") {
                Picker("Show alert", selection: $model.settings.leadTime) {
                    Text("At start").tag(TimeInterval(0))
                    Text("30 sec").tag(TimeInterval(30))
                    Text("1 min").tag(TimeInterval(60))
                    Text("2 min").tag(TimeInterval(120))
                    Text("5 min").tag(TimeInterval(300))
                }
                .pickerStyle(.segmented)
            }

            Section("Appearance") {
                Toggle("Cover all displays", isOn: $model.settings.coverAllDisplays)
                Toggle("Play sound", isOn: $model.settings.playSound)
                if model.settings.playSound {
                    HStack {
                        Picker("Sound", selection: $model.settings.soundName) {
                            ForEach(Self.sounds, id: \.self) { Text($0).tag($0) }
                        }
                        Button {
                            NSSound(named: NSSound.Name(model.settings.soundName))?.play()
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                        }
                        .buttonStyle(.borderless)
                        .help("Preview sound")
                    }
                }
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Try it")
                        Text("Shows the full-screen alert with a sample meeting.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Show Test Alert") { model.testAlert() }
                }
            }
        }
    }
}

// MARK: - Filters

private struct FiltersPane: View {
    @EnvironmentObject private var model: AppModel
    @State private var newPhrase = ""

    var body: some View {
        Form {
            Section("Skip") {
                Toggle("All-day events", isOn: $model.settings.skipAllDay)
                Toggle("Events I've declined", isOn: $model.settings.skipDeclined)
                Toggle("Events with no other attendees", isOn: $model.settings.skipWithoutAttendees)
            }

            Section {
                Toggle("Only alert during working hours", isOn: $model.settings.workingHoursOnly.animation())
                if model.settings.workingHoursOnly {
                    LabeledContent("Hours") {
                        HStack(spacing: 6) {
                            DatePicker("Start", selection: time(\.workStartMinute), displayedComponents: .hourAndMinute)
                            Text("to").foregroundStyle(.secondary)
                            DatePicker("End", selection: time(\.workEndMinute), displayedComponents: .hourAndMinute)
                        }
                        .labelsHidden()
                    }
                    LabeledContent("Days") {
                        HStack(spacing: 5) {
                            ForEach(orderedWeekdays, id: \.self) { weekday in
                                DayToggle(
                                    label: Calendar.current.veryShortWeekdaySymbols[weekday - 1],
                                    isOn: workDay(weekday)
                                )
                            }
                        }
                    }
                }
            } header: {
                Text("Working hours")
            }

            Section {
                if !model.settings.excludeRules.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(model.settings.excludeRules) { rule in
                            RuleChip(text: rule.pattern) {
                                withAnimation {
                                    model.settings.excludeRules.removeAll { $0.id == rule.id }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.secondary)
                    TextField("Add a word or phrase…", text: $newPhrase)
                        .textFieldStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .onSubmit(addPhrase)
                }
            } header: {
                Text("Skip meetings whose title contains")
            } footer: {
                Text("Press Return to add. Matches anywhere in the title, ignoring capitalization: “focus” skips “Team Focus Time”.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addPhrase() {
        let phrase = newPhrase.trimmingCharacters(in: .whitespaces)
        newPhrase = ""
        guard !phrase.isEmpty,
              !model.settings.excludeRules.contains(where: { $0.pattern.caseInsensitiveCompare(phrase) == .orderedSame })
        else { return }
        withAnimation {
            model.settings.excludeRules.append(ExcludeRule(pattern: phrase))
        }
    }

    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    private func workDay(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { model.settings.workDays.contains(weekday) },
            set: { isOn in
                if isOn {
                    model.settings.workDays.insert(weekday)
                } else {
                    model.settings.workDays.remove(weekday)
                }
            }
        )
    }

    private func time(_ keyPath: WritableKeyPath<AlertSettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minute = model.settings[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                model.settings[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

private struct RuleChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.15), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.3)))
    }
}

private struct DayToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Text(label)
                .font(.callout.weight(.semibold))
                .foregroundStyle(isOn ? .white : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(isOn ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(Color.primary.opacity(0.08)))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Upcoming

private struct UpcomingPane: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                if model.upcoming.isEmpty {
                    Text("Nothing in the next 24 hours.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.upcoming) { meeting in
                    let reason = model.exclusionReason(for: meeting)
                    HStack(spacing: 12) {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(meeting.isAllDay ? "All day" : meeting.start.formatted(date: .omitted, time: .shortened))
                                .font(.callout.weight(.medium))
                                .monospacedDigit()
                            Text(meeting.start.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 70, alignment: .trailing)
                        Capsule()
                            .fill(reason == nil ? (model.selectedCalendar?.color ?? .accentColor) : .secondary.opacity(0.4))
                            .frame(width: 3, height: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(meeting.title)
                                .lineLimit(1)
                                .foregroundStyle(reason == nil ? .primary : .secondary)
                            if let service = meeting.serviceName {
                                Label(service, systemImage: "video.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let reason {
                            StatusPill(text: "Skipped · \(reason)", color: .secondary)
                        } else {
                            StatusPill(text: "Will alert", color: .green)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Next 24 hours")
            } footer: {
                Text("Change what gets skipped in Filters.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
