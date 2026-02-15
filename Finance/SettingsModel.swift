import Foundation
import KeychainSDK

@MainActor @Observable
class SettingsModel {
    var state: State = .idle

    private let keychainClient: KeychainClient

    init(keychainClient: KeychainClient) {
        self.keychainClient = keychainClient
    }

    func loadToken() {
        if let token = keychainClient.getAPIToken() {
            state = .loaded(token)
        } else {
            state = .idle
        }
    }

    func saveToken(_ token: String) {
        do {
            try keychainClient.saveAPIToken(token)
            state = .saved(token)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func deleteToken() {
        do {
            try keychainClient.deleteAPIToken()
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    var currentToken: String? {
        switch state {
        case .loaded(let token), .saved(let token): return token
        default: return nil
        }
    }

    var isSaved: Bool {
        if case .saved = state { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let message) = state { return message }
        return nil
    }

    enum State {
        case idle
        case loaded(String)
        case saved(String)
        case error(String)
    }
}
