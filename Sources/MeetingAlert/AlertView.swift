import MeetingAlertCore
import SwiftUI

struct AlertView: View {
    @ObservedObject var state: AlertState
    let onJoin: (URL) -> Void
    /// Called with the time the alert should reappear.
    let onSnooze: (Date) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            VisualEffectBackground()
            Color.black.opacity(0.4)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 48) {
                    ForEach(Array(state.meetings.enumerated()), id: \.element.id) { index, meeting in
                        MeetingCard(meeting: meeting, now: context.date, isPrimary: index == 0, onJoin: onJoin)
                    }
                    controls(now: context.date)
                }
                .padding(64)
                .frame(maxWidth: 1000)
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }

    private func controls(now: Date) -> some View {
        HStack(spacing: 16) {
            if let first = state.meetings.first, first.start.timeIntervalSince(now) > 15 {
                Button("Remind at start") { onSnooze(first.start) }
            }
            Button("Snooze 1 min") { onSnooze(now.addingTimeInterval(60)) }
            Button("Snooze 5 min") { onSnooze(now.addingTimeInterval(300)) }
            Button("Dismiss", action: onDismiss)
                .keyboardShortcut(.cancelAction)
        }
        .controlSize(.large)
    }
}

private struct MeetingCard: View {
    let meeting: Meeting
    let now: Date
    let isPrimary: Bool
    let onJoin: (URL) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(countdown)
                .font(.system(size: isPrimary ? 28 : 20, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Text(meeting.title)
                .font(.system(size: isPrimary ? 64 : 40, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.5)

            Text("\(meeting.start.formatted(date: .omitted, time: .shortened)) – \(meeting.end.formatted(date: .omitted, time: .shortened))")
                .font(.title2)
                .foregroundStyle(.secondary)

            if let location = meeting.location, !location.isEmpty, !location.hasPrefix("http") {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let url = meeting.joinURL {
                joinButton(url)
                    .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private func joinButton(_ url: URL) -> some View {
        let button = Button {
            onJoin(url)
        } label: {
            Label(meeting.joinButton.title, systemImage: meeting.joinButton.symbol)
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.extraLarge)

        if isPrimary {
            button.keyboardShortcut(.defaultAction)
        } else {
            button
        }
    }

    private var countdown: String {
        let seconds = Int(meeting.start.timeIntervalSince(now).rounded())
        if abs(seconds) < 1 { return "Starting now" }
        let text = String(format: "%d:%02d", abs(seconds) / 60, abs(seconds) % 60)
        return seconds > 0 ? "Starts in \(text)" : "Started \(text) ago"
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
