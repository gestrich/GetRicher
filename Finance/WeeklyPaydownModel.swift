import Foundation
import PersistenceService
import SwiftData

// MARK: - Domain Types

enum PivotDay: String, CaseIterable {
    case sunday = "Sunday"
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"

    var weekdayNumber: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}

struct PaydownCalculation {
    let currentBalance: Double
    let pendingAdjustment: Double
    let postPeriodAdjustment: Double
    let adjustedSpending: Double

    static func compute(
        account: PersistenceService.PlaidAccount?,
        periodTransactions: [PersistenceService.Transaction],
        postPeriodClearedTransactions: [PersistenceService.Transaction]
    ) -> PaydownCalculation {
        let balance = account.flatMap { Double($0.balance) } ?? 0.0
        let pendingTotal = periodTransactions
            .filter { $0.isPending }
            .reduce(0.0) { $0 + abs($1.toBase) }
        let postPeriodTotal = postPeriodClearedTransactions
            .reduce(0.0) { $0 + abs($1.toBase) }
        let adjusted = balance + pendingTotal - postPeriodTotal
        return PaydownCalculation(
            currentBalance: balance,
            pendingAdjustment: pendingTotal,
            postPeriodAdjustment: postPeriodTotal,
            adjustedSpending: adjusted
        )
    }
}

struct PaydownDateRange {
    let start: String
    let end: String

    static func compute(pivotDay: PivotDay, referenceDate: Date = Date()) -> PaydownDateRange {
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
}

// MARK: - Model

@MainActor @Observable
class WeeklyPaydownModel {

    var pivotDay: PivotDay = .saturday

    func account(id accountId: Int?, from accounts: [PersistenceService.PlaidAccount]) -> PersistenceService.PlaidAccount? {
        guard let accountId = accountId else { return nil }
        return accounts.first { $0.lunchMoneyId == accountId }
    }

    var dateRange: PaydownDateRange {
        PaydownDateRange.compute(pivotDay: pivotDay)
    }

    func periodTransactions(accountId: Int?, from transactions: [PersistenceService.Transaction]) -> [PersistenceService.Transaction] {
        let range = dateRange
        return transactions.filter { tx in
            let accountMatch = accountId == nil || tx.plaidAccountId == accountId
            let dateMatch = tx.date > range.start && tx.date <= range.end
            return accountMatch && dateMatch && !tx.isIncome
        }
    }

    func postPeriodClearedTransactions(accountId: Int?, from transactions: [PersistenceService.Transaction]) -> [PersistenceService.Transaction] {
        let range = dateRange
        return transactions.filter { tx in
            let accountMatch = accountId == nil || tx.plaidAccountId == accountId
            let isAfterPeriod = tx.date > range.end
            let isCleared = tx.status.lowercased() == "cleared"
            return accountMatch && isAfterPeriod && isCleared && !tx.isIncome
        }
    }

    func calculation(
        accountId: Int?,
        accounts: [PersistenceService.PlaidAccount],
        transactions: [PersistenceService.Transaction]
    ) -> PaydownCalculation {
        PaydownCalculation.compute(
            account: account(id: accountId, from: accounts),
            periodTransactions: periodTransactions(accountId: accountId, from: transactions),
            postPeriodClearedTransactions: postPeriodClearedTransactions(accountId: accountId, from: transactions)
        )
    }
}
