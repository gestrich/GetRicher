import Foundation
import KeychainSDK
import LunchMoneySDK
import PersistenceService
import SwiftData
import SyncService

@MainActor @Observable
class AccountsModel {
    // Accounts are synced as part of TransactionsModel.sync()
    // This model is kept for any account-specific UI state if needed later.
}
