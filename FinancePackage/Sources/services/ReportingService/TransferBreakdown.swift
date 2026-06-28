import FinanceCoreSDK
import Foundation

/// One "source bucket" of a card's period spending: the charges that a given account funds.
/// Cloud 9 → Reserve, everything else → the default account, etc. `amount` is the **signed net**
/// of charges in the bucket (refunds reduce it). Card payments are excluded before bucketing.
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

    /// Allocates a card's period transactions into per-source buckets.
    ///
    /// - `payment`-kind rules identify card payments (settlements); those transactions are dropped
    ///   entirely — they are not spending and must never roll up into an amount owed.
    /// - `transfer`-kind rules with a vendor route matching charges to that rule's source account.
    /// - A single `transfer`-kind rule with no vendor is the default bucket ("everything else").
    /// - Any remaining charges with no default rule land in an "Unspecified" bucket.
    ///
    /// Each bucket's `amount` is the signed sum of `toBase`, so a refund nets against charges in the
    /// same bucket.
    public static func compute(
        accountId: Int,
        periodTransactions: [Transaction],
        vendors: [Vendor],
        rules: [TransferRule],
        accounts: [Account]
    ) -> [TransferBreakdown] {
        let accountRules = rules.filter { $0.targetAccountId == accountId }
        let paymentRules = accountRules.filter { $0.kind == .payment }
        let transferRules = accountRules
            .filter { $0.kind == .transfer && $0.vendor != nil }
            .sorted { $0.priority > $1.priority }
        let defaultRule = accountRules.first { $0.kind == .transfer && $0.vendor == nil }

        func isPayment(_ tx: Transaction) -> Bool {
            paymentRules.contains { rule in
                guard let vendor = rule.vendor else { return false }
                return tx.payee.localizedCaseInsensitiveContains(vendor.filterText)
            }
        }

        // Drop card payments; what remains is spending (charges, net of refunds).
        let charges = periodTransactions.filter { !isPayment($0) }

        var ruleTransactions: [UUID: [Transaction]] = [:]
        var unspecified: [Transaction] = []
        for transaction in charges {
            if let rule = transferRules.first(where: { rule in
                guard let vendor = rule.vendor else { return false }
                return transaction.payee.localizedCaseInsensitiveContains(vendor.filterText)
            }) {
                ruleTransactions[rule.id, default: []].append(transaction)
            } else if let defaultRule {
                ruleTransactions[defaultRule.id, default: []].append(transaction)
            } else {
                unspecified.append(transaction)
            }
        }

        let orderedRules = transferRules + (defaultRule.map { [$0] } ?? [])
        var result: [TransferBreakdown] = orderedRules.compactMap { rule in
            let txs = ruleTransactions[rule.id] ?? []
            guard !txs.isEmpty else { return nil }
            let total = txs.reduce(0.0) { $0 + $1.toBase }
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
        if !unspecified.isEmpty {
            let total = unspecified.reduce(0.0) { $0 + $1.toBase }
            result.append(TransferBreakdown(
                sourceAccountId: nil,
                sourceAccountName: "Unspecified",
                ruleName: "Unspecified",
                amount: total,
                transactionCount: unspecified.count
            ))
        }
        return result
    }
}
