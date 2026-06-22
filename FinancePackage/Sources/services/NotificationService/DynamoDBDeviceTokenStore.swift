import SotoDynamoDB

public struct DynamoDBDeviceTokenStore: DeviceTokenStoreProtocol {
    private let db: DynamoDB
    private let tableName: String

    public init(awsClient: AWSClient, region: Region? = nil, tableName: String) {
        self.db = DynamoDB(client: awsClient, region: region)
        self.tableName = tableName
    }

    public func store(_ token: DeviceToken) async throws {
        var values: [String: DynamoDB.AttributeValue] = [
            ":recordType": .s("deviceToken"),
            ":createdAt": .s(token.createdAt)
        ]
        var expression = "SET recordType = :recordType, createdAt = :createdAt"
        if let userId = token.userId {
            values[":userId"] = .s(userId)
            expression += ", userId = :userId"
        }
        _ = try await db.updateItem(.init(
            expressionAttributeValues: values,
            key: ["id": .s(token.id)],
            tableName: tableName,
            updateExpression: expression
        ))
    }

    public func fetchAll() async throws -> [DeviceToken] {
        let items = try await db.scanAll(
            tableName: tableName,
            filterExpression: "recordType = :t",
            expressionAttributeValues: [":t": .s("deviceToken")]
        )
        return items.compactMap { item in
            guard
                let id = item["id"]?.s,
                let created = item["createdAt"]?.s
            else { return nil }
            let userId = item["userId"]?.s
            return DeviceToken(tokenString: id, createdAt: created, userId: userId)
        }
    }

    public func deleteAll(userId: String) async throws {
        let items = try await db.scanAll(
            tableName: tableName,
            filterExpression: "recordType = :t AND userId = :u",
            expressionAttributeValues: [
                ":t": .s("deviceToken"),
                ":u": .s(userId)
            ]
        )
        for item in items {
            guard let id = item["id"]?.s else { continue }
            _ = try await db.deleteItem(.init(key: ["id": .s(id)], tableName: tableName))
        }
    }
}

extension DynamoDB.AttributeValue {
    var s: String? {
        if case .s(let value) = self { return value }
        return nil
    }
}
