import SotoDynamoDB

public struct DynamoDBDeviceTokenStore: DeviceTokenStoreProtocol {
    private let db: DynamoDB
    private let tableName: String

    public init(awsClient: AWSClient, region: Region? = nil, tableName: String) {
        self.db = DynamoDB(client: awsClient, region: region)
        self.tableName = tableName
    }

    public func store(_ token: DeviceToken) async throws {
        let item: [String: DynamoDB.AttributeValue] = [
            "id": .s(token.id),
            "recordType": .s("deviceToken"),
            "environment": .s(token.environment),
            "createdAt": .s(token.createdAt)
        ]
        _ = try await db.putItem(.init(item: item, tableName: tableName))
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
            return DeviceToken(tokenString: id, environment: env, createdAt: created)
        }
    }
}

extension DynamoDB.AttributeValue {
    var s: String? {
        if case .s(let value) = self { return value }
        return nil
    }
}
