import FinanceCoreSDK
import SwiftUI

struct ReviewInboxView: View {
    @Environment(ReviewInboxModel.self) var model

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .idle:
                    ContentUnavailableView("No Items", systemImage: "tray")
                case .loading:
                    ProgressView("Loading…")
                case .loaded(let items):
                    if items.isEmpty {
                        ContentUnavailableView(
                            "All Clear",
                            systemImage: "checkmark.circle",
                            description: Text("No pending review items.")
                        )
                    } else {
                        List(items) { item in
                            ReviewItemRow(item: item)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button("Dismiss", role: .destructive) {
                                        Task { await model.resolve(item, status: .dismissed) }
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button("Approve") {
                                        Task { await model.resolve(item, status: .approved) }
                                    }
                                    .tint(.green)
                                }
                        }
                    }
                case .error(let message):
                    ContentUnavailableView(
                        "Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                }
            }
            .navigationTitle("Review Inbox")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await model.loadItems() }
                    }
                }
            }
        }
        .task { await model.loadItems() }
    }
}

private struct ReviewItemRow: View {
    let item: ReviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.headline)
            Text(item.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Text(item.kind.displayName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(item.createdAt.prefix(10))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

private extension ReviewItem.Kind {
    var displayName: String {
        switch self {
        case .weeklySpending: return "Weekly Spending"
        case .spendingGoal: return "Spending Goal"
        case .savingsGoal: return "Savings Goal"
        case .funAccountBalance: return "Account Balance"
        case .autopay: return "Autopay"
        case .lowBalance: return "Low Balance"
        }
    }
}
