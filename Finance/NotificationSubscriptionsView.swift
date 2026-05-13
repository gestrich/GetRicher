import FinanceCoreSDK
import SwiftUI

struct NotificationSubscriptionsView: View {
    @Environment(NotificationSubscriptionsModel.self) var model

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error(let message):
                ContentUnavailableView {
                    Label("Couldn't load subscriptions", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") { Task { await model.load() } }
                }
            case .loaded(let subs, let accounts):
                loadedList(subscriptions: subs, accounts: accounts)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    @ViewBuilder
    private func loadedList(subscriptions: [NotificationSubscription], accounts: [Account]) -> some View {
        if accounts.isEmpty {
            ContentUnavailableView(
                "No credit accounts",
                systemImage: "creditcard",
                description: Text("Credit accounts sync from Lunch Money on the hourly job.")
            )
        } else {
            List {
                Section {
                    ForEach(accounts) { account in
                        accountRow(
                            account: account,
                            subscription: subscriptions.first(where: { $0.accountId == account.lunchMoneyId })
                        )
                    }
                } footer: {
                    Text("Subscribe to receive a single combined push per scheduled hour listing every account that matched.")
                }
                if let msg = model.errorMessage {
                    Section {
                        Text(msg).foregroundColor(.red).font(.footnote)
                    }
                }
            }
        }
    }

    private func accountRow(account: Account, subscription: NotificationSubscription?) -> some View {
        NavigationLink {
            EditSubscriptionView(account: account, existing: subscription)
                .environment(model)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .font(.body)
                if let sub = subscription {
                    Text(sub.scheduleSummary)
                        .font(.caption)
                        .foregroundColor(sub.enabled ? .secondary : .secondary.opacity(0.5))
                    if !sub.enabled {
                        Text("Disabled")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("Not subscribed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private extension NotificationSubscription {
    var scheduleSummary: String {
        let dayString: String
        let daySet = Set(daysOfWeek)
        if daySet == Set(DayOfWeek.allCases) {
            dayString = "Every day"
        } else if daySet == Set(DayOfWeek.weekdays) {
            dayString = "Weekdays"
        } else {
            dayString = daysOfWeek.map { $0.rawValue.capitalized }.joined(separator: ", ")
        }
        let hourString = formatHour(hour)
        return "\(dayString) at \(hourString) (\(timezone))"
    }
}

private func formatHour(_ hour: Int) -> String {
    let suffix = hour < 12 ? "AM" : "PM"
    let h = hour % 12
    let display = h == 0 ? 12 : h
    return "\(display) \(suffix)"
}
