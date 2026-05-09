import Foundation

public struct Tag: Sendable {
    public let lunchMoneyId: Int?
    public let name: String?

    public init(lunchMoneyId: Int? = nil, name: String? = nil) {
        self.lunchMoneyId = lunchMoneyId
        self.name = name
    }
}
