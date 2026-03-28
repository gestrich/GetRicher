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

struct MatchedTransfer: Identifiable {
    let id = UUID()
    let transaction: PersistenceService.Transaction
    let pattern: PersistenceService.TransferPattern
    let sourceAccountName: String
}

struct TransferBreakdown: Identifiable {
    let id = UUID()
    let sourceAccountId: Int?
    let sourceAccountName: String
    let ruleName: String
    let amount: Double
    let transactionCount: Int
}

// MARK: - Model

@MainActor @Observable
class WeeklyPaydownModel {

    var pivotDay: PivotDay = .saturday {
        didSet { refreshPeriods() }
    }
    var budgetPeriods: [BudgetPeriod] = []
    var selectedPeriod: BudgetPeriod?

    init() {
        refreshPeriods()
    }

    func refreshPeriods() {
        let periods = BudgetPeriod.periods(count: 11, pivotDay: pivotDay)
        budgetPeriods = periods
        // Default to the most recent completed period (index 1) if available
        selectedPeriod = periods.count > 1 ? periods[1] : periods.first
    }

    func account(id accountId: Int?, from accounts: [PersistenceService.PlaidAccount]) -> PersistenceService.PlaidAccount? {
        guard let accountId = accountId else { return nil }
        return accounts.first { $0.lunchMoneyId == accountId }
    }

    var dateRange: PaydownDateRange {
        guard let period = selectedPeriod else {
            return PaydownDateRange.compute(pivotDay: pivotDay)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return PaydownDateRange(
            start: formatter.string(from: period.start),
            end: formatter.string(from: period.end)
        )
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
            let isPosted = !tx.isPending
            return accountMatch && isAfterPeriod && isPosted && !tx.isIncome
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

    func matchedTransfers(
        accountId: Int,
        periodTransactions: [PersistenceService.Transaction],
        patterns: [PersistenceService.TransferPattern],
        accounts: [PersistenceService.PlaidAccount]
    ) -> [MatchedTransfer] {
        let accountPatterns = patterns.filter { $0.targetAccountId == accountId }
        guard !accountPatterns.isEmpty else { return [] }

        // Credits have negative toBase
        let credits = periodTransactions.filter { $0.toBase < 0 }
        var matches: [MatchedTransfer] = []
        for tx in credits {
            for pattern in accountPatterns {
                if tx.payee.localizedCaseInsensitiveContains(pattern.matchText) {
                    let sourceName = accounts.first { $0.lunchMoneyId == pattern.sourceAccountId }?.displayName ?? "Unknown"
                    matches.append(MatchedTransfer(transaction: tx, pattern: pattern, sourceAccountName: sourceName))
                    break
                }
            }
        }
        return matches
    }

    func nonTransferTransactions(
        periodTransactions: [PersistenceService.Transaction],
        matchedTransfers: [MatchedTransfer]
    ) -> [PersistenceService.Transaction] {
        let transferIds = Set(matchedTransfers.map { $0.transaction.lunchMoneyId })
        return periodTransactions.filter { !transferIds.contains($0.lunchMoneyId) }
    }

    func transferBreakdown(
        accountId: Int,
        periodTransactions: [PersistenceService.Transaction],
        vendors: [PersistenceService.Vendor],
        rules: [PersistenceService.TransferRule],
        accounts: [PersistenceService.PlaidAccount]
    ) -> [TransferBreakdown] {
        let accountRules = rules
            .filter { $0.targetAccountId == accountId }
            .sorted { $0.priority > $1.priority }

        guard !accountRules.isEmpty else { return [] }

        let accountVendors = vendors.filter { $0.accountId == accountId || $0.accountId == nil }

        // Group transactions by matched rule
        var ruleTransactions: [UUID: [PersistenceService.Transaction]] = [:]
        for rule in accountRules {
            ruleTransactions[rule.id] = []
        }

        for transaction in periodTransactions {
            var matched = false
            for rule in accountRules {
                guard let vendor = rule.vendor else { continue }
                if transaction.payee.localizedCaseInsensitiveContains(vendor.filterText) {
                    ruleTransactions[rule.id, default: []].append(transaction)
                    matched = true
                    break
                }
            }
            if !matched {
                // Find default rule (vendor == nil)
                if let defaultRule = accountRules.first(where: { $0.vendor == nil }) {
                    ruleTransactions[defaultRule.id, default: []].append(transaction)
                }
            }
        }

        return accountRules.compactMap { rule in
            let txs = ruleTransactions[rule.id] ?? []
            guard !txs.isEmpty else { return nil }
            let total = txs.reduce(0.0) { $0 + abs($1.toBase) }
            let sourceName = rule.sourceAccountId.flatMap { srcId in
                accounts.first { $0.lunchMoneyId == srcId }?.displayName
            } ?? "Unspecified"

            return TransferBreakdown(
                sourceAccountId: rule.sourceAccountId,
                sourceAccountName: sourceName,
                ruleName: rule.name,
                amount: total,
                transactionCount: txs.count
            )
        }
    }
}
