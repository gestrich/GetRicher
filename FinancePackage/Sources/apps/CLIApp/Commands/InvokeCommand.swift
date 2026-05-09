import ArgumentParser
import ClientService
import Foundation

struct InvokeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "invoke",
        abstract: "Invoke the local Lambda handler. Requires LambdaApp running with LOCAL_LAMBDA_SERVER_ENABLED=1."
    )

    @Option(name: .long, help: "Route path to invoke")
    var route: String = "/hello"

    @Option(name: .long, help: "Local Lambda server port")
    var port: Int = 8080

    mutating func run() async throws {
        let localPort = port
        let localRoute = route
        let data = try await Task { @MainActor in
            let client = APIClient(localPort: localPort, serviceName: "CLIInvoke")
            return try await client.get(localRoute)
        }.value
        print(String(data: data, encoding: .utf8) ?? "")
    }
}
