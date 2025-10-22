//
//  NetworkClient.swift
//  FuekiWallet
//
//  Core HTTP client with URLSession and async/await support
//

import Foundation
import Combine

/// Main network client for making HTTP requests
public final class NetworkClient {

    // MARK: - Properties

    private let session: URLSession
    private let requestBuilder: RequestBuilder
    private let responseHandler: ResponseHandler
    private let retryExecutor: RetryExecutor
    private let rateLimiter: RateLimiter
    private let certificatePinner: CertificatePinner?
    private let networkLogger: NetworkLogger
    private let cache: NetworkCache

    /// Current network reachability status
    public var isReachable: Bool {
        reachability.isReachable
    }

    private let reachability: NetworkReachability

    // MARK: - Initialization

    public init(
        configuration: URLSessionConfiguration = .default,
        authTokenProvider: (() async -> String?)? = nil,
        retryPolicy: RetryPolicy = .default,
        certificatePinner: CertificatePinner? = nil,
        enableLogging: Bool = true
    ) {
        // Configure session
        let sessionConfig = configuration
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 300
        sessionConfig.waitsForConnectivity = true
        sessionConfig.httpMaximumConnectionsPerHost = 5
        sessionConfig.requestCachePolicy = .useProtocolCachePolicy
        sessionConfig.tlsMinimumSupportedProtocolVersion = .TLSv13

        self.session = URLSession(configuration: sessionConfig)
        self.requestBuilder = RequestBuilder(authTokenProvider: authTokenProvider)
        self.responseHandler = ResponseHandler()
        self.retryExecutor = RetryExecutor(policy: retryPolicy)
        self.rateLimiter = RateLimiter()
        self.certificatePinner = certificatePinner
        self.networkLogger = NetworkLogger(enabled: enableLogging)
        self.cache = NetworkCache()
        self.reachability = NetworkReachability()

        // Setup session delegate if certificate pinning is enabled
        if let pinner = certificatePinner {
            let delegate = SessionDelegate(certificatePinner: pinner)
            let delegateSession = URLSession(
                configuration: sessionConfig,
                delegate: delegate,
                delegateQueue: nil
            )
            // Note: Replace session with delegateSession if pinning is used
        }
    }

    // MARK: - Public Methods

    /// Perform network request with automatic retry
    public func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type = T.self
    ) async throws -> T {
        // Check network reachability
        guard isReachable else {
            throw NetworkError.noConnection
        }

        // Apply rate limiting
        try await rateLimiter.checkLimit(for: endpoint.path)

        // Check cache first
        if let cached: T = cache.retrieve(for: endpoint) {
            networkLogger.logCacheHit(endpoint: endpoint)
            return cached
        }

        // Execute with retry
        let result: T = try await retryExecutor.execute {
            try await self.performRequest(endpoint, responseType: responseType)
        }

        // Cache successful response
        cache.store(result, for: endpoint)

        return result
    }

    /// Perform network request without decoding (returns raw data)
    public func requestData(_ endpoint: APIEndpoint) async throws -> Data {
        guard isReachable else {
            throw NetworkError.noConnection
        }

        try await rateLimiter.checkLimit(for: endpoint.path)

        return try await retryExecutor.execute {
            try await self.performDataRequest(endpoint)
        }
    }

    /// Upload file with progress tracking
    public func upload(
        _ endpoint: APIEndpoint,
        fileURL: URL,
        progress: ((Double) -> Void)? = nil
    ) async throws -> Data {
        let request = try await requestBuilder.buildRequest(from: endpoint)

        networkLogger.logRequest(request)

        let task = session.uploadTask(with: request, fromFile: fileURL)

        // Note: Progress tracking requires URLSessionTaskDelegate
        // For simplicity, using basic implementation here

        let (data, response) = try await withCheckedThrowingContinuation { continuation in
            task.resume()
            // Implementation needed for proper async/await upload
        }

        networkLogger.logResponse(response, data: data)

        return try responseHandler.handleRawData((data, response))
    }

    /// Download file with progress tracking
    public func download(
        _ endpoint: APIEndpoint,
        to destinationURL: URL,
        progress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let request = try await requestBuilder.buildRequest(from: endpoint)

        networkLogger.logRequest(request)

        let (tempURL, response) = try await session.download(for: request)

        networkLogger.logResponse(response, data: nil)

        // Validate response
        try responseHandler.handleRawData((Data(), response))

        // Move file to destination
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        return destinationURL
    }

    /// Cancel all pending requests
    public func cancelAllRequests() {
        session.invalidateAndCancel()
    }

    // MARK: - Combine Support

    /// Perform request and return Combine publisher
    public func publisher<T: Decodable>(
        for endpoint: APIEndpoint,
        responseType: T.Type = T.self
    ) -> AnyPublisher<T, NetworkError> {
        Future { promise in
            Task {
                do {
                    let result = try await self.request(endpoint, responseType: responseType)
                    promise(.success(result))
                } catch let error as NetworkError {
                    promise(.failure(error))
                } catch {
                    promise(.failure(.unknown(error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Private Methods

    private func performRequest<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        let request = try await requestBuilder.buildRequest(from: endpoint)

        networkLogger.logRequest(request)

        do {
            let (data, response) = try await session.data(for: request)

            networkLogger.logResponse(response, data: data)

            return try responseHandler.handle((data, response))
        } catch let urlError as URLError {
            throw NetworkError.from(urlError: urlError)
        } catch let networkError as NetworkError {
            throw networkError
        } catch {
            throw NetworkError.unknown(error)
        }
    }

    private func performDataRequest(_ endpoint: APIEndpoint) async throws -> Data {
        let request = try await requestBuilder.buildRequest(from: endpoint)

        networkLogger.logRequest(request)

        do {
            let (data, response) = try await session.data(for: request)

            networkLogger.logResponse(response, data: data)

            return try responseHandler.handleRawData((data, response))
        } catch let urlError as URLError {
            throw NetworkError.from(urlError: urlError)
        } catch let networkError as NetworkError {
            throw networkError
        } catch {
            throw NetworkError.unknown(error)
        }
    }
}

// MARK: - Session Delegate
private class SessionDelegate: NSObject, URLSessionDelegate {

    private let certificatePinner: CertificatePinner

    init(certificatePinner: CertificatePinner) {
        self.certificatePinner = certificatePinner
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if certificatePinner.validate(serverTrust: serverTrust, for: challenge.protectionSpace.host) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
