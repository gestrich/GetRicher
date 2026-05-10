import ClientService
import FinanceCoreSDK
import Foundation
import KeychainSDK
import LoggingSDK
import Observation

@Observable
@MainActor
final class AdminModel {
    var adminPassword: String = ""
    var isAdminAuthenticated: Bool = false
    var users: [AdminUserInfo] = []
    var reports: [ReviewItem] = []
    var errors: AdminErrorsResponse?
    var isLoading = false
    var errorMessage: String?

    private let keychainClient: any KeychainClientProtocol
    private let logger = Logger(label: "GetRicher.AdminModel")

    init(keychainClient: any KeychainClientProtocol) {
        self.keychainClient = keychainClient
        loadAdminCredentials()
    }

    var hasAdminAccess: Bool {
        isAdminAuthenticated && !adminPassword.isEmpty
    }

    func saveAdminCredentials() {
        try? keychainClient.saveAdminPassword(adminPassword)
        isAdminAuthenticated = true
    }

    func loadAdminCredentials() {
        if let stored = keychainClient.getAdminPassword(), !stored.isEmpty {
            adminPassword = stored
            isAdminAuthenticated = true
        }
    }

    func signOutAdmin() {
        try? keychainClient.deleteAdminPassword()
        adminPassword = ""
        isAdminAuthenticated = false
        users = []
        reports = []
        errors = nil
    }

    func loadUsers(backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        logger.info("Admin: load users")
        do {
            let client = APIClient(baseURL: backendURL)
            users = try await client.adminListUsers(adminPassword: adminPassword)
        } catch {
            logger.error("Admin: load users failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func deleteUser(username: String, backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        logger.info("Admin: delete user \(username)")
        do {
            let client = APIClient(baseURL: backendURL)
            try await client.adminDeleteUser(username: username, adminPassword: adminPassword)
            users.removeAll { $0.username == username }
        } catch {
            logger.error("Admin: delete user \(username) failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func updateLMToken(username: String, lmToken: String, backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        logger.info("Admin: update LM token for \(username)")
        do {
            let client = APIClient(baseURL: backendURL)
            try await client.adminUpdateLMToken(username: username, lmToken: lmToken, adminPassword: adminPassword)
        } catch {
            logger.error("Admin: update LM token for \(username) failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func loadReports(backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        logger.info("Admin: load reports")
        do {
            let client = APIClient(baseURL: backendURL)
            reports = try await client.adminListReports(adminPassword: adminPassword)
        } catch {
            logger.error("Admin: load reports failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func deleteReport(id: String, backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        logger.info("Admin: delete report \(id)")
        do {
            let client = APIClient(baseURL: backendURL)
            try await client.adminDeleteReport(id: id, adminPassword: adminPassword)
            reports.removeAll { $0.id == id }
        } catch {
            logger.error("Admin: delete report \(id) failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func loadErrors(backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        logger.info("Admin: load errors")
        do {
            let client = APIClient(baseURL: backendURL)
            errors = try await client.adminErrors(adminPassword: adminPassword)
        } catch {
            logger.error("Admin: load errors failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
