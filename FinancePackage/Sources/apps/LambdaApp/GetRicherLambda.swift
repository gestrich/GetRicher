import AWSLambdaEvents
import AWSLambdaRuntime
import Crypto
import FinanceCoreSDK
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HTTPTypes
import LunchMoneySDK
import NotificationService
import ReportingService
import SecretsService
import SotoCloudWatchLogs
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
            let transferRuleStore: any TransferRuleStoreProtocol = LoggingTransferRuleStore()
            let vendorStore: any VendorStoreProtocol = LoggingVendorStore()
            let subscriptionStore: any NotificationSubscriptionStoreProtocol = LoggingNotificationSubscriptionStore()
            let notificationClient: any PushNotificationClientProtocol = LoggingPushNotificationClient()
            let iosLogsClient: any IOSLogsClientProtocol = LoggingIOSLogsClient()
            let runtime = LambdaRuntime { (event: LambdaDispatchEvent, context: LambdaContext) -> APIGatewayResponse in
                let lunchMoneyToken = try await secretsClient.secret(named: "LUNCH_MONEY_TOKEN")
                let githubToken = (try? await secretsClient.secret(named: "GITHUB_TOKEN")) ?? ""
                return try await Self.handle(
                    lunchMoneyToken: lunchMoneyToken,
                    githubToken: githubToken,
                    client: lunchMoneyClient,
                    event: event,
                    context: context,
                    tokenStore: tokenStore,
                    reviewItemStore: reviewItemStore,
                    userStore: userStore,
                    accountStore: accountStore,
                    transactionStore: transactionStore,
                    transferRuleStore: transferRuleStore,
                    vendorStore: vendorStore,
                    subscriptionStore: subscriptionStore,
                    notificationClient: notificationClient,
                    iosLogsClient: iosLogsClient
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
            let transferRuleStore = DynamoDBTransferRuleStore(awsClient: awsClient, region: region, tableName: dynamoTableName)
            let vendorStore = DynamoDBVendorStore(awsClient: awsClient, region: region, tableName: dynamoTableName)
            let subscriptionStore = DynamoDBNotificationSubscriptionStore(awsClient: awsClient, region: region, tableName: dynamoTableName)
            let snsAppArn = ProcessInfo.processInfo.environment["SNS_PLATFORM_ARN"] ?? ""
            let notificationClient: any PushNotificationClientProtocol = snsAppArn.isEmpty
                ? LoggingPushNotificationClient()
                : SNSPushNotificationClient(awsClient: awsClient, region: region, platformApplicationArn: snsAppArn)
            let iosLogsClient: any IOSLogsClientProtocol = AWSIOSLogsClient(awsClient: awsClient, region: region)
            let runtime = LambdaRuntime { (event: LambdaDispatchEvent, context: LambdaContext) -> APIGatewayResponse in
                let lunchMoneyToken = try await secretsClient.secret(named: "LUNCH_MONEY_TOKEN")
                let githubToken = (try? await secretsClient.secret(named: "GITHUB_TOKEN")) ?? ""
                return try await Self.handle(
                    lunchMoneyToken: lunchMoneyToken,
                    githubToken: githubToken,
                    client: lunchMoneyClient,
                    event: event,
                    context: context,
                    tokenStore: tokenStore,
                    reviewItemStore: reviewItemStore,
                    userStore: userStore,
                    accountStore: accountStore,
                    transactionStore: transactionStore,
                    transferRuleStore: transferRuleStore,
                    vendorStore: vendorStore,
                    subscriptionStore: subscriptionStore,
                    notificationClient: notificationClient,
                    iosLogsClient: iosLogsClient
                )
            }
            try await runtime.run()
            try? await awsClient.shutdown()
        }
    }

    static func handle(
        lunchMoneyToken: String,
        githubToken: String,
        client: LunchMoneyClient,
        event: LambdaDispatchEvent,
        context: LambdaContext,
        tokenStore: any DeviceTokenStoreProtocol,
        reviewItemStore: any ReviewItemStoreProtocol,
        userStore: any UserStoreProtocol,
        accountStore: any AccountStoreProtocol,
        transactionStore: any TransactionStoreProtocol,
        transferRuleStore: any TransferRuleStoreProtocol,
        vendorStore: any VendorStoreProtocol,
        subscriptionStore: any NotificationSubscriptionStoreProtocol,
        notificationClient: any PushNotificationClientProtocol,
        iosLogsClient: any IOSLogsClientProtocol
    ) async throws -> APIGatewayResponse {
        do {
            switch event.kind {
            case .apiGateway(let request):
                return try await handleAPIGateway(
                    lunchMoneyToken: lunchMoneyToken,
                    githubToken: githubToken,
                    client: client,
                    request: request,
                    context: context,
                    tokenStore: tokenStore,
                    reviewItemStore: reviewItemStore,
                    userStore: userStore,
                    accountStore: accountStore,
                    transactionStore: transactionStore,
                    transferRuleStore: transferRuleStore,
                    vendorStore: vendorStore,
                    subscriptionStore: subscriptionStore,
                    notificationClient: notificationClient,
                    iosLogsClient: iosLogsClient
                )
            case .scheduled(let task):
                context.logger.info("EventBridge scheduled trigger: task=\(task ?? "<none>")")
                switch task {
                case "refresh":
                    await handleHourlyDataFetch(
                        client: client,
                        globalLunchMoneyToken: lunchMoneyToken,
                        userStore: userStore,
                        accountStore: accountStore,
                        transactionStore: transactionStore,
                        context: context
                    )
                    return APIGatewayResponse(statusCode: .ok, headers: [:], body: #"{"status":"ok"}"#)
                case "push":
                    await handleSubscriptionPushTick(
                        now: Date(),
                        userStore: userStore,
                        accountStore: accountStore,
                        transactionStore: transactionStore,
                        transferRuleStore: transferRuleStore,
                        vendorStore: vendorStore,
                        tokenStore: tokenStore,
                        subscriptionStore: subscriptionStore,
                        notificationClient: notificationClient,
                        context: context
                    )
                    return APIGatewayResponse(statusCode: .ok, headers: [:], body: #"{"status":"ok"}"#)
                default:
                    // Unknown / no payload: ignore. The canonical scheduled tasks are
                    // "refresh" (hourly LM→DynamoDB sync) and "push" (hourly subscription evaluator).
                    context.logger.warning("Ignoring scheduled trigger with unknown task=\(task ?? "<none>")")
                    return APIGatewayResponse(statusCode: .ok, headers: [:], body: #"{"status":"ignored"}"#)
                }
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
        githubToken: String,
        client: LunchMoneyClient,
        request: APIGatewayRequest,
        context: LambdaContext,
        tokenStore: any DeviceTokenStoreProtocol,
        reviewItemStore: any ReviewItemStoreProtocol,
        userStore: any UserStoreProtocol,
        accountStore: any AccountStoreProtocol,
        transactionStore: any TransactionStoreProtocol,
        transferRuleStore: any TransferRuleStoreProtocol,
        vendorStore: any VendorStoreProtocol,
        subscriptionStore: any NotificationSubscriptionStoreProtocol,
        notificationClient: any PushNotificationClientProtocol,
        iosLogsClient: any IOSLogsClientProtocol
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
                userStore: userStore,
                accountStore: accountStore,
                transactionStore: transactionStore,
                transferRuleStore: transferRuleStore,
                vendorStore: vendorStore,
                tokenStore: tokenStore,
                subscriptionStore: subscriptionStore,
                notificationClient: notificationClient,
                context: context
            )
        } else if request.httpMethod == .post && request.path == "/api/send-my-report" {
            return try await handleSendMyReport(
                tokenStore: tokenStore,
                userStore: userStore,
                accountStore: accountStore,
                transactionStore: transactionStore,
                transferRuleStore: transferRuleStore,
                vendorStore: vendorStore,
                subscriptionStore: subscriptionStore,
                notificationClient: notificationClient,
                event: request,
                context: context
            )
        } else if request.httpMethod == .get && request.path == "/api/notification-subscriptions" {
            return try await handleListSubscriptions(
                event: request,
                userStore: userStore,
                subscriptionStore: subscriptionStore,
                context: context
            )
        } else if request.httpMethod == .post && request.path == "/api/notification-subscriptions" {
            return try await handleUpsertSubscription(
                event: request,
                userStore: userStore,
                accountStore: accountStore,
                subscriptionStore: subscriptionStore,
                context: context
            )
        } else if request.httpMethod == .post && request.path == "/api/notification-subscriptions/delete" {
            return try await handleDeleteSubscription(
                event: request,
                userStore: userStore,
                subscriptionStore: subscriptionStore,
                context: context
            )
        } else if request.httpMethod == .get && request.path == "/api/weekly-paydown" {
            return try await handleWeeklyPaydown(
                event: request,
                userStore: userStore,
                accountStore: accountStore,
                transactionStore: transactionStore,
                transferRuleStore: transferRuleStore,
                vendorStore: vendorStore,
                context: context
            )
        } else if request.httpMethod == .get && request.path == "/api/transfer-rules" {
            return try await handleGetTransferRules(event: request, userStore: userStore, transferRuleStore: transferRuleStore, context: context)
        } else if request.httpMethod == .put && request.path == "/api/transfer-rules" {
            return try await handlePutTransferRules(event: request, userStore: userStore, transferRuleStore: transferRuleStore, context: context)
        } else if request.httpMethod == .get && request.path == "/api/vendors" {
            return try await handleGetVendors(event: request, userStore: userStore, vendorStore: vendorStore, context: context)
        } else if request.httpMethod == .put && request.path == "/api/vendors" {
            return try await handlePutVendors(event: request, userStore: userStore, vendorStore: vendorStore, context: context)
        } else if request.httpMethod == .get && request.path == "/api/accounts" {
            return try await handleGetAccounts(event: request, userStore: userStore, accountStore: accountStore, context: context)
        } else if request.httpMethod == .get && request.path == "/api/transactions" {
            return try await handleGetTransactions(event: request, userStore: userStore, transactionStore: transactionStore, context: context)
        } else if request.httpMethod == .post && request.path == "/api/refresh" {
            return try await handleRefresh(event: request, client: client, globalLunchMoneyToken: lunchMoneyToken, userStore: userStore, accountStore: accountStore, transactionStore: transactionStore, context: context)
        } else if request.httpMethod == .post && request.path == "/api/test-push" {
            return try await handleTestPush(tokenStore: tokenStore, notificationClient: notificationClient, context: context)
        } else if request.httpMethod == .get && request.path == "/api/admin/users" {
            return try await handleAdminListUsers(event: request, userStore: userStore, context: context)
        } else if request.httpMethod == .delete && request.path.hasPrefix("/api/admin/users/") && !request.path.hasSuffix("/lm-token") {
            let username = String(request.path.dropFirst("/api/admin/users/".count))
            return try await handleAdminDeleteUser(username: username, event: request, userStore: userStore, accountStore: accountStore, transactionStore: transactionStore, tokenStore: tokenStore, context: context)
        } else if request.httpMethod == .put && request.path.hasSuffix("/lm-token") && request.path.hasPrefix("/api/admin/users/") {
            let withoutPrefix = String(request.path.dropFirst("/api/admin/users/".count))
            let username = String(withoutPrefix.dropLast("/lm-token".count))
            return try await handleAdminUpdateLMToken(username: username, event: request, userStore: userStore, context: context)
        } else if request.httpMethod == .get && request.path == "/api/admin/reports" {
            return try await handleAdminListReports(event: request, reviewItemStore: reviewItemStore, context: context)
        } else if request.httpMethod == .delete && request.path.hasPrefix("/api/admin/reports/") {
            let reportId = String(request.path.dropFirst("/api/admin/reports/".count))
            return try await handleAdminDeleteReport(reportId: reportId, event: request, reviewItemStore: reviewItemStore, context: context)
        } else if request.httpMethod == .get && request.path == "/api/admin/errors" {
            return try await handleAdminErrors(iosLogsClient: iosLogsClient, context: context)
        } else if request.httpMethod == .get && request.path == "/api/build-status" {
            return try await handleBuildStatus(githubToken: githubToken, context: context)
        } else if request.httpMethod == .post && request.path == "/api/otlp/logs" {
            return try await handleOTLPLogs(event: request, userStore: userStore, context: context)
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
        globalLunchMoneyToken: String,
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
                let token = user.lunchMoneyToken ?? globalLunchMoneyToken
                let tokenSource = user.lunchMoneyToken != nil ? "per-user" : "global-fallback"
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

                    context.logger.info("Synced user \(user.username) [token=\(tokenSource)]: \(accounts.count) account(s), \(allTransactions.count) transaction(s)")
                } catch {
                    context.logger.error("Failed to sync user \(user.username): \(error)")
                }
            }
        } catch {
            context.logger.error("Hourly data fetch failed to load users: \(error)")
        }
    }

    private static func pivotDay() -> PivotDay {
        let raw = ProcessInfo.processInfo.environment["PIVOT_DAY"] ?? "saturday"
        return PivotDay.allCases.first { $0.rawValue.lowercased() == raw.lowercased() } ?? .saturday
    }

    /// Computes a user's current-period paydown from DynamoDB. DynamoDB is the single source
    /// of truth — Lunch Money is only consulted by the hourly sync, never by report/API reads.
    /// TransferRules + Vendors are pushed by the iOS app and applied here so the notification
    /// body reflects the same "Amount to Pay" the iOS Weekly Paydown view shows.
    private static func computeCurrentPeriodFromDynamoDB(
        userId: String,
        accountStore: any AccountStoreProtocol,
        transactionStore: any TransactionStoreProtocol,
        transferRuleStore: any TransferRuleStoreProtocol,
        vendorStore: any VendorStoreProtocol,
        context: LambdaContext
    ) async throws -> (reports: [AccountPaydownReport], notificationBody: String) {
        let pivot = pivotDay()
        let range = PaydownDateRange.computeCurrentPeriod(pivotDay: pivot)
        async let accountsFetch = accountStore.fetchAll(userId: userId)
        async let transactionsFetch = transactionStore.fetch(
            userId: userId,
            startDate: range.start,
            endDate: range.end
        )
        async let rulesFetch = transferRuleStore.fetchAll(userId: userId)
        async let vendorsFetch = vendorStore.fetchAll(userId: userId)
        let accounts = try await accountsFetch
        let transactions = try await transactionsFetch
        let rules = try await rulesFetch
        let vendors = try await vendorsFetch
        let reports = WeeklyPaydownReport.compute(
            accounts: accounts,
            transactions: transactions,
            rules: rules,
            vendors: vendors,
            dateRange: range
        )
        let body = WeeklyPaydownReport.notificationBody(from: reports)
        let notificationBody = body.isEmpty ? "No credit accounts found" : body
        return (reports: reports, notificationBody: notificationBody)
    }

    /// Hourly cron tick. Iterates all users with notification subscriptions, evaluates each
    /// against the current time + timezone, and sends one combined push per user listing the
    /// accounts whose schedule matched. Dedupes via `lastSentLocalDate` on each subscription so
    /// the same hour-day-tz combination only fires once per local day.
    private static func handleSubscriptionPushTick(
        now: Date,
        userStore: any UserStoreProtocol,
        accountStore: any AccountStoreProtocol,
        transactionStore: any TransactionStoreProtocol,
        transferRuleStore: any TransferRuleStoreProtocol,
        vendorStore: any VendorStoreProtocol,
        tokenStore: any DeviceTokenStoreProtocol,
        subscriptionStore: any NotificationSubscriptionStoreProtocol,
        notificationClient: any PushNotificationClientProtocol,
        context: LambdaContext
    ) async {
        do {
            let allSubs = try await subscriptionStore.fetchAll()
            let byUser = Dictionary(grouping: allSubs, by: { $0.userId })
            let allTokens = try await tokenStore.fetchAll()
            context.logger.info("Push tick: \(byUser.count) user(s) with subscription(s)")
            for (userId, subs) in byUser {
                let fired = ScheduleEvaluator.fire(subs: subs, now: now)
                guard !fired.isEmpty else { continue }
                do {
                    try await sendCombinedPush(
                        userId: userId,
                        fired: fired,
                        accountStore: accountStore,
                        transactionStore: transactionStore,
                        transferRuleStore: transferRuleStore,
                        vendorStore: vendorStore,
                        allTokens: allTokens,
                        subscriptionStore: subscriptionStore,
                        notificationClient: notificationClient,
                        recordLastSent: true,
                        context: context
                    )
                } catch {
                    context.logger.error("Failed push tick for user \(userId): \(error)")
                }
            }
        } catch {
            context.logger.error("Push tick failed to load subscriptions: \(error)")
        }
    }

    /// Computes the current-period paydown for `userId`, filters to the subscribed accounts in
    /// `fired`, builds one combined push payload, and sends it to all of the user's devices.
    /// When `recordLastSent` is true, each fired subscription's `lastSentLocalDate` is updated
    /// (cron path). On the fire-now path callers pass false so a manual fire doesn't suppress the
    /// next scheduled tick.
    private static func sendCombinedPush(
        userId: String,
        fired: [ScheduleEvaluator.FiredSubscription],
        accountStore: any AccountStoreProtocol,
        transactionStore: any TransactionStoreProtocol,
        transferRuleStore: any TransferRuleStoreProtocol,
        vendorStore: any VendorStoreProtocol,
        allTokens: [DeviceToken],
        subscriptionStore: any NotificationSubscriptionStoreProtocol,
        notificationClient: any PushNotificationClientProtocol,
        recordLastSent: Bool,
        context: LambdaContext
    ) async throws {
        let (allReports, _) = try await computeCurrentPeriodFromDynamoDB(
            userId: userId,
            accountStore: accountStore,
            transactionStore: transactionStore,
            transferRuleStore: transferRuleStore,
            vendorStore: vendorStore,
            context: context
        )
        let firedAccountIds = Set(fired.map { $0.subscription.accountId })
        let reports = allReports.filter { firedAccountIds.contains($0.account.lunchMoneyId) }
        guard let payload = CombinedReportPushBuilder.build(reports: reports) else {
            context.logger.info("User \(userId): no matching reports for fired subs (accounts may not exist)")
            return
        }
        let userTokens = allTokens.filter { $0.userId == userId }
        if userTokens.isEmpty {
            context.logger.info("User \(userId): fired \(fired.count) sub(s) but no device tokens registered")
        } else {
            try await notificationClient.send(payload, to: userTokens)
            context.logger.info("Push tick: sent 1 combined push to user \(userId) covering \(fired.count) sub(s), \(userTokens.count) device(s)")
        }
        if recordLastSent {
            for f in fired {
                try? await subscriptionStore.markSent(
                    userId: userId,
                    accountId: f.subscription.accountId,
                    localDate: f.localDate
                )
            }
        }
    }

    /// Admin/manual trigger. Fires every user's enabled subscriptions immediately, ignoring the
    /// schedule (but still requires the user to have at least one enabled subscription).
    /// Admin "Generate Report Now". Identical to the hourly cron sweep — runs
    /// `ScheduleEvaluator.fire` across every user's subscriptions using the current
    /// time and only fires what's actually due (after the scheduled hour, not yet
    /// sent today). Records `lastSentLocalDate` so the cron doesn't double-send.
    private static func handleGenerateReport(
        userStore: any UserStoreProtocol,
        accountStore: any AccountStoreProtocol,
        transactionStore: any TransactionStoreProtocol,
        transferRuleStore: any TransferRuleStoreProtocol,
        vendorStore: any VendorStoreProtocol,
        tokenStore: any DeviceTokenStoreProtocol,
        subscriptionStore: any NotificationSubscriptionStoreProtocol,
        notificationClient: any PushNotificationClientProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        await handleSubscriptionPushTick(
            now: Date(),
            userStore: userStore,
            accountStore: accountStore,
            transactionStore: transactionStore,
            transferRuleStore: transferRuleStore,
            vendorStore: vendorStore,
            tokenStore: tokenStore,
            subscriptionStore: subscriptionStore,
            notificationClient: notificationClient,
            context: context
        )
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: #"{"status":"ok"}"#
        )
    }

    private static func handleGetAccounts(
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        accountStore: any AccountStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard let username = event.queryStringParameters?["username"],
              let password = event.queryStringParameters?["password"]
        else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Missing username or password"}"#
            )
        }
        guard let user = try await userStore.find(username: username),
              UserAccount.hashPassword(password) == user.passwordHash
        else {
            return APIGatewayResponse(
                statusCode: .unauthorized,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Invalid credentials"}"#
            )
        }
        let accounts = try await accountStore.fetchAll(userId: user.username)
        context.logger.info("Fetched \(accounts.count) account(s) for user \(user.username)")
        let data = try JSONEncoder().encode(accounts)
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "[]"
        )
    }

    private static func handleGetTransactions(
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        transactionStore: any TransactionStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard let username = event.queryStringParameters?["username"],
              let password = event.queryStringParameters?["password"],
              let startDate = event.queryStringParameters?["startDate"],
              let endDate = event.queryStringParameters?["endDate"]
        else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Missing username, password, startDate, or endDate"}"#
            )
        }
        guard let user = try await userStore.find(username: username),
              UserAccount.hashPassword(password) == user.passwordHash
        else {
            return APIGatewayResponse(
                statusCode: .unauthorized,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Invalid credentials"}"#
            )
        }
        let transactions = try await transactionStore.fetch(userId: user.username, startDate: startDate, endDate: endDate)
        context.logger.info("Fetched \(transactions.count) transaction(s) for user \(user.username)")
        let data = try JSONEncoder().encode(transactions)
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "[]"
        )
    }

    private static func handleRefresh(
        event: APIGatewayRequest,
        client: LunchMoneyClient,
        globalLunchMoneyToken: String,
        userStore: any UserStoreProtocol,
        accountStore: any AccountStoreProtocol,
        transactionStore: any TransactionStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard let bodyString = event.body,
              let bodyData = bodyString.data(using: .utf8),
              let request = try? JSONDecoder().decode(RefreshRequest.self, from: bodyData)
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
        // Fall back to the Lambda's global LM token when the user hasn't configured a per-user one.
        let token = user.lunchMoneyToken ?? globalLunchMoneyToken

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

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate) ?? endDate
        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)

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

        context.logger.info("Refreshed user \(user.username): \(accounts.count) account(s), \(allTransactions.count) transaction(s)")

        struct RefreshResult: Encodable {
            let accounts: [Account]
            let transactionCount: Int
        }
        let result = RefreshResult(accounts: accounts, transactionCount: allTransactions.count)
        let data = try JSONEncoder().encode(result)
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "{}"
        )
    }

    /// User-triggered sweep. Runs `ScheduleEvaluator.fire` for this user's enabled
    /// subscriptions using the current time and fires whatever's due (after the
    /// scheduled hour, not yet sent today). Records `lastSentLocalDate` so the next
    /// cron tick doesn't double-send. If nothing is due — for example the scheduled
    /// hour hasn't passed yet today, or it already fired — returns 200 with
    /// `firedCount: 0` and an explanatory `reason`.
    private static func handleSendMyReport(
        tokenStore: any DeviceTokenStoreProtocol,
        userStore: any UserStoreProtocol,
        accountStore: any AccountStoreProtocol,
        transactionStore: any TransactionStoreProtocol,
        transferRuleStore: any TransferRuleStoreProtocol,
        vendorStore: any VendorStoreProtocol,
        subscriptionStore: any NotificationSubscriptionStoreProtocol,
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

        let subs = try await subscriptionStore.fetch(userId: user.username)
        if subs.isEmpty {
            context.logger.info("send-my-report: user \(user.username) has no subscriptions")
            return APIGatewayResponse(
                statusCode: .ok,
                headers: ["Content-Type": "application/json"],
                body: #"{"status":"ok","firedCount":0,"reason":"no subscriptions"}"#
            )
        }
        let now = Date()
        let fired = ScheduleEvaluator.fire(subs: subs, now: now)
        if fired.isEmpty {
            context.logger.info("send-my-report: user \(user.username) has \(subs.count) sub(s) but none due (current time before scheduled hour, or already sent today)")
            return APIGatewayResponse(
                statusCode: .ok,
                headers: ["Content-Type": "application/json"],
                body: #"{"status":"ok","firedCount":0,"reason":"nothing due (before scheduled hour, or already sent today)"}"#
            )
        }
        let allTokens = try await tokenStore.fetchAll()
        try await sendCombinedPush(
            userId: user.username,
            fired: fired,
            accountStore: accountStore,
            transactionStore: transactionStore,
            transferRuleStore: transferRuleStore,
            vendorStore: vendorStore,
            allTokens: allTokens,
            subscriptionStore: subscriptionStore,
            notificationClient: notificationClient,
            recordLastSent: true,
            context: context
        )
        let userTokenCount = allTokens.filter { $0.userId == user.username }.count
        struct SendReportResult: Encodable {
            let status: String
            let firedCount: Int
            let notificationsSent: Int
        }
        let result = SendReportResult(
            status: "ok",
            firedCount: fired.count,
            notificationsSent: userTokenCount == 0 ? 0 : 1
        )
        let data = try JSONEncoder().encode(result)
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "{}"
        )
    }

    // MARK: - Notification subscription routes

    private static func handleListSubscriptions(
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        subscriptionStore: any NotificationSubscriptionStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard let username = event.queryStringParameters?["username"],
              let password = event.queryStringParameters?["password"]
        else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Missing username or password"}"#
            )
        }
        guard let user = try await userStore.find(username: username),
              UserAccount.hashPassword(password) == user.passwordHash
        else {
            return APIGatewayResponse(
                statusCode: .unauthorized,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Invalid credentials"}"#
            )
        }
        let subs = try await subscriptionStore.fetch(userId: user.username)
        context.logger.info("Listed \(subs.count) subscription(s) for user \(user.username)")
        let data = try JSONEncoder().encode(subs)
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "[]"
        )
    }

    private static func handleUpsertSubscription(
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        accountStore: any AccountStoreProtocol,
        subscriptionStore: any NotificationSubscriptionStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard let bodyString = event.body,
              let bodyData = bodyString.data(using: .utf8),
              let request = try? JSONDecoder().decode(UpsertSubscriptionRequest.self, from: bodyData)
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
        guard !request.daysOfWeek.isEmpty,
              (0...23).contains(request.hour),
              TimeZone(identifier: request.timezone) != nil
        else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Invalid schedule (daysOfWeek non-empty, hour 0-23, valid IANA timezone)"}"#
            )
        }
        let userAccounts = try await accountStore.fetchAll(userId: user.username)
        guard userAccounts.contains(where: { $0.lunchMoneyId == request.accountId }) else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"accountId does not belong to user"}"#
            )
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let existing = try await subscriptionStore.find(userId: user.username, accountId: request.accountId)
        let subscription = NotificationSubscription(
            userId: user.username,
            accountId: request.accountId,
            daysOfWeek: request.daysOfWeek,
            hour: request.hour,
            timezone: request.timezone,
            enabled: request.enabled,
            lastSentLocalDate: existing?.lastSentLocalDate,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )
        try await subscriptionStore.upsert(subscription)
        context.logger.info("Upserted subscription for user \(user.username) account \(request.accountId)")
        let data = try JSONEncoder().encode(subscription)
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "{}"
        )
    }

    private static func handleDeleteSubscription(
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        subscriptionStore: any NotificationSubscriptionStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard let bodyString = event.body,
              let bodyData = bodyString.data(using: .utf8),
              let request = try? JSONDecoder().decode(DeleteSubscriptionRequest.self, from: bodyData)
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
        try await subscriptionStore.delete(userId: user.username, accountId: request.accountId)
        context.logger.info("Deleted subscription for user \(user.username) account \(request.accountId)")
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: #"{"status":"ok"}"#
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

    private static func handleAdminListUsers(
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        let users = try await userStore.fetchAll()
        struct AdminUserInfo: Encodable {
            let username: String
            let createdAt: String
            let hasLMToken: Bool
        }
        let infos = users.map { AdminUserInfo(username: $0.username, createdAt: $0.createdAt, hasLMToken: $0.lunchMoneyToken != nil) }
        context.logger.info("Admin: listed \(infos.count) user(s)")
        let data = try JSONEncoder().encode(infos)
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "[]"
        )
    }

    private static func handleAdminDeleteUser(
        username: String,
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        accountStore: any AccountStoreProtocol,
        transactionStore: any TransactionStoreProtocol,
        tokenStore: any DeviceTokenStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard !username.isEmpty else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Missing username"}"#
            )
        }
        try await accountStore.deleteAll(userId: username)
        try await transactionStore.deleteAll(userId: username)
        try await tokenStore.deleteAll(userId: username)
        try await userStore.delete(username: username)
        context.logger.info("Admin: deleted user \(username) and all associated data")
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: #"{"status":"ok"}"#
        )
    }

    private static func handleAdminUpdateLMToken(
        username: String,
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard let bodyString = event.body,
              let bodyData = bodyString.data(using: .utf8),
              let request = try? JSONDecoder().decode(AdminUpdateLMTokenRequest.self, from: bodyData)
        else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Missing or invalid body"}"#
            )
        }
        guard !username.isEmpty else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Missing username"}"#
            )
        }
        try await userStore.update(lunchMoneyToken: request.lmToken, forUsername: username)
        context.logger.info("Admin: updated LM token for user \(username)")
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: #"{"status":"ok"}"#
        )
    }

    private static func handleAdminListReports(
        event: APIGatewayRequest,
        reviewItemStore: any ReviewItemStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        let items = try await reviewItemStore.fetchAll()
        context.logger.info("Admin: listed \(items.count) report(s)")
        let data = try JSONEncoder().encode(items)
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "[]"
        )
    }

    private static func handleAdminDeleteReport(
        reportId: String,
        event: APIGatewayRequest,
        reviewItemStore: any ReviewItemStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard !reportId.isEmpty else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Missing report id"}"#
            )
        }
        try await reviewItemStore.delete(id: reportId)
        context.logger.info("Admin: deleted report \(reportId)")
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: #"{"status":"ok"}"#
        )
    }

    private static func handleAdminErrors(
        iosLogsClient: any IOSLogsClientProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        struct ErrorsResponse: Encodable {
            let errors: [String]
            let message: String
        }
        do {
            let errors = try await iosLogsClient.fetchRecentErrors(hours: 24)
            let message = errors.isEmpty ? "No errors in the last 24 hours." : ""
            let response = ErrorsResponse(errors: errors, message: message)
            let data = try JSONEncoder().encode(response)
            return APIGatewayResponse(
                statusCode: .ok,
                headers: ["Content-Type": "application/json"],
                body: String(data: data, encoding: .utf8) ?? "{}"
            )
        } catch {
            context.logger.error("Failed to fetch iOS logs: \(error)")
            let response = ErrorsResponse(errors: [], message: "Failed to fetch logs: \(error.localizedDescription)")
            let data = try JSONEncoder().encode(response)
            return APIGatewayResponse(
                statusCode: .ok,
                headers: ["Content-Type": "application/json"],
                body: String(data: data, encoding: .utf8) ?? "{}"
            )
        }
    }

    private static func handleBuildStatus(
        githubToken: String,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        struct GitHubRunsResponse: Decodable {
            let workflowRuns: [GitHubRun]
            enum CodingKeys: String, CodingKey { case workflowRuns = "workflow_runs" }
        }
        struct GitHubRun: Decodable {
            let id: Int
            let name: String
            let status: String
            let conclusion: String?
            let createdAt: String
            let htmlUrl: String
            let headCommit: GitHubCommit?
            enum CodingKeys: String, CodingKey {
                case id, name, status, conclusion
                case createdAt = "created_at"
                case htmlUrl = "html_url"
                case headCommit = "head_commit"
            }
        }
        struct GitHubCommit: Decodable { let message: String }
        struct BuildRun: Encodable {
            let id: Int
            let name: String
            let status: String
            let conclusion: String?
            let createdAt: String
            let htmlUrl: String
            let commitMessage: String
        }
        struct BuildStatusResult: Encodable { let runs: [BuildRun] }

        guard let url = URL(string: "https://api.github.com/repos/gestrich/GetRicher/actions/runs?per_page=10") else {
            return APIGatewayResponse(statusCode: .internalServerError, headers: [:], body: #"{"error":"Invalid GitHub URL"}"#)
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(githubToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        req.setValue("GetRicher-Lambda/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: req)
        let ghResponse = try JSONDecoder().decode(GitHubRunsResponse.self, from: data)
        let runs = ghResponse.workflowRuns.map { run in
            BuildRun(
                id: run.id,
                name: run.name,
                status: run.status,
                conclusion: run.conclusion,
                createdAt: run.createdAt,
                htmlUrl: run.htmlUrl,
                commitMessage: run.headCommit?.message ?? ""
            )
        }
        let result = BuildStatusResult(runs: runs)
        let responseData = try JSONEncoder().encode(result)
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: responseData, encoding: .utf8) ?? "{}"
        )
    }

    // MARK: - Transfer rules + vendors (per-user, replace-all)

    private static func authenticatedUser(
        username: String?,
        password: String?,
        userStore: any UserStoreProtocol
    ) async throws -> UserAccount? {
        guard let username, let password else { return nil }
        guard let user = try await userStore.find(username: username),
              UserAccount.hashPassword(password) == user.passwordHash
        else { return nil }
        return user
    }

    private static func handleGetTransferRules(
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        transferRuleStore: any TransferRuleStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard let user = try await authenticatedUser(
            username: event.queryStringParameters?["username"],
            password: event.queryStringParameters?["password"],
            userStore: userStore
        ) else {
            return APIGatewayResponse(statusCode: .unauthorized, headers: ["Content-Type": "application/json"], body: #"{"error":"Invalid credentials"}"#)
        }
        let rules = try await transferRuleStore.fetchAll(userId: user.username)
        let data = try JSONEncoder().encode(rules)
        context.logger.info("Fetched \(rules.count) transfer rule(s) for user \(user.username)")
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "[]"
        )
    }

    private static func handlePutTransferRules(
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        transferRuleStore: any TransferRuleStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        struct Body: Decodable { let username: String; let password: String; let rules: [TransferRule] }
        guard let bodyString = event.body,
              let bodyData = bodyString.data(using: .utf8),
              let request = try? JSONDecoder().decode(Body.self, from: bodyData)
        else {
            return APIGatewayResponse(statusCode: .badRequest, headers: ["Content-Type": "application/json"], body: #"{"error":"Missing or invalid body"}"#)
        }
        guard let user = try await authenticatedUser(username: request.username, password: request.password, userStore: userStore) else {
            return APIGatewayResponse(statusCode: .unauthorized, headers: ["Content-Type": "application/json"], body: #"{"error":"Invalid credentials"}"#)
        }
        try await transferRuleStore.replaceAll(request.rules, userId: user.username)
        context.logger.info("Stored \(request.rules.count) transfer rule(s) for user \(user.username)")
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: #"{"status":"ok"}"#
        )
    }

    private static func handleGetVendors(
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        vendorStore: any VendorStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard let user = try await authenticatedUser(
            username: event.queryStringParameters?["username"],
            password: event.queryStringParameters?["password"],
            userStore: userStore
        ) else {
            return APIGatewayResponse(statusCode: .unauthorized, headers: ["Content-Type": "application/json"], body: #"{"error":"Invalid credentials"}"#)
        }
        let vendors = try await vendorStore.fetchAll(userId: user.username)
        let data = try JSONEncoder().encode(vendors)
        context.logger.info("Fetched \(vendors.count) vendor(s) for user \(user.username)")
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: String(data: data, encoding: .utf8) ?? "[]"
        )
    }

    private static func handlePutVendors(
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        vendorStore: any VendorStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        struct Body: Decodable { let username: String; let password: String; let vendors: [Vendor] }
        guard let bodyString = event.body,
              let bodyData = bodyString.data(using: .utf8),
              let request = try? JSONDecoder().decode(Body.self, from: bodyData)
        else {
            return APIGatewayResponse(statusCode: .badRequest, headers: ["Content-Type": "application/json"], body: #"{"error":"Missing or invalid body"}"#)
        }
        guard let user = try await authenticatedUser(username: request.username, password: request.password, userStore: userStore) else {
            return APIGatewayResponse(statusCode: .unauthorized, headers: ["Content-Type": "application/json"], body: #"{"error":"Invalid credentials"}"#)
        }
        try await vendorStore.replaceAll(request.vendors, userId: user.username)
        context.logger.info("Stored \(request.vendors.count) vendor(s) for user \(user.username)")
        return APIGatewayResponse(
            statusCode: .ok,
            headers: ["Content-Type": "application/json"],
            body: #"{"status":"ok"}"#
        )
    }

    private static func handleWeeklyPaydown(
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        accountStore: any AccountStoreProtocol,
        transactionStore: any TransactionStoreProtocol,
        transferRuleStore: any TransferRuleStoreProtocol,
        vendorStore: any VendorStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        guard let username = event.queryStringParameters?["username"],
              let password = event.queryStringParameters?["password"]
        else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Missing username or password"}"#
            )
        }
        guard let user = try await userStore.find(username: username),
              UserAccount.hashPassword(password) == user.passwordHash
        else {
            return APIGatewayResponse(
                statusCode: .unauthorized,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Invalid credentials"}"#
            )
        }
        let (reports, body) = try await computeCurrentPeriodFromDynamoDB(
            userId: user.username,
            accountStore: accountStore,
            transactionStore: transactionStore,
            transferRuleStore: transferRuleStore,
            vendorStore: vendorStore,
            context: context
        )
        struct AccountReportDTO: Encodable {
            let lunchMoneyId: Int
            let displayName: String
            let balance: String
            let periodSpending: Double
            let transferTotal: Double
            let netPeriodSpending: Double
        }
        struct WeeklyPaydownResult: Encodable {
            let periodStart: String
            let periodEnd: String
            let body: String
            let accounts: [AccountReportDTO]
        }
        let dtos = reports.map { r in
            AccountReportDTO(
                lunchMoneyId: r.account.lunchMoneyId,
                displayName: r.account.displayName,
                balance: r.account.balance,
                periodSpending: r.calculation.periodSpending,
                transferTotal: r.transferTotal,
                netPeriodSpending: r.netPeriodSpending
            )
        }
        let result = WeeklyPaydownResult(
            periodStart: reports.first?.periodStart ?? "",
            periodEnd: reports.first?.periodEnd ?? "",
            body: body,
            accounts: dtos
        )
        let data = try JSONEncoder().encode(result)
        context.logger.info("Computed weekly paydown for \(reports.count) credit account(s)")
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

    private static func handleOTLPLogs(
        event: APIGatewayRequest,
        userStore: any UserStoreProtocol,
        context: LambdaContext
    ) async throws -> APIGatewayResponse {
        // Local dev mode: print body and return without forwarding
        if ProcessInfo.processInfo.environment["LUNCH_MONEY_TOKEN"] != nil {
            let size = event.body?.count ?? 0
            let username = event.headers.first(where: { $0.key.lowercased() == "x-getricher-username" })?.value ?? "unknown"
            context.logger.info("OTLP logs received (dev mode): \(size) bytes from user \(username)")
            return APIGatewayResponse(
                statusCode: .ok,
                headers: ["Content-Type": "application/json"],
                body: #"{"status":"ok"}"#
            )
        }

        guard let username = event.headers.first(where: { $0.key.lowercased() == "x-getricher-username" })?.value,
              let password = event.headers.first(where: { $0.key.lowercased() == "x-getricher-password" })?.value
        else {
            return APIGatewayResponse(
                statusCode: .unauthorized,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Missing credentials"}"#
            )
        }

        guard let user = try await userStore.find(username: username),
              UserAccount.hashPassword(password) == user.passwordHash
        else {
            return APIGatewayResponse(
                statusCode: .unauthorized,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Invalid credentials"}"#
            )
        }

        guard let bodyString = event.body else {
            return APIGatewayResponse(
                statusCode: .badRequest,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Missing body"}"#
            )
        }

        let otlpData: Data
        if event.isBase64Encoded {
            guard let decoded = Data(base64Encoded: bodyString) else {
                return APIGatewayResponse(
                    statusCode: .badRequest,
                    headers: ["Content-Type": "application/json"],
                    body: #"{"error":"Invalid base64 body"}"#
                )
            }
            otlpData = decoded
        } else {
            otlpData = Data(bodyString.utf8)
        }

        let region = ProcessInfo.processInfo.environment["AWS_REGION"] ?? "us-east-1"
        let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] ?? ""
        let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] ?? ""
        let sessionToken = ProcessInfo.processInfo.environment["AWS_SESSION_TOKEN"]

        guard !accessKey.isEmpty, !secretKey.isEmpty else {
            context.logger.error("Missing AWS credentials for OTLP forwarding")
            return APIGatewayResponse(
                statusCode: .internalServerError,
                headers: ["Content-Type": "application/json"],
                body: #"{"error":"Internal server error"}"#
            )
        }

        let cwURL = URL(string: "https://logs.\(region).amazonaws.com/v1/logs")!
        let otlpHeaders: [(String, String)] = [
            ("content-type", "application/x-protobuf"),
            ("x-aws-log-group", "/getricher/ios"),
            ("x-aws-log-stream", user.username),
        ]

        let signedHeaders = sigV4Sign(
            url: cwURL,
            method: "POST",
            headers: otlpHeaders,
            body: otlpData,
            service: "logs",
            region: region,
            accessKey: accessKey,
            secretKey: secretKey,
            sessionToken: sessionToken
        )

        var urlRequest = URLRequest(url: cwURL)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = otlpData
        for (name, value) in signedHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        let upstreamStatus = (response as? HTTPURLResponse)?.statusCode ?? 502
        context.logger.info("Forwarded OTLP logs for user \(user.username): upstream status \(upstreamStatus)")

        return APIGatewayResponse(
            statusCode: HTTPResponse.Status(code: upstreamStatus),
            headers: ["Content-Type": "application/json"],
            body: upstreamStatus < 300 ? #"{"status":"ok"}"# : #"{"error":"Upstream error"}"#
        )
    }

    private static func sigV4Sign(
        url: URL,
        method: String,
        headers: [(String, String)],
        body: Data,
        service: String,
        region: String,
        accessKey: String,
        secretKey: String,
        sessionToken: String?
    ) -> [(name: String, value: String)] {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")

        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = dateFormatter.string(from: date)
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStamp = dateFormatter.string(from: date)

        let host = url.host ?? ""
        let path = url.path.isEmpty ? "/" : url.path
        let query = url.query ?? ""

        var canonHeaders: [(String, String)] = headers.map { ($0.0.lowercased(), $0.1) }
        canonHeaders.append(("host", host))
        canonHeaders.append(("x-amz-date", amzDate))
        if let token = sessionToken {
            canonHeaders.append(("x-amz-security-token", token))
        }
        canonHeaders.sort { $0.0 < $1.0 }

        let canonicalHeadersStr = canonHeaders.map { "\($0.0):\($0.1)\n" }.joined()
        let signedHeadersStr = canonHeaders.map { $0.0 }.joined(separator: ";")

        let bodyHash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        let canonicalRequest = [method.uppercased(), path, query, canonicalHeadersStr, signedHeadersStr, bodyHash].joined(separator: "\n")
        let crHash = SHA256.hash(data: Data(canonicalRequest.utf8)).map { String(format: "%02x", $0) }.joined()

        let scope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = "AWS4-HMAC-SHA256\n\(amzDate)\n\(scope)\n\(crHash)"

        func hmacData(_ key: Data, _ message: String) -> Data {
            let symKey = SymmetricKey(data: key)
            return Data(HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: symKey))
        }

        let kDate = hmacData(Data("AWS4\(secretKey)".utf8), dateStamp)
        let kRegion = hmacData(kDate, region)
        let kService = hmacData(kRegion, service)
        let kSigning = hmacData(kService, "aws4_request")

        let sigSymKey = SymmetricKey(data: kSigning)
        let signature = Data(HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: sigSymKey))
            .map { String(format: "%02x", $0) }.joined()

        let authHeader = "AWS4-HMAC-SHA256 Credential=\(accessKey)/\(scope), SignedHeaders=\(signedHeadersStr), Signature=\(signature)"

        var result: [(name: String, value: String)] = headers.map { (name: $0.0, value: $0.1) }
        result.append((name: "x-amz-date", value: amzDate))
        result.append((name: "Authorization", value: authHeader))
        if let token = sessionToken {
            result.append((name: "x-amz-security-token", value: token))
        }
        return result
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

private struct RefreshRequest: Decodable {
    let username: String
    let password: String
}

private struct AdminUpdateLMTokenRequest: Decodable {
    let lmToken: String
}

private struct UpsertSubscriptionRequest: Decodable {
    let username: String
    let password: String
    let accountId: Int
    let daysOfWeek: [DayOfWeek]
    let hour: Int
    let timezone: String
    let enabled: Bool
}

private struct DeleteSubscriptionRequest: Decodable {
    let username: String
    let password: String
    let accountId: Int
}

// MARK: - iOS Logs Client

protocol IOSLogsClientProtocol: Sendable {
    func fetchRecentErrors(hours: Int) async throws -> [String]
}

fileprivate struct LoggingIOSLogsClient: IOSLogsClientProtocol {
    func fetchRecentErrors(hours: Int) async throws -> [String] { [] }
}

fileprivate struct AWSIOSLogsClient: IOSLogsClientProtocol, @unchecked Sendable {
    private let cloudWatchLogs: CloudWatchLogs

    init(awsClient: AWSClient, region: Region?) {
        self.cloudWatchLogs = CloudWatchLogs(client: awsClient, region: region)
    }

    func fetchRecentErrors(hours: Int) async throws -> [String] {
        let startTime = Int64(Date().addingTimeInterval(-Double(hours) * 3600).timeIntervalSince1970 * 1000)
        let request = CloudWatchLogs.FilterLogEventsRequest(
            filterPattern: "ERROR",
            logGroupName: "/getricher/ios",
            startTime: startTime
        )
        do {
            let response = try await cloudWatchLogs.filterLogEvents(request)
            return response.events?.compactMap { $0.message } ?? []
        } catch let error as CloudWatchLogsErrorType where error == .resourceNotFoundException {
            return []
        }
    }
}

// MARK: - Stub Stores

private struct LoggingDeviceTokenStore: DeviceTokenStoreProtocol {
    func store(_ token: DeviceToken) async throws {
        print("[DeviceTokenStore] STUB store token: \(token.id)")
    }
    func fetchAll() async throws -> [DeviceToken] {
        print("[DeviceTokenStore] STUB fetchAll -> []")
        return []
    }
    func deleteAll(userId: String) async throws {
        print("[DeviceTokenStore] STUB deleteAll userId=\(userId)")
    }
}

// MARK: - Lambda dispatch event

struct LambdaDispatchEvent: Decodable, Sendable {
    enum Kind: Sendable {
        case apiGateway(APIGatewayRequest)
        /// EventBridge scheduled trigger. `task` identifies which job: "refresh" (hourly LM→DynamoDB sync)
        /// or "report" (daily paydown push). `nil` = legacy scheduled event with no payload (do both).
        case scheduled(task: String?)
    }

    let kind: Kind

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if (try? container.decodeIfPresent(String.self, forKey: .httpMethod)) != nil {
            kind = .apiGateway(try APIGatewayRequest(from: decoder))
        } else {
            let task = try? container.decodeIfPresent(String.self, forKey: .task)
            kind = .scheduled(task: task)
        }
    }

    enum CodingKeys: String, CodingKey {
        case httpMethod, task
    }
}
