import FinanceCoreSDK

public struct LoggingUserStore: UserStoreProtocol {
    public init() {}

    public func create(_ user: UserAccount) async throws {
        print("[UserStore] STUB create user: \(user.username)")
    }

    public func find(username: String) async throws -> UserAccount? {
        print("[UserStore] STUB find username=\(username) -> nil")
        return nil
    }

    public func fetchAll() async throws -> [UserAccount] {
        print("[UserStore] STUB fetchAll -> []")
        return []
    }

    public func update(lunchMoneyToken: String, forUsername username: String) async throws {
        print("[UserStore] STUB update lunchMoneyToken for username=\(username)")
    }

    public func delete(username: String) async throws {
        print("[UserStore] STUB delete username=\(username)")
    }
}
