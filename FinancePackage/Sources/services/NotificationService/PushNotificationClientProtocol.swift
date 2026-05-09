public protocol PushNotificationClientProtocol: Sendable {
    func send(_ payload: NotificationPayload, to tokens: [DeviceToken]) async throws
}
