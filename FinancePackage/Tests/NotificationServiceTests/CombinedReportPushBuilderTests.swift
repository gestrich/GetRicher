import Testing
@testable import NotificationService
import FinanceCoreSDK
import ReportingService
import Foundation

@Suite("CombinedReportPushBuilder")
struct CombinedReportPushBuilderTests {
    /// A report with a given owed-from-primary, spend total, and optional funded line.
    private static func report(
        id: Int,
        displayName: String,
        owedFromPrimary: Double,
        spendTotal: Double,
        funded: (Int, String, Double)? = nil
    ) -> AccountPaydownReport {
        let account = Account(
            lunchMoneyId: id, name: displayName, displayName: displayName, type: "credit",
            subtype: "credit_card", mask: "0000", institutionName: "Bank", status: "active",
            balance: "0.00", currency: "usd"
        )
        let fundedByAccount = funded.map { [FundingOwed(fundingAccountId: $0.0, fundingAccountName: $0.1, amount: $0.2)] } ?? []
        // owedFromPrimary = owedTotal − funded; pick currentBalance so owedFromPrimary lands right.
        let fundedSum = fundedByAccount.reduce(0.0) { $0 + $1.amount }
        let owed = PaymentsOwed(
            currentBalance: owedFromPrimary + fundedSum,
            pendingInPeriod: 0,
            postedAfterPeriod: 0,
            fundedByAccount: fundedByAccount
        )
        let spend = WeeklySpend(buckets: [SpendBucket(typeId: nil, typeName: "Other Spend", fundingAccountId: nil, amount: spendTotal, count: 1)])
        return AccountPaydownReport(
            account: account, periodStart: "2026-05-01", periodEnd: "2026-05-07",
            spend: spend, payments: WeeklyPayments(total: 0, count: 0), owed: owed
        )
    }

    @Test("Empty input returns nil")
    func emptyInput() {
        #expect(CombinedReportPushBuilder.build(current: [], last: []) == nil)
    }

    @Test("Single account shows pay + spent")
    func singleAccount() {
        let payload = CombinedReportPushBuilder.build(
            current: [],
            last: [Self.report(id: 1, displayName: "PNC Core", owedFromPrimary: 780, spendTotal: 310)]
        )
        #expect(payload?.title == "PNC Core")
        #expect(payload?.body == "Pay $780.00 · Spent $310.00")
        #expect(payload?.data["accountId"] == "1")
    }

    @Test("Funded account adds a line")
    func funded() {
        let payload = CombinedReportPushBuilder.build(
            current: [],
            last: [Self.report(id: 1, displayName: "PNC Core", owedFromPrimary: 780, spendTotal: 510, funded: (99, "Reserve", 200))]
        )
        #expect(payload?.body == "Pay $780.00 + $200.00 Reserve · Spent $510.00")
    }

    @Test("Multi-account combines into one summary")
    func multiAccount() {
        let payload = CombinedReportPushBuilder.build(
            current: [],
            last: [
                Self.report(id: 1, displayName: "PNC Core", owedFromPrimary: 780, spendTotal: 310),
                Self.report(id: 2, displayName: "Points", owedFromPrimary: 50, spendTotal: 50),
            ]
        )
        #expect(payload?.title == "Paydown summary")
        #expect(payload?.body == "PNC Core — Pay $780.00 · Spent $310.00\nPoints — Pay $50.00 · Spent $50.00")
        #expect(payload?.data["accountId"] == nil)
    }
}
