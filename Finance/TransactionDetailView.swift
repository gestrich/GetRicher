import CoreService
import SwiftUI

struct TransactionDetailView: View {
    let transaction: CoreService.Transaction

    var body: some View {
        List {
            Section("Basic Info") {
                DetailRow(label: "ID", value: "\(transaction.id)")
                DetailRow(label: "Date", value: transaction.date)
                DetailRow(label: "Payee", value: transaction.payee)
                DetailRow(label: "Display Name", value: transaction.displayName)
                DetailRow(label: "Original Name", value: transaction.originalName)
                DetailRow(label: "Amount", value: CurrencyFormatter.format(amount: transaction.amount, currency: transaction.currency))
                DetailRow(label: "To Base", value: CurrencyFormatter.format(amount: transaction.toBase, currency: transaction.currency))
                DetailRow(label: "Status", value: transaction.status.capitalized)
            }

            Section("Flags") {
                DetailRow(label: "Is Income", value: transaction.isIncome ? "Yes" : "No")
                DetailRow(label: "Is Pending", value: transaction.isPending ? "Yes" : "No")
                DetailRow(label: "Exclude from Budget", value: transaction.excludeFromBudget ? "Yes" : "No")
                DetailRow(label: "Exclude from Totals", value: transaction.excludeFromTotals ? "Yes" : "No")
            }

            if transaction.categoryId != nil || transaction.categoryName != nil {
                Section("Category") {
                    DetailRow(label: "Category ID", value: transaction.categoryId.map { "\($0)" })
                    DetailRow(label: "Category Name", value: transaction.categoryName)
                    DetailRow(label: "Category Group ID", value: transaction.categoryGroupId.map { "\($0)" })
                    DetailRow(label: "Category Group Name", value: transaction.categoryGroupName)
                }
            }

            if let notes = transaction.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                }
            }

            if let displayNotes = transaction.displayNotes, !displayNotes.isEmpty {
                Section("Display Notes") {
                    Text(displayNotes)
                        .font(.body)
                }
            }

            Section("Timestamps") {
                DetailRow(label: "Created At", value: formatTimestamp(transaction.createdAt))
                DetailRow(label: "Updated At", value: formatTimestamp(transaction.updatedAt))
            }

            if transaction.recurringId != nil {
                Section("Recurring Info") {
                    DetailRow(label: "Recurring ID", value: transaction.recurringId.map { "\($0)" })
                    DetailRow(label: "Recurring Payee", value: transaction.recurringPayee)
                    DetailRow(label: "Recurring Description", value: transaction.recurringDescription)
                    DetailRow(label: "Cadence", value: transaction.recurringCadence)
                    DetailRow(label: "Type", value: transaction.recurringType)
                    DetailRow(label: "Amount", value: transaction.recurringAmount)
                    DetailRow(label: "Currency", value: transaction.recurringCurrency)
                    DetailRow(label: "Granularity", value: transaction.recurringGranularity)
                    DetailRow(label: "Quantity", value: transaction.recurringQuantity.map { "\($0)" })
                }
            }

            if transaction.parentId != nil || transaction.hasChildren || transaction.groupId != nil {
                Section("Grouping") {
                    DetailRow(label: "Parent ID", value: transaction.parentId.map { "\($0)" })
                    DetailRow(label: "Has Children", value: transaction.hasChildren ? "Yes" : "No")
                    DetailRow(label: "Group ID", value: transaction.groupId.map { "\($0)" })
                    DetailRow(label: "Is Group", value: transaction.isGroup ? "Yes" : "No")
                }
            }

            if transaction.assetId != nil {
                Section("Asset") {
                    DetailRow(label: "Asset ID", value: transaction.assetId.map { "\($0)" })
                    DetailRow(label: "Institution Name", value: transaction.assetInstitutionName)
                    DetailRow(label: "Asset Name", value: transaction.assetName)
                    DetailRow(label: "Display Name", value: transaction.assetDisplayName)
                    DetailRow(label: "Status", value: transaction.assetStatus)
                }
            }

            if transaction.plaidAccountId != nil {
                Section("Account (Plaid)") {
                    DetailRow(label: "Account ID", value: transaction.plaidAccountId.map { "\($0)" })
                    DetailRow(label: "Account Name", value: transaction.plaidAccountName)
                    DetailRow(label: "Account Mask", value: transaction.plaidAccountMask)
                    DetailRow(label: "Institution", value: transaction.institutionName)
                    DetailRow(label: "Display Name", value: transaction.plaidAccountDisplayName)
                    DetailRow(label: "Account Display Name", value: transaction.accountDisplayName)
                }
            }

            if let plaidMetadata = transaction.plaidMetadata, !plaidMetadata.isEmpty {
                Section("Plaid Metadata") {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(plaidMetadata)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .padding(.vertical, 4)
                    }
                }
            }

            if let tags = transaction.tags, !tags.isEmpty {
                Section("Tags") {
                    ForEach(tags, id: \.id) { tag in
                        if let name = tag.name {
                            Text(name)
                        }
                    }
                }
            }

            Section("Source & IDs") {
                DetailRow(label: "Source", value: transaction.source)
                DetailRow(label: "External ID", value: transaction.externalId)
            }
        }
        .navigationTitle("Transaction Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatTimestamp(_ timestamp: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: timestamp) else {
            return timestamp
        }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short

        return displayFormatter.string(from: date)
    }
}

struct DetailRow: View {
    let label: String
    let value: String?

    var body: some View {
        if let value = value, !value.isEmpty {
            HStack(alignment: .top) {
                Text(label)
                    .foregroundStyle(.secondary)
                    .frame(width: 140, alignment: .leading)
                Spacer()
                Text(value)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
