import FinanceCoreSDK

public struct LoggingVendorStore: VendorStoreProtocol {
    public init() {}

    public func replaceAll(_ vendors: [Vendor], userId: String) async throws {
        print("[VendorStore] STUB replaceAll \(vendors.count) vendor(s) for userId=\(userId)")
    }

    public func fetchAll(userId: String) async throws -> [Vendor] {
        print("[VendorStore] STUB fetchAll userId=\(userId) -> []")
        return []
    }

    public func deleteAll(userId: String) async throws {
        print("[VendorStore] STUB deleteAll userId=\(userId)")
    }
}
