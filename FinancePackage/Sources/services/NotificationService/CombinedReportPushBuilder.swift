import FinanceCoreSDK
import Foundation
import ReportingService

/// Builds a single combined `NotificationPayload` covering one or more credit accounts.
/// Each account shows the **last** completed cycle's Amount to Pay (owed from primary, plus any
/// funded-account lines) and Total Spend.
public enum CombinedReportPushBuilder {
    public static func build(
        current: [AccountPaydownReport],
        last: [AccountPaydownReport]
    ) -> NotificationPayload? {
        guard !last.isEmpty else { return nil }

        func money(_ v: Double) -> String { String(format: "$%.2f", v) }

        func line(_ r: AccountPaydownReport) -> String {
            var s = "Pay \(money(r.owed.owedFromPrimary))"
            for f in r.owed.fundedByAccount {
                s += " + \(money(f.amount)) \(f.fundingAccountName)"
            }
            s += " · Spent \(money(r.spend.total))"
            return s
        }

        if last.count == 1 {
            let r = last[0]
            return NotificationPayload(
                title: r.account.displayName,
                body: line(r),
                data: [
                    "deepLink": "paydown",
                    "accountId": String(r.account.lunchMoneyId)
                ]
            )
        }

        let parts = last.map { "\($0.account.displayName) — \(line($0))" }
        return NotificationPayload(
            title: "Paydown summary",
            body: parts.joined(separator: "\n"),
            data: ["deepLink": "paydown"]
        )
    }
}
