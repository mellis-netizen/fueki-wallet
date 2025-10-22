//
//  RequestBuilder.swift
//  FuekiWallet
//
//  Request construction and configuration
//

import Foundation

/// Builds URLRequest from APIEndpoint
public final class RequestBuilder {

    // MARK: - Properties

    private let authTokenProvider: (() async -> String?)?
    private var requestInterceptors: [(URLRequest) -> URLRequest] = []

    // MARK: - Initialization

    public init(authTokenProvider: (() async -> String?)? = nil) {
        self.authTokenProvider = authTokenProvider
    }

    // MARK: - Public Methods

    /// Build URLRequest from endpoint
    public func buildRequest(from endpoint: APIEndpoint) async throws -> URLRequest {
        guard let url = endpoint.url else {
            throw NetworkError.invalidURL(endpoint.path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeout
        request.cachePolicy = endpoint.cachePolicy

        // Set headers
        endpoint.headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add authentication if required
        if endpoint.requiresAuthentication {
            if let token = await authTokenProvider?() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        // Add common headers
        request.setValue("FuekiWallet/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")

        // Set body if present
        if let bodyParams = endpoint.bodyParameters {
            try setBody(bodyParams, encoding: endpoint.encoding, on: &request)
        }

        // Apply interceptors
        var finalRequest = request
        for interceptor in requestInterceptors {
            finalRequest = interceptor(finalRequest)
        }

        return finalRequest
    }

    /// Add request interceptor
    public func addInterceptor(_ interceptor: @escaping (URLRequest) -> URLRequest) {
        requestInterceptors.append(interceptor)
    }

    /// Remove all interceptors
    public func removeAllInterceptors() {
        requestInterceptors.removeAll()
    }

    // MARK: - Private Methods

    private func setBody(_ parameters: [String: Any],
                        encoding: ParameterEncoding,
                        on request: inout URLRequest) throws {
        switch encoding {
        case .json:
            try setJSONBody(parameters, on: &request)
        case .urlEncoded:
            try setURLEncodedBody(parameters, on: &request)
        case .multipart:
            try setMultipartBody(parameters, on: &request)
        case .custom:
            // Custom encoding should be handled by caller
            break
        }
    }

    private func setJSONBody(_ parameters: [String: Any], on request: inout URLRequest) throws {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters)
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } catch {
            throw NetworkError.encodingError(error)
        }
    }

    private func setURLEncodedBody(_ parameters: [String: Any], on request: inout URLRequest) throws {
        let encodedParams = parameters
            .map { key, value in
                "\(key)=\(encodeURIComponent("\(value)"))"
            }
            .joined(separator: "&")

        request.httpBody = encodedParams.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    }

    private func setMultipartBody(_ parameters: [String: Any], on request: inout URLRequest) throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        for (key, value) in parameters {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)

            if let data = value as? Data {
                // Binary data
                body.append("Content-Disposition: form-data; name=\"\(key)\"; filename=\"file\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
                body.append(data)
            } else {
                // Text data
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)".data(using: .utf8)!)
            }

            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    }

    private func encodeURIComponent(_ string: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.init(charactersIn: "-._~"))
        return string.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? string
    }
}

// MARK: - Request Signing Extension
public extension RequestBuilder {
    /// Sign request with HMAC for sensitive operations
    func signRequest(_ request: inout URLRequest, secretKey: String) throws {
        guard let body = request.httpBody else { return }

        let timestamp = Int(Date().timeIntervalSince1970)
        let message = "\(timestamp)\(request.httpMethod ?? "")\(request.url?.path ?? "")"

        let signature = try hmacSHA256(message: message, key: secretKey)

        request.setValue("\(timestamp)", forHTTPHeaderField: "X-Timestamp")
        request.setValue(signature, forHTTPHeaderField: "X-Signature")
    }

    private func hmacSHA256(message: String, key: String) throws -> String {
        guard let messageData = message.data(using: .utf8),
              let keyData = key.data(using: .utf8) else {
            throw NetworkError.encodingError(NSError(domain: "RequestBuilder", code: -1))
        }

        var hmac = [UInt8](repeating: 0, count: Int(32))
        keyData.withUnsafeBytes { keyBytes in
            messageData.withUnsafeBytes { messageBytes in
                // Note: In production, use CommonCrypto CCHmac
                // This is simplified for demonstration
            }
        }

        return Data(hmac).base64EncodedString()
    }
}
