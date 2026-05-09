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

    /// Generates budget periods based on the pivot day.
    /// Period 0 is the current (in-progress) period; period 1 is the one just completed, etc.
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

        var periodEnd = calendar.date(byAdding: .day, value: -1, to: mostRecentPivot)!
        for _ in 1..<count {
            let periodStart = calendar.date(byAdding: .day, value: -6, to: periodEnd)!
            result.append(BudgetPeriod(start: periodStart, end: periodEnd))
            periodEnd = calendar.date(byAdding: .day, value: -7, to: periodEnd)!
        }

        return result
    }
}
