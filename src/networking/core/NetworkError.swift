import Foundation

/// Comprehensive network error types
enum NetworkError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case encodingError(Error)
    case noInternetConnection
    case timeout
    case sslPinningFailed
    case cancelled
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case serverError(message: String)
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, _):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .noInternetConnection:
            return "No internet connection available"
        case .timeout:
            return "Request timed out"
        case .sslPinningFailed:
            return "SSL certificate validation failed"
        case .cancelled:
            return "Request was cancelled"
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limit exceeded. Retry after \(Int(retryAfter)) seconds"
            }
            return "Rate limit exceeded"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .timeout, .noInternetConnection, .httpError(let code, _):
            return code >= 500 || code == 429
        default:
            return false
        }
    }
}

/// Network request priority
enum RequestPriority: Int, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    static func < (lhs: RequestPriority, rhs: RequestPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
