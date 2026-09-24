import AppKit
import MeetingAlertCore
import SwiftUI

/// The window-style dropdown under the menu bar icon.
struct MenuPanel: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.horizontal, 12)
            content
                .padding(12)
            Divider().padding(.horizontal, 12)
            footer
        }
        .frame(width: 340)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            IconTile(symbol: model.isPaused ? "bell.slash.fill" : "bell.fill", color: model.isPaused ? .gray : .orange, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text("Meeting Alert")
                    .font(.headline)
                if let calendar = model.selectedCalendar {
                    HStack(spacing: 5) {
                        CalendarDot(color: calendar.color)
                            .scaleEffect(0.8)
                        Text(calendar.title)
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch model.authStatus {
        case .fullAccess:
            if model.selectedCalendar == nil {
                EmptyState(
                    symbol: "calendar.badge.plus",
                    title: "Choose a calendar",
                    message: "Pick the calendar Meeting Alert should watch.",
                    action: ("Choose Calendar…", { run { model.showCalendarPicker() } })
                )
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    today(now: context.date)
                }
            }
        case .notDetermined:
            EmptyState(
                symbol: "calendar",
                title: "Calendar access needed",
                message: "Meeting Alert reads your calendar to know when meetings start.",
                action: ("Grant Access…", { Task { await model.requestAccess() } })
            )
        default:
            EmptyState(
                symbol: "lock.fill",
                title: "Calendar access denied",
                message: "Allow Meeting Alert under Privacy & Security › Calendars.",
                action: ("Open Privacy Settings…", { run { model.openPrivacySettings() } })
            )
        }
    }

    @ViewBuilder
    private func today(now: Date) -> some View {
        let meetings = model.todaysMeetings(at: now)
        let next = model.nextMeeting(at: now)
        let later = meetings.filter { $0.id != next?.id }
        let color = model.selectedCalendar?.color ?? .accentColor

        VStack(alignment: .leading, spacing: 10) {
            if model.isPaused, let until = model.pausedUntil {
                HStack {
                    Image(systemName: "pause.circle.fill")
                    Text("Paused until \(until.formatted(date: .omitted, time: .shortened))")
                    Spacer()
                    Button("Resume") { model.resume() }
                        .controlSize(.small)
                }
                .font(.callout)
                .padding(10)
                .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if let next {
                NextMeetingCard(meeting: next, now: now, color: color) { url in
                    run { NSWorkspace.shared.open(url) }
                }
            }

            if !later.isEmpty {
                Text(next == nil ? "TODAY" : "LATER TODAY")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
                VStack(spacing: 2) {
                    ForEach(later) { meeting in
                        MeetingRow(meeting: meeting, now: now, color: color) { url in
                            run { NSWorkspace.shared.open(url) }
                        }
                    }
                }
            }

            if meetings.isEmpty {
                EmptyState(
                    symbol: "checkmark.circle.fill",
                    title: "You're free",
                    message: "No more meetings today.",
                    action: nil
                )
            }
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 4) {
            if model.isPaused {
                FooterButton(symbol: "play.fill", help: "Resume alerts") { model.resume() }
            } else {
                Menu {
                    Button("For 30 Minutes") { model.pause(for: 30 * 60) }
                    Button("For 1 Hour") { model.pause(for: 60 * 60) }
                    Button("For 2 Hours") { model.pause(for: 2 * 60 * 60) }
                    Button("Until Tomorrow") { model.pauseUntilTomorrow() }
                } label: {
                    Image(systemName: "pause.fill")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .frame(width: 30, height: 26)
                .help("Pause alerts")
            }
            FooterButton(symbol: "bell.and.waves.left.and.right", help: "Show a test alert") {
                run { model.testAlert() }
            }
            Spacer()
            FooterButton(symbol: "gearshape.fill", help: "Settings") {
                run {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            FooterButton(symbol: "power", help: "Quit Meeting Alert") {
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    /// Closes the panel, then performs the action (e.g. opening a window that should appear in front).
    private func run(_ action: @escaping () -> Void) {
        NSApp.keyWindow?.close()
        action()
    }
}

private struct NextMeetingCard: View {
    let meeting: Meeting
    let now: Date
    let color: Color
    let onJoin: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NEXT")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
                Spacer()
                Text(relativeStart(meeting.start, now: now))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(meeting.start.timeIntervalSince(now) < 5 * 60 ? .orange : .secondary)
            }
            Text(meeting.title)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
            HStack {
                Label(meeting.timeRange, systemImage: "clock")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                if let url = meeting.joinURL {
                    Button {
                        onJoin(url)
                    } label: {
                        Label("Join \(meeting.serviceName ?? "")", systemImage: "video.fill")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(color)
                    .controlSize(.regular)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.25))
        )
    }
}

private struct MeetingRow: View {
    let meeting: Meeting
    let now: Date
    let color: Color
    let onJoin: (URL) -> Void

    var body: some View {
        Button {
            if let url = meeting.joinURL { onJoin(url) }
        } label: {
            HStack(spacing: 10) {
                Text(meeting.start <= now ? "Now" : meeting.start.formatted(date: .omitted, time: .shortened))
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                    .frame(width: 64, alignment: .trailing)
                Capsule()
                    .fill(color)
                    .frame(width: 3, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(meeting.title)
                        .lineLimit(1)
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if meeting.joinURL != nil {
                    Image(systemName: "video.fill")
                        .foregroundStyle(color)
                        .help("Join \(meeting.serviceName ?? "call")")
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
        }
        .buttonStyle(HoverButtonStyle())
        .disabled(meeting.joinURL == nil)
    }

    private var duration: String {
        let minutes = Int(meeting.end.timeIntervalSince(meeting.start) / 60)
        return minutes < 60 ? "\(minutes) min" : minutes % 60 == 0 ? "\(minutes / 60) hr" : "\(minutes / 60) hr \(minutes % 60) min"
    }
}

private struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    let action: (label: String, perform: () -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let action {
                Button(action.label, action: action.perform)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

private struct FooterButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 26)
        }
        .buttonStyle(HoverButtonStyle(cornerRadius: 6))
        .help(help)
    }
}
