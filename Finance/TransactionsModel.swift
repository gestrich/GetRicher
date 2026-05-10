import ClientService
import Foundation
import KeychainSDK
import LoggingSDK
import PersistenceService
import SwiftData
import SyncService

@MainActor @Observable
class TransactionsModel: Identifiable {
    let id = UUID()
    var syncState: SyncState = .idle

    private let syncCoordinator: SyncCoordinator
    private let logger = Logger(label: "GetRicher.TransactionsModel")
    let syncClient: any FinanceSyncClientProtocol

    init(syncClient: any FinanceSyncClientProtocol, keychainClient: any KeychainClientProtocol) {
        self.syncClient = syncClient
        self.syncCoordinator = SyncCoordinator(
            syncClient: syncClient,
            keychainClient: keychainClient
        )
    }

    func sync(context: ModelContext, accountId: Int?, startDate: Date, endDate: Date) {
        syncState = .syncing
        Task {
            await performSync(context: context, accountId: accountId, startDate: startDate, endDate: endDate)
        }
    }

    func syncAndWait(context: ModelContext, accountId: Int?, startDate: Date, endDate: Date) async {
        syncState = .syncing
        await performSync(context: context, accountId: accountId, startDate: startDate, endDate: endDate)
    }

    private func performSync(context: ModelContext, accountId: Int?, startDate: Date, endDate: Date) async {
        logger.info("Starting sync (accountId: \(accountId.map(String.init) ?? "all"))")
        do {
            let results = try await syncCoordinator.sync(
                context: context,
                accountId: accountId,
                startDate: startDate,
                endDate: endDate
            )
            let count = results.transactions.inserted + results.transactions.updated
            if count == 0 && !results.transactions.hasChanges {
                logger.notice("Sync completed with no transactions — dashboard may show empty state")
            } else {
                logger.info("Sync completed: \(results.transactions.inserted) inserted, \(results.transactions.updated) updated")
            }
            syncState = .synced(results.transactions)
        } catch {
            logger.error("Sync failed: \(error.localizedDescription)")
            syncState = .error(error.localizedDescription)
        }
    }

    var isSyncing: Bool {
        if case .syncing = syncState { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let message) = syncState { return message }
        return nil
    }

    enum SyncState {
        case idle
        case syncing
        case synced(SyncResult)
        case error(String)
    }
}
