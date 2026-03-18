import Foundation
import SwiftData

@Model
public final class Tag {
    public var lunchMoneyId: Int?
    public var name: String?
    public var transaction: Transaction?

    public init(lunchMoneyId: Int? = nil, name: String? = nil) {
        self.lunchMoneyId = lunchMoneyId
        self.name = name
    }
}
