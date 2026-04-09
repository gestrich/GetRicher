import Foundation
import PersistenceService
import SwiftData
import SyncService

public struct SyncTransactionsUseCase: Sendable {
    private let syncCoordinator: SyncCoordinator

    public init(syncCoordinator: SyncCoordinator) {
        self.syncCoordinator = syncCoordinator
    }

    public struct Result: Sendable {
        public let accounts: SyncResult
        public let transactions: SyncResult
    }

    @MainActor
    public func run(
        context: ModelContext,
        accountId: Int?,
        startDate: Date,
        endDate: Date
    ) async throws -> Result {
        let results = try await syncCoordinator.sync(
            context: context,
            accountId: accountId,
            startDate: startDate,
            endDate: endDate
        )
        return Result(accounts: results.accounts, transactions: results.transactions)
    }
}
