import Foundation

public enum ExclusionReason: Equatable, Sendable, CustomStringConvertible {
    case allDay
    case declined
    case noAttendees
    case outsideWorkingHours
    case matchedRule(String)

    public var description: String {
        switch self {
        case .allDay: "all-day"
        case .declined: "declined"
        case .noAttendees: "no other attendees"
        case .outsideWorkingHours: "outside working hours"
        case .matchedRule(let pattern): "matches “\(pattern)”"
        }
    }
}

public enum MeetingFilter {
    /// Returns why a meeting should not alert, or nil if it should.
    public static func exclusionReason(
        for meeting: Meeting,
        settings: AlertSettings,
        calendar: Calendar = .current
    ) -> ExclusionReason? {
        if settings.skipAllDay && meeting.isAllDay { return .allDay }
        if settings.skipDeclined && meeting.isDeclined { return .declined }
        if settings.skipWithoutAttendees && meeting.attendeeCount <= 1 { return .noAttendees }
        if settings.workingHoursOnly
            && !isWithinWorkingHours(meeting.start, settings: settings, calendar: calendar) {
            return .outsideWorkingHours
        }
        if let rule = settings.excludeRules.first(where: { $0.matches(meeting.title) }) {
            return .matchedRule(rule.pattern)
        }
        return nil
    }

    public static func isWithinWorkingHours(
        _ date: Date,
        settings: AlertSettings,
        calendar: Calendar = .current
    ) -> Bool {
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = parts.weekday, settings.workDays.contains(weekday) else { return false }
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let start = settings.workStartMinute
        let end = settings.workEndMinute
        if start <= end {
            return minute >= start && minute < end
        }
        // Overnight window, e.g. 22:00–06:00.
        return minute >= start || minute < end
    }
}
