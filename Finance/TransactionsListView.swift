import CoreService
import SwiftUI

struct TransactionsListView: View {
    @Environment(TransactionsModel.self) var transactionsModel

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
                        systemImage: "list.bullet.rectangle",
                        description: Text("No transactions found")
                    )
                } else {
                    List {
                        ForEach(transactionsModel.transactions) { transaction in
                            NavigationLink {
                                TransactionDetailView(transaction: transaction)
                            } label: {
                                TransactionRow(transaction: transaction)
                            }
                        }

                        if transactionsModel.hasMore {
                            Section {
                                Button {
                                    let dateRange = DateFilter.all.dateRange
                                    transactionsModel.loadMore(
                                        accountId: nil,
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
                            }
                        }
                    }
                }
            }
            .navigationTitle("Transactions")
            .task {
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
}

struct TransactionRow: View {
    let transaction: CoreService.Transaction

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(transaction.payee)
                    .font(.headline)
                Spacer()
                Text(formattedAmount)
                    .font(.headline)
                    .foregroundStyle(transaction.isIncome ? .green : .primary)
            }

            HStack {
                Text(transaction.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let categoryName = transaction.categoryName {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(transaction.status.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundStyle(statusColor)
                    .cornerRadius(4)
            }

            if let notes = transaction.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var formattedAmount: String {
        CurrencyFormatter.format(amount: transaction.amount, currency: transaction.currency)
    }

    private var statusColor: Color {
        switch transaction.status.lowercased() {
        case "cleared":
            return .green
        case "pending":
            return .orange
        case "uncleared":
            return .gray
        default:
            return .blue
        }
    }
}
