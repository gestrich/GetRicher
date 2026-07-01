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
    @Query(sort: \PersistenceService.TransactionType.priority) var transactionTypes: [PersistenceService.TransactionType]
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
        // Live transaction types for the paydown calc (the shared calc also guards on isDeleted).
        let domainTypes = transactionTypes.filter { !$0.isTombstoned }.map { $0.toDomain() }

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
                            accountPicker
                            periodHeader
                            if selectedAccount != nil {
                                paydownSections(
                                    domainAccounts: domainAccounts,
                                    domainTypes: domainTypes,
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
                            TransactionTypesListView(targetAccountId: selectedAccountId)
                        } label: {
                            Image(systemName: "tag")
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

    @ViewBuilder
    private func paydownSections(
        domainAccounts: [FinanceCoreSDK.Account],
        domainTypes: [FinanceCoreSDK.TransactionType],
        domainTransactions: [FinanceCoreSDK.Transaction]
    ) -> some View {
        let report = paydownModel.report(
            accountId: selectedAccountIdOrNil,
            accounts: domainAccounts,
            transactions: domainTransactions,
            types: domainTypes
        )
        // Breakdowns first, then the derived Amount to Pay result underneath.
        totalSpendSection(report)
        totalPaymentsSection(report)
        amountToPaySection(report)
    }

    private func money(_ v: Double) -> String { CurrencyFormatter.format(amount: v, currency: "USD") }

    /// SwiftData transactions (with detail navigation) for the given lunchMoneyIds.
    private func txns(_ ids: [Int]) -> [PersistenceService.Transaction] {
        guard !ids.isEmpty else { return [] }
        let set = Set(ids)
        return transactions.filter { set.contains($0.lunchMoneyId) }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
    }

    /// Compact "Amount to Pay" result — taps through to the full derivation (which drills into
    /// transactions). Shown last, as the result of the calculation.
    @ViewBuilder
    private func amountToPaySection(_ report: AccountPaydownReport?) -> some View {
        if let report {
            NavigationLink {
                PaydownCalculationView(report: report, allTransactions: transactions)
            } label: {
                card {
                    HStack {
                        Text("Amount to Pay").font(.headline)
                        Spacer()
                        Text(money(report.owed.owedFromPrimary)).font(.title.bold()).foregroundStyle(.green)
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                    }
                    ForEach(report.owed.fundedByAccount) { f in
                        HStack {
                            Text("+ \(money(f.amount)) from \(f.fundingAccountName)")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                    Text("From primary. Tap to see how it's calculated.")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 6)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("PaydownCalculation")
        }
    }

    /// Total Spend bucketed by transaction type (payments excluded). Each bucket drills in.
    private func totalSpendSection(_ report: AccountPaydownReport?) -> some View {
        let spend = report?.spend
        return card {
            Text("Total Spend").font(.headline).padding(.bottom, 12)
            if (spend?.buckets ?? []).isEmpty {
                Text("No spend this period.").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 6)
            } else {
                ForEach(spend?.buckets ?? []) { b in
                    NavigationLink { FilteredTransactionListView(title: b.typeName, transactions: txns(b.transactionIds)) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.typeName).font(.body)
                                Text("\(b.count) transaction\(b.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(money(b.amount)).font(.body.monospacedDigit())
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Divider().padding(.vertical, 8)
            HStack {
                Text("Total").font(.title3.bold())
                Spacer()
                Text(money(spend?.total ?? 0)).font(.title3.bold())
            }
        }
    }

    /// Total Payments made toward the card this period. Drills into the payment transactions.
    private func totalPaymentsSection(_ report: AccountPaydownReport?) -> some View {
        let payments = report?.payments
        return card {
            NavigationLink { FilteredTransactionListView(title: "Payments", transactions: txns(payments?.transactionIds ?? [])) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Payments").font(.headline)
                        Text("\(payments?.count ?? 0) payment\((payments?.count ?? 0) == 1 ? "" : "s") this period")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(money(payments?.total ?? 0)).font(.title2.bold()).foregroundStyle(.secondary)
                    if (payments?.count ?? 0) > 0 {
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
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
