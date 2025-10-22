//
//  ResponseHandler.swift
//  FuekiWallet
//
//  Response parsing and error handling
//

import Foundation

/// Response handler for parsing and validating HTTP responses
public final class ResponseHandler {

    // MARK: - Properties

    private let jsonDecoder: JSONDecoder
    private var responseInterceptors: [(Data, URLResponse) -> (Data, URLResponse)] = []

    // MARK: - Initialization

    public init(jsonDecoder: JSONDecoder = .init()) {
        self.jsonDecoder = jsonDecoder
        self.jsonDecoder.dateDecodingStrategy = .iso8601
        self.jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - Public Methods

    /// Handle response and decode to type T
    public func handle<T: Decodable>(_ response: (data: Data, response: URLResponse)) throws -> T {
        var (data, urlResponse) = response

        // Apply interceptors
        for interceptor in responseInterceptors {
            (data, urlResponse) = interceptor(data, urlResponse)
        }

        // Validate HTTP response
        try validateResponse(urlResponse, data: data)

        // Handle empty response
        if data.isEmpty {
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            throw NetworkError.emptyResponse
        }

        // Decode response
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            throw NetworkError.decodingError(decodingError)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    /// Handle response without decoding (returns raw data)
    public func handleRawData(_ response: (data: Data, response: URLResponse)) throws -> Data {
        var (data, urlResponse) = response

        // Apply interceptors
        for interceptor in responseInterceptors {
            (data, urlResponse) = interceptor(data, urlResponse)
        }

        try validateResponse(urlResponse, data: data)
        return data
    }

    /// Add response interceptor
    public func addInterceptor(_ interceptor: @escaping (Data, URLResponse) -> (Data, URLResponse)) {
        responseInterceptors.append(interceptor)
    }

    /// Remove all interceptors
    public func removeAllInterceptors() {
        responseInterceptors.removeAll()
    }

    // MARK: - Private Methods

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            // Success
            return

        case 400:
            throw NetworkError.badRequest(parseErrorMessage(from: data))

        case 401:
            throw NetworkError.unauthorized

        case 403:
            throw NetworkError.forbidden

        case 404:
            throw NetworkError.notFound

        case 429:
            let retryAfter = parseRetryAfter(from: httpResponse)
            throw NetworkError.tooManyRequests(retryAfter: retryAfter)

        case 500...599:
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)

        default:
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
    }

    private func parseErrorMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? String ?? json["error"] as? String else {
            return "Unknown error"
        }
        return message
    }

    private func parseRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        if let retryAfterString = response.value(forHTTPHeaderField: "Retry-After"),
           let retryAfter = TimeInterval(retryAfterString) {
            return retryAfter
        }
        return nil
    }
}

// MARK: - Empty Response Type
public struct EmptyResponse: Decodable {
    public init() {}
}

// MARK: - Standard Response Wrappers
public struct APIResponse<T: Decodable>: Decodable {
    public let success: Bool
    public let data: T?
    public let message: String?
    public let timestamp: Date?

    enum CodingKeys: String, CodingKey {
        case success
        case data
        case message
        case timestamp
    }
}

public struct PaginatedResponse<T: Decodable>: Decodable {
    public let data: [T]
    public let page: Int
    public let limit: Int
    public let total: Int
    public let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case data
        case page
        case limit
        case total
        case hasMore = "has_more"
    }
}

public struct ErrorResponse: Decodable {
    public let error: String
    public let message: String
    public let code: String?
    public let details: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case error
        case message
        case code
        case details
    }
}

// MARK: - AnyCodable for dynamic error details
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
