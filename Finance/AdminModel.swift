import ClientService
import FinanceCoreSDK
import Foundation
import KeychainSDK
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
        do {
            let client = APIClient(baseURL: backendURL)
            users = try await client.adminListUsers(adminPassword: adminPassword)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteUser(username: String, backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let client = APIClient(baseURL: backendURL)
            try await client.adminDeleteUser(username: username, adminPassword: adminPassword)
            users.removeAll { $0.username == username }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateLMToken(username: String, lmToken: String, backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let client = APIClient(baseURL: backendURL)
            try await client.adminUpdateLMToken(username: username, lmToken: lmToken, adminPassword: adminPassword)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadReports(backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let client = APIClient(baseURL: backendURL)
            reports = try await client.adminListReports(adminPassword: adminPassword)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteReport(id: String, backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let client = APIClient(baseURL: backendURL)
            try await client.adminDeleteReport(id: id, adminPassword: adminPassword)
            reports.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadErrors(backendURL: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let client = APIClient(baseURL: backendURL)
            errors = try await client.adminErrors(adminPassword: adminPassword)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
