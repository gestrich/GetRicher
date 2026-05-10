import Foundation

public struct PaydownDateRange: Sendable {
    public let start: String
    public let end: String

    public init(start: String, end: String) {
        self.start = start
        self.end = end
    }

    public static func compute(pivotDay: PivotDay, referenceDate: Date = Date()) -> PaydownDateRange {
        let calendar = Calendar.current
        let targetWeekday = pivotDay.weekdayNumber
        var end = referenceDate
        while calendar.component(.weekday, from: end) != targetWeekday {
            end = calendar.date(byAdding: .day, value: -1, to: end)!
        }
        end = calendar.startOfDay(for: end)
        let start = calendar.date(byAdding: .day, value: -7, to: end)!

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return PaydownDateRange(start: formatter.string(from: start), end: formatter.string(from: end))
    }

    /// Returns a range from the most recent pivot day through today.
    /// `start` is set to one day before the pivot so Saturday transactions are captured
    /// by the existing `tx.date > start && tx.date <= end` filter convention.
    public static func computeCurrentPeriod(pivotDay: PivotDay, referenceDate: Date = Date()) -> PaydownDateRange {
        let calendar = Calendar.current
        let targetWeekday = pivotDay.weekdayNumber
        var pivotDate = calendar.startOfDay(for: referenceDate)
        while calendar.component(.weekday, from: pivotDate) != targetWeekday {
            pivotDate = calendar.date(byAdding: .day, value: -1, to: pivotDate)!
        }
        let start = calendar.date(byAdding: .day, value: -1, to: pivotDate)!
        let end = calendar.startOfDay(for: referenceDate)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return PaydownDateRange(start: formatter.string(from: start), end: formatter.string(from: end))
    }
}
