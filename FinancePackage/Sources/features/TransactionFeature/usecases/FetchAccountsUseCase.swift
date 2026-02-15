import CoreService
import KeychainSDK
import LunchMoneySDK
import Uniflow

public struct FetchAccountsUseCase: UseCase {
    public typealias Options = Void
    public typealias Result = [PlaidAccount]

    private let lunchMoneyClient: any LunchMoneyClientProtocol
    private let keychainClient: any KeychainClientProtocol

    public init(lunchMoneyClient: any LunchMoneyClientProtocol, keychainClient: any KeychainClientProtocol) {
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
