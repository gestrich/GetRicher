import Foundation
@_exported import Logging

public enum GetRicherLogging {
    public static let defaultLogFileURL: URL = {
        let base: URL
        #if os(iOS) || os(tvOS) || os(watchOS)
        base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        #else
        base = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
        #endif
        return base.appendingPathComponent("GetRicher/getricher.log")
    }()

    @discardableResult
    public static func bootstrap(otelService: OTelLoggingService? = nil, logLevel: Logger.Level = .info) -> OTelLoggingService? {
        let url = defaultLogFileURL
        LoggingSystem.bootstrap { label in
            var fileHandler = FileLogHandler(label: label, fileURL: url)
            fileHandler.logLevel = logLevel
            if let otelService {
                return MultiplexLogHandler([fileHandler, otelService.makeLogHandler(label: label)])
            }
            return fileHandler
        }
        return otelService
    }
}
