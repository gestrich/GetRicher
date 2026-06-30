import PersistenceService
import SwiftData
import SwiftUI

struct TransactionTypeEditView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \PersistenceService.PlaidAccount.displayName) var accounts: [PersistenceService.PlaidAccount]

    let type: PersistenceService.TransactionType?
    let targetAccountId: Int

    @State private var name: String = ""
    @State private var kindRaw: String = "spend"
    @State private var fundingAccountId: Int = -1
    @State private var patternsText: String = ""
    @State private var priority: Int = 0

    private var isPayment: Bool { kindRaw == "payment" }
    private var isEditing: Bool { type != nil }

    private var fundingAccounts: [PersistenceService.PlaidAccount] {
        accounts.filter { $0.lunchMoneyId != targetAccountId }
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name (e.g. Cloud 9)", text: $name)
            }
            Section {
                Picker("Kind", selection: $kindRaw) {
                    Text("Spend (a purchase)").tag("spend")
                    Text("Payment (settles the card)").tag("payment")
                }
            } header: {
                Text("Kind")
            } footer: {
                Text("Spend counts toward what you owe. Payment transactions (e.g. \"THANK YOU FOR YOUR PMT\") are excluded from the paydown — they already reduce the balance.")
            }
            Section {
                TextField("Payee matches (comma-separated)", text: $patternsText, axis: .vertical)
            } header: {
                Text("Payee Patterns")
            } footer: {
                Text("Case-insensitive substrings. A transaction is this type if its payee contains any of them.")
            }
            if !isPayment {
                Section {
                    Picker("Funded By", selection: $fundingAccountId) {
                        Text("Primary (default)").tag(-1)
                        ForEach(fundingAccounts) { account in
                            Text(account.displayName).tag(account.lunchMoneyId)
                        }
                    }
                } header: {
                    Text("Funding Account")
                } footer: {
                    Text("If this spend is paid from another account (e.g. Cloud 9 → Reserve), pick it here. It's carved out of what you pay from primary.")
                }
            }
            Section {
                Stepper("Priority: \(priority)", value: $priority, in: 0...100)
            } footer: {
                Text("Higher priority types are matched first.")
            }
        }
        .navigationTitle(isEditing ? "Edit Type" : "New Type")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || parsedPatterns.isEmpty)
            }
        }
        .onAppear {
            if let type {
                name = type.name
                kindRaw = type.kindRaw
                fundingAccountId = type.fundingAccountId ?? -1
                patternsText = type.payeePatterns.joined(separator: ", ")
                priority = type.priority
            }
        }
    }

    private var parsedPatterns: [String] {
        patternsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let funding = isPayment ? nil : (fundingAccountId == -1 ? nil : fundingAccountId)
        if let type {
            type.name = trimmedName
            type.kindRaw = kindRaw
            type.fundingAccountId = funding
            type.payeePatterns = parsedPatterns
            type.priority = priority
            type.updatedAt = Date()
        } else {
            let newType = PersistenceService.TransactionType(
                name: trimmedName,
                kindRaw: kindRaw,
                fundingAccountId: funding,
                targetAccountId: targetAccountId,
                payeePatterns: parsedPatterns,
                priority: priority
            )
            modelContext.insert(newType)
        }
        dismiss()
    }
}
