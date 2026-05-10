import FinanceCoreSDK

public protocol UserStoreProtocol: Sendable {
    func create(_ user: UserAccount) async throws
    func find(username: String) async throws -> UserAccount?
}
