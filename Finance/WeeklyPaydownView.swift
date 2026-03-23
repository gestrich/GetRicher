import Charts
import CoreService
import PersistenceService
import SwiftData
import SwiftUI

struct WeeklyPaydownView: View {
    @Environment(TransactionsModel.self) var transactionsModel
    @Environment(WeeklyPaydownModel.self) var paydownModel
    @Environment(\.modelContext) var modelContext
    @Query(sort: \PersistenceService.Transaction.date, order: .reverse) var transactions: [PersistenceService.Transaction]
    @Query(sort: \PersistenceService.PlaidAccount.displayName) var accounts: [PersistenceService.PlaidAccount]
    @Query(sort: \PersistenceService.Vendor.name) var vendors: [PersistenceService.Vendor]
    @Query(sort: \PersistenceService.TransferRule.priority) var transferRules: [PersistenceService.TransferRule]
    @State private var vendorCreationTransaction: PersistenceService.Transaction?
    @AppStorage("paydownSelectedAccountId") private var selectedAccountId: Int = -1

    private var selectedAccountIdOrNil: Int? {
        selectedAccountId == -1 ? nil : selectedAccountId
    }

    var body: some View {
        @Bindable var paydownModel = paydownModel
        let periodTx = paydownModel.periodTransactions(accountId: selectedAccountIdOrNil, from: transactions)
        let selectedAccount = paydownModel.account(id: selectedAccountIdOrNil, from: accounts)

        NavigationStack {
            Group {
                if transactionsModel.isSyncing && transactions.isEmpty {
                    ProgressView("Loading...")
                } else if accounts.isEmpty {
                    ContentUnavailableView(
                        "No Accounts",
                        systemImage: "creditcard",
                        description: Text("No accounts available. Sync data first.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            accountPicker
                            periodHeader
                            if selectedAccount != nil {
                                transferBreakdownSection(periodTransactions: periodTx)
                                calculationBreakdownSection(periodTransactions: periodTx)
                                vendorChart(periodTransactions: periodTx)
                                transactionList(periodTransactions: periodTx)
                            } else {
                                ContentUnavailableView(
                                    "Select an Account",
                                    systemImage: "creditcard",
                                    description: Text("Choose a credit card account to see the weekly paydown amount.")
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Weekly Paydown")
            .toolbar {
                if selectedAccount != nil {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            TransferRulesListView(targetAccountId: selectedAccountId)
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                        }
                    }
                }
            }
            .task(id: transactionsModel.id) {
                let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
                transactionsModel.sync(
                    context: modelContext,
                    accountId: nil,
                    startDate: twoYearsAgo,
                    endDate: Date()
                )
            }
            .refreshable {
                let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
                await transactionsModel.syncAndWait(
                    context: modelContext,
                    accountId: nil,
                    startDate: twoYearsAgo,
                    endDate: Date()
                )
            }
        }
    }

    private var accountPicker: some View {
        @Bindable var paydownModel = paydownModel
        return VStack(spacing: 12) {
            Picker("Account", selection: $selectedAccountId) {
                Text("Select Account").tag(-1)
                ForEach(accounts) { account in
                    Text(account.displayName).tag(account.lunchMoneyId)
                }
            }
            .pickerStyle(.menu)

            Picker("Pivot Day", selection: $paydownModel.pivotDay) {
                ForEach(PivotDay.allCases, id: \.self) { day in
                    Text(day.rawValue).tag(day)
                }
            }
            .pickerStyle(.menu)

            Picker("Period", selection: $paydownModel.periodSelection) {
                ForEach(PeriodSelection.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
    }

    private var periodHeader: some View {
        let range = paydownModel.dateRange
        return VStack(spacing: 4) {
            Text("7-Day Period")
                .font(.headline)
            Text("\(range.start) → \(range.end)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private func transferBreakdownSection(periodTransactions: [PersistenceService.Transaction]) -> some View {
        let accountRules = transferRules.filter { $0.targetAccountId == selectedAccountId }
        let breakdown = paydownModel.transferBreakdown(
            accountId: selectedAccountId,
            periodTransactions: periodTransactions,
            vendors: vendors,
            rules: transferRules,
            accounts: accounts
        )

        return Group {
            if !accountRules.isEmpty && !breakdown.isEmpty {
                VStack(spacing: 0) {
                    Text("Transfer Breakdown")
                        .font(.headline)
                        .padding(.bottom, 12)

                    ForEach(breakdown) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.sourceAccountName)
                                    .font(.body)
                                Text("\(item.ruleName) — \(item.transactionCount) transaction\(item.transactionCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(CurrencyFormatter.format(amount: item.amount, currency: "USD"))
                                .font(.body.monospacedDigit())
                        }
                        .padding(.vertical, 6)
                    }

                    Divider()
                        .padding(.vertical, 8)

                    HStack {
                        Text("Total")
                            .font(.title3.bold())
                        Spacer()
                        Text(CurrencyFormatter.format(amount: breakdown.reduce(0) { $0 + $1.amount }, currency: "USD"))
                            .font(.title3.bold())
                            .foregroundStyle(.green)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private func calculationBreakdownSection(periodTransactions: [PersistenceService.Transaction]) -> some View {
        let calc = paydownModel.calculation(accountId: selectedAccountIdOrNil, accounts: accounts, transactions: transactions)
        let breakdown = paydownModel.transferBreakdown(
            accountId: selectedAccountId,
            periodTransactions: periodTransactions,
            vendors: vendors,
            rules: transferRules,
            accounts: accounts
        )
        let transferTotal = breakdown.reduce(0.0) { $0 + $1.amount }
        let hasTransfers = !breakdown.isEmpty
        let finalAmount = calc.adjustedSpending - transferTotal
        let pendingTransactions = periodTransactions.filter { $0.isPending }
        let clearedInPeriod = periodTransactions.filter { !$0.isPending }
        let pendingTotal = pendingTransactions.reduce(0.0) { $0 + abs($1.toBase) }
        let clearedInPeriodTotal = clearedInPeriod.reduce(0.0) { $0 + abs($1.toBase) }
        let periodGrandTotal = pendingTotal + clearedInPeriodTotal
        let postPeriodTransactions = paydownModel.postPeriodClearedTransactions(accountId: selectedAccountIdOrNil, from: transactions)

        return VStack(spacing: 0) {
            Text("Paydown Calculation")
                .font(.headline)
                .padding(.bottom, 12)

            NavigationLink {
                FilteredTransactionListView(
                    title: "Period Transactions",
                    transactions: periodTransactions
                )
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Period Spending")
                                .font(.body)
                            Spacer()
                            Text(CurrencyFormatter.format(amount: periodGrandTotal, currency: "USD"))
                                .font(.body.monospacedDigit())
                        }
                        Text("\(clearedInPeriod.count) cleared (\(CurrencyFormatter.format(amount: clearedInPeriodTotal, currency: "USD"))) · \(pendingTransactions.count) pending (\(CurrencyFormatter.format(amount: pendingTotal, currency: "USD")))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            .foregroundStyle(.primary)

            Divider()
                .padding(.vertical, 4)

            CalculationRow(
                label: "Current Balance",
                amount: calc.currentBalance,
                explanation: "The balance reported by your bank right now. This reflects all cleared transactions but not pending ones.",
                isTotal: false,
                sign: ""
            )

            NavigationLink {
                FilteredTransactionListView(
                    title: "Pending in Period",
                    transactions: pendingTransactions
                )
            } label: {
                HStack {
                    CalculationRow(
                        label: "Pending in Period",
                        amount: calc.pendingAdjustment,
                        explanation: "Transactions within the 7-day period that haven't cleared yet. These are real charges that your balance doesn't include, so we add them.",
                        isTotal: false,
                        sign: "+"
                    )
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

            NavigationLink {
                FilteredTransactionListView(
                    title: "Cleared After Period",
                    transactions: postPeriodTransactions
                )
            } label: {
                HStack {
                    CalculationRow(
                        label: "Cleared After Period",
                        amount: calc.postPeriodAdjustment,
                        explanation: "Transactions that cleared AFTER the 7-day window. They're already in your balance but belong to next week, so we subtract them.",
                        isTotal: false,
                        sign: "−"
                    )
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

            if hasTransfers {
                CalculationRow(
                    label: "Covered by Transfers",
                    amount: transferTotal,
                    explanation: "Amount covered by transfers from other accounts. These are subtracted since the linked accounts will handle the payment.",
                    isTotal: false,
                    sign: "−"
                )

                Divider()
                    .padding(.vertical, 8)

                CalculationRow(
                    label: "Amount to Pay",
                    amount: finalAmount,
                    explanation: "The remaining amount to pay after transfers from other accounts cover their portion.",
                    isTotal: true,
                    sign: "="
                )
            } else {
                Divider()
                    .padding(.vertical, 8)

                CalculationRow(
                    label: "Amount to Pay",
                    amount: calc.adjustedSpending,
                    explanation: "This is how much to pay your credit card vendor for the 7-day period.",
                    isTotal: true,
                    sign: "="
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("PaydownCalculation")
    }

    private func vendorChart(periodTransactions: [PersistenceService.Transaction]) -> some View {
        let vendorSpending = VendorSpending.aggregate(from: periodTransactions)
        let topVendors = Array(vendorSpending.prefix(8))

        return Group {
            if !topVendors.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Vendors This Week")
                        .font(.headline)
                        .padding(.horizontal)

                    Chart(topVendors) { vendor in
                        BarMark(
                            x: .value("Amount", vendor.totalAmount),
                            y: .value("Vendor", vendor.vendor)
                        )
                        .foregroundStyle(by: .value("Vendor", vendor.vendor))
                        .annotation(position: .trailing) {
                            Text(CurrencyFormatter.format(amount: vendor.totalAmount, currency: "USD"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: CGFloat(topVendors.count * 44))
                    .padding()
                    .chartLegend(.hidden)
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private func transactionList(periodTransactions: [PersistenceService.Transaction]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transactions (\(periodTransactions.count))")
                .font(.headline)
                .padding(.horizontal)

            if periodTransactions.isEmpty {
                Text("No transactions in this period.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(periodTransactions) { transaction in
                    NavigationLink {
                        TransactionDetailView(transaction: transaction)
                    } label: {
                        TransactionRow(transaction: transaction)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
    }
}

struct CalculationRow: View {
    let label: String
    let amount: Double
    let explanation: String
    let isTotal: Bool
    let sign: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if !sign.isEmpty {
                    Text(sign)
                        .font(isTotal ? .title2.bold() : .body)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                Text(label)
                    .font(isTotal ? .title2.bold() : .body)
                Spacer()
                Text(CurrencyFormatter.format(amount: amount, currency: "USD"))
                    .font(isTotal ? .title2.bold() : .body.monospacedDigit())
                    .foregroundStyle(isTotal ? .green : .primary)
            }
            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }
}
