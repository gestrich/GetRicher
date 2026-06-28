import Charts
import CoreService
import FinanceCoreSDK
import PersistenceService
import ReportingService
import SwiftData
import SwiftUI

struct WeeklyPaydownView: View {
    @Environment(TransactionsModel.self) var transactionsModel
    @Environment(WeeklyPaydownModel.self) var paydownModel
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) private var scenePhase
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

        // Domain types for model computation
        let domainTransactions = transactions.map { $0.toDomain() }
        let domainAccounts = accounts.map { $0.toDomain() }
        // Exclude tombstoned rules/vendors from the calc (the shared calc also guards, but keep
        // the domain inputs clean).
        let domainVendors = vendors.filter { !$0.isDeleted }.map { $0.toDomain() }
        let domainRules = transferRules.filter { !$0.isDeleted }.map { $0.toDomain() }

        // Period date range (shared by domain and SwiftData transaction filters)
        let range = paydownModel.dateRange

        // Domain period transactions for charts and calculations
        let periodDomainTx = domainTransactions.filter { tx in
            let accountMatch = selectedAccountIdOrNil == nil || tx.plaidAccountId == selectedAccountIdOrNil
            return accountMatch && tx.date >= range.start && tx.date <= range.end && !tx.isIncome
        }
        let selectedAccount = paydownModel.account(id: selectedAccountIdOrNil, from: domainAccounts)

        // SwiftData period transactions for list display with detail navigation
        let periodTx = transactions.filter { tx in
            let accountMatch = selectedAccountIdOrNil == nil || tx.plaidAccountId == selectedAccountIdOrNil
            let dateMatch = tx.date >= range.start && tx.date <= range.end
            return accountMatch && dateMatch && !tx.isIncome
        }
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
                            syncDiagnostics
                            accountPicker
                            periodHeader
                            if selectedAccount != nil {
                                paydownBreakdownSection(
                                    domainAccounts: domainAccounts,
                                    domainVendors: domainVendors,
                                    domainRules: domainRules,
                                    domainTransactions: domainTransactions
                                )
                                vendorChart(periodDomainTransactions: periodDomainTx)
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
                if paydownModel.account(id: selectedAccountIdOrNil, from: accounts.map { $0.toDomain() }) != nil {
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
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    paydownModel.refreshPeriods()
                }
            }
        }
    }

    // TEMP diagnostics for sync debugging — shows local rule state + last sync error.
    private var syncDiagnostics: some View {
        let total = transferRules.count
        let deleted = transferRules.filter { $0.isDeleted }.count
        let testRules = transferRules.filter { $0.name.localizedCaseInsensitiveContains("test") }
        let testDesc = testRules.map { "\($0.name)[del=\($0.isDeleted),upd=\(Int($0.updatedAt.timeIntervalSinceReferenceDate))]" }.joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 2) {
            Text("SYNC DIAG").font(.caption2.bold()).foregroundStyle(.secondary)
            Text("rules: \(total) total, \(deleted) deleted")
                .font(.caption2.monospaced())
            if !testDesc.isEmpty {
                Text("test: \(testDesc)").font(.caption2.monospaced()).foregroundStyle(.orange)
            }
            Text("lastSync: \(transactionsModel.errorMessage ?? "ok")")
                .font(.caption2.monospaced())
                .foregroundStyle(transactionsModel.errorMessage == nil ? .green : .red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(paydownModel.budgetPeriods) { period in
                        Button {
                            paydownModel.selectedPeriod = period
                        } label: {
                            Text(period.displayLabel)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(paydownModel.selectedPeriod == period ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(paydownModel.selectedPeriod == period ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }
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

    /// Per-source paydown: each bucket = how much to transfer from a funding account to cover
    /// that account's share of the period's charges. Card payments are excluded by the shared calc.
    private func paydownBreakdownSection(
        domainAccounts: [FinanceCoreSDK.Account],
        domainVendors: [FinanceCoreSDK.Vendor],
        domainRules: [FinanceCoreSDK.TransferRule],
        domainTransactions: [FinanceCoreSDK.Transaction]
    ) -> some View {
        let report = paydownModel.report(
            accountId: selectedAccountIdOrNil,
            accounts: domainAccounts,
            transactions: domainTransactions,
            rules: domainRules,
            vendors: domainVendors
        )
        let buckets = report?.buckets ?? []
        let total = report?.amountToPay ?? 0

        return VStack(spacing: 0) {
            Text("Pay From Each Account")
                .font(.headline)
                .padding(.bottom, 12)

            if buckets.isEmpty {
                Text("No charges in this period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(buckets) { bucket in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bucket.sourceAccountName)
                                .font(.body)
                            Text("\(bucket.ruleName) — \(bucket.transactionCount) transaction\(bucket.transactionCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(CurrencyFormatter.format(amount: bucket.amount, currency: "USD"))
                            .font(.body.monospacedDigit())
                    }
                    .padding(.vertical, 6)
                }
            }

            Divider()
                .padding(.vertical, 8)

            HStack {
                Text("Amount to Pay")
                    .font(.title2.bold())
                Spacer()
                Text(CurrencyFormatter.format(amount: total, currency: "USD"))
                    .font(.title2.bold())
                    .foregroundStyle(.green)
            }

            Text("Each row is a transfer from that account for the charges it funds. Card payments are excluded.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("PaydownCalculation")
    }

    private func vendorChart(periodDomainTransactions: [FinanceCoreSDK.Transaction]) -> some View {
        let vendorSpending = VendorSpending.aggregate(from: periodDomainTransactions)
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
