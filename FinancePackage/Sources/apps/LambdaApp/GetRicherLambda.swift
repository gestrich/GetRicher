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
            let reviewItemStore: any ReviewItemStoreProtocol = LoggingReviewItemStore()
            let userStore: any UserStoreProtocol = LoggingUserStore()
            let accountStore: any AccountStoreProtocol = LoggingAccountStore()
            let transactionStore: any TransactionStoreProtocol = LoggingTransactionStore()
            let notificationClient: any PushNotificationClientProtocol = LoggingPushNotificationClient()
            let runtime = LambdaRuntime { (event: LambdaDispatchEvent, context: LambdaContext) -> APIGatewayResponse in
                let lunchMoneyToken = try await secretsClient.secret(named: "LUNCH_MONEY_TOKEN")
                return try await Self.handle(
                    lunchMoneyToken: lunchMoneyToken,
                    client: lunchMoneyClient,
                    event: event,
                    context: context,
                    tokenStore: tokenStore,
                    reviewItemStore: reviewItemStore,
                    userStore: userStore,
                    accountStore: accountStore,
                    transactionStore: transactionStore,
                    notificationClient: notificationClient
                )
            }
            try await runtime.run()
        } else {
            let awsClient = AWSClient(middleware: LoggingMiddleware())
            let secretsClient = AWSSecretsClient(awsClient: awsClient, region: region)
            let tokenStore = DynamoDBDeviceTokenStore(awsClient: awsClient, region: region, tableName: dynamoTableName)
            let reviewItemStore = DynamoDBReviewItemStore(awsClient: awsClient, region: region, tableName: dynamoTableName)
            let userStore = DynamoDBUserStore(awsClient: awsClient, region: region, tableName: dynamoTableName)
            let accountStore = DynamoDBAccountStore(awsClient: awsClient, region: region, tableName: dynamoTableName)
            let transactionStore = DynamoDBTransactionStore(awsClient: awsClient, region: region, tableName: dynamoTableName)
            let snsAppArn = ProcessInfo.processInfo.environment["SNS_PLATFORM_ARN"] ?? ""
            let notificationClient: any PushNotificationClientProtocol = snsAppArn.isEmpty
                ? LoggingPushNotificationClient()
                : SNSPushNotificationClient(awsClient: awsClient, region: region, platformApplicationArn: snsAppArn)
            let runtime = LambdaRuntime { (event: LambdaDispatchEvent, context: LambdaContext) -> APIGatewayResponse in
                let lunchMoneyToken = try await secretsClient.secret(named: "LUNCH_MONEY_TOKEN")
                return try await Self.handle(
                    lunchMoneyToken: lunchMoneyToken,
                    client: lunchMoneyClient,
                    event: event,
                    context: context,
                    tokenStore: tokenStore,
                    reviewItemStore: reviewItemStore,
                    userStore: userStore,
                    accountStore: accountStore,
                    transactionStore: transactionStore,
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
        event: LambdaDispatchEvent,
        context: LambdaContext,
        tokenStore: any DeviceTokenStoreProtocol,
        reviewItemStore: any ReviewItemStoreProtocol,
        userStore: any UserStoreProtocol,
        accountStore: any AccountStoreProtocol,
        transactionStore: any TransactionStoreProtocol,
        notificationClient: any PushNotificationClientProtocol
    ) async throws -> APIGatewayResponse {
        do {
            switch event.kind {
            case .apiGateway(let request):
                return try await handleAPIGateway(
                    lunchMoneyToken: lunchMoneyToken,
                    client: client,
                    request: request,
                    context: context,
                    tokenStore: tokenStore,
                    reviewItemStore: reviewItemStore,
                    userStore: userStore,
                    accountStore: accountStore,
                    transactionStore: transactionStore,
                    notificationClient: notificationClient
                )
            case .scheduled:
                context.logger.info("EventBridge scheduled trigger received")
                await handleHourlyDataFetch(
                    client: client,
                    userStore: userStore,
                    accountStore: accountStore,
                    transactionStore: transactionStore,
                    context: context
                )
                return try await handleGenerateReport(
                    lunchMoneyToken: lunchMoneyToken,
                    client: client,
                    reviewItemStore: reviewItemStore,
                    tokenStore: tokenStore,
                    notificationClient: notificationClient,
                    context: context
                )
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

    private static func handleAPIGateway(
        lunchMoneyToken: String,
        client: LunchMoneyClient,
        request: APIGatewayRequest,
        context: LambdaContext,
        tokenStore: any DeviceTokenStoreProtocol,
        reviewItemStore: any ReviewItemStoreProtocol,
        userStore: any UserStoreProtocol,
        accountStore: any AccountStoreProtocol,
        transactionStore: any TransactionStoreProtocol,
        notificationClient: any PushNotificationClientProtocol
    ) async throws -> APIGatewayResponse {
        if request.httpMethod == .post && request.path == "/api/users/register" {
            return try await handleUserRegistration(event: request, userStore: userStore, context: context)
        } else if request.httpMethod == .post && request.path == "/api/device-tokens" {
            return try await handleDeviceTokenRegistration(event: request, tokenStore: tokenStore, userStore: userStore, context: context)
        } else if request.httpMethod == .get && request.path == "/api/low-balance-check" {
            return try await handleLowBalanceCheck(
                lunchMoneyToken: lunchMoneyToken,
                client: client,
                tokenStore: tokenStore,
                notificationClient: notificationClient,
                event: request,
                context: context
            )
        } else if request.httpMethod == .get && request.path == "/api/review-items" {
            return try await handleGetReviewItems(reviewItemStore: reviewItemStore, context: context)
        } else if request.httpMethod == .post && request.path == "/api/review-items/resolve" {
            return try await handleResolveReviewItem(event: request, reviewItemStore: reviewItemStore, context: context)
        } else if request.httpMethod == .post && request.path == "/api/generate-report" {
            return try await handleGenerateReport(
                lunchMoneyToken: lunchMoneyToken,
                client: client,
                reviewItemStore: reviewItemStore,
                tokenStore: tokenStore,
                notificationClient: notificationClient,
                context: context
            )
        } else if request.httpMethod == .post && request.path == "/api/send-my-report" {
            return try await handleSendMyReport(
                lunchMoneyToken: lunchMoneyToken,
                client: client,
                tokenStore: tokenStore,
                userStore: userStore,
                notificationClient: notificationClient,
                event: request,
                context: context
            )
        } else if request.httpMethod == .post && request.path == "/api/test-push" {
            return try await handleTestPush(tokenStore: tokenStore, notificationClient: notificationClient, context: context)
        } else {
            return try await handleAccountSummary(token: lunchMoneyToken, client: client, context: context)
        }
    }

    private static func handleUserRegistration(
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard let bodyString = event.body,
              let bodyData = bodyString.data(using: .utf8),
              let request = try? JSONDecoder().decode(UserRegistrationRequest.self, from: bodyData)
        else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Missing or invalid body"}"#
            )
        }
        if try await userStore.find(username: request.username) != nil {
            return APIGatewayResponse(
                statusCode: .conflict,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Username already exists"}"#
            )
        }
        let user = UserAccount(
            username: request.username,
            passwordHash: UserAccount.hashPassword(request.password),
            createdAt: ISO8601DateFormatter().string(from: Date()),
            lunchMoneyToken: request.lunchMoneyToken
        )
        try await userStore.create(user)
        context.logger.info("Registered user: \(user.username)")
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: #"{"status":"ok"}"#
        )
    }

    private static func handleDeviceTokenRegistration(
        event: APIGatewayRequest,
        tokenStore: any DeviceTokenStoreProtocol,
        userStore: any UserStoreProtocol,
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
        guard let user = try await userStore.find(username: request.username),
              UserAccount.hashPassword(request.password) == user.passwordHash
        else {
            return APIGatewayResponse(
                statusCode: .unauthorized,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Invalid credentials"}"#
            )
        }
        let token = DeviceToken(tokenString: request.token, environment: request.environment, userId: request.username)
        try await tokenStore.store(token)
        context.logger.info("Stored device token: \(token.id) for user: \(request.username)")
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
                        data: ["deepLink": "inbox"]
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

    private static func handleGetReviewItems(
        reviewItemStore: any ReviewItemStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        let items = try await reviewItemStore.fetchPending()
        context.logger.info("Fetched \(items.count) pending review item(s)")
        let data = try JSONEncoder().encode(items)
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "[]"
        )
    }

    private static func handleResolveReviewItem(
        event: APIGatewayRequest,
        reviewItemStore: any ReviewItemStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard let bodyString = event.body,
              let bodyData = bodyString.data(using: .utf8),
              let request = try? JSONDecoder().decode(ResolveRequest.self, from: bodyData),
              let status = ReviewItem.Status(rawValue: request.status)
        else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Missing or invalid body"}"#
            )
        }
        try await reviewItemStore.resolve(id: request.id, status: status)
        context.logger.info("Resolved review item \(request.id) with status \(request.status)")
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: #"{"status":"ok"}"#
        )
    }

    private static func handleHourlyDataFetch(
        client: LunchMoneyClient,
        userStore: any UserStoreProtocol,
        accountStore: any AccountStoreProtocol,
        transactionStore: any TransactionStoreProtocol,
        context: LambdaContext
    ) async {
        do {
            let users = try await userStore.fetchAll()
            context.logger.info("Hourly data fetch: processing \(users.count) user(s)")

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate
            let startDateString = dateFormatter.string(from: startDate)
            let endDateString = dateFormatter.string(from: endDate)

            for user in users {
                guard let token = user.lunchMoneyToken else {
                    context.logger.info("Skipping user \(user.username): no LM token")
                    continue
                }
                do {
                    let accountsResponse = try await client.fetchPlaidAccounts(token: token)
                    let accounts = accountsResponse.plaidAccounts.map { dto in
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
                    try await accountStore.store(accounts, userId: user.username)

                    let limit = 500
                    var offset = 0
                    var allTransactions: [Transaction] = []
                    while true {
                        let response = try await client.fetchTransactions(
                            token: token,
                            accountId: nil,
                            startDate: startDateString,
                            endDate: endDateString,
                            limit: limit,
                            offset: offset
                        )
                        allTransactions.append(contentsOf: response.transactions.map { $0.toDomain() })
                        if response.transactions.count < limit { break }
                        offset += limit
                    }
                    try await transactionStore.store(allTransactions, userId: user.username)

                    context.logger.info("Synced user \(user.username): \(accounts.count) account(s), \(allTransactions.count) transaction(s)")
                } catch {
                    context.logger.error("Failed to sync user \(user.username): \(error)")
                }
            }
        } catch {
            context.logger.error("Hourly data fetch failed to load users: \(error)")
        }
    }

    private static func generatePaydownData(
        lunchMoneyToken: String,
        client: LunchMoneyClient,
        context: LambdaContext
    ) async throws -> (accounts: [Account], notificationBody: String) {
        let pivotDayString = ProcessInfo.processInfo.environment["PIVOT_DAY"] ?? "saturday"
        let pivotDay = PivotDay.allCases.first { $0.rawValue.lowercased() == pivotDayString.lowercased() } ?? .saturday

        let accountsResponse = try await client.fetchPlaidAccounts(token: lunchMoneyToken)
        let accounts = accountsResponse.plaidAccounts.map { dto in
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

        let range = PaydownDateRange.compute(pivotDay: pivotDay)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fetchEndDate: String
        if let rangeEndDate = dateFormatter.date(from: range.end),
           let extended = Calendar.current.date(byAdding: .day, value: 7, to: rangeEndDate) {
            fetchEndDate = dateFormatter.string(from: extended)
        } else {
            fetchEndDate = range.end
        }

        let limit = 500
        var offset = 0
        var allTransactionDTOs: [TransactionDTO] = []
        while true {
            let response = try await client.fetchTransactions(
                token: lunchMoneyToken,
                accountId: nil,
                startDate: range.start,
                endDate: fetchEndDate,
                limit: limit,
                offset: offset
            )
            allTransactionDTOs.append(contentsOf: response.transactions)
            if response.transactions.count < limit { break }
            offset += limit
        }

        let transactions = allTransactionDTOs.map { $0.toDomain() }
        let reports = WeeklyPaydownReport.compute(accounts: accounts, transactions: transactions, pivotDay: pivotDay)
        let body = WeeklyPaydownReport.notificationBody(from: reports)
        let notificationBody = body.isEmpty ? "No credit accounts found" : body

        return (accounts: accounts, notificationBody: notificationBody)
    }

    private static func handleGenerateReport(
        lunchMoneyToken: String,
        client: LunchMoneyClient,
        reviewItemStore: any ReviewItemStoreProtocol,
        tokenStore: any DeviceTokenStoreProtocol,
        notificationClient: any PushNotificationClientProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        let (accounts, summaryText) = try await generatePaydownData(
            lunchMoneyToken: lunchMoneyToken,
            client: client,
            context: context
        )

        let now = ISO8601DateFormatter().string(from: Date())
        let item = ReviewItem(
            id: UUID().uuidString,
            kind: .funAccountBalance,
            title: "Daily Paydown Report",
            summary: summaryText,
            status: .pending,
            createdAt: now
        )
        try await reviewItemStore.store(item)

        let tokens = try await tokenStore.fetchAll()
        if !tokens.isEmpty {
            let payload = NotificationPayload(
                title: "Weekly Paydown Report",
                body: summaryText,
                data: ["deepLink": "inbox"]
            )
            try await notificationClient.send(payload, to: tokens)
        }
        context.logger.info("Generated paydown report: stored review item \(item.id), notified \(tokens.count) device(s)")

        struct GenerateResult: Encodable {
            let reviewItemId: String
            let accountCount: Int
            let notificationsSent: Int
        }
        let result = GenerateResult(
            reviewItemId: item.id,
            accountCount: accounts.count,
            notificationsSent: tokens.count
        )
        let data = try JSONEncoder().encode(result)
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "{}"
        )
    }

    private static func handleSendMyReport(
        lunchMoneyToken: String,
        client: LunchMoneyClient,
        tokenStore: any DeviceTokenStoreProtocol,
        userStore: any UserStoreProtocol,
        notificationClient: any PushNotificationClientProtocol,
        event: APIGatewayRequest,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard let bodyString = event.body,
              let bodyData = bodyString.data(using: .utf8),
              let request = try? JSONDecoder().decode(SendMyReportRequest.self, from: bodyData)
        else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Missing or invalid body"}"#
            )
        }
        guard let user = try await userStore.find(username: request.username),
              UserAccount.hashPassword(request.password) == user.passwordHash
        else {
            return APIGatewayResponse(
                statusCode: .unauthorized,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Invalid credentials"}"#
            )
        }

        let (_, summaryText) = try await generatePaydownData(
            lunchMoneyToken: lunchMoneyToken,
            client: client,
            context: context
        )

        let allTokens = try await tokenStore.fetchAll()
        let userTokens = allTokens.filter { $0.userId == request.username }

        var notificationsSent = 0
        if !userTokens.isEmpty {
            let payload = NotificationPayload(
                title: "Weekly Paydown Report",
                body: summaryText,
                data: ["deepLink": "inbox"]
            )
            try await notificationClient.send(payload, to: userTokens)
            notificationsSent = userTokens.count
        }
        context.logger.info("Sent report to user \(request.username): \(notificationsSent) device(s)")

        struct SendReportResult: Encodable {
            let status: String
            let notificationsSent: Int
        }
        let result = SendReportResult(status: "ok", notificationsSent: notificationsSent)
        let data = try JSONEncoder().encode(result)
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "{}"
        )
    }

    private static func handleTestPush(
        tokenStore: any DeviceTokenStoreProtocol,
        notificationClient: any PushNotificationClientProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        let tokens = try await tokenStore.fetchAll()
        guard !tokens.isEmpty else {
            return APIGatewayResponse(
                statusCode: .ok,
                headers: ["Content-Type": "application/json"],
                body: #"{"status":"ok","notificationsSent":0,"message":"No device tokens registered"}"#
            )
        }
        let payload = NotificationPayload(
            title: "Test Notification",
            body: "Push notifications are working.",
            data: ["deepLink": "inbox"]
        )
        try await notificationClient.send(payload, to: tokens)
        context.logger.info("Test push sent to \(tokens.count) device(s)")
        struct TestResult: Encodable {
            let status: String
            let notificationsSent: Int
        }
        let result = TestResult(status: "ok", notificationsSent: tokens.count)
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

// MARK: - Private types

private struct UserRegistrationRequest: Decodable {
    let username: String
    let password: String
    let lunchMoneyToken: String?
}

private struct DeviceTokenRequest: Decodable {
    let token: String
    let environment: String
    let username: String
    let password: String
}

private struct ResolveRequest: Decodable {
    let id: String
    let status: String
}

private struct SendMyReportRequest: Decodable {
    let username: String
    let password: String
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

// MARK: - Lambda dispatch event

struct LambdaDispatchEvent: Decodable, Sendable {
    enum Kind: Sendable {
        case apiGateway(APIGatewayRequest)
        case scheduled
    }

    let kind: Kind

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if (try? container.decodeIfPresent(String.self, forKey: .httpMethod)) != nil {
            kind = .apiGateway(try APIGatewayRequest(from: decoder))
        } else {
            kind = .scheduled
        }
    }

    enum CodingKeys: String, CodingKey {
        case httpMethod
    }
}
