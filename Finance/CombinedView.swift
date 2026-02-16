import Charts
import CoreService
import SwiftUI

struct CombinedView: View {
    @Environment(TransactionsModel.self) var transactionsModel
    @Environment(AccountsModel.self) var accountsModel
    @State private var selectedAccountId: Int? = nil
    @State private var selectedDateFilter: DateFilter = .all
    @State private var showSettings = false

    private var selectedAccountBalance: String? {
        guard let accountId = selectedAccountId,
              let account = accountsModel.accounts.first(where: { $0.id == accountId }) else {
            return nil
        }
        return CurrencyFormatter.format(amount: account.balance, currency: account.currency)
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactionsModel.isLoading {
                    ProgressView("Loading...")
                } else if let errorMessage = transactionsModel.errorMessage {
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
                            fetchData()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if transactionsModel.transactions.isEmpty {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.bar",
                        description: Text("No transactions available")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            let vendorSpending = VendorSpending.aggregate(from: transactionsModel.transactions)
                            let topVendors = Array(vendorSpending.prefix(10))

                            VStack(spacing: 12) {
                                Picker("Account", selection: $selectedAccountId) {
                                    Text("All Accounts").tag(nil as Int?)
                                    ForEach(accountsModel.accounts) { account in
                                        Text(account.displayName).tag(account.id as Int?)
                                    }
                                }
                                .pickerStyle(.menu)

                                if let balance = selectedAccountBalance {
                                    Text("Balance: \(balance)")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }

                                HStack(spacing: 8) {
                                    ForEach(DateFilter.allCases, id: \.self) { filter in
                                        Button {
                                            selectedDateFilter = filter
                                        } label: {
                                            Text(filter.rawValue)
                                                .font(.subheadline)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(selectedDateFilter == filter ? Color.accentColor : Color(.systemGray5))
                                                .foregroundStyle(selectedDateFilter == filter ? .white : .primary)
                                                .cornerRadius(8)
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

                                ForEach(transactionsModel.transactions.prefix(50)) { transaction in
                                    NavigationLink {
                                        TransactionDetailView(transaction: transaction)
                                    } label: {
                                        TransactionRow(transaction: transaction)
                                    }
                                    .buttonStyle(.plain)
                                }

                                if transactionsModel.hasMore {
                                    Button {
                                        let dateRange = selectedDateFilter.dateRange
                                        transactionsModel.loadMore(
                                            accountId: selectedAccountId,
                                            startDate: dateRange.start,
                                            endDate: dateRange.end
                                        )
                                    } label: {
                                        HStack {
                                            Spacer()
                                            if transactionsModel.isLoadingMore {
                                                ProgressView()
                                                    .padding(.horizontal, 8)
                                                Text("Loading...")
                                            } else {
                                                Text("Load More")
                                            }
                                            Spacer()
                                        }
                                    }
                                    .disabled(transactionsModel.isLoadingMore)
                                    .padding()
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
            .task {
                fetchData()
            }
            .refreshable {
                let dateRange = selectedDateFilter.dateRange
                transactionsModel.fetchTransactions(
                    accountId: selectedAccountId,
                    startDate: dateRange.start,
                    endDate: dateRange.end
                )
            }
            .onChange(of: selectedAccountId) { _, newValue in
                let dateRange = selectedDateFilter.dateRange
                transactionsModel.fetchTransactions(
                    accountId: newValue,
                    startDate: dateRange.start,
                    endDate: dateRange.end
                )
            }
            .onChange(of: selectedDateFilter) { _, newValue in
                let dateRange = newValue.dateRange
                transactionsModel.fetchTransactions(
                    accountId: selectedAccountId,
                    startDate: dateRange.start,
                    endDate: dateRange.end
                )
            }
        }
    }

    private func fetchData() {
        accountsModel.fetchAccounts()
        let dateRange = selectedDateFilter.dateRange
        transactionsModel.fetchTransactions(
            accountId: selectedAccountId,
            startDate: dateRange.start,
            endDate: dateRange.end
        )
    }
}
