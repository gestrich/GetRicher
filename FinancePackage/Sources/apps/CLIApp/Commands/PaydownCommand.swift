import ArgumentParser
import ClientService
import Foundation

struct PaydownCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "paydown",
        abstract: "Fetch the current weekly paydown (same data the iOS Weekly Paydown tab and daily push notification use)"
    )

    @OptionGroup var config: CLIConfiguration

    mutating func run() async throws {
        guard !config.baseURL.isEmpty else {
            throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
        }
        let baseURL = config.baseURL
        let result = try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            return try await client.fetchWeeklyPaydown()
        }.value

        print("Period: \(result.periodStart) → \(result.periodEnd)")
        print(String(repeating: "─", count: 60))
        for account in result.accounts {
            let net = String(format: "$%.2f", account.netPeriodSpending)
            let gross = String(format: "$%.2f", account.periodSpending)
            let transfers = String(format: "$%.2f", account.transferTotal)
            print("\(account.displayName)")
            print("  Period spending: \(gross)")
            if account.transferTotal != 0 {
                print("  Covered by transfers: −\(transfers)")
            }
            print("  Net amount to pay: \(net)")
        }
        print(String(repeating: "─", count: 60))
        print("Notification body: \(result.body)")
    }
}
