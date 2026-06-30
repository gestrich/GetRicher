import FinanceCoreSDK

public struct LoggingTransactionTypeStore: TransactionTypeStoreProtocol {
    public init() {}

    public func replaceAll(_ rules: [TransactionType], userId: String) async throws {
        print("[TransactionTypeStore] STUB replaceAll \(rules.count) type(s) for userId=\(userId)")
    }

    public func fetchAll(userId: String) async throws -> [TransactionType] {
        print("[TransactionTypeStore] STUB fetchAll userId=\(userId) -> []")
        return []
    }

    public func deleteAll(userId: String) async throws {
        print("[TransactionTypeStore] STUB deleteAll userId=\(userId)")
    }
}
