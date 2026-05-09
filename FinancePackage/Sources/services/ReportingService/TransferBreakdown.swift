import FinanceCoreSDK
import Foundation

public struct TransferBreakdown: Identifiable, Sendable {
    public let id: UUID
    public let sourceAccountId: Int?
    public let sourceAccountName: String
    public let ruleName: String
    public let amount: Double
    public let transactionCount: Int

    public init(
        id: UUID = UUID(),
        sourceAccountId: Int?,
        sourceAccountName: String,
        ruleName: String,
        amount: Double,
        transactionCount: Int
    ) {
        self.id = id
        self.sourceAccountId = sourceAccountId
        self.sourceAccountName = sourceAccountName
        self.ruleName = ruleName
        self.amount = amount
        self.transactionCount = transactionCount
    }

    public static func compute(
        accountId: Int,
        periodTransactions: [Transaction],
        vendors: [Vendor],
        rules: [TransferRule],
        accounts: [Account]
    ) -> [TransferBreakdown] {
        let accountRules = rules
            .filter { $0.targetAccountId == accountId }
            .sorted { $0.priority > $1.priority }

        guard !accountRules.isEmpty else { return [] }

        var ruleTransactions: [UUID: [Transaction]] = [:]
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
