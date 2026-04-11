import Foundation
import LoggingSDK
import Uniflow

public struct ClearLogsUseCase: UseCase {
    public init() {}

    public func run(options: Void) async throws {
        let url = GetRicherLogging.defaultLogFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: 0)
        try handle.close()
    }
}
