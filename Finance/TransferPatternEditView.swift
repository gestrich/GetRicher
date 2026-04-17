import PersistenceService
import SwiftData
import SwiftUI

struct TransferPatternEditView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \PersistenceService.PlaidAccount.displayName) var accounts: [PersistenceService.PlaidAccount]

    let pattern: PersistenceService.TransferPattern?
    let targetAccountId: Int

    @State private var name: String = ""
    @State private var matchText: String = ""
    @State private var selectedSourceAccountId: Int = -1

    private var isEditing: Bool { pattern != nil }

    private var sourceAccounts: [PersistenceService.PlaidAccount] {
        accounts.filter { $0.lunchMoneyId != targetAccountId }
    }

    var body: some View {
        Form {
            detailsSection
            matchSection
            sourceAccountSection
        }
        .navigationTitle(isEditing ? "Edit Pattern" : "New Pattern")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || matchText.trimmingCharacters(in: .whitespaces).isEmpty || selectedSourceAccountId == -1)
            }
        }
        .onAppear {
            if let pattern {
                name = pattern.name
                matchText = pattern.matchText
                selectedSourceAccountId = pattern.sourceAccountId
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Name", text: $name)
        }
    }

    private var matchSection: some View {
        Section {
            TextField("Match Text", text: $matchText)
        } header: {
            Text("Match Text")
        } footer: {
            Text("Substring to match on transaction payee. Case-insensitive.")
        }
    }

    private var sourceAccountSection: some View {
        Section("Source Account") {
            Picker("Transfer From", selection: $selectedSourceAccountId) {
                Text("Select Account").tag(-1)
                ForEach(sourceAccounts) { account in
                    Text(account.displayName).tag(account.lunchMoneyId)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedMatch = matchText.trimmingCharacters(in: .whitespaces)

        if let pattern {
            pattern.name = trimmedName
            pattern.matchText = trimmedMatch
            pattern.sourceAccountId = selectedSourceAccountId
        } else {
            let newPattern = PersistenceService.TransferPattern(
                name: trimmedName,
                matchText: trimmedMatch,
                sourceAccountId: selectedSourceAccountId,
                targetAccountId: targetAccountId
            )
            modelContext.insert(newPattern)
        }
        dismiss()
    }
}
