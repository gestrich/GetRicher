import FinanceCoreSDK
import Foundation
import SotoDynamoDB

public struct DynamoDBNotificationSubscriptionStore: NotificationSubscriptionStoreProtocol {
    private let db: DynamoDB
    private let tableName: String

    public init(awsClient: AWSClient, region: Region? = nil, tableName: String) {
        self.db = DynamoDB(client: awsClient, region: region)
        self.tableName = tableName
    }

    private func recordId(userId: String, accountId: Int) -> String {
        "\(userId)#notificationSubscription#\(accountId)"
    }

    public func upsert(_ subscription: NotificationSubscription) async throws {
        let payload = try JSONEncoder().encode(subscription)
        let payloadString = String(data: payload, encoding: .utf8) ?? "{}"
        _ = try await db.updateItem(.init(
            expressionAttributeValues: [
                ":recordType": .s("notificationSubscription"),
                ":userId": .s(subscription.userId),
                ":payload": .s(payloadString)
            ],
            key: ["id": .s(recordId(userId: subscription.userId, accountId: subscription.accountId))],
            tableName: tableName,
            updateExpression: "SET recordType = :recordType, userId = :userId, payload = :payload"
        ))
    }

    public func fetch(userId: String) async throws -> [NotificationSubscription] {
        let items = try await db.scanAll(
            tableName: tableName,
            filterExpression: "recordType = :t AND userId = :u",
            expressionAttributeValues: [
                ":t": .s("notificationSubscription"),
                ":u": .s(userId)
            ]
        )
        return decodeItems(items)
    }

    public func fetchAll() async throws -> [NotificationSubscription] {
        let items = try await db.scanAll(
            tableName: tableName,
            filterExpression: "recordType = :t",
            expressionAttributeValues: [":t": .s("notificationSubscription")]
        )
        return decodeItems(items)
    }

    public func find(userId: String, accountId: Int) async throws -> NotificationSubscription? {
        let response = try await db.getItem(.init(
            key: ["id": .s(recordId(userId: userId, accountId: accountId))],
            tableName: tableName
        ))
        guard let item = response.item,
              let payloadString = item["payload"]?.s,
              let data = payloadString.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(NotificationSubscription.self, from: data)
    }

    public func delete(userId: String, accountId: Int) async throws {
        _ = try await db.deleteItem(.init(
            key: ["id": .s(recordId(userId: userId, accountId: accountId))],
            tableName: tableName
        ))
    }

    public func markSent(userId: String, accountId: Int, localDate: String) async throws {
        guard var existing = try await find(userId: userId, accountId: accountId) else { return }
        existing.lastSentLocalDate = localDate
        existing.updatedAt = ISO8601DateFormatter().string(from: Date())
        try await upsert(existing)
    }

    private func decodeItems(_ items: [[String: DynamoDB.AttributeValue]]) -> [NotificationSubscription] {
        items.compactMap { item in
            guard let payloadString = item["payload"]?.s,
                  let data = payloadString.data(using: .utf8)
            else { return nil }
            return try? JSONDecoder().decode(NotificationSubscription.self, from: data)
        }
    }
}

/// Stub store used in environments without DynamoDB credentials (local Lambda invoke).
public struct LoggingNotificationSubscriptionStore: NotificationSubscriptionStoreProtocol {
    public init() {}

    public func upsert(_ subscription: NotificationSubscription) async throws {
        print("[NotificationSubscriptionStore] STUB upsert: \(subscription.id)")
    }

    public func fetch(userId: String) async throws -> [NotificationSubscription] {
        print("[NotificationSubscriptionStore] STUB fetch userId=\(userId) -> []")
        return []
    }

    public func fetchAll() async throws -> [NotificationSubscription] {
        print("[NotificationSubscriptionStore] STUB fetchAll -> []")
        return []
    }

    public func find(userId: String, accountId: Int) async throws -> NotificationSubscription? {
        print("[NotificationSubscriptionStore] STUB find userId=\(userId) accountId=\(accountId) -> nil")
        return nil
    }

    public func delete(userId: String, accountId: Int) async throws {
        print("[NotificationSubscriptionStore] STUB delete userId=\(userId) accountId=\(accountId)")
    }

    public func markSent(userId: String, accountId: Int, localDate: String) async throws {
        print("[NotificationSubscriptionStore] STUB markSent userId=\(userId) accountId=\(accountId) localDate=\(localDate)")
    }
}
