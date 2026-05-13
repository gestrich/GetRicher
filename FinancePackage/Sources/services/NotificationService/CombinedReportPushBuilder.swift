import FinanceCoreSDK
import Foundation
import ReportingService

/// Builds a single combined `NotificationPayload` covering one or more credit accounts.
/// The shape adapts to the count of accounts:
///   1 account  → "displayName" / "Amount to pay: $X.XX" (matches the legacy single-account push)
///   2+ accounts → "Paydown summary" / "Acct1: $X.XX • Acct2: $Y.YY"
public enum CombinedReportPushBuilder {
    public static func build(reports: [AccountPaydownReport]) -> NotificationPayload? {
        guard !reports.isEmpty else { return nil }

        if reports.count == 1 {
            let r = reports[0]
            let amount = String(format: "$%.2f", r.netPeriodSpending)
            return NotificationPayload(
                title: r.account.displayName,
                body: "Amount to pay: \(amount)",
                data: [
                    "deepLink": "paydown",
                    "accountId": String(r.account.lunchMoneyId)
                ]
            )
        }

        let parts = reports.map { r -> String in
            let amount = String(format: "$%.2f", r.netPeriodSpending)
            return "\(r.account.displayName): \(amount)"
        }
        return NotificationPayload(
            title: "Paydown summary",
            body: parts.joined(separator: " • "),
            data: ["deepLink": "paydown"]
        )
    }
}
