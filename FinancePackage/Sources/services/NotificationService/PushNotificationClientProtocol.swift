/// Outcome of a push send. `delivered` counts tokens SNS accepted a publish for; `failedTokens`
/// holds the (truncated) tokens that errored — typically endpoints SNS has disabled because APNS
/// rejected an earlier delivery (e.g. a token left over from a previous app build).
/// Note: a delivered count only means SNS accepted the publish, not that APNS reached the device.
public struct PushDeliveryResult: Sendable, Equatable {
    public let attempted: Int
    public let delivered: Int
    public let failedTokens: [String]

    public init(attempted: Int, delivered: Int, failedTokens: [String] = []) {
        self.attempted = attempted
        self.delivered = delivered
        self.failedTokens = failedTokens
    }
}

public protocol PushNotificationClientProtocol: Sendable {
    @discardableResult
    func send(_ payload: NotificationPayload, to tokens: [DeviceToken]) async throws -> PushDeliveryResult
}
