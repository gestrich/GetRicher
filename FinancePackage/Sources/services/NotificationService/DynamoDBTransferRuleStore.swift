import FinanceCoreSDK
import Foundation
import SotoDynamoDB

public struct DynamoDBTransferRuleStore: TransferRuleStoreProtocol {
    private let db: DynamoDB
    private let tableName: String

    public init(awsClient: AWSClient, region: Region? = nil, tableName: String) {
        self.db = DynamoDB(client: awsClient, region: region)
        self.tableName = tableName
    }

    public func replaceAll(_ rules: [TransferRule], userId: String) async throws {
        try await deleteAll(userId: userId)
        for rule in rules {
            let payload = try JSONEncoder().encode(rule)
            let payloadString = String(data: payload, encoding: .utf8) ?? "{}"
            _ = try await db.updateItem(.init(
                expressionAttributeValues: [
                    ":recordType": .s("transferRule"),
                    ":userId": .s(userId),
                    ":payload": .s(payloadString)
                ],
                key: ["id": .s("\(userId)#transferRule#\(rule.id.uuidString)")],
                tableName: tableName,
                updateExpression: "SET recordType = :recordType, userId = :userId, payload = :payload"
            ))
        }
    }

    public func fetchAll(userId: String) async throws -> [TransferRule] {
        let response = try await db.scan(.init(
            expressionAttributeValues: [
                ":t": .s("transferRule"),
                ":u": .s(userId)
            ],
            filterExpression: "recordType = :t AND userId = :u",
            tableName: tableName
        ))
        return (response.items ?? []).compactMap { item in
            guard let payloadString = item["payload"]?.s,
                  let data = payloadString.data(using: .utf8),
                  let rule = try? JSONDecoder().decode(TransferRule.self, from: data)
            else { return nil }
            return rule
        }
    }

    public func deleteAll(userId: String) async throws {
        let response = try await db.scan(.init(
            expressionAttributeValues: [
                ":t": .s("transferRule"),
                ":u": .s(userId)
            ],
            filterExpression: "recordType = :t AND userId = :u",
            tableName: tableName
        ))
        for item in (response.items ?? []) {
            guard let id = item["id"]?.s else { continue }
            _ = try await db.deleteItem(.init(key: ["id": .s(id)], tableName: tableName))
        }
    }
}
