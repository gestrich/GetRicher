import FinanceCoreSDK
import Foundation
import ReportingService

/// Builds a single combined `NotificationPayload` covering one or more credit accounts.
/// Each account shows two balance-based amounts (`netAdjustedSpending`):
///   Current → the in-progress cycle, Last → the last completed cycle (the amount to pay now).
/// The shape adapts to the count of accounts:
///   1 account  → title = displayName, body = "Current: $X.XX\nLast: $Y.YY"
///   2+ accounts → title = "Paydown summary", body = "Acct1 — Current $X / Last $Y • Acct2 — …"
public enum CombinedReportPushBuilder {
    public static func build(
        current: [AccountPaydownReport],
        last: [AccountPaydownReport]
    ) -> NotificationPayload? {
        guard !last.isEmpty else { return nil }

        // Index current-cycle amounts by account so we can pair them with the last-cycle rows.
        let currentByAccount = Dictionary(
            current.map { ($0.account.lunchMoneyId, $0.netAdjustedSpending) },
            uniquingKeysWith: { first, _ in first }
        )
        func amount(_ value: Double) -> String { String(format: "$%.2f", value) }
        func currentAmount(for report: AccountPaydownReport) -> String {
            amount(currentByAccount[report.account.lunchMoneyId] ?? 0)
        }

        if last.count == 1 {
            let r = last[0]
            return NotificationPayload(
                title: r.account.displayName,
                body: "Current: \(currentAmount(for: r))\nLast: \(amount(r.netAdjustedSpending))",
                data: [
                    "deepLink": "paydown",
                    "accountId": String(r.account.lunchMoneyId)
                ]
            )
        }

        let parts = last.map { r in
            "\(r.account.displayName) — Current \(currentAmount(for: r)) / Last \(amount(r.netAdjustedSpending))"
        }
        return NotificationPayload(
            title: "Paydown summary",
            body: parts.joined(separator: " • "),
            data: ["deepLink": "paydown"]
        )
    }
}
