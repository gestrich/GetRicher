import KeychainSDK
import LunchMoneySDK
import PersistenceService
import SwiftData
import SwiftUI

@main
struct FinanceApp: App {
    @State private var transactionsModel: TransactionsModel
    @State private var settingsModel: SettingsModel
    @State private var weeklyPaydownModel = WeeklyPaydownModel()

    let modelContainer: ModelContainer

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
        _settingsModel = State(initialValue: SettingsModel(keychainClient: keychainClient))

        do {
            modelContainer = try ModelContainer(for: PersistenceService.Transaction.self, PersistenceService.PlaidAccount.self, PersistenceService.Tag.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(transactionsModel)
                .environment(settingsModel)
                .environment(weeklyPaydownModel)
                .modelContainer(modelContainer)
        }
    }
}
