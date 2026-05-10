import ArgumentParser
import ClientService
import Foundation

struct AccountsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "accounts",
        abstract: "Fetch and print cached accounts for a user"
    )

    @OptionGroup var config: CLIConfiguration

    mutating func run() async throws {
        guard !config.baseURL.isEmpty else {
            throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
        }
        let baseURL = config.baseURL
        let username = config.username
        let password = config.password
        let accounts = try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            return try await client.fetchAccounts(username: username, password: password)
        }.value
        if accounts.isEmpty {
            print("No accounts found.")
            return
        }
        for account in accounts {
            print("\(account.displayName) [\(account.type)/\(account.subtype)]: \(account.balance) \(account.currency) (\(account.status))")
        }
    }
}
