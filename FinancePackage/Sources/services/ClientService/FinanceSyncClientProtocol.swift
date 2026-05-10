import FinanceCoreSDK

public protocol FinanceSyncClientProtocol: Sendable {
    func fetchAccounts(username: String, password: String) async throws -> [Account]
    func fetchTransactions(username: String, password: String, startDate: String, endDate: String) async throws -> [Transaction]
    func triggerRefresh(username: String, password: String) async throws
}
