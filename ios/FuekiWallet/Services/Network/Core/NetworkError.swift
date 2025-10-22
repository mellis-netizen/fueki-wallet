//
//  NetworkError.swift
//  FuekiWallet
//
//  Created by Backend API Developer
//

import Foundation

/// Comprehensive network error types for blockchain RPC operations
public enum NetworkError: Error, LocalizedError, Equatable {
    // Connection errors
    case noConnection
    case timeout
    case connectionLost
    case sslError(String)
    case dnsResolutionFailed

    // HTTP errors
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case serverError(statusCode: Int)

    // RPC errors
    case rpcError(code: Int, message: String, data: String?)
    case invalidRPCResponse
    case methodNotFound(String)
    case invalidParams(String)

    // Blockchain-specific errors
    case insufficientFunds
    case gasEstimationFailed
    case nonceError
    case transactionReverted(String?)
    case blockchainNotSupported

    // Data errors
    case invalidData
    case decodingError(String)
    case encodingError(String)
    case serializationError

    // Rate limiting
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case tooManyRequests

    // WebSocket errors
    case webSocketConnectionFailed
    case webSocketDisconnected
    case webSocketMessageError(String)

    // Retry errors
    case maxRetriesExceeded
    case allEndpointsFailed([String: Error])

    // Auth errors
    case unauthorized
    case forbidden
    case apiKeyInvalid

    // Unknown
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection available"
        case .timeout:
            return "Request timed out"
        case .connectionLost:
            return "Connection lost"
        case .sslError(let message):
            return "SSL error: \(message)"
        case .dnsResolutionFailed:
            return "DNS resolution failed"

        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message ?? "Unknown error")"
        case .serverError(let code):
            return "Server error: \(code)"

        case .rpcError(let code, let message, _):
            return "RPC error \(code): \(message)"
        case .invalidRPCResponse:
            return "Invalid RPC response format"
        case .methodNotFound(let method):
            return "RPC method not found: \(method)"
        case .invalidParams(let detail):
            return "Invalid RPC parameters: \(detail)"

        case .insufficientFunds:
            return "Insufficient funds for transaction"
        case .gasEstimationFailed:
            return "Gas estimation failed"
        case .nonceError:
            return "Invalid transaction nonce"
        case .transactionReverted(let reason):
            return "Transaction reverted: \(reason ?? "Unknown reason")"
        case .blockchainNotSupported:
            return "Blockchain not supported"

        case .invalidData:
            return "Invalid data received"
        case .decodingError(let detail):
            return "Decoding error: \(detail)"
        case .encodingError(let detail):
            return "Encoding error: \(detail)"
        case .serializationError:
            return "Serialization error"

        case .rateLimitExceeded(let retryAfter):
            if let retry = retryAfter {
                return "Rate limit exceeded. Retry after \(Int(retry)) seconds"
            }
            return "Rate limit exceeded"
        case .tooManyRequests:
            return "Too many requests"

        case .webSocketConnectionFailed:
            return "WebSocket connection failed"
        case .webSocketDisconnected:
            return "WebSocket disconnected"
        case .webSocketMessageError(let detail):
            return "WebSocket message error: \(detail)"

        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        case .allEndpointsFailed(let errors):
            return "All endpoints failed (\(errors.count) attempts)"

        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .apiKeyInvalid:
            return "Invalid API key"

        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .timeout, .connectionLost, .noConnection,
             .serverError, .rateLimitExceeded, .tooManyRequests:
            return true
        case .httpError(let code, _):
            return code >= 500 || code == 429
        default:
            return false
        }
    }

    public var retryDelay: TimeInterval {
        switch self {
        case .rateLimitExceeded(let retryAfter):
            return retryAfter ?? 60.0
        case .tooManyRequests:
            return 30.0
        case .timeout:
            return 5.0
        default:
            return 2.0
        }
    }
}
