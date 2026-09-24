import AppKit
import MeetingAlertCore
import SwiftUI

@MainActor
final class AlertState: ObservableObject {
    @Published var meetings: [Meeting] = []
}

/// Borderless windows can't become key by default, which would break keyboard shortcuts.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class AlertController {
    private let state = AlertState()
    private var windows: [NSWindow] = []
    private let onJoin: (URL) -> Void
    private let onSnooze: ([Meeting], Date) -> Void

    init(onJoin: @escaping (URL) -> Void, onSnooze: @escaping ([Meeting], Date) -> Void) {
        self.onJoin = onJoin
        self.onSnooze = onSnooze
    }

    func show(_ meetings: [Meeting], settings: AlertSettings) {
        for meeting in meetings where !state.meetings.contains(where: { $0.id == meeting.id }) {
            state.meetings.append(meeting)
        }
        state.meetings.sort { $0.start < $1.start }

        if windows.isEmpty {
            let screens = settings.coverAllDisplays ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
            windows = screens.map(makeWindow)
        }
        if settings.playSound {
            NSSound(named: NSSound.Name(settings.soundName))?.play()
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.forEach { $0.orderFrontRegardless() }
        windows.first?.makeKey()
    }

    func dismiss() {
        windows.forEach { $0.orderOut(nil) }
        windows = []
        state.meetings = []
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.setFrame(screen.frame, display: false)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AlertView(
            state: state,
            onJoin: { [weak self] url in
                self?.onJoin(url)
                self?.dismiss()
            },
            onSnooze: { [weak self] fireAt in
                guard let self else { return }
                self.onSnooze(self.state.meetings, fireAt)
                self.dismiss()
            },
            onDismiss: { [weak self] in self?.dismiss() }
        ))
        return window
    }
}
