import FinanceCoreSDK

public protocol FinanceSyncClientProtocol: Sendable {
    func fetchAccounts(username: String, password: String) async throws -> [Account]
    func fetchTransactions(username: String, password: String, startDate: String, endDate: String) async throws -> [Transaction]
    func triggerRefresh(username: String, password: String) async throws
    /// Sends local TransferRules to the server, which last-write-wins merges them and returns the
    /// merged set (incl. tombstones). The client adopts the result so neither side clobbers the other.
    @discardableResult
    func putTransferRules(username: String, password: String, rules: [TransferRule]) async throws -> [TransferRule]
    /// Sends local Vendors to the server, which last-write-wins merges and returns the merged set.
    @discardableResult
    func putVendors(username: String, password: String, vendors: [Vendor]) async throws -> [Vendor]
}
