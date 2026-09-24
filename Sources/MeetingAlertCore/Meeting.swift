import Foundation

/// A calendar event, decoupled from EventKit so filtering logic is testable.
public struct Meeting: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var location: String?
    public var notes: String?
    public var url: URL?
    public var isDeclined: Bool
    /// Number of attendees including you. EventKit reports 0 when there are no invitees.
    public var attendeeCount: Int
    /// Used instead of the detected video-call link, e.g. for the test alert.
    public var joinURLOverride: URL?

    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        url: URL? = nil,
        isDeclined: Bool = false,
        attendeeCount: Int = 0,
        joinURLOverride: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.url = url
        self.isDeclined = isDeclined
        self.attendeeCount = attendeeCount
        self.joinURLOverride = joinURLOverride
    }

    public var joinURL: URL? {
        joinURLOverride ?? MeetingLinkDetector.joinURL(url: url, location: location, notes: notes)
    }
}
