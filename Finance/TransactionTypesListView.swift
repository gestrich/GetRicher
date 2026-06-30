import PersistenceService
import SwiftData
import SwiftUI

struct TransactionTypesListView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \PersistenceService.TransactionType.priority, order: .reverse) var allTypes: [PersistenceService.TransactionType]

    let targetAccountId: Int

    @State private var editingType: PersistenceService.TransactionType?
    @State private var isAddingType = false

    private var types: [PersistenceService.TransactionType] {
        allTypes.filter { $0.targetAccountId == targetAccountId && !$0.isTombstoned }
    }

    var body: some View {
        List {
            if types.isEmpty {
                ContentUnavailableView(
                    "No Transaction Types",
                    systemImage: "tag",
                    description: Text("Tap + to classify transactions (e.g. Cloud 9 spend, or PNC payments).")
                )
            } else {
                ForEach(types) { type in
                    Button {
                        editingType = type
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(type.name).font(.headline)
                                Text(type.kindRaw == "payment" ? "PAYMENT" : "SPEND")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(type.kindRaw == "payment" ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            Text("Matches: \(type.payeePatterns.joined(separator: ", "))")
                                .font(.caption).foregroundStyle(.secondary)
                            if let funding = type.fundingAccountId {
                                Text("Funded by account \(funding)").font(.caption2).foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteTypes)
            }
        }
        .navigationTitle("Transaction Types")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAddingType = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $isAddingType) {
            NavigationStack { TransactionTypeEditView(type: nil, targetAccountId: targetAccountId) }
        }
        .sheet(item: $editingType) { type in
            NavigationStack { TransactionTypeEditView(type: type, targetAccountId: targetAccountId) }
        }
    }

    private func deleteTypes(at offsets: IndexSet) {
        let current = types
        for index in offsets {
            // Soft-delete (tombstone) so the deletion propagates via last-write-wins merge.
            current[index].isTombstoned = true
            current[index].updatedAt = Date()
        }
        try? modelContext.save()
    }
}
