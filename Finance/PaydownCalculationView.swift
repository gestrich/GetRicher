import CoreService
import FinanceCoreSDK
import PersistenceService
import ReportingService
import SwiftUI

/// Shows how "Amount to Pay" is derived from the current balance, adjusted for period timing and
/// carved out for funded types. Every transaction-backed row drills into its transactions.
struct PaydownCalculationView: View {
    let report: AccountPaydownReport
    let allTransactions: [PersistenceService.Transaction]

    private var owed: PaymentsOwed { report.owed }
    private func money(_ v: Double) -> String { CurrencyFormatter.format(amount: v, currency: "USD") }
    private func txns(_ ids: [Int]) -> [PersistenceService.Transaction] {
        let set = Set(ids)
        return allTransactions.filter { set.contains($0.lunchMoneyId) }
    }

    var body: some View {
        List {
            Section {
                row("Current Balance", owed.currentBalance, sign: "", ids: [])
                row("Pending This Period", owed.pendingInPeriod, sign: "+", ids: owed.pendingTransactionIds)
                row("Posted After Period", owed.postedAfterPeriod, sign: "−", ids: owed.postedAfterTransactionIds)
                totalRow("Owed (all sources)", owed.owedTotal)
            } header: {
                Text("Balance, adjusted for period timing")
            } footer: {
                Text("Current balance, plus charges dated this week that haven't posted yet, minus charges that posted after the week. Card payments are excluded — they already reduced the balance.")
            }

            if !owed.fundedByAccount.isEmpty {
                Section {
                    ForEach(owed.fundedByAccount) { f in
                        row("Paid from \(f.fundingAccountName)", f.amount, sign: "−", ids: f.transactionIds)
                    }
                } header: {
                    Text("Covered by other accounts")
                } footer: {
                    Text("These charges are paid from another account (e.g. Cloud 9 → Reserve), so they're subtracted from what you pay from primary.")
                }
            }

            Section {
                totalRow("Amount to Pay (from primary)", owed.owedFromPrimary, emphasized: true)
            }
        }
        .navigationTitle("Amount to Pay")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func row(_ label: String, _ amount: Double, sign: String, ids: [Int]) -> some View {
        let content = HStack {
            if !sign.isEmpty { Text(sign).foregroundStyle(.secondary).frame(width: 16) }
            Text(label)
            Spacer()
            Text(money(amount)).monospacedDigit()
        }
        if ids.isEmpty {
            content
        } else {
            NavigationLink {
                FilteredTransactionListView(title: label, transactions: txns(ids))
            } label: {
                HStack {
                    content
                    Text("\(ids.count)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func totalRow(_ label: String, _ amount: Double, emphasized: Bool = false) -> some View {
        HStack {
            Text(label).font(emphasized ? .headline : .body.bold())
            Spacer()
            Text(money(amount))
                .font((emphasized ? Font.title3 : Font.body).bold().monospacedDigit())
                .foregroundStyle(emphasized ? .green : .primary)
        }
    }
}
