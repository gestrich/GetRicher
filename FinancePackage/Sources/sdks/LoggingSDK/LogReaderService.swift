import Foundation

public struct LogReaderService: Sendable {
    private let fileURL: URL

    public init(fileURL: URL = GetRicherLogging.defaultLogFileURL) {
        self.fileURL = fileURL
    }

    public func readAll() throws -> [LogEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let decoder = JSONDecoder()
        return content
            .split(separator: "\n")
            .compactMap { line in
                try? decoder.decode(LogEntry.self, from: Data(line.utf8))
            }
    }

    public func clearLogs() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.truncate(atOffset: 0)
        try handle.close()
    }

    public func rawContent() throws -> String {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return "" }
        return try String(contentsOf: fileURL, encoding: .utf8)
    }
}
