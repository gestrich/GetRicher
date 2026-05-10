import Foundation
import SotoDynamoDB

let awsClient = AWSClient(credentialProvider: .environment)
let db = DynamoDB(client: awsClient, region: .useast1)
let item: [String: DynamoDB.AttributeValue] = [
    "id": .s("diag-test-\(UUID().uuidString)"),
    "recordType": .s("diag")
]
do {
    _ = try await db.putItem(.init(item: item, tableName: "get-richer"))
    print("SUCCESS")
} catch {
    print("ERROR: \(error)")
}
try? await awsClient.shutdown()
