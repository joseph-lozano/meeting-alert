import Foundation

public struct ExcludeRule: Codable, Identifiable, Hashable, Sendable {
    public var id = UUID()
    public var pattern: String

    public init(pattern: String) {
        self.pattern = pattern
    }

    /// Case- and diacritic-insensitive substring match. Blank patterns never match.
    public func matches(_ title: String) -> Bool {
        let trimmed = pattern.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return title.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

public struct AlertSettings: Codable, Equatable, Sendable {
    public var calendarID: String?
    /// Seconds before the meeting start to show the alert.
    public var leadTime: TimeInterval = 60
    public var playSound = true
    public var soundName = "Glass"
    public var coverAllDisplays = true

    public var workingHoursOnly = false
    /// Minutes since midnight.
    public var workStartMinute = 9 * 60
    public var workEndMinute = 17 * 60
    /// `Calendar` weekday numbers: 1 = Sunday … 7 = Saturday.
    public var workDays: Set<Int> = [2, 3, 4, 5, 6]

    public var skipAllDay = true
    public var skipDeclined = true
    public var skipWithoutAttendees = false
    public var excludeRules: [ExcludeRule] = []

    public init() {}

    // Decode field-by-field so settings saved by older builds keep working when fields are added.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AlertSettings()
        calendarID = try c.decodeIfPresent(String.self, forKey: .calendarID) ?? d.calendarID
        leadTime = try c.decodeIfPresent(TimeInterval.self, forKey: .leadTime) ?? d.leadTime
        playSound = try c.decodeIfPresent(Bool.self, forKey: .playSound) ?? d.playSound
        soundName = try c.decodeIfPresent(String.self, forKey: .soundName) ?? d.soundName
        coverAllDisplays = try c.decodeIfPresent(Bool.self, forKey: .coverAllDisplays) ?? d.coverAllDisplays
        workingHoursOnly = try c.decodeIfPresent(Bool.self, forKey: .workingHoursOnly) ?? d.workingHoursOnly
        workStartMinute = try c.decodeIfPresent(Int.self, forKey: .workStartMinute) ?? d.workStartMinute
        workEndMinute = try c.decodeIfPresent(Int.self, forKey: .workEndMinute) ?? d.workEndMinute
        workDays = try c.decodeIfPresent(Set<Int>.self, forKey: .workDays) ?? d.workDays
        skipAllDay = try c.decodeIfPresent(Bool.self, forKey: .skipAllDay) ?? d.skipAllDay
        skipDeclined = try c.decodeIfPresent(Bool.self, forKey: .skipDeclined) ?? d.skipDeclined
        skipWithoutAttendees = try c.decodeIfPresent(Bool.self, forKey: .skipWithoutAttendees) ?? d.skipWithoutAttendees
        excludeRules = try c.decodeIfPresent([ExcludeRule].self, forKey: .excludeRules) ?? d.excludeRules
    }
}
