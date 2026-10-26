import Foundation

/// An error from the API. Switch on `code` (stable), never on `message`.
struct APIError: Error, Equatable, Sendable {
    let status: Int
    let code: String
    let message: String
    var requestID: String?
}

/// The network behind a small protocol, so tests use a fake instead of URLSession.
protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// The real transport. (URLSession's own `data(for:delegate:)` has an extra parameter, so it
/// cannot satisfy the protocol directly.)
struct URLSessionTransport: HTTPTransport {
    var session: URLSession = .shared

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

/// The only place the app talks HTTP: JSON, timeouts, Problem Details → APIError.
struct APIClient: Sendable {
    let baseURL: URL
    let transport: any HTTPTransport

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom(parseISO8601)
        return d
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await send(request(path, method: "GET"))
    }

    func post<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
        var req = request(path, method: "POST")
        req.httpBody = try JSONEncoder().encode(body)
        return try await send(req)
    }

    private func request(_ path: String, method: String) -> URLRequest {
        var req = URLRequest(url: baseURL.appending(path: path), timeoutInterval: 15)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch {
            throw APIError(status: 0, code: "network_error", message: "Cannot reach the server")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let problem = try? Self.decoder.decode(Problem.self, from: data)
            let error = APIError(
                status: status,
                code: problem?.code ?? "http_\(status)",
                message: problem?.detail ?? "Request failed",
                requestID: problem?.requestId
            )
            Log.api.error("API \(status) \(error.code, privacy: .public) request=\(error.requestID ?? "-", privacy: .public)")
            throw error
        }
        return try Self.decoder.decode(T.self, from: data)
    }

    private struct Problem: Decodable {
        let code: String?
        let detail: String?
        let requestId: String?
    }
}

/// The backend sends dates like 2026-01-01T10:00:00.123456Z (microseconds) or without fractions.
private func parseISO8601(_ decoder: Decoder) throws -> Date {
    let text = try decoder.singleValueContainer().decode(String.self)
    if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) { return date }
    if let date = try? Date.ISO8601FormatStyle().parse(text) { return date }
    throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date: \(text)"))
}
