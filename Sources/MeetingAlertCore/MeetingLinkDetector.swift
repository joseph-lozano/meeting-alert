import Foundation

public enum MeetingLinkDetector {
    static let hosts = [
        "zoom.us",
        "meet.google.com",
        "teams.microsoft.com",
        "teams.live.com",
        "webex.com",
        "whereby.com",
        "around.co",
        "meet.jit.si",
        "facetime.apple.com",
        "chime.aws",
        "gotomeeting.com",
        "meet.goto.com",
        "tuple.app",
    ]

    /// Zoom invites include many zoom.us links (dial-in lists, support pages); only these paths join a meeting.
    static let zoomJoinPaths = ["/j/", "/my/", "/w/", "/s/", "/wc/"]

    /// Finds the first video-call link in the event's URL, location, then notes.
    public static func joinURL(url: URL?, location: String?, notes: String?) -> URL? {
        var candidates: [URL] = []
        if let url { candidates.append(url) }
        for text in [location, notes].compactMap({ $0 }) {
            candidates += extractURLs(from: text)
        }
        return candidates.first(where: isMeetingURL)
    }

    public static func isMeetingURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host?.lowercased()
        else { return false }
        guard let matched = hosts.first(where: { host == $0 || host.hasSuffix("." + $0) }) else {
            return false
        }
        if matched == "zoom.us" {
            return zoomJoinPaths.contains { url.path.hasPrefix($0) }
        }
        if matched == "meet.google.com" {
            return url.path.count > 1
        }
        return true
    }

    static func extractURLs(from text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        return detector
            .matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap(\.url)
    }
}
