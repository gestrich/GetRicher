import AWSLambdaRuntime
import AWSLambdaEvents
import Foundation

@main
struct GetRicherLambda {
    static func main() async throws {
        let runtime = LambdaRuntime { (event: APIGatewayRequest, context: LambdaContext) -> APIGatewayResponse in
            APIGatewayResponse(
                statusCode: .ok,
                headers: ["Content-Type": "application/json"],
                body: #"{"message":"hello"}"#
            )
        }
        try await runtime.run()
    }
}
