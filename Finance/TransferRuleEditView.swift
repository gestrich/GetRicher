import PersistenceService
import SwiftData
import SwiftUI

struct TransferRuleEditView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \PersistenceService.Vendor.name) var vendors: [PersistenceService.Vendor]
    @Query(sort: \PersistenceService.PlaidAccount.displayName) var accounts: [PersistenceService.PlaidAccount]

    let rule: PersistenceService.TransferRule?
    let targetAccountId: Int

    @State private var name: String = ""
    @State private var selectedVendorId: UUID?
    @State private var selectedSourceAccountId: Int = -1
    @State private var priority: Int = 0
    /// "transfer" routes matched charges to a source account; "payment" excludes matched
    /// transactions (card payments / settlements) from the paydown entirely.
    @State private var kindRaw: String = "transfer"
    private var isPayment: Bool { kindRaw == "payment" }

    private var isEditing: Bool { rule != nil }

    private var sourceAccounts: [PersistenceService.PlaidAccount] {
        accounts.filter { $0.lunchMoneyId != targetAccountId }
    }

    var body: some View {
        Form {
            detailsSection
            kindSection
            vendorSection
            if !isPayment {
                sourceAccountSection
            }
            prioritySection
        }
        .navigationTitle(isEditing ? "Edit Rule" : "New Rule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let rule {
                name = rule.name
                selectedVendorId = rule.vendor?.id
                selectedSourceAccountId = rule.sourceAccountId ?? -1
                priority = rule.priority
                kindRaw = rule.kindRaw
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Name", text: $name)
        }
    }

    private var kindSection: some View {
        Section {
            Picker("Kind", selection: $kindRaw) {
                Text("Transfer (pay from an account)").tag("transfer")
                Text("Payment (exclude from spending)").tag("payment")
            }
        } header: {
            Text("Rule Kind")
        } footer: {
            Text("Transfer rules route matched charges to a source account. Payment rules mark matched transactions as card payments and exclude them from the paydown.")
        }
    }

    private var vendorSection: some View {
        Section("Vendor") {
            Picker("Vendor", selection: $selectedVendorId) {
                Text("Default (all unmatched)").tag(nil as UUID?)
                ForEach(vendors.filter { !$0.isTombstoned }) { vendor in
                    Text(vendor.name).tag(vendor.id as UUID?)
                }
            }
            .onChange(of: selectedVendorId) { _, newValue in
                if let vendorId = newValue, let vendor = vendors.first(where: { $0.id == vendorId }), name.isEmpty {
                    name = vendor.name
                }
            }
        }
    }

    private var sourceAccountSection: some View {
        Section("Source Account") {
            Picker("Pay From", selection: $selectedSourceAccountId) {
                Text("Not Specified").tag(-1)
                ForEach(sourceAccounts) { account in
                    Text(account.displayName).tag(account.lunchMoneyId)
                }
            }
        }
    }

    private var prioritySection: some View {
        Section {
            Stepper("Priority: \(priority)", value: $priority, in: 0...100)
        } header: {
            Text("Priority")
        } footer: {
            Text("Higher priority rules are matched first. Default (catch-all) rules should have the lowest priority.")
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let vendor = vendors.first { $0.id == selectedVendorId }
        // Payment rules don't fund from a source account.
        let sourceId = isPayment ? nil : (selectedSourceAccountId == -1 ? nil : selectedSourceAccountId)

        if let rule {
            rule.name = trimmedName
            rule.vendor = vendor
            rule.sourceAccountId = sourceId
            rule.priority = priority
            rule.kindRaw = kindRaw
            rule.updatedAt = Date() // bump for last-write-wins sync
        } else {
            let newRule = PersistenceService.TransferRule(
                name: trimmedName,
                vendor: vendor,
                sourceAccountId: sourceId,
                targetAccountId: targetAccountId,
                priority: priority,
                kindRaw: kindRaw
            )
            modelContext.insert(newRule)
        }
        dismiss()
    }
}
