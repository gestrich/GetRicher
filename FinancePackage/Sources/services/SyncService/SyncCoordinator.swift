import ClientService
import FinanceCoreSDK
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

        // Last-write-wins merge of TransferRules + Vendors with the server, then adopt the merged
        // result locally. Sends local state (incl. tombstones), the server merges and returns the
        // union, and we reconcile it back — so neither side clobbers the other.
        try await mergeRulesAndVendors(context: context, username: username, password: password)

        return (accounts: accountResult, transactions: transactionResult)
    }

    @MainActor
    public func mergeRulesAndVendors(context: ModelContext, username: String, password: String) async throws {
        let localVendors = (try? context.fetch(FetchDescriptor<PersistenceService.Vendor>())) ?? []
        let localRules = (try? context.fetch(FetchDescriptor<PersistenceService.TransferRule>())) ?? []
        let domainVendors = localVendors.map { $0.toDomain() }
        let domainRules = localRules.map { $0.toDomain() }
        let mergedVendors: [FinanceCoreSDK.Vendor]
        let mergedRules: [FinanceCoreSDK.TransferRule]
        do {
            mergedVendors = try await syncClient.putVendors(username: username, password: password, vendors: domainVendors)
        } catch {
            throw SyncError.mergeFailed("putVendors (sent \(domainVendors.count)): \(error)")
        }
        do {
            mergedRules = try await syncClient.putTransferRules(username: username, password: password, rules: domainRules)
        } catch {
            throw SyncError.mergeFailed("putTransferRules (sent \(domainRules.count)): \(error)")
        }
        do {
            try RuleVendorSyncService().apply(vendors: mergedVendors, rules: mergedRules, context: context)
        } catch {
            throw SyncError.mergeFailed("apply (\(mergedRules.count) rules, \(mergedVendors.count) vendors): \(error)")
        }
    }
}

public enum SyncError: Error, Sendable, LocalizedError {
    case noCredentials
    case mergeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noCredentials: return "No credentials"
        case .mergeFailed(let detail): return "Rule/vendor merge failed — \(detail)"
        }
    }
}
