import Foundation
import KeychainSDK
import LunchMoneySDK
import PersistenceService
import SwiftData

public struct SyncCoordinator: Sendable {
    private let lunchMoneyClient: any LunchMoneyClientProtocol
    private let keychainClient: any KeychainClientProtocol
    private let transactionSync: TransactionSyncService
    private let accountSync: AccountSyncService
    private let pageSize: Int

    public init(
        lunchMoneyClient: any LunchMoneyClientProtocol,
        keychainClient: any KeychainClientProtocol,
        pageSize: Int = 200
    ) {
        self.lunchMoneyClient = lunchMoneyClient
        self.keychainClient = keychainClient
        self.transactionSync = TransactionSyncService()
        self.accountSync = AccountSyncService()
        self.pageSize = pageSize
    }

    /// Sync both accounts and transactions for the given date range.
    @MainActor
    public func sync(
        context: ModelContext,
        accountId: Int?,
        startDate: Date,
        endDate: Date
    ) async throws -> (accounts: SyncResult, transactions: SyncResult) {
        guard let token = keychainClient.getAPIToken() else {
            throw SyncError.noAPIToken
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let start = dateFormatter.string(from: startDate)
        let end = dateFormatter.string(from: endDate)

        // Fetch accounts
        let accountsResponse = try await lunchMoneyClient.fetchPlaidAccounts(token: token)
        let accountResult = try accountSync.sync(dtos: accountsResponse.plaidAccounts, context: context)

        // Fetch all transaction pages
        var allTransactionDTOs: [TransactionDTO] = []
        var offset = 0
        var hasMore = true
        while hasMore {
            let response = try await lunchMoneyClient.fetchTransactions(
                token: token,
                accountId: accountId,
                startDate: start,
                endDate: end,
                limit: pageSize,
                offset: offset
            )
            allTransactionDTOs.append(contentsOf: response.transactions)
            hasMore = response.transactions.count == pageSize
            offset += pageSize
        }

        let transactionResult = try transactionSync.sync(dtos: allTransactionDTOs, context: context)

        return (accounts: accountResult, transactions: transactionResult)
    }
}

public enum SyncError: Error, Sendable {
    case noAPIToken
}
