import Foundation
import KeychainSDK
import LunchMoneySDK
import PersistenceService
import SwiftData
import SyncService
import TransactionFeature

@MainActor @Observable
class TransactionsModel: Identifiable {
    let id = UUID()
    var syncState: SyncState = .idle

    private let syncUseCase: SyncTransactionsUseCase

    init(lunchMoneyClient: any LunchMoneySDK.LunchMoneyClientProtocol, keychainClient: any KeychainSDK.KeychainClientProtocol, pageSize: Int) {
        let syncCoordinator = SyncCoordinator(
            lunchMoneyClient: lunchMoneyClient,
            keychainClient: keychainClient,
            pageSize: pageSize
        )
        self.syncUseCase = SyncTransactionsUseCase(syncCoordinator: syncCoordinator)
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
            let result = try await syncUseCase.run(
                context: context,
                accountId: accountId,
                startDate: startDate,
                endDate: endDate
            )
            syncState = .synced(result.transactions)
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
