import FinanceCoreSDK
import Foundation
import SotoDynamoDB

public struct DynamoDBTransactionStore: TransactionStoreProtocol {
    private let db: DynamoDB
    private let tableName: String

    public init(awsClient: AWSClient, region: Region? = nil, tableName: String) {
        self.db = DynamoDB(client: awsClient, region: region)
        self.tableName = tableName
    }

    public func store(_ transactions: [Transaction], userId: String) async throws {
        for transaction in transactions {
            let payload = try JSONEncoder().encode(transaction)
            let payloadString = String(data: payload, encoding: .utf8) ?? "{}"
            _ = try await db.updateItem(.init(
                expressionAttributeNames: ["#dt": "date"],
                expressionAttributeValues: [
                    ":recordType": .s("transaction"),
                    ":userId": .s(userId),
                    ":date": .s(transaction.date),
                    ":payload": .s(payloadString)
                ],
                key: ["id": .s("\(userId)#transaction#\(transaction.lunchMoneyId)")],
                tableName: tableName,
                updateExpression: "SET recordType = :recordType, userId = :userId, #dt = :date, payload = :payload"
            ))
        }
    }

    public func fetch(userId: String, startDate: String, endDate: String) async throws -> [Transaction] {
        let response = try await db.scan(.init(
            expressionAttributeNames: ["#dt": "date"],
            expressionAttributeValues: [
                ":t": .s("transaction"),
                ":u": .s(userId),
                ":start": .s(startDate),
                ":end": .s(endDate)
            ],
            filterExpression: "recordType = :t AND userId = :u AND #dt BETWEEN :start AND :end",
            tableName: tableName
        ))
        return (response.items ?? []).compactMap { item in
            guard let payloadString = item["payload"]?.s,
                  let data = payloadString.data(using: .utf8),
                  let transaction = try? JSONDecoder().decode(Transaction.self, from: data)
            else { return nil }
            return transaction
        }
    }
}
