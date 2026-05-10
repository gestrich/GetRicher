import FinanceCoreSDK
import SotoDynamoDB

public struct DynamoDBUserStore: UserStoreProtocol {
    private let db: DynamoDB
    private let tableName: String

    public init(awsClient: AWSClient, region: Region? = nil, tableName: String) {
        self.db = DynamoDB(client: awsClient, region: region)
        self.tableName = tableName
    }

    public func create(_ user: UserAccount) async throws {
        _ = try await db.updateItem(.init(
            expressionAttributeValues: [
                ":recordType": .s("user"),
                ":passwordHash": .s(user.passwordHash),
                ":createdAt": .s(user.createdAt)
            ],
            key: ["id": .s(user.username)],
            tableName: tableName,
            updateExpression: "SET recordType = :recordType, passwordHash = :passwordHash, createdAt = :createdAt"
        ))
    }

    public func find(username: String) async throws -> UserAccount? {
        let response = try await db.getItem(.init(
            key: ["id": .s(username)],
            tableName: tableName
        ))
        guard
            let item = response.item,
            item["recordType"]?.s == "user",
            let passwordHash = item["passwordHash"]?.s,
            let createdAt = item["createdAt"]?.s
        else { return nil }
        return UserAccount(username: username, passwordHash: passwordHash, createdAt: createdAt)
    }
}
