import CoreService
import PersistenceService
import SwiftData
import SwiftUI

struct TransactionsListView: View {
    @Environment(TransactionsModel.self) var transactionsModel
    @Environment(\.modelContext) var modelContext
    @Query(sort: \PersistenceService.Transaction.date, order: .reverse) var transactions: [PersistenceService.Transaction]
    @State private var vendorCreationTransaction: PersistenceService.Transaction?

    var body: some View {
        NavigationStack {
            Group {
                if transactionsModel.isSyncing && transactions.isEmpty {
                    ProgressView("Loading transactions...")
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
                            let dateRange = DateFilter.all.dateRange
                            transactionsModel.sync(
                                context: modelContext,
                                accountId: nil,
                                startDate: dateRange.start,
                                endDate: dateRange.end
                            )
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if transactions.isEmpty {
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "list.bullet.rectangle",
                        description: Text("No transactions found")
                    )
                } else {
                    List {
                        ForEach(transactions) { transaction in
                            NavigationLink {
                                TransactionDetailView(transaction: transaction)
                            } label: {
                                TransactionRow(transaction: transaction)
                            }
                            .contextMenu {
                                TransactionContextMenu(
                                    transaction: transaction,
                                    onCreateVendor: { vendorCreationTransaction = transaction }
                                )
                            }
                        }
                    }
                    .sheet(item: $vendorCreationTransaction) { transaction in
                        NavigationStack {
                            VendorEditView(
                                prefilledName: transaction.payee,
                                prefilledFilterText: transaction.payee,
                                prefilledAccountId: transaction.plaidAccountId
                            )
                        }
                    }
                }
            }
            .navigationTitle("Transactions")
            .task {
                let dateRange = DateFilter.all.dateRange
                transactionsModel.sync(
                    context: modelContext,
                    accountId: nil,
                    startDate: dateRange.start,
                    endDate: dateRange.end
                )
            }
            .refreshable {
                let dateRange = DateFilter.all.dateRange
                transactionsModel.sync(
                    context: modelContext,
                    accountId: nil,
                    startDate: dateRange.start,
                    endDate: dateRange.end
                )
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: PersistenceService.Transaction

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
