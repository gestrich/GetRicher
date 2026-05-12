import Foundation

public struct PaydownDateRange: Sendable {
    public let start: String
    public let end: String

    public init(start: String, end: String) {
        self.start = start
        self.end = end
    }

    /// Returns the most recent completed weekly period.
    /// The pivot day is the FIRST day of a period (e.g., Saturday starts a week with Saturday pivot).
    /// Completed period: start = prior pivot, end = day before this pivot (7 days, inclusive on both ends).
    public static func compute(pivotDay: PivotDay, referenceDate: Date = Date()) -> PaydownDateRange {
        let calendar = Calendar.current
        let mostRecent = mostRecentPivot(pivotDay: pivotDay, referenceDate: referenceDate, calendar: calendar)
        let end = calendar.date(byAdding: .day, value: -1, to: mostRecent)!
        let start = calendar.date(byAdding: .day, value: -7, to: mostRecent)!
        return PaydownDateRange(start: format(start), end: format(end))
    }

    /// Returns the current in-progress weekly period: from the most recent pivot (inclusive)
    /// through today (inclusive). Pairs with the `>= start && <= end` filter convention.
    public static func computeCurrentPeriod(pivotDay: PivotDay, referenceDate: Date = Date()) -> PaydownDateRange {
        let calendar = Calendar.current
        let mostRecent = mostRecentPivot(pivotDay: pivotDay, referenceDate: referenceDate, calendar: calendar)
        let end = calendar.startOfDay(for: referenceDate)
        return PaydownDateRange(start: format(mostRecent), end: format(end))
    }

    private static func mostRecentPivot(pivotDay: PivotDay, referenceDate: Date, calendar: Calendar) -> Date {
        var date = calendar.startOfDay(for: referenceDate)
        while calendar.component(.weekday, from: date) != pivotDay.weekdayNumber {
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        }
        return date
    }

    private static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
