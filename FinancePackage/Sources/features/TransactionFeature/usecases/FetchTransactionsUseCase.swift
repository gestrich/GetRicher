import CoreService
import Foundation
import KeychainSDK
import LunchMoneySDK
import Uniflow

public struct FetchTransactionsUseCase: UseCase {
    public struct Options: Sendable {
        public let accountId: Int?
        public let startDate: Date
        public let endDate: Date
        public let existingTransactions: [Transaction]
        public let offset: Int

        public init(accountId: Int?, startDate: Date, endDate: Date, existingTransactions: [Transaction], offset: Int) {
            self.accountId = accountId
            self.startDate = startDate
            self.endDate = endDate
            self.existingTransactions = existingTransactions
            self.offset = offset
        }
    }

    public struct Result: Sendable {
        public let transactions: [Transaction]
        public let hasMore: Bool
    }

    private let lunchMoneyClient: any LunchMoneyClientProtocol
    private let keychainClient: any KeychainClientProtocol
    private let pageSize: Int

    public init(
        lunchMoneyClient: any LunchMoneyClientProtocol,
        keychainClient: any KeychainClientProtocol,
        pageSize: Int
    ) {
        self.lunchMoneyClient = lunchMoneyClient
        self.keychainClient = keychainClient
        self.pageSize = pageSize
    }

    public func run(options: Options) async throws -> Result {
        guard let token = keychainClient.getAPIToken() else {
            throw FetchTransactionsError.noAPIToken
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let response = try await lunchMoneyClient.fetchTransactions(
            token: token,
            accountId: options.accountId,
            startDate: dateFormatter.string(from: options.startDate),
            endDate: dateFormatter.string(from: options.endDate),
            limit: pageSize,
            offset: options.offset
        )

        let newTransactions = response.transactions.map(TransactionMapper.map)
        let hasMore = newTransactions.count == pageSize

        var allTransactions = options.existingTransactions
        allTransactions.append(contentsOf: newTransactions)
        allTransactions.sort { $0.date > $1.date }

        return Result(transactions: allTransactions, hasMore: hasMore)
    }
}

public enum FetchTransactionsError: Error, Sendable {
    case noAPIToken
}
