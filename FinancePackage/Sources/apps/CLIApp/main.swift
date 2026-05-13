import ArgumentParser
import Foundation

@main
struct GetRicherCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get-richer",
        abstract: "GetRicher CLI — manage accounts, transactions, reports, and review items",
        version: "1.0.0",
        subcommands: [
            AccountsCommand.self,
            TransactionsCommand.self,
            RefreshCommand.self,
            ReportCommand.self,
            SendReportCommand.self,
            PaydownCommand.self,
            NotificationsCommand.self,
            ReviewItemsCommand.self,
            ResolveItemCommand.self,
            AdminCommand.self,
            InvokeCommand.self,
        ]
    )
}
