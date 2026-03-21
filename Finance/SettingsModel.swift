import Foundation
import KeychainSDK

enum AppMode: Int {
    case demo = 0
    case token = 1
}

@MainActor @Observable
class SettingsModel {
    var state: State = .idle
    var appMode: AppMode {
        didSet {
            guard appMode != oldValue else { return }
            UserDefaults.standard.set(appMode.rawValue, forKey: "appMode")
            if appMode == .demo {
                deleteToken()
            }
            modeChangeCount += 1
        }
    }

    /// Incremented each time the mode changes; observers can use this to react.
    var modeChangeCount: Int = 0

    private(set) var keychainClient: any KeychainClientProtocol

    init(keychainClient: any KeychainClientProtocol) {
        self.keychainClient = keychainClient
        let raw = UserDefaults.standard.object(forKey: "appMode") as? Int
        if let raw, let mode = AppMode(rawValue: raw) {
            self.appMode = mode
        } else {
            // Migration: check old "demoMode" key
            let oldDemoMode = UserDefaults.standard.object(forKey: "demoMode") as? Bool ?? true
            self.appMode = oldDemoMode ? .demo : .token
            UserDefaults.standard.set(self.appMode.rawValue, forKey: "appMode")
        }
    }

    var isDemoMode: Bool {
        appMode == .demo
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
            if appMode != .token {
                appMode = .token
            }
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
