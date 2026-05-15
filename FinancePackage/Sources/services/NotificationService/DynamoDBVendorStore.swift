import FinanceCoreSDK
import Foundation
import SotoDynamoDB

public struct DynamoDBVendorStore: VendorStoreProtocol {
    private let db: DynamoDB
    private let tableName: String

    public init(awsClient: AWSClient, region: Region? = nil, tableName: String) {
        self.db = DynamoDB(client: awsClient, region: region)
        self.tableName = tableName
    }

    public func replaceAll(_ vendors: [Vendor], userId: String) async throws {
        try await deleteAll(userId: userId)
        for vendor in vendors {
            let payload = try JSONEncoder().encode(vendor)
            let payloadString = String(data: payload, encoding: .utf8) ?? "{}"
            _ = try await db.updateItem(.init(
                expressionAttributeValues: [
                    ":recordType": .s("vendor"),
                    ":userId": .s(userId),
                    ":payload": .s(payloadString)
                ],
                key: ["id": .s("\(userId)#vendor#\(vendor.id.uuidString)")],
                tableName: tableName,
                updateExpression: "SET recordType = :recordType, userId = :userId, payload = :payload"
            ))
        }
    }

    public func fetchAll(userId: String) async throws -> [Vendor] {
        let items = try await db.scanAll(
            tableName: tableName,
            filterExpression: "recordType = :t AND userId = :u",
            expressionAttributeValues: [
                ":t": .s("vendor"),
                ":u": .s(userId)
            ]
        )
        return items.compactMap { item in
            guard let payloadString = item["payload"]?.s,
                  let data = payloadString.data(using: .utf8),
                  let vendor = try? JSONDecoder().decode(Vendor.self, from: data)
            else { return nil }
            return vendor
        }
    }

    public func deleteAll(userId: String) async throws {
        let items = try await db.scanAll(
            tableName: tableName,
            filterExpression: "recordType = :t AND userId = :u",
            expressionAttributeValues: [
                ":t": .s("vendor"),
                ":u": .s(userId)
            ]
        )
        for item in items {
            guard let id = item["id"]?.s else { continue }
            _ = try await db.deleteItem(.init(key: ["id": .s(id)], tableName: tableName))
        }
    }
}
