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
            ":environment": .s(token.environment),
            ":createdAt": .s(token.createdAt)
        ]
        var expression = "SET recordType = :recordType, environment = :environment, createdAt = :createdAt"
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
        let response = try await db.scan(.init(
            expressionAttributeValues: [":t": .s("deviceToken")],
            filterExpression: "recordType = :t",
            tableName: tableName
        ))
        return (response.items ?? []).compactMap { item in
            guard
                let id = item["id"]?.s,
                let env = item["environment"]?.s,
                let created = item["createdAt"]?.s
            else { return nil }
            let userId = item["userId"]?.s
            return DeviceToken(tokenString: id, environment: env, createdAt: created, userId: userId)
        }
    }

    public func deleteAll(userId: String) async throws {
        let response = try await db.scan(.init(
            expressionAttributeValues: [
                ":t": .s("deviceToken"),
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

extension DynamoDB.AttributeValue {
    var s: String? {
        if case .s(let value) = self { return value }
        return nil
    }
}
