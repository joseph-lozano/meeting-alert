#if DEBUG
import AppKit
import MeetingAlertCore
import SwiftUI

/// Renders the UI with sample data to PNGs, so styling can be checked without screen recording:
///     swift build && .build/debug/MeetingAlert --snapshot <dir>
@MainActor
enum Snapshots {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--snapshot"), args.indices.contains(flag + 1) else { return }
        let dir = URL(fileURLWithPath: args[flag + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        _ = NSApplication.shared

        let model = AppModel(connectToCalendar: false)
        model.loadDemo(settings: demoSettings, calendars: demoCalendars, meetings: demoMeetings)

        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            render(MenuPanel().environmentObject(model).background(Color(nsColor: .windowBackgroundColor)), size: nil, appearance: appearance, to: dir.appendingPathComponent("menu-\(name).png"))
            for pane in SettingsPane.allCases {
                render(
                    SettingsView(pane: pane).environmentObject(model),
                    size: CGSize(width: 700, height: 540),
                    appearance: appearance,
                    to: dir.appendingPathComponent("settings-\(pane.rawValue)-\(name).png")
                )
            }
        }
        exit(0)
    }

    private static func render(_ view: some View, size: CGSize?, appearance: NSAppearance.Name, to url: URL) {
        let host = NSHostingView(rootView: view)
        let frame = CGRect(origin: .zero, size: size ?? host.fittingSize)
        let window = NSWindow(contentRect: frame, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        host.frame = frame
        window.orderFrontRegardless()
        window.setFrameOrigin(CGPoint(x: -10_000, y: -10_000))
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        host.layoutSubtreeIfNeeded()

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        window.orderOut(nil)
    }

    private static let demoCalendars = [
        CalendarOption(id: "work", title: "joseph@example.com", source: "Google", color: Color(red: 0.26, green: 0.52, blue: 0.96)),
        CalendarOption(id: "home", title: "Home", source: "iCloud", color: .green),
    ]

    private static var demoSettings: AlertSettings {
        var s = AlertSettings()
        s.calendarID = "work"
        s.excludeRules = ["Focus time", "Lunch", "OOO", "Commute"].map { ExcludeRule(pattern: $0) }
        return s
    }

    private static var demoMeetings: [Meeting] {
        let now = Date()
        func at(_ minutes: Double) -> Date { now.addingTimeInterval(minutes * 60) }
        return [
            Meeting(id: "1", title: "Design review: onboarding flow", start: at(7), end: at(52),
                    notes: "Join: https://meet.google.com/abc-defg-hij", attendeeCount: 5),
            Meeting(id: "2", title: "Lunch", start: at(70), end: at(130), attendeeCount: 0),
            Meeting(id: "3", title: "1:1 with Sam", start: at(150), end: at(180),
                    location: "https://us02web.zoom.us/j/123456789", attendeeCount: 2),
            Meeting(id: "4", title: "Sprint planning", start: at(200), end: at(260), attendeeCount: 8),
            Meeting(id: "5", title: "Late sync with Tokyo", start: at(60 * 9), end: at(60 * 9 + 30),
                    location: "https://teams.microsoft.com/l/meetup-join/abc", attendeeCount: 4),
        ]
    }
}
#endif
