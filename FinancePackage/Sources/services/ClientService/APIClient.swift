import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor
public class APIClient {
    public var baseURL: String
    public let serviceName: String
    public var mode: APIClientMode = .remote

    private let session: URLSession

    public init(baseURL: String, mode: APIClientMode = .remote, serviceName: String = "Unknown") {
        self.session = URLSession.shared
        self.baseURL = baseURL
        self.mode = mode
        self.serviceName = serviceName
    }

    public convenience init(localPort: Int, serviceName: String) {
        let baseURL = "http://localhost:\(localPort)"
        let endpoint = "\(baseURL)/invoke"
        self.init(baseURL: baseURL, mode: .local(endpoint: endpoint), serviceName: serviceName)
    }

    public func get(_ path: String) async throws -> Data {
        let (data, _) = try await performRequest(endpoint: path, method: "GET", body: nil)
        return data
    }

    public func post(_ path: String, body: Data?, headers: [String: String] = [:]) async throws -> Data {
        let (data, _) = try await performRequest(endpoint: path, method: "POST", body: body, headers: headers)
        return data
    }

    private func makeURL(endpoint: String) throws -> URL {
        switch mode {
        case .remote:
            let urlString = baseURL + endpoint
            guard let url = URL(string: urlString) else { throw APIError.invalidURL }
            return url
        case .local(let invokeEndpoint):
            guard let url = URL(string: invokeEndpoint) else { throw APIError.invalidURL }
            return url
        }
    }

    private func performRequest(endpoint: String, method: String, body: Data?, headers: [String: String] = [:]) async throws -> (Data, URLResponse) {
        let url = try makeURL(endpoint: endpoint)
        var request = URLRequest(url: url)

        switch mode {
        case .remote:
            request.httpMethod = method
            for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
            request.httpBody = body

        case .local:
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try wrapRequest(path: endpoint, method: method, body: body, headers: headers)
        }

        let (responseData, response) = try await session.data(for: request)

        switch mode {
        case .remote:
            try validateResponse(response, data: responseData)
            return (responseData, response)
        case .local:
            return (try unwrapResponse(data: responseData), response)
        }
    }

    private func wrapRequest(path: String, method: String, body: Data?, headers: [String: String]) throws -> Data {
        let bodyString = body.flatMap { String(data: $0, encoding: .utf8) }
        let wrapper = APIGatewayRequestWrapper(resource: path, path: path, httpMethod: method, headers: headers, body: bodyString)
        return try JSONEncoder().encode(wrapper)
    }

    private func unwrapResponse(data: Data) throws -> Data {
        let wrapper = try JSONDecoder().decode(APIGatewayResponseWrapper.self, from: data)
        guard (200...299).contains(wrapper.statusCode) else {
            throw APIError.httpError(statusCode: wrapper.statusCode, data: wrapper.body.data(using: .utf8))
        }
        guard let responseData = wrapper.body.data(using: .utf8) else { throw APIError.invalidResponse }
        return responseData
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }
}

public enum APIClientMode: Sendable {
    case remote
    case local(endpoint: String)
}

public enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingError(Error, rawResponse: String)

    static func httpError(statusCode: Int, data: Data?) -> APIError {
        let message = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
        return .httpError(statusCode: statusCode, message: message)
    }

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .decodingError(let err, let raw): return "Decoding error: \(err)\nResponse: \(raw)"
        }
    }
}
