import FinanceCoreSDK

public protocol NotificationSubscriptionStoreProtocol: Sendable {
    func upsert(_ subscription: NotificationSubscription) async throws
    func fetch(userId: String) async throws -> [NotificationSubscription]
    func fetchAll() async throws -> [NotificationSubscription]
    func find(userId: String, accountId: Int) async throws -> NotificationSubscription?
    func delete(userId: String, accountId: Int) async throws
    func markSent(userId: String, accountId: Int, localDate: String) async throws
}
