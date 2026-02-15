import Foundation

enum DateFilter: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All"

    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .week:
            let sunday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (sunday, now)
        case .month:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (startOfMonth, now)
        case .year:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return (startOfYear, now)
        case .all:
            let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: now)!
            return (twoYearsAgo, now)
        }
    }
}
