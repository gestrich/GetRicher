import ArgumentParser
import ClientService
import Foundation

struct SendReportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "send-report",
        abstract: "Send a push notification paydown report to a user's devices"
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
            try await client.sendReport(username: username, password: password)
        }.value
        print("Report sent successfully.")
    }
}
