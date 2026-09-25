import MeetingAlertCore
import SwiftUI

/// A white SF Symbol on a colored rounded square, like System Settings' sidebar.
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}

struct CalendarDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }
}

struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }
}

/// Lays out children left to right, wrapping onto new rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let positions = arrange(subviews, width: bounds.width).positions
        for (subview, position) in zip(subviews, positions) {
            subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> (positions: [CGPoint], size: CGSize) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

/// Plain button with a rounded highlight on hover, for rows and icon buttons in the menu panel.
struct HoverButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        HoverBody(configuration: configuration, cornerRadius: cornerRadius)
    }

    private struct HoverBody: View {
        let configuration: Configuration
        let cornerRadius: CGFloat
        @State private var isHovered = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(configuration.isPressed ? 0.14 : isHovered && isEnabled ? 0.08 : 0))
                )
                .onHover { isHovered = $0 }
        }
    }
}

extension Meeting {
    var timeRange: String {
        if isAllDay { return "All day" }
        return "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    /// Title and SF Symbol for the join button.
    var joinButton: (title: String, symbol: String) {
        if serviceName == "GitHub" { return ("Star on GitHub", "star.fill") }
        return ("Join \(serviceName ?? "Meeting")", "video.fill")
    }

    var serviceName: String? {
        guard let host = joinURL?.host else { return nil }
        if host.hasSuffix("zoom.us") { return "Zoom" }
        if host == "meet.google.com" { return "Meet" }
        if host.contains("teams.") { return "Teams" }
        if host.hasSuffix("webex.com") { return "Webex" }
        if host == "github.com" { return "GitHub" }
        return "Call"
    }
}

/// "in 12 min", "in 1 hr 5 min", "now", "started 3 min ago".
func relativeStart(_ start: Date, now: Date) -> String {
    let seconds = start.timeIntervalSince(now)
    if seconds <= 0 {
        let ago = Int(-seconds / 60)
        return ago < 1 ? "now" : "started \(ago) min ago"
    }
    let minutes = Int((seconds / 60).rounded(.up))
    if minutes < 60 { return "in \(minutes) min" }
    let hours = minutes / 60
    let rest = minutes % 60
    return rest == 0 ? "in \(hours) hr" : "in \(hours) hr \(rest) min"
}
