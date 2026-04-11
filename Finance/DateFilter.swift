import Foundation

struct BudgetPeriod: Identifiable, Hashable {
    let start: Date
    let end: Date

    var id: String { "\(startString)-\(endString)" }

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

    var startString: String { Self.formatter.string(from: start) }
    var endString: String { Self.formatter.string(from: end) }

    var displayLabel: String {
        let s = Self.displayFormatter.string(from: start)
        let e = Self.displayFormatter.string(from: end)
        return "\(s) – \(e)"
    }

    /// Generates budget periods based on the pivot day.
    /// Period 0 is the current (in-progress) period: from the most recent pivot day through today.
    /// Period 1 is the one just before that, etc.
    static func periods(count: Int, pivotDay: PivotDay, referenceDate: Date = Date()) -> [BudgetPeriod] {
        let calendar = Calendar.current
        let targetWeekday = pivotDay.weekdayNumber
        let today = calendar.startOfDay(for: referenceDate)

        // Find the most recent pivot day (on or before today)
        var mostRecentPivot = today
        while calendar.component(.weekday, from: mostRecentPivot) != targetWeekday {
            mostRecentPivot = calendar.date(byAdding: .day, value: -1, to: mostRecentPivot)!
        }

        var result: [BudgetPeriod] = []

        // Period 0: current (in-progress) — from mostRecentPivot to today.
        // When today is the pivot day, extend end to tomorrow so the API
        // gets a valid range (end_date must be after start_date).
        let currentEnd = mostRecentPivot == today
            ? calendar.date(byAdding: .day, value: 1, to: today)!
            : today
        result.append(BudgetPeriod(start: mostRecentPivot, end: currentEnd))

        // Past periods: each is 7 days
        var periodEnd = calendar.date(byAdding: .day, value: -1, to: mostRecentPivot)!
        for _ in 1..<count {
            let periodStart = calendar.date(byAdding: .day, value: -6, to: periodEnd)!
            result.append(BudgetPeriod(start: periodStart, end: periodEnd))
            periodEnd = calendar.date(byAdding: .day, value: -7, to: periodEnd)!
        }

        return result
    }
}
