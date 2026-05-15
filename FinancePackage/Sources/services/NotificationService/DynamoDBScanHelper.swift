import SotoDynamoDB

extension DynamoDB {
    /// Scans `tableName` with the given filter, paginating through every page
    /// until LastEvaluatedKey is nil. A single `scan` call only sees up to ~1MB
    /// of pre-filter data, so callers that need complete results must page.
    func scanAll(
        tableName: String,
        filterExpression: String? = nil,
        expressionAttributeNames: [String: String]? = nil,
        expressionAttributeValues: [String: DynamoDB.AttributeValue]? = nil,
        projectionExpression: String? = nil
    ) async throws -> [[String: DynamoDB.AttributeValue]] {
        var items: [[String: DynamoDB.AttributeValue]] = []
        var exclusiveStartKey: [String: DynamoDB.AttributeValue]? = nil
        repeat {
            let response = try await scan(.init(
                exclusiveStartKey: exclusiveStartKey,
                expressionAttributeNames: expressionAttributeNames,
                expressionAttributeValues: expressionAttributeValues,
                filterExpression: filterExpression,
                projectionExpression: projectionExpression,
                tableName: tableName
            ))
            items.append(contentsOf: response.items ?? [])
            exclusiveStartKey = response.lastEvaluatedKey
        } while exclusiveStartKey != nil
        return items
    }
}
