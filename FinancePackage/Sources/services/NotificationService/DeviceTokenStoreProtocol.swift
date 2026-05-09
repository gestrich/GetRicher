public protocol DeviceTokenStoreProtocol: Sendable {
    func store(_ token: DeviceToken) async throws
    func fetchAll() async throws -> [DeviceToken]
}
