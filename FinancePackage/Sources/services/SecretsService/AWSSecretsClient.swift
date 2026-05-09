import SotoSecretsManager

public struct AWSSecretsClient: SecretsClientProtocol, @unchecked Sendable {
    private let awsClient: AWSClient
    private let secretsManager: SecretsManager

    public init(awsClient: AWSClient, region: Region? = nil) {
        self.awsClient = awsClient
        self.secretsManager = SecretsManager(client: awsClient, region: region)
    }

    public func secret(named name: String) async throws -> String {
        let response = try await secretsManager.getSecretValue(.init(secretId: name))
        guard let secretString = response.secretString else {
            throw SecretsError.missingValue(name)
        }
        return secretString
    }
}
