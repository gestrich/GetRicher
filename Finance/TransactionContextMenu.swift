import PersistenceService
import SwiftData
import SwiftUI

struct TransactionContextMenu: View {
    let transaction: PersistenceService.Transaction
    let onCreateVendor: () -> Void

    @Query(sort: \PersistenceService.Category.name) var categories: [PersistenceService.Category]

    var body: some View {
        Button {
            onCreateVendor()
        } label: {
            Label("Create Vendor", systemImage: "building.2")
        }

        if !categories.isEmpty {
            Menu("Set Category") {
                Button("None") {
                    transaction.localCategory = nil
                }
                ForEach(categories) { category in
                    Button {
                        transaction.localCategory = category
                    } label: {
                        if let emoji = category.emoji {
                            Text("\(emoji) \(category.name)")
                        } else {
                            Text(category.name)
                        }
                    }
                }
            }
        }
    }
}
