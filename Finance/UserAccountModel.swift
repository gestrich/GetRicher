import Foundation
import KeychainSDK
import Observation

@Observable
@MainActor
final class UserAccountModel {
    var username: String = ""
    var password: String = ""
    var isRegistered: Bool = false
    var errorMessage: String?

    private let keychainClient: any KeychainClientProtocol

    init(keychainClient: any KeychainClientProtocol) {
        self.keychainClient = keychainClient
        loadCredentials()
    }

    func register(backendURL: String) async {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Username and password are required."
            return
        }
        let trimmedURL = backendURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmedURL.isEmpty, let url = URL(string: trimmedURL + "/api/users/register") else {
            errorMessage = "Invalid backend URL."
            return
        }
        struct RegisterRequest: Encodable {
            let username: String
            let password: String
        }
        guard let body = try? JSONEncoder().encode(RegisterRequest(username: username, password: password)) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200, 201, 409:
                    saveCredentials()
                    errorMessage = nil
                default:
                    errorMessage = "Registration failed (HTTP \(httpResponse.statusCode))."
                }
            }
        } catch {
            errorMessage = "Registration failed: \(error.localizedDescription)"
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
        let trimmedURL = backendURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmedURL.isEmpty, let url = URL(string: trimmedURL + "/api/send-my-report") else {
            errorMessage = "Invalid backend URL."
            return
        }
        struct SendReportRequest: Encodable {
            let username: String
            let password: String
        }
        guard let body = try? JSONEncoder().encode(SendReportRequest(username: username, password: password)) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                errorMessage = "Failed to send report (HTTP \(httpResponse.statusCode))."
            }
        } catch {
            errorMessage = "Failed to send report: \(error.localizedDescription)"
        }
    }
}
