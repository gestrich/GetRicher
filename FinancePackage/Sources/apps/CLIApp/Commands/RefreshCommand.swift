import ArgumentParser
import ClientService
import Foundation

struct RefreshCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "refresh",
        abstract: "Trigger an on-demand Lunch Money data fetch for a user"
    )

    @OptionGroup var config: CLIConfiguration

    mutating func run() async throws {
        guard !config.baseURL.isEmpty else {
            throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
        }
        let baseURL = config.baseURL
        let username = config.username
        let password = config.password
        try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            try await client.triggerRefresh(username: username, password: password)
        }.value
        print("Refresh triggered successfully.")
    }
}
