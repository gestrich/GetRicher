import SotoCore

struct LoggingMiddleware: AWSMiddlewareProtocol {
    func handle(_ request: AWSHTTPRequest, context: AWSMiddlewareContext, next: AWSMiddlewareNextHandler) async throws -> AWSHTTPResponse {
        do {
            if let length = request.body.length, length > 0 {
                let buffer = try await request.body.collect(upTo: 2048)
                let previewSize = min(buffer.readableBytes, 2048)
                let preview = buffer.getString(at: buffer.readerIndex, length: previewSize) ?? "<binary>"
                context.logger.info("[AWSRequest] \(request.method) \(request.url) body=\(preview)")
            } else {
                context.logger.info("[AWSRequest] \(request.method) \(request.url) body=<empty or streaming>")
            }
        } catch {
            context.logger.info("[AWSRequest] \(request.method) \(request.url) body=<error reading body: \(error)>")
        }
        return try await next(request, context)
    }
}
