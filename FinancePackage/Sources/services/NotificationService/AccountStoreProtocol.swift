import FinanceCoreSDK

public protocol AccountStoreProtocol: Sendable {
    func store(_ accounts: [Account], userId: String) async throws
    func fetchAll(userId: String) async throws -> [Account]
}
