import ArgumentParser
import ClientService
import Foundation

struct ResolveItemCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "resolve-item",
        abstract: "Resolve a review item"
    )

    @OptionGroup var config: CLIConfiguration

    @Option(name: .long, help: "Review item ID to resolve")
    var id: String

    @Option(name: .long, help: "Resolution status (approved, dismissed, snoozed)")
    var status: String = "approved"

    mutating func run() async throws {
        guard !config.baseURL.isEmpty else {
            throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
        }
        let baseURL = config.baseURL
        let itemId = id
        let itemStatus = status
        try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            try await client.resolveItem(id: itemId, status: itemStatus)
        }.value
        print("Review item \(id) resolved as \(status).")
    }
}
