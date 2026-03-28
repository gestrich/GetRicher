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
            modelContainer = try ModelContainer(for: PersistenceService.Transaction.self, PersistenceService.PlaidAccount.self, PersistenceService.Tag.self, PersistenceService.Category.self, PersistenceService.Vendor.self, PersistenceService.TransferPattern.self, PersistenceService.TransferRule.self)
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
                .task {
                    if settingsModel.isDemoMode {
                        seedDemoVendorsAndRules()
                    }
                }
                .onChange(of: settingsModel.modeChangeCount) { _, newCount in
                    guard newCount != lastModeChangeCount else { return }
                    lastModeChangeCount = newCount
                    handleModeChange()
                }
        }
    }

    @MainActor
    private func seedDemoVendorsAndRules() {
        let context = modelContainer.mainContext

        // Check if already seeded
        let existingVendors = (try? context.fetch(FetchDescriptor<PersistenceService.Vendor>())) ?? []
        guard existingVendors.isEmpty else { return }

        // Create categories
        let groceries = PersistenceService.Category(name: "Groceries", emoji: "🛒", colorHex: "#34C759")
        let dining = PersistenceService.Category(name: "Dining", emoji: "🍽️", colorHex: "#FF9500")
        let subscriptions = PersistenceService.Category(name: "Subscriptions", emoji: "🔄", colorHex: "#5856D6")
        let shopping = PersistenceService.Category(name: "Shopping", emoji: "🛍️", colorHex: "#FF2D55")

        for cat in [groceries, dining, subscriptions, shopping] {
            context.insert(cat)
        }

        // Create vendors for Amex Gold (accountId: 2)
        let wholeFoods = PersistenceService.Vendor(name: "Whole Foods", filterText: "Whole Foods", category: groceries, accountId: 2)
        let traderJoes = PersistenceService.Vendor(name: "Trader Joe's", filterText: "Trader Joe", category: groceries, accountId: 2)
        let chipotle = PersistenceService.Vendor(name: "Chipotle", filterText: "Chipotle", category: dining, accountId: 2)
        let target = PersistenceService.Vendor(name: "Target", filterText: "Target", category: shopping, accountId: 2)

        for vendor in [wholeFoods, traderJoes, chipotle, target] {
            context.insert(vendor)
        }

        // Create transfer rules for Amex Gold (targetAccountId: 2)
        // Rule: Groceries paid from Ally Savings (sourceAccountId: 3)
        let groceryRule = PersistenceService.TransferRule(
            name: "Groceries → Savings",
            vendor: wholeFoods,
            sourceAccountId: 3,
            targetAccountId: 2,
            priority: 10
        )

        let groceryRule2 = PersistenceService.TransferRule(
            name: "Groceries → Savings",
            vendor: traderJoes,
            sourceAccountId: 3,
            targetAccountId: 2,
            priority: 10
        )

        // Default catch-all: everything else from Chase Checking (sourceAccountId: 1)
        let defaultRule = PersistenceService.TransferRule(
            name: "Everything Else → Checking",
            sourceAccountId: 1,
            targetAccountId: 2,
            priority: 0
        )

        for rule in [groceryRule, groceryRule2, defaultRule] {
            context.insert(rule)
        }

        // Create transfer patterns for Amex Gold (targetAccountId: 2)
        let checkingPayment = PersistenceService.TransferPattern(
            name: "Checking Payment",
            matchText: "ONLINE PAYMENT",
            sourceAccountId: 1,
            targetAccountId: 2
        )

        let savingsPayment = PersistenceService.TransferPattern(
            name: "Savings Payment",
            matchText: "MOBILE PAYMENT",
            sourceAccountId: 3,
            targetAccountId: 2
        )

        for pattern in [checkingPayment, savingsPayment] {
            context.insert(pattern)
        }

        try? context.save()
    }

    @MainActor
    private func handleModeChange() {
        // Clear all SwiftData
        let context = modelContainer.mainContext
        do {
            try context.delete(model: PersistenceService.Transaction.self)
            try context.delete(model: PersistenceService.PlaidAccount.self)
            try context.delete(model: PersistenceService.Tag.self)
            try context.delete(model: PersistenceService.TransferPattern.self)
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
