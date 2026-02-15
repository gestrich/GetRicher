import CoreService
import KeychainSDK
import LunchMoneySDK
import Uniflow

public struct FetchAccountsUseCase: UseCase {
    public typealias Options = Void
    public typealias Result = [PlaidAccount]

    private let lunchMoneyClient: LunchMoneyClient
    private let keychainClient: KeychainClient

    public init(lunchMoneyClient: LunchMoneyClient, keychainClient: KeychainClient) {
        self.lunchMoneyClient = lunchMoneyClient
        self.keychainClient = keychainClient
    }

    public func run(options: Void) async throws -> [PlaidAccount] {
        guard let token = keychainClient.getAPIToken() else {
            throw FetchTransactionsError.noAPIToken
        }

        let response = try await lunchMoneyClient.fetchPlaidAccounts(token: token)
        return response.plaidAccounts
            .map(TransactionMapper.map)
            .sorted { $0.displayName < $1.displayName }
    }
}
