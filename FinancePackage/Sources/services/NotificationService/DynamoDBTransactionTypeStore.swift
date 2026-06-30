import FinanceCoreSDK
import Foundation
import SotoDynamoDB

public struct DynamoDBTransactionTypeStore: TransactionTypeStoreProtocol {
    private let db: DynamoDB
    private let tableName: String

    public init(awsClient: AWSClient, region: Region? = nil, tableName: String) {
        self.db = DynamoDB(client: awsClient, region: region)
        self.tableName = tableName
    }

    public func replaceAll(_ rules: [TransactionType], userId: String) async throws {
        try await deleteAll(userId: userId)
        for rule in rules {
            let payload = try JSONEncoder().encode(rule)
            let payloadString = String(data: payload, encoding: .utf8) ?? "{}"
            _ = try await db.updateItem(.init(
                expressionAttributeValues: [
                    ":recordType": .s("transactionType"),
                    ":userId": .s(userId),
                    ":payload": .s(payloadString)
                ],
                key: ["id": .s("\(userId)#transactionType#\(rule.id.uuidString)")],
                tableName: tableName,
                updateExpression: "SET recordType = :recordType, userId = :userId, payload = :payload"
            ))
        }
    }

    public func fetchAll(userId: String) async throws -> [TransactionType] {
        let items = try await db.scanAll(
            tableName: tableName,
            filterExpression: "recordType = :t AND userId = :u",
            expressionAttributeValues: [
                ":t": .s("transactionType"),
                ":u": .s(userId)
            ]
        )
        return items.compactMap { item in
            guard let payloadString = item["payload"]?.s,
                  let data = payloadString.data(using: .utf8),
                  let rule = try? JSONDecoder().decode(TransactionType.self, from: data)
            else { return nil }
            return rule
        }
    }

    public func deleteAll(userId: String) async throws {
        let items = try await db.scanAll(
            tableName: tableName,
            filterExpression: "recordType = :t AND userId = :u",
            expressionAttributeValues: [
                ":t": .s("transactionType"),
                ":u": .s(userId)
            ]
        )
        for item in items {
            guard let id = item["id"]?.s else { continue }
            _ = try await db.deleteItem(.init(key: ["id": .s(id)], tableName: tableName))
        }
    }
}
