import SwiftUI

@main
struct MeetingAlertApp: App {
    @StateObject private var model = AppModel()

    init() {
        #if DEBUG
        Snapshots.runIfRequested()
        #endif
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanel()
                .environmentObject(model)
        } label: {
            HStack {
                Image(systemName: model.isPaused ? "bell.slash" : "bell")
                if let title = model.menuBarTitle {
                    Text(title)
                }
            }
        }
        .menuBarExtraStyle(.window)

        Window("Meeting Alert Settings", id: "settings") {
            SettingsView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}
