import Testing
@testable import NotificationService
import FinanceCoreSDK
import ReportingService
import Foundation

@Suite("CombinedReportPushBuilder")
struct CombinedReportPushBuilderTests {
    /// A report with a single "Checking" source bucket holding `amount`.
    private static func report(id: Int, displayName: String, amount: Double) -> AccountPaydownReport {
        let account = Account(
            lunchMoneyId: id,
            name: displayName,
            displayName: displayName,
            type: "credit",
            subtype: "credit_card",
            mask: "0000",
            institutionName: "Bank",
            status: "active",
            balance: "0.00",
            currency: "usd"
        )
        return AccountPaydownReport(
            account: account,
            buckets: [TransferBreakdown(
                sourceAccountId: 9,
                sourceAccountName: "Checking",
                ruleName: "Default",
                amount: amount,
                transactionCount: 1
            )],
            periodStart: "2026-05-01",
            periodEnd: "2026-05-12"
        )
    }

    @Test("Empty input returns nil")
    func emptyInput() {
        #expect(CombinedReportPushBuilder.build(current: [], last: []) == nil)
    }

    @Test("Single account shows Last and Current per-source amounts")
    func singleAccount() {
        let payload = CombinedReportPushBuilder.build(
            current: [Self.report(id: 1, displayName: "PNC Spending", amount: 150.00)],
            last: [Self.report(id: 1, displayName: "PNC Spending", amount: 301.21)]
        )
        #expect(payload?.title == "PNC Spending")
        #expect(payload?.body == "Last: Checking $301.21\nCurrent: Checking $150.00")
        #expect(payload?.data["deepLink"] == "paydown")
        #expect(payload?.data["accountId"] == "1")
    }

    @Test("Missing current cycle falls back to $0.00")
    func singleAccountNoCurrent() {
        let payload = CombinedReportPushBuilder.build(
            current: [],
            last: [Self.report(id: 1, displayName: "PNC Spending", amount: 301.21)]
        )
        #expect(payload?.body == "Last: Checking $301.21\nCurrent: $0.00")
    }

    @Test("Multi-account combines into one summary push")
    func multiAccount() {
        let payload = CombinedReportPushBuilder.build(
            current: [
                Self.report(id: 1, displayName: "PNC Spending", amount: 150.00),
                Self.report(id: 2, displayName: "Chase Sapphire", amount: 20.00),
            ],
            last: [
                Self.report(id: 1, displayName: "PNC Spending", amount: 301.21),
                Self.report(id: 2, displayName: "Chase Sapphire", amount: 54.12),
            ]
        )
        #expect(payload?.title == "Paydown summary")
        #expect(payload?.body == "PNC Spending — Last: Checking $301.21 | Current: Checking $150.00\nChase Sapphire — Last: Checking $54.12 | Current: Checking $20.00")
        #expect(payload?.data["deepLink"] == "paydown")
        #expect(payload?.data["accountId"] == nil)
    }
}
