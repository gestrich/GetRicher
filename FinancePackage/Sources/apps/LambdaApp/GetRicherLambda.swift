import AWSLambdaEvents
import AWSLambdaRuntime
import FinanceCoreSDK
import Foundation
import LunchMoneySDK
import NotificationService
import ReportingService
import SecretsService
import SotoSecretsManager

@main
struct GetRicherLambda {
    static func main() async throws {
        let lunchMoneyClient = LunchMoneyClient()
        let dynamoTableName = ProcessInfo.processInfo.environment["DYNAMODB_TABLE_NAME"] ?? "get-richer"
        let region = ProcessInfo.processInfo.environment["AWS_REGION"].map { Region(rawValue: $0) }

        if ProcessInfo.processInfo.environment["LUNCH_MONEY_TOKEN"] != nil {
            let secretsClient = EnvironmentSecretsClient()
            let tokenStore: any DeviceTokenStoreProtocol = LoggingDeviceTokenStore()
            let notificationClient: any PushNotificationClientProtocol = LoggingPushNotificationClient()
            let runtime = LambdaRuntime { (event: APIGatewayRequest, context: LambdaContext) -> APIGatewayResponse in
                let lunchMoneyToken = try await secretsClient.secret(named: "LUNCH_MONEY_TOKEN")
                return try await Self.handle(
                    lunchMoneyToken: lunchMoneyToken,
                    client: lunchMoneyClient,
                    event: event,
                    context: context,
                    tokenStore: tokenStore,
                    notificationClient: notificationClient
                )
            }
            try await runtime.run()
        } else {
            let awsClient = AWSClient()
            let secretsClient = AWSSecretsClient(awsClient: awsClient, region: region)
            let tokenStore = DynamoDBDeviceTokenStore(awsClient: awsClient, region: region, tableName: dynamoTableName)
            let snsAppArn = ProcessInfo.processInfo.environment["SNS_PLATFORM_ARN"] ?? ""
            let notificationClient: any PushNotificationClientProtocol = snsAppArn.isEmpty
                ? LoggingPushNotificationClient()
                : SNSPushNotificationClient(awsClient: awsClient, region: region, platformApplicationArn: snsAppArn)
            let runtime = LambdaRuntime { (event: APIGatewayRequest, context: LambdaContext) -> APIGatewayResponse in
                let lunchMoneyToken = try await secretsClient.secret(named: "LUNCH_MONEY_TOKEN")
                return try await Self.handle(
                    lunchMoneyToken: lunchMoneyToken,
                    client: lunchMoneyClient,
                    event: event,
                    context: context,
                    tokenStore: tokenStore,
                    notificationClient: notificationClient
                )
            }
            try await runtime.run()
            try? await awsClient.shutdown()
        }
    }

    static func handle(
        lunchMoneyToken: String,
        client: LunchMoneyClient,
        event: APIGatewayRequest,
        context: LambdaContext,
        tokenStore: any DeviceTokenStoreProtocol,
        notificationClient: any PushNotificationClientProtocol
    ) async throws -> APIGatewayResponse {
        do {
            if event.httpMethod == .post && event.path == "/api/device-tokens" {
                return try await handleDeviceTokenRegistration(event: event, tokenStore: tokenStore, context: context)
            } else if event.httpMethod == .get && event.path == "/api/low-balance-check" {
                return try await handleLowBalanceCheck(
                    lunchMoneyToken: lunchMoneyToken,
                    client: client,
                    tokenStore: tokenStore,
                    notificationClient: notificationClient,
                    event: event,
                    context: context
                )
            } else {
                return try await handleAccountSummary(token: lunchMoneyToken, client: client, context: context)
            }
        } catch {
            context.logger.error("Handler error: \(error)")
            return APIGatewayResponse(
                statusCode: .internalServerError,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Internal server error"}"#
            )
        }
    }

    private static func handleDeviceTokenRegistration(
        event: APIGatewayRequest,
        tokenStore: any DeviceTokenStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard let bodyString = event.body,
              let bodyData = bodyString.data(using: .utf8),
              let request = try? JSONDecoder().decode(DeviceTokenRequest.self, from: bodyData)
        else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Missing or invalid body"}"#
            )
        }
        let token = DeviceToken(tokenString: request.token, environment: request.environment)
        try await tokenStore.store(token)
        context.logger.info("Stored device token: \(token.id)")
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: #"{"status":"ok"}"#
        )
    }

    private static func handleLowBalanceCheck(
        lunchMoneyToken: String,
        client: LunchMoneyClient,
        tokenStore: any DeviceTokenStoreProtocol,
        notificationClient: any PushNotificationClientProtocol,
        event: APIGatewayRequest,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        let threshold = Double(ProcessInfo.processInfo.environment["LOW_BALANCE_THRESHOLD"] ?? "100") ?? 100.0
        let response = try await client.fetchPlaidAccounts(token: lunchMoneyToken)
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
        let lowAccounts = accounts.filter { (Double($0.balance) ?? 0) < threshold }
        var notificationsSent = 0
        if !lowAccounts.isEmpty {
            let tokens = try await tokenStore.fetchAll()
            if !tokens.isEmpty {
                for account in lowAccounts {
                    let payload = NotificationPayload(
                        title: "Low Balance Alert",
                        body: "\(account.displayName) balance is \(account.balance) \(account.currency)",
                        data: ["deepLink": "dashboard"]
                    )
                    try await notificationClient.send(payload, to: tokens)
                    notificationsSent += 1
                }
            }
        }
        context.logger.info("Low balance check: \(lowAccounts.count) low account(s), \(notificationsSent) notification(s) sent")
        struct CheckResult: Encodable {
            let accounts: AccountSummary
            let lowBalanceCount: Int
            let notificationsSent: Int
            let threshold: Double
        }
        let result = CheckResult(
            accounts: summary,
            lowBalanceCount: lowAccounts.count,
            notificationsSent: notificationsSent,
            threshold: threshold
        )
        let data = try JSONEncoder().encode(result)
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "{}"
        )
    }

    private static func handleAccountSummary(
        token: String,
        client: LunchMoneyClient,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
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
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "{}"
        )
    }
}

private struct DeviceTokenRequest: Decodable {
    let token: String
    let environment: String
}

private struct LoggingDeviceTokenStore: DeviceTokenStoreProtocol {
    func store(_ token: DeviceToken) async throws {
        print("[DeviceTokenStore] STUB store token: \(token.id)")
    }
    func fetchAll() async throws -> [DeviceToken] {
        print("[DeviceTokenStore] STUB fetchAll -> []")
        return []
    }
}
