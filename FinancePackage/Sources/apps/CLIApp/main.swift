import ArgumentParser
import Foundation

@main
struct GetRicherCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get-richer",
        abstract: "CLI tool for GetRicher Lambda local development",
        version: "1.0.0",
        subcommands: [InvokeCommand.self]
    )
}
