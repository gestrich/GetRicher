import Foundation

public protocol UseCase: Sendable {
    associatedtype Options: Sendable = Void
    associatedtype Result: Sendable

    func run(options: Options) async throws -> Result
}

public protocol StreamingUseCase: UseCase {
    associatedtype State: Sendable

    func stream(options: Options) -> AsyncThrowingStream<State, Error>
}

extension StreamingUseCase where Result == State {
    public func run(options: Options) async throws -> Result {
        var last: State?
        for try await state in stream(options: options) {
            last = state
        }
        guard let result = last else {
            throw UniflowError.noResult
        }
        return result
    }
}

public enum UniflowError: Error {
    case noResult
}
