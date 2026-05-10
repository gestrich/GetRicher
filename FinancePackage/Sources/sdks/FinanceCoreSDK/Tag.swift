import Foundation

public struct Tag: Sendable, Codable {
    public let lunchMoneyId: Int?
    public let name: String?

    public init(lunchMoneyId: Int? = nil, name: String? = nil) {
        self.lunchMoneyId = lunchMoneyId
        self.name = name
    }
}
