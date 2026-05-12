import Foundation

public struct BudgetPeriod: Identifiable, Hashable, Sendable {
    public let start: Date
    public let end: Date

    public var id: String { "\(startString)-\(endString)" }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    public var startString: String { Self.formatter.string(from: start) }
    public var endString: String { Self.formatter.string(from: end) }

    public var displayLabel: String {
        let s = Self.displayFormatter.string(from: start)
        let e = Self.displayFormatter.string(from: end)
        return "\(s) – \(e)"
    }

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    /// Generates budget periods. The pivot day is the FIRST day of a period (e.g., Saturday starts a week).
    /// Period 0 is the current in-progress period: start = most recent pivot, end = today (both inclusive).
    /// Period N (N≥1) is a completed prior week: 7 days ending the day before period N-1's start.
    public static func periods(count: Int, pivotDay: PivotDay, referenceDate: Date = Date()) -> [BudgetPeriod] {
        let calendar = Calendar.current
        let targetWeekday = pivotDay.weekdayNumber
        let today = calendar.startOfDay(for: referenceDate)

        var mostRecentPivot = today
        while calendar.component(.weekday, from: mostRecentPivot) != targetWeekday {
            mostRecentPivot = calendar.date(byAdding: .day, value: -1, to: mostRecentPivot)!
        }

        var result: [BudgetPeriod] = []
        result.append(BudgetPeriod(start: mostRecentPivot, end: today))

        var nextPivot = mostRecentPivot
        for _ in 1..<count {
            let periodEnd = calendar.date(byAdding: .day, value: -1, to: nextPivot)!
            let periodStart = calendar.date(byAdding: .day, value: -7, to: nextPivot)!
            result.append(BudgetPeriod(start: periodStart, end: periodEnd))
            nextPivot = periodStart
        }

        return result
    }
}
