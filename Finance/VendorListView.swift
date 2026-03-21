import PersistenceService
import SwiftData
import SwiftUI

struct VendorListView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \PersistenceService.Vendor.name) var vendors: [PersistenceService.Vendor]

    let accountId: Int?

    @State private var editingVendor: PersistenceService.Vendor?
    @State private var isAddingVendor = false

    private var filteredVendors: [PersistenceService.Vendor] {
        guard let accountId else { return vendors }
        return vendors.filter { $0.accountId == accountId || $0.accountId == nil }
    }

    var body: some View {
        List {
            if filteredVendors.isEmpty {
                ContentUnavailableView(
                    "No Vendors",
                    systemImage: "building.2",
                    description: Text("Long-press a transaction to create a vendor.")
                )
            } else {
                ForEach(filteredVendors) { vendor in
                    Button {
                        editingVendor = vendor
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vendor.name)
                                .font(.headline)
                            Text("Filter: \"\(vendor.filterText)\"")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let category = vendor.category {
                                HStack(spacing: 4) {
                                    if let emoji = category.emoji {
                                        Text(emoji)
                                    }
                                    Text(category.name)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteVendors)
            }
        }
        .navigationTitle("Vendors")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingVendor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingVendor) {
            NavigationStack {
                VendorEditView(prefilledAccountId: accountId)
            }
        }
        .sheet(item: $editingVendor) { vendor in
            NavigationStack {
                VendorEditView(vendor: vendor)
            }
        }
    }

    private func deleteVendors(at offsets: IndexSet) {
        let filtered = filteredVendors
        for index in offsets {
            modelContext.delete(filtered[index])
        }
    }
}
