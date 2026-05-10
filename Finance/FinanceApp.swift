import ClientService
import KeychainSDK
import LoggingSDK
import PersistenceService
import SwiftData
import SwiftUI

@main
struct FinanceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var transactionsModel: TransactionsModel
    @State private var settingsModel: SettingsModel
    @State private var userAccountModel: UserAccountModel
    @State private var adminModel: AdminModel
    @State private var weeklyPaydownModel = WeeklyPaydownModel()
    @State private var logsModel = LogsModel()
    @State private var notificationsModel: NotificationsModel
    @State private var reviewInboxModel = ReviewInboxModel()
    @State private var lastModeChangeCount: Int = 0

    let modelContainer: ModelContainer

    init() {
        GetRicherLogging.bootstrap()

        let storedMode = UserDefaults.standard.object(forKey: "appMode") as? Int
        let appMode: AppMode
        if let storedMode, let mode = AppMode(rawValue: storedMode) {
            appMode = mode
        } else {
            let oldDemoMode = UserDefaults.standard.object(forKey: "demoMode") as? Bool ?? true
            appMode = oldDemoMode ? .demo : .token
        }

        let keychainClient: any KeychainClientProtocol
        let syncClient: any FinanceSyncClientProtocol

        if appMode == .demo {
            keychainClient = DemoKeychainClient()
            syncClient = DemoFinanceSyncClient()
        } else {
            keychainClient = KeychainClient()
            let backendURL = UserDefaults.standard.string(forKey: "backendURL") ?? ""
            syncClient = APIClient(baseURL: backendURL)
        }

        _transactionsModel = State(initialValue: TransactionsModel(
            syncClient: syncClient,
            keychainClient: keychainClient
        ))
        _settingsModel = State(initialValue: SettingsModel(keychainClient: keychainClient))
        let userAccountModel = UserAccountModel(keychainClient: keychainClient)
        _userAccountModel = State(initialValue: userAccountModel)
        _adminModel = State(initialValue: AdminModel(keychainClient: keychainClient))
        _notificationsModel = State(initialValue: NotificationsModel(userAccountModel: userAccountModel))

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
                .environment(userAccountModel)
                .environment(adminModel)
                .environment(weeklyPaydownModel)
                .environment(logsModel)
                .environment(notificationsModel)
                .environment(reviewInboxModel)
                .modelContainer(modelContainer)
                .task {
                    if settingsModel.isDemoMode {
                        seedDemoVendorsAndRules()
                    }
                    await notificationsModel.requestPermissionAndRegister()
                }
                .onChange(of: settingsModel.modeChangeCount) { _, newCount in
                    guard newCount != lastModeChangeCount else { return }
                    lastModeChangeCount = newCount
                    handleModeChange()
                }
                .onChange(of: settingsModel.backendURL) { _, newURL in
                    updateBackendURL(newURL)
                }
                .onReceive(NotificationCenter.default.publisher(for: .apnsTokenReceived)) { notification in
                    guard let tokenData = notification.userInfo?["token"] as? Data else { return }
                    Task { await notificationsModel.handleDeviceToken(tokenData) }
                }
                .onReceive(NotificationCenter.default.publisher(for: .apnsTokenFailed)) { notification in
                    guard let error = notification.userInfo?["error"] as? Error else { return }
                    notificationsModel.handleRegistrationError(error)
                }
                .onReceive(NotificationCenter.default.publisher(for: .notificationDeepLink)) { notification in
                    guard let deepLink = notification.userInfo?["deepLink"] as? String else { return }
                    selectedTab = deepLink
                }
        }
    }

    @AppStorage("selectedTab") private var selectedTab: String = "dashboard"

    @MainActor
    private func seedDemoVendorsAndRules() {
        let context = modelContainer.mainContext

        let existingVendors = (try? context.fetch(FetchDescriptor<PersistenceService.Vendor>())) ?? []
        guard existingVendors.isEmpty else { return }

        let groceries = PersistenceService.Category(name: "Groceries", emoji: "🛒", colorHex: "#34C759")
        let dining = PersistenceService.Category(name: "Dining", emoji: "🍽️", colorHex: "#FF9500")
        let subscriptions = PersistenceService.Category(name: "Subscriptions", emoji: "🔄", colorHex: "#5856D6")
        let shopping = PersistenceService.Category(name: "Shopping", emoji: "🛍️", colorHex: "#FF2D55")

        for cat in [groceries, dining, subscriptions, shopping] {
            context.insert(cat)
        }

        let wholeFoods = PersistenceService.Vendor(name: "Whole Foods", filterText: "Whole Foods", category: groceries, accountId: 2)
        let traderJoes = PersistenceService.Vendor(name: "Trader Joe's", filterText: "Trader Joe", category: groceries, accountId: 2)
        let chipotle = PersistenceService.Vendor(name: "Chipotle", filterText: "Chipotle", category: dining, accountId: 2)
        let target = PersistenceService.Vendor(name: "Target", filterText: "Target", category: shopping, accountId: 2)

        for vendor in [wholeFoods, traderJoes, chipotle, target] {
            context.insert(vendor)
        }

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

        let defaultRule = PersistenceService.TransferRule(
            name: "Everything Else → Checking",
            sourceAccountId: 1,
            targetAccountId: 2,
            priority: 0
        )

        for rule in [groceryRule, groceryRule2, defaultRule] {
            context.insert(rule)
        }

        try? context.save()
    }

    @MainActor
    private func updateBackendURL(_ newURL: String) {
        guard !settingsModel.isDemoMode,
              let apiClient = transactionsModel.syncClient as? APIClient
        else { return }
        apiClient.baseURL = newURL
    }

    @MainActor
    private func handleModeChange() {
        let context = modelContainer.mainContext
        do {
            try context.delete(model: PersistenceService.Transaction.self)
            try context.delete(model: PersistenceService.PlaidAccount.self)
            try context.delete(model: PersistenceService.Tag.self)
            try context.save()
        } catch {
            print("Failed to clear data: \(error)")
        }

        let keychainClient: any KeychainClientProtocol
        let syncClient: any FinanceSyncClientProtocol

        if settingsModel.isDemoMode {
            keychainClient = DemoKeychainClient()
            syncClient = DemoFinanceSyncClient()
        } else {
            keychainClient = KeychainClient()
            let backendURL = settingsModel.backendURL
            syncClient = APIClient(baseURL: backendURL)
        }

        transactionsModel = TransactionsModel(
            syncClient: syncClient,
            keychainClient: keychainClient
        )
    }
}
