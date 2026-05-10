import ArgumentParser
import ClientService
import Foundation

struct TransactionsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "transactions",
        abstract: "Fetch transactions for a date range"
    )

    @OptionGroup var config: CLIConfiguration

    @Option(name: .long, help: "Start date (YYYY-MM-DD)")
    var startDate: String

    @Option(name: .long, help: "End date (YYYY-MM-DD)")
    var endDate: String

    mutating func run() async throws {
        guard !config.baseURL.isEmpty else {
            throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
        }
        let baseURL = config.baseURL
        let username = config.username
        let password = config.password
        let start = startDate
        let end = endDate
        let transactions = try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            return try await client.fetchTransactions(username: username, password: password, startDate: start, endDate: end)
        }.value
        if transactions.isEmpty {
            print("No transactions found.")
            return
        }
        for tx in transactions {
            let category = tx.categoryName ?? "uncategorized"
            print("\(tx.date)  \(tx.payee.padding(toLength: 40, withPad: " ", startingAt: 0))  \(tx.amount) \(tx.currency)  [\(category)]")
        }
    }
}
