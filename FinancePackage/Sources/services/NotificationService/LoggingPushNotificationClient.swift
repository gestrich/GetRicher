import Foundation

public struct LoggingPushNotificationClient: PushNotificationClientProtocol {
    public init() {}

    public func send(_ payload: NotificationPayload, to tokens: [DeviceToken]) async throws {
        print("[NotificationService] STUB send '\(payload.title)' to \(tokens.count) device(s): \(tokens.map(\.id).joined(separator: ", "))")
    }
}
