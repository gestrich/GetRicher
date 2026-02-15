//
//  TransactionsListView.swift
//  Finance
//
//  Created by Bill Gestrich on 1/14/26.
//

import SwiftUI

struct TransactionsListView: View {
    @State private var service = LunchMoneyService()

    var body: some View {
        NavigationStack {
            Group {
                if service.isLoading {
                    ProgressView("Loading transactions...")
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
                                await service.fetchTransactions()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if service.transactions.isEmpty {
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "list.bullet.rectangle",
                        description: Text("No transactions found")
                    )
                } else {
                    List {
                        ForEach(service.transactions) { transaction in
                            NavigationLink {
                                TransactionDetailView(transaction: transaction)
                            } label: {
                                TransactionRow(transaction: transaction)
                            }
                        }

                        if service.hasMore {
                            Section {
                                Button {
                                    Task {
                                        await service.loadMoreTransactions()
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
                            }
                        }
                    }
                }
            }
            .navigationTitle("Transactions")
            .task {
                await service.fetchTransactions()
            }
            .refreshable {
                await service.fetchTransactions()
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction

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

#Preview {
    TransactionsListView()
}
