import FinanceCoreSDK

public protocol TransactionStoreProtocol: Sendable {
    func store(_ transactions: [Transaction], userId: String) async throws
    /// Upserts `transactions`, then deletes any rows in [startDate, endDate]
    /// for `userId` whose lunchMoneyId isn't in the supplied batch. Used by
    /// refresh to evict orphaned pending rows that LM has replaced with a
    /// new lunchMoneyId on clearing.
    func replaceWindow(
        _ transactions: [Transaction],
        userId: String,
        startDate: String,
        endDate: String
    ) async throws
    func fetch(userId: String, startDate: String, endDate: String) async throws -> [Transaction]
    func deleteAll(userId: String) async throws
}
