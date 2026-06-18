import Foundation

public struct LoggingPushNotificationClient: PushNotificationClientProtocol {
    public init() {}

    @discardableResult
    public func send(_ payload: NotificationPayload, to tokens: [DeviceToken]) async throws -> PushDeliveryResult {
        print("[NotificationService] STUB send '\(payload.title)' to \(tokens.count) device(s): \(tokens.map(\.id).joined(separator: ", "))")
        return PushDeliveryResult(attempted: tokens.count, delivered: tokens.count)
    }
}
