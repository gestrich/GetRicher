import FinanceCoreSDK

public protocol ReviewItemStoreProtocol: Sendable {
    func store(_ item: ReviewItem) async throws
    func fetchPending() async throws -> [ReviewItem]
    func fetchAll() async throws -> [ReviewItem]
    func resolve(id: String, status: ReviewItem.Status) async throws
    func delete(id: String) async throws
}
