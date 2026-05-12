import FinanceCoreSDK

public protocol VendorStoreProtocol: Sendable {
    func replaceAll(_ vendors: [Vendor], userId: String) async throws
    func fetchAll(userId: String) async throws -> [Vendor]
    func deleteAll(userId: String) async throws
}
