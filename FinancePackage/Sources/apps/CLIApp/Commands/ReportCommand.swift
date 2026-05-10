import ArgumentParser
import ClientService
import Foundation

struct ReportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "report",
        abstract: "Generate a paydown report and print the result"
    )

    @OptionGroup var config: CLIConfiguration

    mutating func run() async throws {
        guard !config.baseURL.isEmpty else {
            throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
        }
        let baseURL = config.baseURL
        let data = try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            return try await client.generateReport()
        }.value
        print(String(data: data, encoding: .utf8) ?? "")
    }
}
