import ArgumentParser
import ClientService
import Foundation

struct ReviewItemsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "review-items",
        abstract: "List pending review items"
    )

    @OptionGroup var config: CLIConfiguration

    mutating func run() async throws {
        guard !config.baseURL.isEmpty else {
            throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
        }
        let baseURL = config.baseURL
        let items = try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            return try await client.fetchReviewItems()
        }.value
        if items.isEmpty {
            print("No pending review items.")
            return
        }
        for item in items {
            print("[\(item.status.rawValue.uppercased())] \(item.title) (id: \(item.id))")
            print("  \(item.summary)")
        }
    }
}
