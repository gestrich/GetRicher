import Foundation

public struct EnvironmentSecretsClient: SecretsClientProtocol {
    public init() {}

    public func secret(named name: String) async throws -> String {
        guard let value = ProcessInfo.processInfo.environment[name] else {
            throw SecretsError.missingEnvironmentVariable(name)
        }
        return value
    }
}
