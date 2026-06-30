import FinanceCoreSDK
import Foundation

/// Resolves a transaction to its `TransactionType` by matching payee patterns.
public enum TransactionClassifier {
    /// The highest-priority live type whose payee patterns match, or `nil` (⇒ Other Spend).
    /// `types` should already be scoped to the relevant card.
    public static func type(for transaction: Transaction, in types: [TransactionType]) -> TransactionType? {
        types
            .filter { !$0.isDeleted && $0.matches(payee: transaction.payee) }
            .sorted { $0.priority > $1.priority }
            .first
    }

    public static func isPayment(_ transaction: Transaction, in types: [TransactionType]) -> Bool {
        type(for: transaction, in: types)?.kind == .payment
    }
}
