import Charts
import CoreService
import PersistenceService
import SwiftData
import SwiftUI

struct CombinedView: View {
    @Environment(TransactionsModel.self) var transactionsModel
    @Environment(\.modelContext) var modelContext
    @Query(sort: \PersistenceService.Transaction.date, order: .reverse) var transactions: [PersistenceService.Transaction]
    @Query(sort: \PersistenceService.PlaidAccount.displayName) var accounts: [PersistenceService.PlaidAccount]
    @AppStorage("dashboardSelectedAccountId") private var selectedAccountId: Int = -1
    @State private var budgetPeriods: [BudgetPeriod] = BudgetPeriod.periods(count: 11, pivotDay: .saturday)
    @State private var selectedPeriod: BudgetPeriod? = BudgetPeriod.periods(count: 11, pivotDay: .saturday).first
    @State private var showSettings = false

    private var filteredTransactions: [PersistenceService.Transaction] {
        guard let period = selectedPeriod else { return [] }
        let start = period.startString
        let end = period.endString

        return transactions.filter { tx in
            let dateMatch = tx.date >= start && tx.date <= end
            let accountMatch = selectedAccountId == -1 || tx.plaidAccountId == selectedAccountId
            return dateMatch && accountMatch
        }
    }

    private var selectedAccountBalance: String? {
        guard selectedAccountId != -1,
              let account = accounts.first(where: { $0.lunchMoneyId == selectedAccountId }) else {
            return nil
        }
        return CurrencyFormatter.format(amount: account.balance, currency: account.currency)
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactionsModel.isSyncing && transactions.isEmpty {
                    ProgressView("Loading...")
                } else if let errorMessage = transactionsModel.errorMessage, transactions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text("Error")
                            .font(.headline)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            syncAllAccounts()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if filteredTransactions.isEmpty && !transactionsModel.isSyncing {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.bar",
                        description: Text("No transactions available")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            let vendorSpending = VendorSpending.aggregate(from: filteredTransactions)
                            let topVendors = Array(vendorSpending.prefix(10))

                            VStack(spacing: 12) {
                                Picker("Account", selection: $selectedAccountId) {
                                    Text("All Accounts").tag(-1)
                                    ForEach(accounts) { account in
                                        Text(account.displayName).tag(account.lunchMoneyId)
                                    }
                                }
                                .pickerStyle(.menu)

                                if let balance = selectedAccountBalance {
                                    Text("Balance: \(balance)")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(budgetPeriods) { period in
                                            Button {
                                                selectedPeriod = period
                                            } label: {
                                                Text(period.displayLabel)
                                                    .font(.subheadline)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(selectedPeriod == period ? Color.accentColor : Color(.systemGray5))
                                                    .foregroundStyle(selectedPeriod == period ? .white : .primary)
                                                    .cornerRadius(8)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)

                            if !topVendors.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Top 10 Vendors")
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
                                    .frame(height: 400)
                                    .padding()
                                    .chartLegend(.hidden)
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .padding()

                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Spending Distribution")
                                        .font(.headline)
                                        .padding(.horizontal)

                                    Chart(topVendors) { vendor in
                                        SectorMark(
                                            angle: .value("Amount", vendor.totalAmount),
                                            innerRadius: .ratio(0.5),
                                            angularInset: 1.5
                                        )
                                        .foregroundStyle(by: .value("Vendor", vendor.vendor))
                                    }
                                    .frame(height: 300)
                                    .padding()
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .padding()
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent Transactions")
                                    .font(.headline)
                                    .padding(.horizontal)

                                ForEach(filteredTransactions.prefix(50)) { transaction in
                                    NavigationLink {
                                        TransactionDetailView(transaction: transaction)
                                    } label: {
                                        TransactionRow(transaction: transaction)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Finance")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task(id: transactionsModel.id) {
                syncAllAccounts()
            }
            .refreshable {
                await syncDataAndWait()
            }
            .onChange(of: selectedPeriod) { _, _ in
                syncAllAccounts()
            }
        }
    }

    private var selectedAccountIdOrNil: Int? {
        selectedAccountId == -1 ? nil : selectedAccountId
    }

    private func syncAllAccounts() {
        guard let period = selectedPeriod else { return }
        transactionsModel.sync(
            context: modelContext,
            accountId: nil,
            startDate: period.start,
            endDate: period.end
        )
    }

    private func syncDataAndWait() async {
        guard let period = selectedPeriod else { return }
        await transactionsModel.syncAndWait(
            context: modelContext,
            accountId: selectedAccountIdOrNil,
            startDate: period.start,
            endDate: period.end
        )
    }
}
