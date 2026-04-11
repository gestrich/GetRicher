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

    public static func bootstrap(logLevel: Logger.Level = .info) {
        let url = defaultLogFileURL
        LoggingSystem.bootstrap { label in
            var handler = FileLogHandler(label: label, fileURL: url)
            handler.logLevel = logLevel
            return handler
        }
    }
}
