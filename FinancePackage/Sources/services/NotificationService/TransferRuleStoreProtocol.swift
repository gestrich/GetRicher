import FinanceCoreSDK

public protocol TransferRuleStoreProtocol: Sendable {
    func replaceAll(_ rules: [TransferRule], userId: String) async throws
    func fetchAll(userId: String) async throws -> [TransferRule]
    func deleteAll(userId: String) async throws
}
