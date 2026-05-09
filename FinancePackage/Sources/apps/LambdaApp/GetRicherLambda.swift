import AWSLambdaEvents
import AWSLambdaRuntime
import FinanceCoreSDK
import Foundation
import LunchMoneySDK
import ReportingService
import SecretsService
import SotoSecretsManager

@main
struct GetRicherLambda {
    static func main() async throws {
        let lunchMoneyClient = LunchMoneyClient()

        if ProcessInfo.processInfo.environment["LUNCH_MONEY_TOKEN"] != nil {
            let secretsClient = EnvironmentSecretsClient()
            let runtime = LambdaRuntime { (event: APIGatewayRequest, context: LambdaContext) -> APIGatewayResponse in
                let token = try await secretsClient.secret(named: "LUNCH_MONEY_TOKEN")
                return try await Self.handle(token: token, client: lunchMoneyClient, context: context)
            }
            try await runtime.run()
        } else {
            let awsClient = AWSClient()
            let region = ProcessInfo.processInfo.environment["AWS_REGION"].map { Region(rawValue: $0) }
            let secretsClient = AWSSecretsClient(awsClient: awsClient, region: region)
            let runtime = LambdaRuntime { (event: APIGatewayRequest, context: LambdaContext) -> APIGatewayResponse in
                let token = try await secretsClient.secret(named: "LUNCH_MONEY_TOKEN")
                return try await Self.handle(token: token, client: lunchMoneyClient, context: context)
            }
            try await runtime.run()
            try? await awsClient.shutdown()
        }
    }

    static func handle(token: String, client: LunchMoneyClient, context: LambdaContext) async throws -> APIGatewayResponse {
        do {
            let response = try await client.fetchPlaidAccounts(token: token)
            let accounts = response.plaidAccounts.map { dto in
                Account(
                    lunchMoneyId: dto.id,
                    name: dto.name,
                    displayName: dto.displayName,
                    type: dto.type,
                    subtype: dto.subtype,
                    mask: dto.mask,
                    institutionName: dto.institutionName,
                    status: dto.status,
                    balance: dto.balance,
                    currency: dto.currency
                )
            }
            let summary = AccountSummary(accounts: accounts)
            let data = try JSONEncoder().encode(summary)
            let body = String(data: data, encoding: .utf8) ?? "{}"
            return APIGatewayResponse(
                statusCode: .ok,
                headers: ["Content-Type": "application/json"],
                body: body
            )
        } catch {
            context.logger.error("Handler error: \(error)")
            return APIGatewayResponse(
                statusCode: .internalServerError,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Internal server error"}"#
            )
        }
    }
}
