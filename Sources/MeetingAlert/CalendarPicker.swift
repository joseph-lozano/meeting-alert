import AppKit
import SwiftUI

@MainActor
final class CalendarPickerController {
    private var window: NSWindow?

    func show(model: AppModel) {
        if window == nil {
            let view = CalendarPickerView(onDone: { [weak self] in self?.close() })
                .environmentObject(model)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Meeting Alert"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
        window = nil
    }
}

private struct CalendarPickerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: String?
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                IconTile(symbol: "bell.fill", color: .orange, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Which calendar should Meeting Alert watch?")
                        .font(.title3.weight(.semibold))
                    Text("You'll get a full-screen alert before meetings on this calendar.")
                        .foregroundStyle(.secondary)
                }
            }

            if model.calendars.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No calendars found. Add your Google account in Internet Accounts and turn on Calendars.")
                    Button("Open Internet Accounts…") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension")!)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
            } else {
                List(selection: $selection) {
                    ForEach(model.calendarGroups, id: \.source) { group in
                        Section(group.source) {
                            ForEach(group.calendars) { calendar in
                                HStack(spacing: 8) {
                                    CalendarDot(color: calendar.color)
                                    Text(calendar.title)
                                }
                                .tag(calendar.id)
                            }
                        }
                    }
                }
                .frame(height: 280)
            }

            HStack {
                Spacer()
                Button("Continue") {
                    model.settings.calendarID = selection
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection == nil)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear { selection = model.settings.calendarID }
    }
}
