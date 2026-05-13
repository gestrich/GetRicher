import ClientService
import Foundation
import KeychainSDK
import LoggingSDK
import Observation

@Observable
@MainActor
final class UserAccountModel {
    var username: String = ""
    var password: String = ""
    var isRegistered: Bool = false
    var errorMessage: String?
    var lastSendReportResult: APIClient.SendReportResult?

    private let keychainClient: any KeychainClientProtocol
    var apiClient: APIClient?
    private let logger = Logger(label: "GetRicher.UserAccountModel")

    init(keychainClient: any KeychainClientProtocol, apiClient: APIClient? = nil) {
        self.keychainClient = keychainClient
        self.apiClient = apiClient
        loadCredentials()
    }

    func register(backendURL: String) async {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Username and password are required."
            return
        }
        guard let client = apiClient else { return }
        logger.info("Registration attempt: \(username)")
        do {
            try await client.register(username: username, password: password)
            saveCredentials()
            errorMessage = nil
        } catch APIError.httpError(let code, _) where code == 409 {
            logger.error("Registration failed: username already exists")
            errorMessage = "Username already exists. Use Log In instead."
        } catch {
            logger.error("Registration failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func login(backendURL: String) async {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Username and password are required."
            return
        }
        guard let client = apiClient else { return }
        logger.info("Login attempt: \(username)")
        do {
            try await client.login(username: username, password: password)
            saveCredentials()
            errorMessage = nil
        } catch APIError.httpError(let code, _) where code == 401 {
            logger.error("Login failed: invalid credentials")
            errorMessage = "Invalid username or password."
        } catch {
            logger.error("Login failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func saveCredentials() {
        try? keychainClient.saveUsername(username)
        try? keychainClient.savePassword(password)
        isRegistered = true
    }

    func loadCredentials() {
        if let savedUsername = keychainClient.getUsername(), !savedUsername.isEmpty {
            username = savedUsername
            isRegistered = true
        }
        if let savedPassword = keychainClient.getPassword() {
            password = savedPassword
        }
    }

    func signOut() {
        try? keychainClient.deleteUsername()
        try? keychainClient.deletePassword()
        username = ""
        password = ""
        isRegistered = false
    }

    func sendReportNow(backendURL: String) async {
        errorMessage = nil
        lastSendReportResult = nil
        guard let client = apiClient else { return }
        logger.info("Send report triggered by user: \(username)")
        do {
            let result = try await client.sendReport(username: username, password: password)
            lastSendReportResult = result
            logger.info("Send report result: firedCount=\(result.firedCount) notificationsSent=\(result.notificationsSent) reason=\(result.reason ?? "")")
        } catch {
            logger.error("Send report failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
