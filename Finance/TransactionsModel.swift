import Foundation
import KeychainSDK
import LunchMoneySDK
import PersistenceService
import SwiftData
import SyncService

@MainActor @Observable
class TransactionsModel: Identifiable {
    let id = UUID()
    var syncState: SyncState = .idle

    private let syncCoordinator: SyncCoordinator

    init(lunchMoneyClient: any LunchMoneyClientProtocol, keychainClient: any KeychainClientProtocol, pageSize: Int) {
        self.syncCoordinator = SyncCoordinator(
            lunchMoneyClient: lunchMoneyClient,
            keychainClient: keychainClient,
            pageSize: pageSize
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
        do {
            let results = try await syncCoordinator.sync(
                context: context,
                accountId: accountId,
                startDate: startDate,
                endDate: endDate
            )
            syncState = .synced(results.transactions)
        } catch {
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
