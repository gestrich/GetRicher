import ArgumentParser
import ClientService
import FinanceCoreSDK
import Foundation

/// Manage a user's transfer/allocation rules on the server. Because the server stores the full
/// rule set (PUT replaces all), `add`/`delete` fetch the current rules, mutate, and PUT back.
struct TransferRulesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "transfer-rules",
        abstract: "List and manage transfer/allocation rules (incl. payment-exclusion rules)",
        subcommands: [ListRules.self, AddRule.self, DeleteRule.self]
    )

    struct ListRules: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list", abstract: "List transfer rules")
        @OptionGroup var config: CLIConfiguration

        func run() async throws {
            let (baseURL, username, password) = try config.requireCredentials()
            let rules = try await Task { @MainActor in
                try await APIClient(baseURL: baseURL, serviceName: "CLI")
                    .fetchTransferRules(username: username, password: password)
            }.value
            if rules.isEmpty { print("No transfer rules."); return }
            for r in rules.sorted(by: { $0.priority > $1.priority }) {
                let vendor = r.vendor.map { "vendor=\"\($0.filterText)\"" } ?? "vendor=<default>"
                let source = r.sourceAccountId.map(String.init) ?? "-"
                print("[\(r.kind.rawValue)] \"\(r.name)\" target=\(r.targetAccountId) source=\(source) \(vendor) priority=\(r.priority) id=\(r.id.uuidString)")
            }
        }
    }

    struct AddRule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a transfer or payment rule (appended to the existing set)")
        @OptionGroup var config: CLIConfiguration
        @Option(help: "Rule name") var name: String
        @Option(help: "Rule kind: transfer or payment") var kind: String = "transfer"
        @Option(help: "Target credit account lunchMoneyId") var targetAccount: Int
        @Option(help: "Source funding account lunchMoneyId (omit for default/payment rules)") var sourceAccount: Int?
        @Option(help: "Vendor filter text to match payees (omit for the default bucket)") var vendorFilter: String?
        @Option(help: "Vendor display name (defaults to the filter text)") var vendorName: String?
        @Option(help: "Priority (higher matches first)") var priority: Int = 0

        func run() async throws {
            let (baseURL, username, password) = try config.requireCredentials()
            guard let ruleKind = RuleKind(rawValue: kind) else {
                throw ValidationError("--kind must be 'transfer' or 'payment'")
            }
            let vendor: Vendor? = vendorFilter.map { Vendor(name: vendorName ?? $0, filterText: $0, accountId: targetAccount) }
            let newRule = TransferRule(
                name: name,
                vendor: vendor,
                sourceAccountId: sourceAccount,
                targetAccountId: targetAccount,
                priority: priority,
                kind: ruleKind
            )
            try await Task { @MainActor in
                let client = APIClient(baseURL: baseURL, serviceName: "CLI")
                var rules = try await client.fetchTransferRules(username: username, password: password)
                rules.append(newRule)
                try await client.putTransferRules(username: username, password: password, rules: rules)
            }.value
            print("Added [\(ruleKind.rawValue)] rule \"\(name)\" (id \(newRule.id.uuidString)).")
        }
    }

    struct DeleteRule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete a transfer rule by id")
        @OptionGroup var config: CLIConfiguration
        @Option(help: "Rule id (UUID) to delete") var id: String

        func run() async throws {
            let (baseURL, username, password) = try config.requireCredentials()
            let ruleId = id
            try await Task { @MainActor in
                let client = APIClient(baseURL: baseURL, serviceName: "CLI")
                let rules = try await client.fetchTransferRules(username: username, password: password)
                let remaining = rules.filter { $0.id.uuidString.caseInsensitiveCompare(ruleId) != .orderedSame }
                guard remaining.count != rules.count else {
                    throw ValidationError("No rule with id \(ruleId)")
                }
                try await client.putTransferRules(username: username, password: password, rules: remaining)
            }.value
            print("Deleted rule \(ruleId).")
        }
    }
}
