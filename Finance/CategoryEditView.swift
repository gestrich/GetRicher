import PersistenceService
import SwiftData
import SwiftUI

struct CategoryEditView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    let category: PersistenceService.Category?

    @State private var name: String = ""
    @State private var emoji: String = ""
    @State private var selectedColor: Color = .blue

    private let colorOptions: [(String, Color)] = [
        ("#FF6B6B", .red),
        ("#4ECDC4", .teal),
        ("#45B7D1", .blue),
        ("#96CEB4", .green),
        ("#FFEAA7", .yellow),
        ("#DDA0DD", .purple),
        ("#FF8C00", .orange),
        ("#778899", .gray),
    ]

    private var isEditing: Bool { category != nil }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                TextField("Emoji (optional)", text: $emoji)
                    .onChange(of: emoji) { _, newValue in
                        if newValue.count > 1 {
                            emoji = String(newValue.suffix(1))
                        }
                    }
            }

            Section("Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(colorOptions, id: \.0) { hex, color in
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                            )
                            .onTapGesture {
                                selectedColor = color
                            }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle(isEditing ? "Edit Category" : "New Category")
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
            if let category {
                name = category.name
                emoji = category.emoji ?? ""
                if let hex = category.colorHex {
                    selectedColor = Color(hex: hex)
                }
            }
        }
    }

    private var selectedColorHex: String {
        colorOptions.first { $0.1 == selectedColor }?.0 ?? "#45B7D1"
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespaces)

        if let category {
            category.name = trimmedName
            category.emoji = trimmedEmoji.isEmpty ? nil : trimmedEmoji
            category.colorHex = selectedColorHex
        } else {
            let newCategory = PersistenceService.Category(
                name: trimmedName,
                emoji: trimmedEmoji.isEmpty ? nil : trimmedEmoji,
                colorHex: selectedColorHex
            )
            modelContext.insert(newCategory)
        }
        dismiss()
    }
}
