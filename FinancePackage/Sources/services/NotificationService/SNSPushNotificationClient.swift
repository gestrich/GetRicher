import SotoSNS

public struct SNSPushNotificationClient: PushNotificationClientProtocol {
    private let sns: SNS
    private let platformApplicationArn: String

    public init(awsClient: AWSClient, region: Region? = nil, platformApplicationArn: String) {
        self.sns = SNS(client: awsClient, region: region)
        self.platformApplicationArn = platformApplicationArn
    }

    public func send(_ payload: NotificationPayload, to tokens: [DeviceToken]) async throws {
        for token in tokens {
            let endpointResponse = try await sns.createPlatformEndpoint(.init(
                platformApplicationArn: platformApplicationArn,
                token: token.id
            ))
            guard let endpointArn = endpointResponse.endpointArn else { continue }
            let message = try payload.apnsMessageJSON()
            _ = try await sns.publish(.init(
                message: message,
                messageStructure: "json",
                targetArn: endpointArn
            ))
        }
    }
}
