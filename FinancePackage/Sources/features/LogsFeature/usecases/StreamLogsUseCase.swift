import LoggingSDK
import Uniflow

public struct StreamLogsUseCase: StreamingUseCase {
    public init() {}

    public func stream(options: Void) -> AsyncThrowingStream<[LogEntry], Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let existing = try LogReaderService().readAll()
                    if !existing.isEmpty {
                        continuation.yield(existing)
                    }
                    for await newEntries in LogFileWatcher().stream() {
                        continuation.yield(newEntries)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
