import PersistenceService
import SwiftData
import SwiftUI

struct TransferPatternListView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \PersistenceService.TransferPattern.name) var allPatterns: [PersistenceService.TransferPattern]

    let targetAccountId: Int?

    @State private var editingPattern: PersistenceService.TransferPattern?
    @State private var isAddingPattern = false

    private var patterns: [PersistenceService.TransferPattern] {
        guard let targetAccountId else { return allPatterns }
        return allPatterns.filter { $0.targetAccountId == targetAccountId }
    }

    var body: some View {
        List {
            if patterns.isEmpty {
                ContentUnavailableView(
                    "No Transfer Patterns",
                    systemImage: "arrow.triangle.2.circlepath",
                    description: Text("Tap + to create a transfer pattern for this account.")
                )
            } else {
                ForEach(patterns) { pattern in
                    Button {
                        editingPattern = pattern
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pattern.name)
                                .font(.headline)
                            Text("Match: \"\(pattern.matchText)\"")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deletePatterns)
            }
        }
        .navigationTitle("Transfer Patterns")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingPattern = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingPattern) {
            NavigationStack {
                TransferPatternEditView(pattern: nil, targetAccountId: targetAccountId ?? 0)
            }
        }
        .sheet(item: $editingPattern) { pattern in
            NavigationStack {
                TransferPatternEditView(pattern: pattern, targetAccountId: pattern.targetAccountId)
            }
        }
    }

    private func deletePatterns(at offsets: IndexSet) {
        let currentPatterns = patterns
        for index in offsets {
            modelContext.delete(currentPatterns[index])
        }
    }
}
