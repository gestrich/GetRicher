import FinanceCoreSDK

public struct LoggingTransactionStore: TransactionStoreProtocol {
    public init() {}

    public func store(_ transactions: [Transaction], userId: String) async throws {
        print("[TransactionStore] STUB store \(transactions.count) transaction(s) for userId=\(userId)")
    }

    public func fetch(userId: String, startDate: String, endDate: String) async throws -> [Transaction] {
        print("[TransactionStore] STUB fetch userId=\(userId) start=\(startDate) end=\(endDate) -> []")
        return []
    }
}
