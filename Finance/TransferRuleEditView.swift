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

    private var isEditing: Bool { rule != nil }

    private var sourceAccounts: [PersistenceService.PlaidAccount] {
        accounts.filter { $0.lunchMoneyId != targetAccountId }
    }

    var body: some View {
        Form {
            detailsSection
            vendorSection
            sourceAccountSection
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
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Name", text: $name)
        }
    }

    private var vendorSection: some View {
        Section("Vendor") {
            Picker("Vendor", selection: $selectedVendorId) {
                Text("Default (all unmatched)").tag(nil as UUID?)
                ForEach(vendors) { vendor in
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
        let sourceId = selectedSourceAccountId == -1 ? nil : selectedSourceAccountId

        if let rule {
            rule.name = trimmedName
            rule.vendor = vendor
            rule.sourceAccountId = sourceId
            rule.priority = priority
        } else {
            let newRule = PersistenceService.TransferRule(
                name: trimmedName,
                vendor: vendor,
                sourceAccountId: sourceId,
                targetAccountId: targetAccountId,
                priority: priority
            )
            modelContext.insert(newRule)
        }
        dismiss()
    }
}
