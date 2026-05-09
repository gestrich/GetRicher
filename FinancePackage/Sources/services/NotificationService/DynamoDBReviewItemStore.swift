import FinanceCoreSDK
import Foundation
import SotoDynamoDB

public struct DynamoDBReviewItemStore: ReviewItemStoreProtocol {
    private let db: DynamoDB
    private let tableName: String

    public init(awsClient: AWSClient, region: Region? = nil, tableName: String) {
        self.db = DynamoDB(client: awsClient, region: region)
        self.tableName = tableName
    }

    public func store(_ item: ReviewItem) async throws {
        var attributes: [String: DynamoDB.AttributeValue] = [
            "id": .s(item.id),
            "recordType": .s("reviewItem"),
            "kind": .s(item.kind.rawValue),
            "title": .s(item.title),
            "summary": .s(item.summary),
            "itemStatus": .s(item.status.rawValue),
            "createdAt": .s(item.createdAt)
        ]
        if let resolvedAt = item.resolvedAt {
            attributes["resolvedAt"] = .s(resolvedAt)
        }
        _ = try await db.putItem(.init(item: attributes, tableName: tableName))
    }

    public func fetchPending() async throws -> [ReviewItem] {
        let response = try await db.scan(.init(
            expressionAttributeValues: [
                ":t": .s("reviewItem"),
                ":s": .s(ReviewItem.Status.pending.rawValue)
            ],
            filterExpression: "recordType = :t AND itemStatus = :s",
            tableName: tableName
        ))
        return (response.items ?? []).compactMap { parseItem($0) }
    }

    public func resolve(id: String, status: ReviewItem.Status) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        _ = try await db.updateItem(.init(
            expressionAttributeValues: [
                ":s": .s(status.rawValue),
                ":r": .s(now)
            ],
            key: ["id": .s(id)],
            tableName: tableName,
            updateExpression: "SET itemStatus = :s, resolvedAt = :r"
        ))
    }

    private func parseItem(_ item: [String: DynamoDB.AttributeValue]) -> ReviewItem? {
        guard
            let id = item["id"]?.s,
            let kindRaw = item["kind"]?.s,
            let kind = ReviewItem.Kind(rawValue: kindRaw),
            let title = item["title"]?.s,
            let summary = item["summary"]?.s,
            let statusRaw = item["itemStatus"]?.s,
            let status = ReviewItem.Status(rawValue: statusRaw),
            let createdAt = item["createdAt"]?.s
        else { return nil }
        return ReviewItem(
            id: id,
            kind: kind,
            title: title,
            summary: summary,
            status: status,
            createdAt: createdAt,
            resolvedAt: item["resolvedAt"]?.s
        )
    }
}
