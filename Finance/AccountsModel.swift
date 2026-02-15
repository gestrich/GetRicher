import CoreService
import Foundation
import KeychainSDK
import LunchMoneySDK
import TransactionFeature

@MainActor @Observable
class AccountsModel {
    var state: State = .idle

    private let fetchAccountsUseCase: FetchAccountsUseCase

    init(lunchMoneyClient: any LunchMoneyClientProtocol, keychainClient: any KeychainClientProtocol) {
        self.fetchAccountsUseCase = FetchAccountsUseCase(
            lunchMoneyClient: lunchMoneyClient,
            keychainClient: keychainClient
        )
    }

    func fetchAccounts() {
        state = .loading
        Task {
            do {
                let accounts = try await fetchAccountsUseCase.run(options: ())
                state = .loaded(accounts)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    var accounts: [PlaidAccount] {
        if case .loaded(let accounts) = state { return accounts }
        return []
    }

    enum State {
        case idle
        case loading
        case loaded([PlaidAccount])
        case error(String)
    }
}
