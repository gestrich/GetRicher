import OTel
import Logging
import ServiceLifecycle

public struct OTelLoggingService: Service, Sendable {
    private let factory: @Sendable (String) -> any LogHandler
    private let underlyingService: any Service

    public init(baseURL: String, username: String, password: String) throws {
        var config = OTel.Configuration.default
        config.serviceName = "GetRicher-iOS"
        config.logs.otlpExporter.endpoint = "\(baseURL)/api/otlp/logs"
        config.logs.otlpExporter.protocol = .httpProtobuf
        config.logs.otlpExporter.headers = [
            ("X-GetRicher-Username", username),
            ("X-GetRicher-Password", password),
        ]

        let backend = try OTel.makeLoggingBackend(configuration: config)
        self.factory = backend.factory
        self.underlyingService = backend.service
    }

    public func makeLogHandler(label: String) -> any LogHandler {
        factory(label)
    }

    public func run() async throws {
        try await underlyingService.run()
    }
}
