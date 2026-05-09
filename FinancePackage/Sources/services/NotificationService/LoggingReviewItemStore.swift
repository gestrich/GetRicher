import FinanceCoreSDK

public struct LoggingReviewItemStore: ReviewItemStoreProtocol {
    public init() {}

    public func store(_ item: ReviewItem) async throws {
        print("[ReviewItemStore] STUB store item: \(item.id) kind=\(item.kind.rawValue)")
    }

    public func fetchPending() async throws -> [ReviewItem] {
        print("[ReviewItemStore] STUB fetchPending -> []")
        return []
    }

    public func resolve(id: String, status: ReviewItem.Status) async throws {
        print("[ReviewItemStore] STUB resolve id=\(id) status=\(status.rawValue)")
    }
}
