import FinanceCoreSDK

public struct LoggingTransferRuleStore: TransferRuleStoreProtocol {
    public init() {}

    public func replaceAll(_ rules: [TransferRule], userId: String) async throws {
        print("[TransferRuleStore] STUB replaceAll \(rules.count) rule(s) for userId=\(userId)")
    }

    public func fetchAll(userId: String) async throws -> [TransferRule] {
        print("[TransferRuleStore] STUB fetchAll userId=\(userId) -> []")
        return []
    }

    public func deleteAll(userId: String) async throws {
        print("[TransferRuleStore] STUB deleteAll userId=\(userId)")
    }
}
