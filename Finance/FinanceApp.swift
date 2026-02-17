import KeychainSDK
import LunchMoneySDK
import SwiftUI

@main
struct FinanceApp: App {
    @State private var transactionsModel: TransactionsModel
    @State private var accountsModel: AccountsModel
    @State private var settingsModel: SettingsModel

    init() {
        let isDemoMode = UserDefaults.standard.object(forKey: "demoMode") as? Bool ?? true

        let keychainClient: any KeychainClientProtocol
        let lunchMoneyClient: any LunchMoneyClientProtocol

        if isDemoMode {
            keychainClient = DemoKeychainClient()
            lunchMoneyClient = DemoLunchMoneyClient()
        } else {
            keychainClient = KeychainClient()
            lunchMoneyClient = LunchMoneyClient()
        }

        let pageSizeOverride = UserDefaults.standard.integer(forKey: "pageSize")
        let pageSize = pageSizeOverride > 0 ? pageSizeOverride : 200
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
