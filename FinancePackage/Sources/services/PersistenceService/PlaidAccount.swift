import Foundation
import SwiftData

@Model
public final class PlaidAccount {
    #Unique<PlaidAccount>([\.lunchMoneyId])

    public var lunchMoneyId: Int
    public var name: String
    public var displayName: String
    public var type: String
    public var subtype: String
    public var mask: String
    public var institutionName: String
    public var status: String
    public var balance: String
    public var currency: String

    public init(
        lunchMoneyId: Int,
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
        self.lunchMoneyId = lunchMoneyId
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
