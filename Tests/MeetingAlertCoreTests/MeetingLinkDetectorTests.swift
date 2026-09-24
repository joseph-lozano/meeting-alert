import Foundation
import Testing
@testable import MeetingAlertCore

@Test func findsGoogleMeetLinkInNotes() {
    let notes = """
    Join with Google Meet: https://meet.google.com/abc-defg-hij
    Learn more about Meet at: https://support.google.com/a/users/answer/9282720
    """
    #expect(MeetingLinkDetector.joinURL(url: nil, location: nil, notes: notes)?.absoluteString
        == "https://meet.google.com/abc-defg-hij")
}

@Test func skipsNonJoinZoomLinks() {
    let notes = """
    Find your local number: https://us02web.zoom.us/u/kdEAbc
    Join Zoom Meeting
    https://us02web.zoom.us/j/81234567890?pwd=abc123
    """
    #expect(MeetingLinkDetector.joinURL(url: nil, location: nil, notes: notes)?.absoluteString
        == "https://us02web.zoom.us/j/81234567890?pwd=abc123")
}

@Test func prefersLocationOverNotes() {
    let url = MeetingLinkDetector.joinURL(
        url: nil,
        location: "https://teams.microsoft.com/l/meetup-join/19%3ameeting",
        notes: "https://meet.google.com/abc-defg-hij"
    )
    #expect(url?.host == "teams.microsoft.com")
}

@Test func ignoresUnknownHosts() {
    #expect(MeetingLinkDetector.joinURL(url: URL(string: "https://example.com/x"), location: "Room 4", notes: nil) == nil)
    #expect(MeetingLinkDetector.joinURL(url: nil, location: nil, notes: "https://evilzoom.us/j/1") == nil)
}

@Test func joinURLOverrideWinsOverDetectedLink() {
    let start = Date()
    let meeting = Meeting(
        id: "t", title: "Test", start: start, end: start,
        location: "https://meet.google.com/abc-defg-hij",
        joinURLOverride: URL(string: "https://github.com/joseph-lozano/meeting-alert")
    )
    #expect(meeting.joinURL?.host == "github.com")
}
