import FinanceCoreSDK

public struct LoggingAccountStore: AccountStoreProtocol {
    public init() {}

    public func store(_ accounts: [Account], userId: String) async throws {
        print("[AccountStore] STUB store \(accounts.count) account(s) for userId=\(userId)")
    }

    public func fetchAll(userId: String) async throws -> [Account] {
        print("[AccountStore] STUB fetchAll userId=\(userId) -> []")
        return []
    }

    public func deleteAll(userId: String) async throws {
        print("[AccountStore] STUB deleteAll userId=\(userId)")
    }
}
