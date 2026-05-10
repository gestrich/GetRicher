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

    public func update(lunchMoneyToken: String, forUsername username: String) async throws {
        print("[UserStore] STUB update lunchMoneyToken for username=\(username)")
    }
}
