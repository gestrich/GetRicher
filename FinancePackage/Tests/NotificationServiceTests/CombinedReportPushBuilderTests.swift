import Testing
@testable import NotificationService
import FinanceCoreSDK
import ReportingService
import Foundation

@Suite("CombinedReportPushBuilder")
struct CombinedReportPushBuilderTests {
    private static func report(id: Int, displayName: String, netSpending: Double) -> AccountPaydownReport {
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
        // Build a calculation whose periodSpending equals netSpending (no transfers).
        let calculation = PaydownCalculation(
            currentBalance: 0,
            pendingAdjustment: 0,
            postPeriodAdjustment: 0,
            adjustedSpending: netSpending,
            periodSpending: netSpending
        )
        return AccountPaydownReport(
            account: account,
            calculation: calculation,
            transferBreakdown: [],
            periodStart: "2026-05-01",
            periodEnd: "2026-05-12"
        )
    }

    @Test("Empty input returns nil")
    func emptyInput() {
        #expect(CombinedReportPushBuilder.build(reports: []) == nil)
    }

    @Test("Single account uses legacy single-account shape")
    func singleAccount() {
        let payload = CombinedReportPushBuilder.build(reports: [
            Self.report(id: 1, displayName: "PNC Spending", netSpending: 301.21)
        ])
        #expect(payload?.title == "PNC Spending")
        #expect(payload?.body == "Amount to pay: $301.21")
        #expect(payload?.data["deepLink"] == "paydown")
        #expect(payload?.data["accountId"] == "1")
    }

    @Test("Multi-account combines into one summary push")
    func multiAccount() {
        let payload = CombinedReportPushBuilder.build(reports: [
            Self.report(id: 1, displayName: "PNC Spending", netSpending: 301.21),
            Self.report(id: 2, displayName: "Chase Sapphire", netSpending: 54.12),
        ])
        #expect(payload?.title == "Paydown summary")
        #expect(payload?.body == "PNC Spending: $301.21 • Chase Sapphire: $54.12")
        #expect(payload?.data["deepLink"] == "paydown")
        // accountId is omitted for multi-account pushes.
        #expect(payload?.data["accountId"] == nil)
    }
}
