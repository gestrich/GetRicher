import Foundation

/// What a `TransactionType` represents for the paydown.
public enum TransactionTypeKind: String, Sendable, Codable, Hashable {
    /// A purchase or refund — counts as spending.
    case spend
    /// A settlement that pays the card down (e.g. "THANK YOU FOR YOUR PMT") — never counted as
    /// spending and never adjusted in the Payments Owed math.
    case payment
}

/// A user-defined classification of credit-card transactions, identified by payee patterns.
/// Replaces the old Vendor + TransferRule + RuleKind for the paydown.
public struct TransactionType: Identifiable, Sendable, Codable, Hashable, LWWMergeable {
    public let id: UUID
    public var name: String
    public var kind: TransactionTypeKind
    /// `.spend` types only: the other account that funds this spend (e.g. Cloud 9 → Six Month
    /// Reserve). `nil` ⇒ funded from the primary payment. Ignored for `.payment` types.
    public var fundingAccountId: Int?
    /// Which credit card this type applies to.
    public var targetAccountId: Int
    /// Case-insensitive payee substrings; a transaction matches if its payee contains any of them.
    public var payeePatterns: [String]
    /// Higher priority matches first when a transaction could match multiple types.
    public var priority: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var isDeleted: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        kind: TransactionTypeKind,
        fundingAccountId: Int? = nil,
        targetAccountId: Int,
        payeePatterns: [String] = [],
        priority: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDeleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.fundingAccountId = fundingAccountId
        self.targetAccountId = targetAccountId
        self.payeePatterns = payeePatterns
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    /// Whether this type matches a payee (case-insensitive substring on any pattern).
    public func matches(payee: String) -> Bool {
        payeePatterns.contains { !$0.isEmpty && payee.localizedCaseInsensitiveContains($0) }
    }
}
