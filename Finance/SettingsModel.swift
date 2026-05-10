import Foundation
import KeychainSDK
import LoggingSDK

enum AppMode: Int {
    case demo = 0
    case token = 1
}

@MainActor @Observable
class SettingsModel {
    var appMode: AppMode {
        didSet {
            guard appMode != oldValue else { return }
            UserDefaults.standard.set(appMode.rawValue, forKey: "appMode")
            modeChangeCount += 1
        }
    }

    var modeChangeCount: Int = 0

    var backendURL: String = UserDefaults.standard.string(forKey: "backendURL") ?? "" {
        didSet { UserDefaults.standard.set(backendURL, forKey: "backendURL") }
    }

    private let logger = Logger(label: "GetRicher.SettingsModel")

    init(keychainClient: any KeychainClientProtocol) {
        let raw = UserDefaults.standard.object(forKey: "appMode") as? Int
        if let raw, let mode = AppMode(rawValue: raw) {
            self.appMode = mode
        } else {
            let oldDemoMode = UserDefaults.standard.object(forKey: "demoMode") as? Bool ?? true
            self.appMode = oldDemoMode ? .demo : .token
            UserDefaults.standard.set(self.appMode.rawValue, forKey: "appMode")
        }
    }

    var isDemoMode: Bool {
        appMode == .demo
    }
}
