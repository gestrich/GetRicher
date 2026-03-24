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
                            let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
                            transactionsModel.sync(
                                context: modelContext,
                                accountId: nil,
                                startDate: twoYearsAgo,
                                endDate: Date()
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
                transactionsModel.sync(
                    context: modelContext,
                    accountId: nil,
                    startDate: twoYearsAgo,
                    endDate: Date()
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

                Text(transaction.isPending ? "Pending" : "Posted")
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
        transaction.isPending ? .orange : .green
    }
}
