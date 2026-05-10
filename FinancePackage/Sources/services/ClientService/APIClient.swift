import FinanceCoreSDK
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
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    fileprivate func decodeOrThrow<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw APIError.decodingError(error, rawResponse: raw)
        }
    }
}

// MARK: - User Account

extension APIClient {
    public func register(username: String, password: String) async throws {
        struct RegisterRequest: Encodable {
            let username: String
            let password: String
        }
        let body = try JSONEncoder().encode(RegisterRequest(username: username, password: password))
        _ = try await post("/api/users/register", body: body, headers: ["Content-Type": "application/json"])
    }

    public func login(username: String, password: String) async throws {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
        ]
        let query = components.percentEncodedQuery ?? ""
        _ = try await get("/api/accounts?\(query)")
    }
}

// MARK: - FinanceSyncClientProtocol

extension APIClient: FinanceSyncClientProtocol {
    public func fetchAccounts(username: String, password: String) async throws -> [Account] {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
        ]
        let query = components.percentEncodedQuery ?? ""
        let data = try await get("/api/accounts?\(query)")
        return try decodeOrThrow([Account].self, from: data)
    }

    public func fetchTransactions(username: String, password: String, startDate: String, endDate: String) async throws -> [Transaction] {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "startDate", value: startDate),
            URLQueryItem(name: "endDate", value: endDate),
        ]
        let query = components.percentEncodedQuery ?? ""
        let data = try await get("/api/transactions?\(query)")
        return try decodeOrThrow([Transaction].self, from: data)
    }

    public func triggerRefresh(username: String, password: String) async throws {
        struct RefreshBody: Encodable {
            let username: String
            let password: String
        }
        let body = try JSONEncoder().encode(RefreshBody(username: username, password: password))
        _ = try await post("/api/refresh", body: body, headers: ["Content-Type": "application/json"])
    }

}

// MARK: - Review items

extension APIClient {
    public func fetchReviewItems() async throws -> [ReviewItem] {
        let data = try await get("/api/review-items")
        return try decodeOrThrow([ReviewItem].self, from: data)
    }

    public func resolveItem(id: String, status: String) async throws {
        struct ResolveBody: Encodable {
            let id: String
            let status: String
        }
        let body = try JSONEncoder().encode(ResolveBody(id: id, status: status))
        _ = try await post("/api/review-items/resolve", body: body, headers: ["Content-Type": "application/json"])
    }
}

// MARK: - Reports

extension APIClient {
    public func generateReport() async throws -> Data {
        return try await post("/api/generate-report", body: nil)
    }

    public func sendReport(username: String, password: String) async throws {
        struct SendReportBody: Encodable {
            let username: String
            let password: String
        }
        let body = try JSONEncoder().encode(SendReportBody(username: username, password: password))
        _ = try await post("/api/send-my-report", body: body, headers: ["Content-Type": "application/json"])
    }
}

// MARK: - Admin

extension APIClient {
    public func adminListUsers() async throws -> [AdminUserInfo] {
        let data = try await get("/api/admin/users")
        return try decodeOrThrow([AdminUserInfo].self, from: data)
    }

    public func adminDeleteUser(username: String) async throws {
        _ = try await performDelete("/api/admin/users/\(username)")
    }

    public func adminUpdateLMToken(username: String, lmToken: String) async throws {
        struct Body: Encodable { let lmToken: String }
        let body = try JSONEncoder().encode(Body(lmToken: lmToken))
        _ = try await put("/api/admin/users/\(username)/lm-token", body: body, headers: ["Content-Type": "application/json"])
    }

    public func adminListReports() async throws -> [ReviewItem] {
        let data = try await get("/api/admin/reports")
        return try decodeOrThrow([ReviewItem].self, from: data)
    }

    public func adminDeleteReport(id: String) async throws {
        _ = try await performDelete("/api/admin/reports/\(id)")
    }

    public func adminErrors() async throws -> AdminErrorsResponse {
        let data = try await get("/api/admin/errors")
        return try decodeOrThrow(AdminErrorsResponse.self, from: data)
    }

    public func buildStatus() async throws -> BuildStatusResponse {
        let data = try await get("/api/build-status")
        return try decodeOrThrow(BuildStatusResponse.self, from: data)
    }

    func performDelete(_ path: String) async throws -> Data {
        let (data, _) = try await performRequest(endpoint: path, method: "DELETE", body: nil)
        return data
    }

    func put(_ path: String, body: Data?, headers: [String: String] = [:]) async throws -> Data {
        let (data, _) = try await performRequest(endpoint: path, method: "PUT", body: body, headers: headers)
        return data
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
