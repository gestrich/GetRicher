import Foundation

public struct NotificationPayload: Sendable {
    public let title: String
    public let body: String
    public let data: [String: String]

    public init(title: String, body: String, data: [String: String] = [:]) {
        self.title = title
        self.body = body
        self.data = data
    }

    func apnsMessageJSON() throws -> String {
        let aps: [String: Any] = [
            "alert": ["title": title, "body": body],
            "sound": "default"
        ]
        var payload: [String: Any] = ["aps": aps]
        if !data.isEmpty {
            payload["data"] = data
        }
        let apnsJSON = String(data: try JSONSerialization.data(withJSONObject: payload), encoding: .utf8) ?? "{}"
        let wrapper: [String: Any] = [
            "default": body,
            "APNS": apnsJSON,
            "APNS_SANDBOX": apnsJSON
        ]
        let wrapperData = try JSONSerialization.data(withJSONObject: wrapper)
        return String(data: wrapperData, encoding: .utf8) ?? "{}"
    }
}
