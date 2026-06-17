import SotoSNS

public struct SNSPushNotificationClient: PushNotificationClientProtocol {
    private let sns: SNS
    private let platformApplicationArn: String

    public init(awsClient: AWSClient, region: Region? = nil, platformApplicationArn: String) {
        self.sns = SNS(client: awsClient, region: region)
        self.platformApplicationArn = platformApplicationArn
    }

    public func send(_ payload: NotificationPayload, to tokens: [DeviceToken]) async throws {
        let message = try payload.apnsMessageJSON()
        for token in tokens {
            do {
                let endpointResponse = try await sns.createPlatformEndpoint(.init(
                    platformApplicationArn: platformApplicationArn,
                    token: token.id
                ))
                guard let endpointArn = endpointResponse.endpointArn else { continue }
                // SNS disables an endpoint after a delivery failure (e.g. a token left over from
                // a previous app build). Proactively re-enable so a still-valid device recovers,
                // and isolate each token in its own do/catch so one disabled endpoint can't abort
                // the whole batch — otherwise a single stale token fails every push for the user.
                _ = try? await sns.setEndpointAttributes(.init(
                    attributes: ["Enabled": "true"],
                    endpointArn: endpointArn
                ))
                _ = try await sns.publish(.init(
                    message: message,
                    messageStructure: "json",
                    targetArn: endpointArn
                ))
            } catch {
                continue
            }
        }
    }
}
