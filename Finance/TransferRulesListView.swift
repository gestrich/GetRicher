import PersistenceService
import SwiftData
import SwiftUI

struct TransferRulesListView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \PersistenceService.TransferRule.priority) var allRules: [PersistenceService.TransferRule]

    let targetAccountId: Int

    @State private var editingRule: PersistenceService.TransferRule?
    @State private var isAddingRule = false

    private var rules: [PersistenceService.TransferRule] {
        allRules.filter { $0.targetAccountId == targetAccountId }
    }

    var body: some View {
        List {
            if rules.isEmpty {
                ContentUnavailableView(
                    "No Transfer Rules",
                    systemImage: "arrow.left.arrow.right",
                    description: Text("Tap + to create a transfer rule for this account.")
                )
            } else {
                ForEach(rules) { rule in
                    Button {
                        editingRule = rule
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.name)
                                .font(.headline)
                            if let vendor = rule.vendor {
                                Text("Vendor: \(vendor.name)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Default (all unmatched transactions)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            Text("Priority: \(rule.priority)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteRules)
            }
        }
        .navigationTitle("Transfer Rules")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingRule = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingRule) {
            NavigationStack {
                TransferRuleEditView(rule: nil, targetAccountId: targetAccountId)
            }
        }
        .sheet(item: $editingRule) { rule in
            NavigationStack {
                TransferRuleEditView(rule: rule, targetAccountId: targetAccountId)
            }
        }
    }

    private func deleteRules(at offsets: IndexSet) {
        let currentRules = rules
        for index in offsets {
            modelContext.delete(currentRules[index])
        }
    }
}
