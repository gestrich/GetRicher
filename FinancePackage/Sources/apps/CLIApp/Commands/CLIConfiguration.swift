import ArgumentParser
import Foundation

struct CLIConfiguration: ParsableArguments {
    @Option(name: .long, help: "API base URL (or set GETRICHER_API_URL)")
    var baseURL: String = ProcessInfo.processInfo.environment["GETRICHER_API_URL"] ?? ""

    @Option(name: .long, help: "Username")
    var username: String = ""

    @Option(name: .long, help: "Password")
    var password: String = ""
}
