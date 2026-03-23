import PersistenceService
import SwiftUI

struct FilteredTransactionListView: View {
    let title: String
    let transactions: [PersistenceService.Transaction]

    var body: some View {
        List {
            if transactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "tray",
                    description: Text("There are no transactions to display.")
                )
            } else {
                ForEach(transactions) { transaction in
                    NavigationLink {
                        TransactionDetailView(transaction: transaction)
                    } label: {
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
