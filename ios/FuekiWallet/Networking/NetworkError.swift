//
//  NetworkError.swift
//  FuekiWallet
//
//  Comprehensive error types for network operations
//

import Foundation

/// Comprehensive network error types
public enum NetworkError: Error, LocalizedError, Equatable {
    // Connection Errors
    case noConnection
    case timeout
    case connectionLost
    case cannotConnectToHost(String)

    // HTTP Errors
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case unauthorized
    case forbidden
    case notFound
    case serverError(statusCode: Int)
    case tooManyRequests(retryAfter: TimeInterval?)

    // Data Errors
    case invalidData
    case decodingError(Error)
    case encodingError(Error)
    case emptyResponse

    // Request Errors
    case invalidURL(String)
    case invalidRequest
    case cancelled
    case badRequest(String)

    // Security Errors
    case certificatePinningFailed
    case sslError(Error)
    case authenticationFailed
    case tokenExpired

    // Rate Limiting
    case rateLimitExceeded(retryAfter: TimeInterval)

    // Unknown
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        // Connection
        case .noConnection:
            return "No internet connection available"
        case .timeout:
            return "Request timed out"
        case .connectionLost:
            return "Connection was lost"
        case .cannotConnectToHost(let host):
            return "Cannot connect to host: \(host)"

        // HTTP
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code, _):
            return "HTTP error: \(code)"
        case .unauthorized:
            return "Unauthorized - authentication required"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .serverError(let code):
            return "Server error: \(code)"
        case .tooManyRequests(let retryAfter):
            if let retry = retryAfter {
                return "Too many requests. Retry after \(Int(retry)) seconds"
            }
            return "Too many requests"

        // Data
        case .invalidData:
            return "Invalid data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .emptyResponse:
            return "Empty response received"

        // Request
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidRequest:
            return "Invalid request configuration"
        case .cancelled:
            return "Request was cancelled"
        case .badRequest(let message):
            return "Bad request: \(message)"

        // Security
        case .certificatePinningFailed:
            return "Certificate pinning validation failed"
        case .sslError(let error):
            return "SSL error: \(error.localizedDescription)"
        case .authenticationFailed:
            return "Authentication failed"
        case .tokenExpired:
            return "Authentication token expired"

        // Rate Limiting
        case .rateLimitExceeded(let retryAfter):
            return "Rate limit exceeded. Retry after \(Int(retryAfter)) seconds"

        // Unknown
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .timeout, .connectionLost, .serverError, .tooManyRequests, .rateLimitExceeded:
            return true
        case .httpError(let code, _):
            return code >= 500 // Retry server errors
        default:
            return false
        }
    }

    public var statusCode: Int? {
        switch self {
        case .httpError(let code, _), .serverError(let code):
            return code
        case .unauthorized:
            return 401
        case .forbidden:
            return 403
        case .notFound:
            return 404
        case .tooManyRequests:
            return 429
        default:
            return nil
        }
    }

    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.noConnection, .noConnection),
             (.timeout, .timeout),
             (.connectionLost, .connectionLost),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.invalidData, .invalidData),
             (.emptyResponse, .emptyResponse),
             (.invalidRequest, .invalidRequest),
             (.cancelled, .cancelled),
             (.certificatePinningFailed, .certificatePinningFailed),
             (.authenticationFailed, .authenticationFailed),
             (.tokenExpired, .tokenExpired):
            return true
        case (.cannotConnectToHost(let lHost), .cannotConnectToHost(let rHost)):
            return lHost == rHost
        case (.httpError(let lCode, _), .httpError(let rCode, _)):
            return lCode == rCode
        case (.serverError(let lCode), .serverError(let rCode)):
            return lCode == rCode
        case (.invalidURL(let lUrl), .invalidURL(let rUrl)):
            return lUrl == rUrl
        case (.badRequest(let lMsg), .badRequest(let rMsg)):
            return lMsg == rMsg
        default:
            return false
        }
    }
}

// MARK: - URLError Mapping
extension NetworkError {
    static func from(urlError: URLError) -> NetworkError {
        switch urlError.code {
        case .notConnectedToInternet, .dataNotAllowed:
            return .noConnection
        case .timedOut:
            return .timeout
        case .networkConnectionLost:
            return .connectionLost
        case .cannotConnectToHost:
            return .cannotConnectToHost(urlError.failureURLString ?? "unknown")
        case .cancelled, .userCancelledAuthentication:
            return .cancelled
        case .serverCertificateUntrusted, .clientCertificateRejected:
            return .certificatePinningFailed
        case .secureConnectionFailed:
            return .sslError(urlError)
        default:
            return .unknown(urlError)
        }
    }
}
