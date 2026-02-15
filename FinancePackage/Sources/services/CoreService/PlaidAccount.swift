import Foundation

public struct PlaidAccount: Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let displayName: String
    public let type: String
    public let subtype: String
    public let mask: String
    public let institutionName: String
    public let status: String
    public let balance: String
    public let currency: String

    public init(
        id: Int,
        name: String,
        displayName: String,
        type: String,
        subtype: String,
        mask: String,
        institutionName: String,
        status: String,
        balance: String,
        currency: String
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.type = type
        self.subtype = subtype
        self.mask = mask
        self.institutionName = institutionName
        self.status = status
        self.balance = balance
        self.currency = currency
    }
}
