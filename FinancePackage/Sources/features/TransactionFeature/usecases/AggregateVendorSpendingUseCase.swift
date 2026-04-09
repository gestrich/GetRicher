import Foundation
import PersistenceService

public struct AggregateVendorSpendingUseCase: Sendable {

    public init() {}

    @MainActor
    public func run(transactions: [Transaction]) -> [VendorSpending] {
        VendorSpending.aggregate(from: transactions)
    }
}
