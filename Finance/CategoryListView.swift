import PersistenceService
import SwiftData
import SwiftUI

struct CategoryListView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \PersistenceService.Category.name) var categories: [PersistenceService.Category]
    @State private var editingCategory: PersistenceService.Category?
    @State private var isAddingCategory = false

    var body: some View {
        List {
            if categories.isEmpty {
                ContentUnavailableView(
                    "No Categories",
                    systemImage: "tag",
                    description: Text("Tap + to create a category.")
                )
            } else {
                ForEach(categories) { category in
                    Button {
                        editingCategory = category
                    } label: {
                        HStack {
                            if let emoji = category.emoji {
                                Text(emoji)
                                    .font(.title2)
                            }
                            Text(category.name)
                                .font(.body)
                            Spacer()
                            if let colorHex = category.colorHex {
                                Circle()
                                    .fill(Color(hex: colorHex))
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteCategories)
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingCategory = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingCategory) {
            NavigationStack {
                CategoryEditView(category: nil)
            }
        }
        .sheet(item: $editingCategory) { category in
            NavigationStack {
                CategoryEditView(category: category)
            }
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
