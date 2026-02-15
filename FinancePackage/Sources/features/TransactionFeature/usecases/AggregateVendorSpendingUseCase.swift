import CoreService
import Uniflow

public struct AggregateVendorSpendingUseCase: UseCase {
    public struct Options: Sendable {
        public let transactions: [Transaction]

        public init(transactions: [Transaction]) {
            self.transactions = transactions
        }
    }

    public typealias Result = [VendorSpending]

    public init() {}

    public func run(options: Options) async throws -> [VendorSpending] {
        VendorSpending.aggregate(from: options.transactions)
    }
}
