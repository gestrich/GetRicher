import FinanceCoreSDK
import Foundation
import ReportingService

/// Builds a single combined `NotificationPayload` covering one or more credit accounts.
/// Each account shows two cycles — Current (in-progress) and Last (completed, the one to pay) —
/// each as a per-source amount: how much to transfer from each funding account.
public enum CombinedReportPushBuilder {
    public static func build(
        current: [AccountPaydownReport],
        last: [AccountPaydownReport]
    ) -> NotificationPayload? {
        guard !last.isEmpty else { return nil }

        let currentByAccount = Dictionary(
            current.map { ($0.account.lunchMoneyId, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        func amount(_ value: Double) -> String { String(format: "$%.2f", value) }

        /// "Reserve $272.45 · Payroll $1,140.00" — one segment per source bucket.
        func bucketLine(_ report: AccountPaydownReport?) -> String {
            guard let report, !report.buckets.isEmpty else { return amount(report?.amountToPay ?? 0) }
            return report.buckets
                .map { "\($0.sourceAccountName) \(amount($0.amount))" }
                .joined(separator: " · ")
        }

        if last.count == 1 {
            let r = last[0]
            let cur = currentByAccount[r.account.lunchMoneyId]
            return NotificationPayload(
                title: r.account.displayName,
                body: "Last: \(bucketLine(r))\nCurrent: \(bucketLine(cur))",
                data: [
                    "deepLink": "paydown",
                    "accountId": String(r.account.lunchMoneyId)
                ]
            )
        }

        let parts = last.map { r -> String in
            "\(r.account.displayName) — Last: \(bucketLine(r)) | Current: \(bucketLine(currentByAccount[r.account.lunchMoneyId]))"
        }
        return NotificationPayload(
            title: "Paydown summary",
            body: parts.joined(separator: "\n"),
            data: ["deepLink": "paydown"]
        )
    }
}
