import ArgumentParser
import ClientService
import FinanceCoreSDK
import Foundation

/// Manage a user's paydown transaction types on the server. The server stores the full set and
/// last-write-wins merges, so `add`/`delete` send a single record and the server unions/tombstones.
struct TransactionTypesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "transaction-types",
        abstract: "List and manage paydown transaction types (spend / payment)",
        subcommands: [ListTypes.self, AddType.self, DeleteType.self]
    )

    struct ListTypes: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list", abstract: "List transaction types")
        @OptionGroup var config: CLIConfiguration

        func run() async throws {
            let (baseURL, username, password) = try config.requireCredentials()
            let types = try await Task { @MainActor in
                try await APIClient(baseURL: baseURL, serviceName: "CLI")
                    .fetchTransactionTypes(username: username, password: password)
            }.value
            let live = types.filter { !$0.isDeleted }
            if live.isEmpty { print("No transaction types."); return }
            for t in live.sorted(by: { $0.priority > $1.priority }) {
                let funding = t.fundingAccountId.map { " funding=\($0)" } ?? ""
                print("[\(t.kind.rawValue)] \"\(t.name)\" target=\(t.targetAccountId)\(funding) patterns=\(t.payeePatterns) priority=\(t.priority) id=\(t.id.uuidString)")
            }
        }
    }

    struct AddType: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "add", abstract: "Add a transaction type")
        @OptionGroup var config: CLIConfiguration
        @Option(help: "Type name") var name: String
        @Option(help: "Kind: spend or payment") var kind: String = "spend"
        @Option(help: "Target credit account lunchMoneyId") var targetAccount: Int
        @Option(help: "Funding account lunchMoneyId (spend types covered by another account, e.g. Cloud 9 → Reserve)") var fundingAccount: Int?
        @Option(help: "Comma-separated payee substrings to match") var patterns: String
        @Option(help: "Priority (higher matches first)") var priority: Int = 0

        func run() async throws {
            let (baseURL, username, password) = try config.requireCredentials()
            guard let typeKind = TransactionTypeKind(rawValue: kind) else {
                throw ValidationError("--kind must be 'spend' or 'payment'")
            }
            let payeePatterns = patterns.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let newType = TransactionType(
                name: name,
                kind: typeKind,
                fundingAccountId: typeKind == .payment ? nil : fundingAccount,
                targetAccountId: targetAccount,
                payeePatterns: payeePatterns,
                priority: priority
            )
            _ = try await Task { @MainActor in
                try await APIClient(baseURL: baseURL, serviceName: "CLI")
                    .putTransactionTypes(username: username, password: password, types: [newType])
            }.value
            print("Added [\(typeKind.rawValue)] type \"\(name)\" (id \(newType.id.uuidString)).")
        }
    }

    struct DeleteType: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete a transaction type by id (tombstone)")
        @OptionGroup var config: CLIConfiguration
        @Option(help: "Type id (UUID) to delete") var id: String

        func run() async throws {
            let (baseURL, username, password) = try config.requireCredentials()
            let typeId = id
            try await Task { @MainActor in
                let client = APIClient(baseURL: baseURL, serviceName: "CLI")
                let types = try await client.fetchTransactionTypes(username: username, password: password)
                guard var target = types.first(where: { $0.id.uuidString.caseInsensitiveCompare(typeId) == .orderedSame }) else {
                    throw ValidationError("No type with id \(typeId)")
                }
                target.isDeleted = true
                target.updatedAt = Date()
                _ = try await client.putTransactionTypes(username: username, password: password, types: [target])
            }.value
            print("Deleted type \(typeId).")
        }
    }
}
