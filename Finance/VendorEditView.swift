import PersistenceService
import SwiftData
import SwiftUI

struct VendorEditView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \PersistenceService.Category.name) var categories: [PersistenceService.Category]
    @Query(sort: \PersistenceService.PlaidAccount.displayName) var accounts: [PersistenceService.PlaidAccount]

    let vendor: PersistenceService.Vendor?
    let prefilledName: String?
    let prefilledFilterText: String?
    let prefilledAccountId: Int?

    @State private var name: String = ""
    @State private var filterText: String = ""
    @State private var selectedCategoryId: UUID?
    @State private var selectedAccountId: Int = -1

    init(vendor: PersistenceService.Vendor? = nil, prefilledName: String? = nil, prefilledFilterText: String? = nil, prefilledAccountId: Int? = nil) {
        self.vendor = vendor
        self.prefilledName = prefilledName
        self.prefilledFilterText = prefilledFilterText
        self.prefilledAccountId = prefilledAccountId
    }

    private var isEditing: Bool { vendor != nil }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                TextField("Filter Text (matches payee)", text: $filterText)
            }

            Section("Category") {
                Picker("Category", selection: $selectedCategoryId) {
                    Text("None").tag(nil as UUID?)
                    ForEach(categories) { category in
                        HStack {
                            if let emoji = category.emoji {
                                Text(emoji)
                            }
                            Text(category.name)
                        }
                        .tag(category.id as UUID?)
                    }
                }
            }

            Section("Account") {
                Picker("Account", selection: $selectedAccountId) {
                    Text("Any Account").tag(-1)
                    ForEach(accounts) { account in
                        Text(account.displayName).tag(account.lunchMoneyId)
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Vendor" : "New Vendor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || filterText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let vendor {
                name = vendor.name
                filterText = vendor.filterText
                selectedCategoryId = vendor.category?.id
                selectedAccountId = vendor.accountId ?? -1
            } else {
                name = prefilledName ?? ""
                filterText = prefilledFilterText ?? ""
                selectedAccountId = prefilledAccountId ?? -1
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedFilter = filterText.trimmingCharacters(in: .whitespaces)
        let category = categories.first { $0.id == selectedCategoryId }
        let accountId = selectedAccountId == -1 ? nil : selectedAccountId

        if let vendor {
            vendor.name = trimmedName
            vendor.filterText = trimmedFilter
            vendor.category = category
            vendor.accountId = accountId
        } else {
            let newVendor = PersistenceService.Vendor(
                name: trimmedName,
                filterText: trimmedFilter,
                category: category,
                accountId: accountId
            )
            modelContext.insert(newVendor)
        }
        dismiss()
    }
}
