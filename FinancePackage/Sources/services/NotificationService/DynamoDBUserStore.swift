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
        var values: [String: DynamoDB.AttributeValue] = [
            ":recordType": .s("user"),
            ":passwordHash": .s(user.passwordHash),
            ":createdAt": .s(user.createdAt)
        ]
        var expression = "SET recordType = :recordType, passwordHash = :passwordHash, createdAt = :createdAt"
        if let token = user.lunchMoneyToken {
            values[":lunchMoneyToken"] = .s(token)
            expression += ", lunchMoneyToken = :lunchMoneyToken"
        }
        _ = try await db.updateItem(.init(
            expressionAttributeValues: values,
            key: ["id": .s(user.username)],
            tableName: tableName,
            updateExpression: expression
        ))
    }

    public func fetchAll() async throws -> [UserAccount] {
        let response = try await db.scan(.init(
            expressionAttributeValues: [":t": .s("user")],
            filterExpression: "recordType = :t",
            tableName: tableName
        ))
        return (response.items ?? []).compactMap { item in
            guard
                let id = item["id"]?.s,
                let passwordHash = item["passwordHash"]?.s,
                let createdAt = item["createdAt"]?.s
            else { return nil }
            return UserAccount(
                username: id,
                passwordHash: passwordHash,
                createdAt: createdAt,
                lunchMoneyToken: item["lunchMoneyToken"]?.s
            )
        }
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
        return UserAccount(
            username: username,
            passwordHash: passwordHash,
            createdAt: createdAt,
            lunchMoneyToken: item["lunchMoneyToken"]?.s
        )
    }

    public func update(lunchMoneyToken: String, forUsername username: String) async throws {
        _ = try await db.updateItem(.init(
            expressionAttributeValues: [":token": .s(lunchMoneyToken)],
            key: ["id": .s(username)],
            tableName: tableName,
            updateExpression: "SET lunchMoneyToken = :token"
        ))
    }
}
