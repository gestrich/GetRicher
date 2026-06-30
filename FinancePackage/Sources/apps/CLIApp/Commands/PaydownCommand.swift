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
        guard !config.username.isEmpty, !config.password.isEmpty else {
            throw ValidationError("--username and --password are required")
        }
        let baseURL = config.baseURL
        let username = config.username
        let password = config.password
        let result = try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            return try await client.fetchWeeklyPaydown(username: username, password: password)
        }.value

        func money(_ v: Double) -> String { String(format: "$%.2f", v) }
        func printCycle(_ label: String, _ c: APIClient.PaydownCycleDTO) {
            print("  \(label):")
            print("    Amount to Pay (primary): \(money(c.owedFromPrimary))")
            for f in c.fundedByAccount {
                print("      + \(money(f.amount)) from \(f.fundingAccountName)")
            }
            print("      (balance \(money(c.currentBalance)) + pending \(money(c.pendingInPeriod)) − postedAfter \(money(c.postedAfterPeriod)) = owed \(money(c.owedTotal)))")
            print("    Total Spend: \(money(c.spendTotal))")
            for b in c.spendBuckets {
                print("      • \(b.typeName): \(money(b.amount)) — \(b.count) txn\(b.count == 1 ? "" : "s")")
            }
            print("    Total Payments: \(money(c.paymentsTotal))")
        }

        print("Last cycle:    \(result.periodStart) → \(result.periodEnd)")
        print("Current cycle: \(result.currentPeriodStart) → \(result.currentPeriodEnd)")
        print(String(repeating: "─", count: 60))
        for account in result.accounts {
            print("\(account.displayName)")
            printCycle("Last", account.last)
            printCycle("Current", account.current)
        }
        print(String(repeating: "─", count: 60))
        print("Notification body: \(result.body)")
    }
}
