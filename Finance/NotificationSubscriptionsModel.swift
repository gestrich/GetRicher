import ClientService
import FinanceCoreSDK
import Foundation
import LoggingSDK
import Observation

@Observable
@MainActor
final class NotificationSubscriptionsModel {
    enum State {
        case idle
        case loading
        case loaded(subscriptions: [NotificationSubscription], creditAccounts: [Account])
        case error(String)
    }

    private(set) var state: State = .idle
    var errorMessage: String?

    private let userAccountModel: UserAccountModel
    private let logger = Logger(label: "GetRicher.NotificationSubscriptionsModel")

    init(userAccountModel: UserAccountModel) {
        self.userAccountModel = userAccountModel
    }

    var subscriptions: [NotificationSubscription] {
        if case .loaded(let subs, _) = state { return subs }
        return []
    }

    var creditAccounts: [Account] {
        if case .loaded(_, let accounts) = state { return accounts }
        return []
    }

    func load() async {
        errorMessage = nil
        guard let client = userAccountModel.apiClient,
              userAccountModel.isRegistered,
              !userAccountModel.username.isEmpty,
              !userAccountModel.password.isEmpty
        else {
            state = .error("Not signed in")
            return
        }
        state = .loading
        do {
            async let subsFetch = client.listNotificationSubscriptions(
                username: userAccountModel.username,
                password: userAccountModel.password
            )
            async let accountsFetch = client.fetchAccounts(
                username: userAccountModel.username,
                password: userAccountModel.password
            )
            let (subs, accounts) = try await (subsFetch, accountsFetch)
            let creditAccounts = accounts.filter { $0.type == "credit" }
            state = .loaded(subscriptions: subs, creditAccounts: creditAccounts)
        } catch {
            logger.error("Failed to load subscriptions: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            state = .error(error.localizedDescription)
        }
    }

    func upsert(_ subscription: NotificationSubscriptionWrite) async {
        errorMessage = nil
        guard let client = userAccountModel.apiClient,
              !userAccountModel.username.isEmpty,
              !userAccountModel.password.isEmpty
        else { return }
        do {
            _ = try await client.upsertNotificationSubscription(
                username: userAccountModel.username,
                password: userAccountModel.password,
                subscription: subscription
            )
            await load()
        } catch {
            logger.error("Failed to upsert subscription: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func delete(accountId: Int) async {
        errorMessage = nil
        guard let client = userAccountModel.apiClient,
              !userAccountModel.username.isEmpty,
              !userAccountModel.password.isEmpty
        else { return }
        do {
            try await client.deleteNotificationSubscription(
                username: userAccountModel.username,
                password: userAccountModel.password,
                accountId: accountId
            )
            await load()
        } catch {
            logger.error("Failed to delete subscription: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func subscription(for accountId: Int) -> NotificationSubscription? {
        subscriptions.first(where: { $0.accountId == accountId })
    }
}
