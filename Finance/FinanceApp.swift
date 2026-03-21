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
    @State private var lastModeChangeCount: Int = 0

    let modelContainer: ModelContainer

    init() {
        let storedMode = UserDefaults.standard.object(forKey: "appMode") as? Int
        let appMode: AppMode
        if let storedMode, let mode = AppMode(rawValue: storedMode) {
            appMode = mode
        } else {
            let oldDemoMode = UserDefaults.standard.object(forKey: "demoMode") as? Bool ?? true
            appMode = oldDemoMode ? .demo : .token
        }

        let keychainClient: any KeychainClientProtocol
        let lunchMoneyClient: any LunchMoneyClientProtocol

        if appMode == .demo {
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
            modelContainer = try ModelContainer(for: PersistenceService.Transaction.self, PersistenceService.PlaidAccount.self, PersistenceService.Tag.self, PersistenceService.Category.self, PersistenceService.Vendor.self, PersistenceService.TransferRule.self)
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
                .onChange(of: settingsModel.modeChangeCount) { _, newCount in
                    guard newCount != lastModeChangeCount else { return }
                    lastModeChangeCount = newCount
                    handleModeChange()
                }
        }
    }

    @MainActor
    private func handleModeChange() {
        // Clear all SwiftData
        let context = modelContainer.mainContext
        do {
            try context.delete(model: PersistenceService.Transaction.self)
            try context.delete(model: PersistenceService.PlaidAccount.self)
            try context.delete(model: PersistenceService.Tag.self)
            try context.save()
        } catch {
            print("Failed to clear data: \(error)")
        }

        // Recreate clients based on new mode
        let keychainClient: any KeychainClientProtocol
        let lunchMoneyClient: any LunchMoneyClientProtocol

        if settingsModel.isDemoMode {
            keychainClient = DemoKeychainClient()
            lunchMoneyClient = DemoLunchMoneyClient()
        } else {
            keychainClient = KeychainClient()
            lunchMoneyClient = LunchMoneyClient()
        }

        let pageSizeOverride = UserDefaults.standard.integer(forKey: "pageSize")
        let pageSize = pageSizeOverride > 0 ? pageSizeOverride : 200
        transactionsModel = TransactionsModel(
            lunchMoneyClient: lunchMoneyClient,
            keychainClient: keychainClient,
            pageSize: pageSize
        )
    }
}
