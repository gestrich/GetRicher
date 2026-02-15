import Charts
import CoreService
import SwiftUI

struct VendorSpendingView: View {
    @Environment(TransactionsModel.self) var transactionsModel
    @Environment(AccountsModel.self) var accountsModel
    @State private var selectedAccount: String = "All Accounts"

    var body: some View {
        NavigationStack {
            Group {
                if transactionsModel.isLoading {
                    ProgressView("Loading transactions...")
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
                            let dateRange = DateFilter.all.dateRange
                            transactionsModel.fetchTransactions(
                                accountId: nil,
                                startDate: dateRange.start,
                                endDate: dateRange.end
                            )
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if transactionsModel.transactions.isEmpty {
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "chart.bar",
                        description: Text("No spending data available")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            let filteredTransactions = filterTransactions(transactionsModel.transactions)
                            let vendorSpending = VendorSpending.aggregate(from: filteredTransactions)
                            let topVendors = Array(vendorSpending.prefix(10))

                            Picker("Account", selection: $selectedAccount) {
                                Text("All Accounts").tag("All Accounts")
                                ForEach(accountsModel.accounts.map(\.displayName), id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }
                            .pickerStyle(.menu)
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
                                    }
                                    .frame(height: 400)
                                    .padding()
                                    .chartLegend(.hidden)
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .padding()

                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Spending by Vendor")
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

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("All Vendors")
                                        .font(.headline)
                                        .padding(.horizontal)

                                    ForEach(vendorSpending) { vendor in
                                        VendorRow(vendor: vendor)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Spending by Vendor")
            .task {
                accountsModel.fetchAccounts()
                let dateRange = DateFilter.all.dateRange
                transactionsModel.fetchTransactions(
                    accountId: nil,
                    startDate: dateRange.start,
                    endDate: dateRange.end
                )
            }
            .refreshable {
                let dateRange = DateFilter.all.dateRange
                transactionsModel.fetchTransactions(
                    accountId: nil,
                    startDate: dateRange.start,
                    endDate: dateRange.end
                )
            }
        }
    }

    private func filterTransactions(_ transactions: [CoreService.Transaction]) -> [CoreService.Transaction] {
        if selectedAccount == "All Accounts" {
            return transactions
        }
        return transactions.filter { $0.accountDisplayName == selectedAccount }
    }
}

struct VendorRow: View {
    let vendor: VendorSpending

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vendor.vendor)
                    .font(.headline)
                Text("\(vendor.transactionCount) transaction\(vendor.transactionCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(CurrencyFormatter.format(amount: vendor.totalAmount, currency: "USD"))
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
    }
}
