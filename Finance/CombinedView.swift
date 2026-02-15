//
//  CombinedView.swift
//  Finance
//
//  Created by Bill Gestrich on 1/14/26.
//

import SwiftUI
import Charts

enum DateFilter: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All"

    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .week:
            let sunday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (sunday, now)
        case .month:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            return (startOfMonth, now)
        case .year:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now))!
            return (startOfYear, now)
        case .all:
            let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: now)!
            return (twoYearsAgo, now)
        }
    }
}

struct CombinedView: View {
    @State private var service = LunchMoneyService()
    @State private var selectedAccountId: Int? = nil
    @State private var selectedDateFilter: DateFilter = .all
    @State private var showSettings = false

    private var selectedAccountBalance: String? {
        guard let accountId = selectedAccountId,
              let account = service.plaidAccounts.first(where: { $0.id == accountId }) else {
            return nil
        }
        return CurrencyFormatter.format(amount: account.balance, currency: account.currency)
    }

    var body: some View {
        NavigationStack {
            Group {
                if service.isLoading {
                    ProgressView("Loading...")
                } else if let errorMessage = service.errorMessage {
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
                            Task {
                                await service.fetchPlaidAccounts()
                                await service.fetchTransactions()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if service.transactions.isEmpty {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.bar",
                        description: Text("No transactions available")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            let filteredTransactions = filterTransactions(service.transactions)
                            let vendorSpending = VendorSpending.aggregate(from: filteredTransactions)
                            let topVendors = Array(vendorSpending.prefix(10))

                            VStack(spacing: 12) {
                                Picker("Account", selection: $selectedAccountId) {
                                    Text("All Accounts").tag(nil as Int?)
                                    ForEach(service.plaidAccounts) { account in
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
                                        .annotation(position: .overlay) {
                                            Text(CurrencyFormatter.format(amount: vendor.totalAmount, currency: "USD"))
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.white)
                                        }
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

                                if service.hasMore {
                                    Button {
                                        Task {
                                            let dateRange = selectedDateFilter.dateRange
                                            await service.loadMoreTransactions(accountId: selectedAccountId, startDate: dateRange.start, endDate: dateRange.end)
                                        }
                                    } label: {
                                        HStack {
                                            Spacer()
                                            if service.isLoadingMore {
                                                ProgressView()
                                                    .padding(.horizontal, 8)
                                                Text("Loading...")
                                            } else {
                                                Text("Load More")
                                            }
                                            Spacer()
                                        }
                                    }
                                    .disabled(service.isLoadingMore)
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
                await service.fetchPlaidAccounts()
                let dateRange = selectedDateFilter.dateRange
                await service.fetchTransactions(accountId: selectedAccountId, startDate: dateRange.start, endDate: dateRange.end)
            }
            .refreshable {
                let dateRange = selectedDateFilter.dateRange
                await service.fetchTransactions(accountId: selectedAccountId, startDate: dateRange.start, endDate: dateRange.end)
            }
            .onChange(of: selectedAccountId) { _, newValue in
                Task {
                    let dateRange = selectedDateFilter.dateRange
                    await service.fetchTransactions(accountId: newValue, startDate: dateRange.start, endDate: dateRange.end)
                }
            }
            .onChange(of: selectedDateFilter) { _, newValue in
                Task {
                    let dateRange = newValue.dateRange
                    await service.fetchTransactions(accountId: selectedAccountId, startDate: dateRange.start, endDate: dateRange.end)
                }
            }
        }
    }

    private func filterTransactions(_ transactions: [Transaction]) -> [Transaction] {
        // No filtering needed since we're fetching per account from the API
        return transactions
    }
}

#Preview {
    CombinedView()
}
