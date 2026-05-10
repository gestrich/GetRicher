import FinanceCoreSDK

public protocol TransactionStoreProtocol: Sendable {
    func store(_ transactions: [Transaction], userId: String) async throws
    func fetch(userId: String, startDate: String, endDate: String) async throws -> [Transaction]
    func deleteAll(userId: String) async throws
}
