import Foundation
import LoggingSDK
import Uniflow

public struct ClearLogsUseCase: UseCase {
    public init() {}

    public func run(options: Void) async throws {
        guard let handle = try? FileHandle(forWritingTo: GetRicherLogging.defaultLogFileURL) else { return }
        try? handle.truncate(atOffset: 0)
        try? handle.close()
    }
}
