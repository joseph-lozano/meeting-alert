import Foundation
import Testing
@testable import MeetingAlertCore

private var calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Chicago")!
    return c
}()

/// 2026-09-23 is a Wednesday.
private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
}

private func meeting(_ title: String = "Sync", at start: Date = date(23, 10)) -> Meeting {
    Meeting(id: title, title: title, start: start, end: start.addingTimeInterval(1800), attendeeCount: 3)
}

@Test func alertsForOrdinaryWorkdayMeeting() {
    #expect(MeetingFilter.exclusionReason(for: meeting(), settings: AlertSettings(), calendar: calendar) == nil)
}

@Test func excludesOutsideWorkingHours() {
    var s = AlertSettings()
    s.workingHoursOnly = true
    #expect(MeetingFilter.exclusionReason(for: meeting(at: date(23, 8, 59)), settings: s, calendar: calendar) == .outsideWorkingHours)
    #expect(MeetingFilter.exclusionReason(for: meeting(at: date(23, 9)), settings: s, calendar: calendar) == nil)
    #expect(MeetingFilter.exclusionReason(for: meeting(at: date(23, 17)), settings: s, calendar: calendar) == .outsideWorkingHours)
    // Saturday
    #expect(MeetingFilter.exclusionReason(for: meeting(at: date(26, 10)), settings: s, calendar: calendar) == .outsideWorkingHours)
}

@Test func workingHoursFilterIsOffByDefault() {
    let s = AlertSettings()
    #expect(MeetingFilter.exclusionReason(for: meeting(at: date(26, 22)), settings: s, calendar: calendar) == nil)
}

@Test func overnightWorkingHours() {
    var s = AlertSettings()
    s.workStartMinute = 22 * 60
    s.workEndMinute = 6 * 60
    #expect(MeetingFilter.isWithinWorkingHours(date(23, 23), settings: s, calendar: calendar))
    #expect(MeetingFilter.isWithinWorkingHours(date(23, 5), settings: s, calendar: calendar))
    #expect(!MeetingFilter.isWithinWorkingHours(date(23, 12), settings: s, calendar: calendar))
}

@Test func excludesByTitleSubstringCaseInsensitive() {
    var s = AlertSettings()
    s.excludeRules = [ExcludeRule(pattern: "focus time")]
    #expect(MeetingFilter.exclusionReason(for: meeting("🎧 Focus Time"), settings: s, calendar: calendar) == .matchedRule("focus time"))
    #expect(MeetingFilter.exclusionReason(for: meeting("Planning"), settings: s, calendar: calendar) == nil)
}

@Test func blankRulesNeverMatch() {
    #expect(!ExcludeRule(pattern: "  ").matches("anything"))
}

@Test func decodesRulesSavedWithOldRegexFlag() throws {
    let json = #"{"excludeRules": [{"id": "6F1C9A52-2B39-4F0C-9B8E-3A1D2C4B5E6F", "pattern": "Lunch", "isRegex": false}]}"#
    let s = try JSONDecoder().decode(AlertSettings.self, from: json.data(using: .utf8)!)
    #expect(s.excludeRules.map(\.pattern) == ["Lunch"])
}

@Test func skipsAllDayDeclinedAndSolo() {
    var s = AlertSettings()
    s.skipWithoutAttendees = true
    var m = meeting()
    m.isAllDay = true
    #expect(MeetingFilter.exclusionReason(for: m, settings: s, calendar: calendar) == .allDay)
    m = meeting()
    m.isDeclined = true
    #expect(MeetingFilter.exclusionReason(for: m, settings: s, calendar: calendar) == .declined)
    m = meeting()
    m.attendeeCount = 0
    #expect(MeetingFilter.exclusionReason(for: m, settings: s, calendar: calendar) == .noAttendees)
}

@Test func settingsDecodeWithMissingFields() throws {
    let json = #"{"leadTime": 120, "excludeRules": []}"#.data(using: .utf8)!
    let s = try JSONDecoder().decode(AlertSettings.self, from: json)
    #expect(s.leadTime == 120)
    #expect(s.workDays == [2, 3, 4, 5, 6])
    #expect(s.soundName == "Glass")
}
