import ArgumentParser
import Foundation

struct CLIConfiguration: ParsableArguments {
    @Option(name: .long, help: "API base URL (or set GETRICHER_API_URL)")
    var baseURL: String = ProcessInfo.processInfo.environment["GETRICHER_API_URL"] ?? ""

    @Option(name: .long, help: "Username (or set GETRICHER_USERNAME)")
    var username: String = ProcessInfo.processInfo.environment["GETRICHER_USERNAME"] ?? ""

    @Option(name: .long, help: "Password (or set GETRICHER_PASSWORD)")
    var password: String = ProcessInfo.processInfo.environment["GETRICHER_PASSWORD"] ?? ""

    /// Validates and returns the connection triple, throwing a clear error if anything is missing.
    func requireCredentials() throws -> (baseURL: String, username: String, password: String) {
        guard !baseURL.isEmpty else {
            throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
        }
        guard !username.isEmpty, !password.isEmpty else {
            throw ValidationError("--username and --password are required (or set GETRICHER_USERNAME/GETRICHER_PASSWORD)")
        }
        return (baseURL, username, password)
    }
}
