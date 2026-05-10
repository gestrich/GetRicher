import ArgumentParser
import ClientService
import Foundation

struct AdminCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "admin",
        abstract: "Admin management commands",
        subcommands: [
            AdminListUsersCommand.self,
            AdminDeleteUserCommand.self,
            AdminListReportsCommand.self,
            AdminDeleteReportCommand.self,
            AdminUpdateLMTokenCommand.self,
            AdminErrorsCommand.self,
        ]
    )
}

struct AdminListUsersCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-users",
        abstract: "List all registered users"
    )

    @OptionGroup var config: CLIConfiguration

    mutating func run() async throws {
        guard !config.baseURL.isEmpty else {
            throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
        }
        let baseURL = config.baseURL
        let users = try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            return try await client.adminListUsers()
        }.value
        if users.isEmpty {
            print("No users found.")
            return
        }
        for user in users {
            let tokenStatus = user.hasLMToken ? "has-token" : "no-token"
            print("\(user.username) | created: \(user.createdAt) | \(tokenStatus)")
        }
    }
}

struct AdminDeleteUserCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete-user",
        abstract: "Delete a user and all their data"
    )

    @OptionGroup var config: CLIConfiguration

    @Argument(help: "Username to delete")
    var username: String

    mutating func run() async throws {
        guard !config.baseURL.isEmpty else {
            throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
        }
        let baseURL = config.baseURL
        let usernameToDelete = username
        try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            try await client.adminDeleteUser(username: usernameToDelete)
        }.value
        print("Deleted user: \(username)")
    }
}

struct AdminListReportsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-reports",
        abstract: "List all review items across all users"
    )

    @OptionGroup var config: CLIConfiguration

    mutating func run() async throws {
        guard !config.baseURL.isEmpty else {
            throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
        }
        let baseURL = config.baseURL
        let reports = try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            return try await client.adminListReports()
        }.value
        if reports.isEmpty {
            print("No reports found.")
            return
        }
        for report in reports {
            print("[\(report.status.rawValue)] \(report.id) | \(report.title) | \(report.createdAt)")
        }
    }
}

struct AdminDeleteReportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete-report",
        abstract: "Delete a specific review item"
    )

    @OptionGroup var config: CLIConfiguration

    @Argument(help: "Report ID to delete")
    var reportId: String

    mutating func run() async throws {
        guard !config.baseURL.isEmpty else {
            throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
        }
        let baseURL = config.baseURL
        let id = reportId
        try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            try await client.adminDeleteReport(id: id)
        }.value
        print("Deleted report: \(reportId)")
    }
}

struct AdminUpdateLMTokenCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update-lm-token",
        abstract: "Update a user's Lunch Money token"
    )

    @OptionGroup var config: CLIConfiguration

    @Argument(help: "Username")
    var username: String

    @Option(name: .long, help: "New Lunch Money API token")
    var lmToken: String

    mutating func run() async throws {
        guard !config.baseURL.isEmpty else {
            throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
        }
        let baseURL = config.baseURL
        let usernameArg = username
        let tokenArg = lmToken
        try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            try await client.adminUpdateLMToken(username: usernameArg, lmToken: tokenArg)
        }.value
        print("Updated LM token for user: \(username)")
    }
}

struct AdminErrorsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "errors",
        abstract: "Fetch recent Lambda errors"
    )

    @OptionGroup var config: CLIConfiguration

    mutating func run() async throws {
        guard !config.baseURL.isEmpty else {
            throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
        }
        let baseURL = config.baseURL
        let response = try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            return try await client.adminErrors()
        }.value
        if !response.message.isEmpty {
            print("Status: \(response.message)")
        }
        if response.errors.isEmpty {
            print("No errors recorded.")
        } else {
            for error in response.errors {
                print(error)
            }
        }
    }
}
