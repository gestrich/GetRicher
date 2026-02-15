import KeychainSDK
import LunchMoneySDK
import SwiftUI

@main
struct FinanceApp: App {
    @State private var transactionsModel: TransactionsModel
    @State private var accountsModel: AccountsModel
    @State private var settingsModel: SettingsModel

    init() {
        let keychainClient = KeychainClient()
        let lunchMoneyClient = LunchMoneyClient()
        let pageSize = 200
        _transactionsModel = State(initialValue: TransactionsModel(
            lunchMoneyClient: lunchMoneyClient,
            keychainClient: keychainClient,
            pageSize: pageSize
        ))
        _accountsModel = State(initialValue: AccountsModel(
            lunchMoneyClient: lunchMoneyClient,
            keychainClient: keychainClient
        ))
        _settingsModel = State(initialValue: SettingsModel(keychainClient: keychainClient))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(transactionsModel)
                .environment(accountsModel)
                .environment(settingsModel)
        }
    }
}
