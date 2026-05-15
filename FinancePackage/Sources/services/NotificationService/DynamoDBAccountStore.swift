import FinanceCoreSDK
import Foundation
import SotoDynamoDB

public struct DynamoDBAccountStore: AccountStoreProtocol {
    private let db: DynamoDB
    private let tableName: String

    public init(awsClient: AWSClient, region: Region? = nil, tableName: String) {
        self.db = DynamoDB(client: awsClient, region: region)
        self.tableName = tableName
    }

    public func store(_ accounts: [Account], userId: String) async throws {
        for account in accounts {
            let payload = try JSONEncoder().encode(account)
            let payloadString = String(data: payload, encoding: .utf8) ?? "{}"
            _ = try await db.updateItem(.init(
                expressionAttributeValues: [
                    ":recordType": .s("account"),
                    ":userId": .s(userId),
                    ":payload": .s(payloadString)
                ],
                key: ["id": .s("\(userId)#account#\(account.lunchMoneyId)")],
                tableName: tableName,
                updateExpression: "SET recordType = :recordType, userId = :userId, payload = :payload"
            ))
        }
    }

    public func fetchAll(userId: String) async throws -> [Account] {
        let items = try await db.scanAll(
            tableName: tableName,
            filterExpression: "recordType = :t AND userId = :u",
            expressionAttributeValues: [
                ":t": .s("account"),
                ":u": .s(userId)
            ]
        )
        return items.compactMap { item in
            guard let payloadString = item["payload"]?.s,
                  let data = payloadString.data(using: .utf8),
                  let account = try? JSONDecoder().decode(Account.self, from: data)
            else { return nil }
            return account
        }
    }

    public func deleteAll(userId: String) async throws {
        let items = try await db.scanAll(
            tableName: tableName,
            filterExpression: "recordType = :t AND userId = :u",
            expressionAttributeValues: [
                ":t": .s("account"),
                ":u": .s(userId)
            ]
        )
        for item in items {
            guard let id = item["id"]?.s else { continue }
            _ = try await db.deleteItem(.init(key: ["id": .s(id)], tableName: tableName))
        }
    }
}
