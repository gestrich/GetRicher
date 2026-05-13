import ArgumentParser
import ClientService
import FinanceCoreSDK
import Foundation

struct NotificationsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "notifications",
        abstract: "Manage push notification subscriptions",
        subcommands: [
            NotificationsListCommand.self,
            NotificationsSubscribeCommand.self,
            NotificationsUnsubscribeCommand.self,
            NotificationsSendNowCommand.self,
        ]
    )
}

struct NotificationsListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List notification subscriptions for the current user"
    )

    @OptionGroup var config: CLIConfiguration

    mutating func run() async throws {
        try validateConfig(config)
        let baseURL = config.baseURL
        let username = config.username
        let password = config.password
        let subscriptions = try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            return try await client.listNotificationSubscriptions(username: username, password: password)
        }.value
        if subscriptions.isEmpty {
            print("No subscriptions.")
            return
        }
        for s in subscriptions {
            let days = s.daysOfWeek.map { $0.rawValue }.joined(separator: ",")
            let lastSent = s.lastSentLocalDate.map { " | last sent: \($0)" } ?? ""
            print("account=\(s.accountId) days=\(days) hour=\(s.hour) tz=\(s.timezone) enabled=\(s.enabled)\(lastSent)")
        }
    }
}

struct NotificationsSubscribeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "subscribe",
        abstract: "Create or update a notification subscription for one account"
    )

    @OptionGroup var config: CLIConfiguration

    @Option(name: .long, help: "Account lunchMoneyId to subscribe to")
    var accountId: Int

    @Option(name: .long, help: "Comma-separated days (MON,TUE,WED,THU,FRI,SAT,SUN) or EVERY_DAY")
    var days: String

    @Option(name: .long, help: "Hour of the day (0-23) in the given timezone")
    var hour: Int

    @Option(name: .long, help: "IANA timezone (e.g. America/New_York, UTC)")
    var timezone: String = "UTC"

    @Flag(name: .long, help: "Disable the subscription (subscription is enabled by default)")
    var disabled: Bool = false

    mutating func run() async throws {
        try validateConfig(config)
        let parsedDays = try parseDays(days)
        guard (0...23).contains(hour) else { throw ValidationError("hour must be between 0 and 23") }
        guard TimeZone(identifier: timezone) != nil else { throw ValidationError("Invalid timezone identifier: \(timezone)") }

        let baseURL = config.baseURL
        let username = config.username
        let password = config.password
        let write = NotificationSubscriptionWrite(
            accountId: accountId,
            daysOfWeek: parsedDays,
            hour: hour,
            timezone: timezone,
            enabled: !disabled
        )
        let result = try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            return try await client.upsertNotificationSubscription(username: username, password: password, subscription: write)
        }.value
        let dayList = result.daysOfWeek.map { $0.rawValue }.joined(separator: ",")
        print("Subscribed account=\(result.accountId) days=\(dayList) hour=\(result.hour) tz=\(result.timezone) enabled=\(result.enabled)")
    }

    private func parseDays(_ raw: String) throws -> [DayOfWeek] {
        let trimmed = raw.trimmingCharacters(in: .whitespaces).uppercased()
        if trimmed == "EVERY_DAY" || trimmed == "EVERYDAY" || trimmed == "ALL" {
            return DayOfWeek.everyDay
        }
        if trimmed == "WEEKDAYS" {
            return DayOfWeek.weekdays
        }
        let parts = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var result: [DayOfWeek] = []
        for part in parts {
            guard let d = DayOfWeek(rawValue: part) else {
                throw ValidationError("Unknown day: '\(part)'. Use MON,TUE,WED,THU,FRI,SAT,SUN or EVERY_DAY.")
            }
            if !result.contains(d) { result.append(d) }
        }
        guard !result.isEmpty else { throw ValidationError("--days must list at least one day") }
        return result
    }
}

struct NotificationsUnsubscribeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "unsubscribe",
        abstract: "Delete a notification subscription for one account"
    )

    @OptionGroup var config: CLIConfiguration

    @Option(name: .long, help: "Account lunchMoneyId to unsubscribe")
    var accountId: Int

    mutating func run() async throws {
        try validateConfig(config)
        let baseURL = config.baseURL
        let username = config.username
        let password = config.password
        let id = accountId
        try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            try await client.deleteNotificationSubscription(username: username, password: password, accountId: id)
        }.value
        print("Unsubscribed account=\(accountId)")
    }
}

struct NotificationsSendNowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "send-now",
        abstract: "Fire all enabled subscriptions immediately (ignores schedule); useful for end-to-end testing"
    )

    @OptionGroup var config: CLIConfiguration

    mutating func run() async throws {
        try validateConfig(config)
        let baseURL = config.baseURL
        let username = config.username
        let password = config.password
        try await Task { @MainActor in
            let client = APIClient(baseURL: baseURL, serviceName: "CLI")
            try await client.sendReport(username: username, password: password)
        }.value
        print("Sent.")
    }
}

private func validateConfig(_ config: CLIConfiguration) throws {
    guard !config.baseURL.isEmpty else {
        throw ValidationError("--base-url is required (or set GETRICHER_API_URL)")
    }
    guard !config.username.isEmpty, !config.password.isEmpty else {
        throw ValidationError("--username and --password are required")
    }
}
