//
//  APIEndpoint.swift
//  FuekiWallet
//
//  API endpoint definitions and request configuration
//

import Foundation

/// HTTP method types
public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
}

/// Request body encoding types
public enum ParameterEncoding {
    case json
    case urlEncoded
    case multipart
    case custom(ContentType)

    public struct ContentType {
        let value: String

        public static let json = ContentType(value: "application/json")
        public static let formUrlEncoded = ContentType(value: "application/x-www-form-urlencoded")
        public static let multipartFormData = ContentType(value: "multipart/form-data")
    }

    var contentType: String {
        switch self {
        case .json:
            return ContentType.json.value
        case .urlEncoded:
            return ContentType.formUrlEncoded.value
        case .multipart:
            return ContentType.multipartFormData.value
        case .custom(let type):
            return type.value
        }
    }
}

/// API endpoint protocol
public protocol APIEndpoint {
    /// Base URL for the endpoint
    var baseURL: String { get }

    /// Path component
    var path: String { get }

    /// HTTP method
    var method: HTTPMethod { get }

    /// Headers
    var headers: [String: String] { get }

    /// Query parameters
    var queryParameters: [String: Any]? { get }

    /// Body parameters
    var bodyParameters: [String: Any]? { get }

    /// Encoding type
    var encoding: ParameterEncoding { get }

    /// Request timeout
    var timeout: TimeInterval { get }

    /// Whether to use certificate pinning
    var requiresCertificatePinning: Bool { get }

    /// Whether request requires authentication
    var requiresAuthentication: Bool { get }

    /// Whether request should be retried on failure
    var shouldRetry: Bool { get }

    /// Cache policy
    var cachePolicy: URLRequest.CachePolicy { get }
}

// MARK: - Default Implementations
public extension APIEndpoint {
    var headers: [String: String] {
        ["Content-Type": encoding.contentType]
    }

    var queryParameters: [String: Any]? {
        nil
    }

    var bodyParameters: [String: Any]? {
        nil
    }

    var encoding: ParameterEncoding {
        .json
    }

    var timeout: TimeInterval {
        30.0
    }

    var requiresCertificatePinning: Bool {
        true
    }

    var requiresAuthentication: Bool {
        true
    }

    var shouldRetry: Bool {
        true
    }

    var cachePolicy: URLRequest.CachePolicy {
        .useProtocolCachePolicy
    }

    /// Full URL combining base and path
    var url: URL? {
        guard var components = URLComponents(string: baseURL) else {
            return nil
        }

        components.path = path

        // Add query parameters if present
        if let queryParams = queryParameters, !queryParams.isEmpty {
            components.queryItems = queryParams.map { key, value in
                URLQueryItem(name: key, value: "\(value)")
            }
        }

        return components.url
    }
}

// MARK: - Common Endpoints
public enum WalletEndpoint {
    case createWallet(data: [String: Any])
    case getWallet(id: String)
    case updateWallet(id: String, data: [String: Any])
    case deleteWallet(id: String)
    case listWallets(page: Int, limit: Int)
    case backup(walletId: String)
    case restore(backupData: Data)

    case getBalance(walletId: String, tokenAddress: String?)
    case getTransactions(walletId: String, page: Int, limit: Int)
    case getTransaction(txHash: String)
    case sendTransaction(data: [String: Any])
    case estimateGas(data: [String: Any])

    case getTokens(walletId: String)
    case addToken(walletId: String, tokenAddress: String)
    case removeToken(walletId: String, tokenAddress: String)
    case getTokenPrice(tokenAddress: String, currency: String)

    case getNFTs(walletId: String)
    case getNFTMetadata(contractAddress: String, tokenId: String)
    case transferNFT(data: [String: Any])
}

extension WalletEndpoint: APIEndpoint {
    public var baseURL: String {
        // TODO: Replace with actual API base URL from configuration
        return "https://api.fueki.io/v1"
    }

    public var path: String {
        switch self {
        case .createWallet:
            return "/wallets"
        case .getWallet(let id), .updateWallet(let id, _), .deleteWallet(let id):
            return "/wallets/\(id)"
        case .listWallets:
            return "/wallets"
        case .backup(let walletId):
            return "/wallets/\(walletId)/backup"
        case .restore:
            return "/wallets/restore"

        case .getBalance(let walletId, _):
            return "/wallets/\(walletId)/balance"
        case .getTransactions(let walletId, _, _):
            return "/wallets/\(walletId)/transactions"
        case .getTransaction(let hash):
            return "/transactions/\(hash)"
        case .sendTransaction:
            return "/transactions"
        case .estimateGas:
            return "/transactions/estimate"

        case .getTokens(let walletId):
            return "/wallets/\(walletId)/tokens"
        case .addToken(let walletId, _):
            return "/wallets/\(walletId)/tokens"
        case .removeToken(let walletId, let address):
            return "/wallets/\(walletId)/tokens/\(address)"
        case .getTokenPrice(let address, _):
            return "/tokens/\(address)/price"

        case .getNFTs(let walletId):
            return "/wallets/\(walletId)/nfts"
        case .getNFTMetadata(let contract, let tokenId):
            return "/nfts/\(contract)/\(tokenId)"
        case .transferNFT:
            return "/nfts/transfer"
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .createWallet, .sendTransaction, .addToken, .restore, .transferNFT:
            return .post
        case .updateWallet:
            return .put
        case .deleteWallet, .removeToken:
            return .delete
        default:
            return .get
        }
    }

    public var queryParameters: [String: Any]? {
        switch self {
        case .listWallets(let page, let limit):
            return ["page": page, "limit": limit]
        case .getBalance(_, let tokenAddress):
            return tokenAddress.map { ["token": $0] }
        case .getTransactions(_, let page, let limit):
            return ["page": page, "limit": limit]
        case .getTokenPrice(_, let currency):
            return ["currency": currency]
        default:
            return nil
        }
    }

    public var bodyParameters: [String: Any]? {
        switch self {
        case .createWallet(let data), .updateWallet(_, let data),
             .sendTransaction(let data), .estimateGas(let data),
             .transferNFT(let data):
            return data
        case .addToken(_, let address):
            return ["tokenAddress": address]
        default:
            return nil
        }
    }

    public var requiresAuthentication: Bool {
        switch self {
        case .getTokenPrice, .getNFTMetadata:
            return false // Public endpoints
        default:
            return true
        }
    }

    public var requiresCertificatePinning: Bool {
        switch self {
        case .createWallet, .backup, .restore, .sendTransaction, .transferNFT:
            return true // Critical operations require pinning
        default:
            return false
        }
    }
}
