import FinanceCoreSDK

public protocol FinanceSyncClientProtocol: Sendable {
    func fetchAccounts(username: String, password: String) async throws -> [Account]
    func fetchTransactions(username: String, password: String, startDate: String, endDate: String) async throws -> [Transaction]
    func triggerRefresh(username: String, password: String) async throws
    /// Replaces the user's server-side TransferRules. Used to keep DynamoDB in sync with iOS SwiftData
    /// so the server-side paydown computation applies the same bill-mapping subtractions.
    func putTransferRules(username: String, password: String, rules: [TransferRule]) async throws
    /// Replaces the user's server-side Vendors.
    func putVendors(username: String, password: String, vendors: [Vendor]) async throws
}
