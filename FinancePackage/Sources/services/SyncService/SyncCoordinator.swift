import ClientService
import Foundation
import KeychainSDK
import PersistenceService
import SwiftData

public struct SyncCoordinator: Sendable {
    private let syncClient: any FinanceSyncClientProtocol
    private let keychainClient: any KeychainClientProtocol
    private let transactionSync: TransactionSyncService
    private let accountSync: AccountSyncService

    public init(
        syncClient: any FinanceSyncClientProtocol,
        keychainClient: any KeychainClientProtocol
    ) {
        self.syncClient = syncClient
        self.keychainClient = keychainClient
        self.transactionSync = TransactionSyncService()
        self.accountSync = AccountSyncService()
    }

    @MainActor
    public func sync(
        context: ModelContext,
        accountId: Int?,
        startDate: Date,
        endDate: Date
    ) async throws -> (accounts: SyncResult, transactions: SyncResult) {
        guard let username = keychainClient.getUsername(), !username.isEmpty,
              let password = keychainClient.getPassword(), !password.isEmpty
        else {
            throw SyncError.noCredentials
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let start = dateFormatter.string(from: startDate)
        let end = dateFormatter.string(from: endDate)

        let accounts = try await syncClient.fetchAccounts(username: username, password: password)
        let accountResult = try accountSync.sync(accounts: accounts, context: context)

        let allTransactions = try await syncClient.fetchTransactions(
            username: username,
            password: password,
            startDate: start,
            endDate: end
        )
        let transactionResult = try transactionSync.sync(transactions: allTransactions, context: context)

        return (accounts: accountResult, transactions: transactionResult)
    }
}

public enum SyncError: Error, Sendable {
    case noCredentials
}
