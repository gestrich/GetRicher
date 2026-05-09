import Foundation

public protocol SecretsClientProtocol: Sendable {
    func secret(named name: String) async throws -> String
}

public enum SecretsError: Error, Sendable {
    case missingEnvironmentVariable(String)
    case missingValue(String)
}
