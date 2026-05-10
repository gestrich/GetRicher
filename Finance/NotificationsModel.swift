import Foundation
import Observation
import UIKit
import UserNotifications

@Observable
@MainActor
final class NotificationsModel {
    enum State {
        case idle
        case permissionDenied
        case registered(token: String)
        case registrationFailed(Error)
    }

    var state: State = .idle

    private let userAccountModel: UserAccountModel

    init(userAccountModel: UserAccountModel) {
        self.userAccountModel = userAccountModel
    }

    var registeredToken: String? {
        if case .registered(let token) = state { return token }
        return nil
    }

    func requestPermissionAndRegister() async {
        UNUserNotificationCenter.current().delegate = UIApplication.shared.delegate as? any UNUserNotificationCenterDelegate
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            } else {
                state = .permissionDenied
            }
        } catch {
            state = .registrationFailed(error)
        }
    }

    func handleDeviceToken(_ tokenData: Data) async {
        let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
        state = .registered(token: tokenString)
        await sendTokenToBackend(tokenString)
    }

    func handleRegistrationError(_ error: Error) {
        state = .registrationFailed(error)
    }

    func sendTokenToBackend(_ token: String) async {
        guard userAccountModel.isRegistered,
              !userAccountModel.username.isEmpty,
              !userAccountModel.password.isEmpty
        else { return }

        guard let rawURL = UserDefaults.standard.string(forKey: "backendURL"),
              !rawURL.isEmpty,
              let url = URL(string: rawURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api/device-tokens")
        else { return }

        struct DeviceTokenRequest: Encodable {
            let token: String
            let environment: String
            let username: String
            let password: String
        }

        let requestBody = DeviceTokenRequest(
            token: token,
            environment: "sandbox",
            username: userAccountModel.username,
            password: userAccountModel.password
        )
        guard let body = try? JSONEncoder().encode(requestBody) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        _ = try? await URLSession.shared.data(for: request)
    }
}
