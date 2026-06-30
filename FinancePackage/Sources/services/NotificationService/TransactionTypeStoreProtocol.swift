import FinanceCoreSDK

public protocol TransactionTypeStoreProtocol: Sendable {
    func replaceAll(_ rules: [TransactionType], userId: String) async throws
    func fetchAll(userId: String) async throws -> [TransactionType]
    func deleteAll(userId: String) async throws
}
