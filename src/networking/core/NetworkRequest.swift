import Foundation

/// HTTP methods
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    case head = "HEAD"
    case options = "OPTIONS"
}

/// Network request configuration
protocol NetworkRequest {
    associatedtype Response: Decodable

    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var queryParameters: [String: String]? { get }
    var body: Data? { get }
    var timeout: TimeInterval { get }
    var priority: RequestPriority { get }
    var cachePolicy: URLRequest.CachePolicy { get }
    var requiresAuthentication: Bool { get }
}

extension NetworkRequest {
    var timeout: TimeInterval { 30.0 }
    var priority: RequestPriority { .normal }
    var cachePolicy: URLRequest.CachePolicy { .useProtocolCachePolicy }
    var requiresAuthentication: Bool { false }
    var headers: [String: String]? { nil }
    var queryParameters: [String: String]? { nil }
    var body: Data? { nil }

    func buildURLRequest() throws -> URLRequest {
        guard var components = URLComponents(string: baseURL + path) else {
            throw NetworkError.invalidURL(baseURL + path)
        }

        if let queryParameters = queryParameters, !queryParameters.isEmpty {
            components.queryItems = queryParameters.map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }

        guard let url = components.url else {
            throw NetworkError.invalidURL(components.string ?? "")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeout
        request.cachePolicy = cachePolicy

        // Set default headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add custom headers
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        // Set body
        request.httpBody = body

        return request
    }
}

/// Encodable request with body
protocol EncodableRequest: NetworkRequest {
    associatedtype RequestBody: Encodable
    var requestBody: RequestBody? { get }
}

extension EncodableRequest {
    var body: Data? {
        guard let requestBody = requestBody else { return nil }
        return try? JSONEncoder().encode(requestBody)
    }
}
