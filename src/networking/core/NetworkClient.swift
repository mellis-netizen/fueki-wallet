import Foundation
import Combine

/// Main network client for handling all API requests
final class NetworkClient: NSObject {

    // MARK: - Properties

    static let shared = NetworkClient()

    private let session: URLSession
    private let retryStrategy: RetryStrategy
    private let requestQueue: RequestQueue
    private let certificatePinner: CertificatePinner?
    private var activeRequests: [UUID: URLSessionDataTask] = [:]
    private let requestLock = NSLock()

    // MARK: - Configuration

    struct Configuration {
        let timeout: TimeInterval
        let maxRetries: Int
        let retryDelay: TimeInterval
        let enableSSLPinning: Bool
        let pinnedCertificates: [String: Data]
        let maxConcurrentRequests: Int

        static let `default` = Configuration(
            timeout: 30.0,
            maxRetries: 3,
            retryDelay: 1.0,
            enableSSLPinning: true,
            pinnedCertificates: [:],
            maxConcurrentRequests: 6
        )
    }

    private let configuration: Configuration

    // MARK: - Initialization

    init(configuration: Configuration = .default) {
        self.configuration = configuration
        self.retryStrategy = RetryStrategy(
            maxRetries: configuration.maxRetries,
            baseDelay: configuration.retryDelay
        )
        self.requestQueue = RequestQueue(maxConcurrent: configuration.maxConcurrentRequests)

        if configuration.enableSSLPinning {
            self.certificatePinner = CertificatePinner(
                certificates: configuration.pinnedCertificates
            )
        } else {
            self.certificatePinner = nil
        }

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        sessionConfig.waitsForConnectivity = true
        sessionConfig.requestCachePolicy = .returnCacheDataElseLoad
        sessionConfig.urlCache = URLCache.shared

        self.session = URLSession(
            configuration: sessionConfig,
            delegate: nil,
            delegateQueue: nil
        )

        super.init()

        if let pinner = certificatePinner {
            let sessionWithDelegate = URLSession(
                configuration: sessionConfig,
                delegate: self,
                delegateQueue: nil
            )
            // Note: In production, replace session with sessionWithDelegate
        }
    }

    // MARK: - Public API

    /// Execute a network request with async/await
    func execute<T: NetworkRequest>(_ request: T) async throws -> T.Response {
        // Check network reachability
        guard NetworkReachability.shared.isConnected else {
            throw NetworkError.noInternetConnection
        }

        let requestID = UUID()
        var urlRequest = try request.buildURLRequest()

        // Add authentication if required
        if request.requiresAuthentication {
            urlRequest = try await addAuthentication(to: urlRequest)
        }

        return try await withRetry(request: request, urlRequest: urlRequest, requestID: requestID)
    }

    /// Execute request and return Combine publisher
    func publisher<T: NetworkRequest>(for request: T) -> AnyPublisher<T.Response, Error> {
        Future { promise in
            Task {
                do {
                    let response = try await self.execute(request)
                    promise(.success(response))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// Cancel a specific request
    func cancel(requestID: UUID) {
        requestLock.lock()
        defer { requestLock.unlock() }

        activeRequests[requestID]?.cancel()
        activeRequests.removeValue(forKey: requestID)
    }

    /// Cancel all active requests
    func cancelAll() {
        requestLock.lock()
        defer { requestLock.unlock() }

        activeRequests.values.forEach { $0.cancel() }
        activeRequests.removeAll()
    }

    // MARK: - Private Methods

    private func withRetry<T: NetworkRequest>(
        request: T,
        urlRequest: URLRequest,
        requestID: UUID,
        attempt: Int = 0
    ) async throws -> T.Response {
        do {
            return try await performRequest(request: request, urlRequest: urlRequest, requestID: requestID)
        } catch let error as NetworkError {
            if error.isRetryable && attempt < configuration.maxRetries {
                let delay = retryStrategy.delay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await withRetry(
                    request: request,
                    urlRequest: urlRequest,
                    requestID: requestID,
                    attempt: attempt + 1
                )
            }
            throw error
        }
    }

    private func performRequest<T: NetworkRequest>(
        request: T,
        urlRequest: URLRequest,
        requestID: UUID
    ) async throws -> T.Response {
        let (data, response) = try await session.data(for: urlRequest)

        // Remove from active requests
        requestLock.lock()
        activeRequests.removeValue(forKey: requestID)
        requestLock.unlock()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // Handle HTTP errors
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { TimeInterval($0) }
                throw NetworkError.rateLimitExceeded(retryAfter: retryAfter)
            }
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        // Decode response
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.Response.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    private func addAuthentication(to request: URLRequest) async throws -> URLRequest {
        // TODO: Implement authentication token retrieval
        // For now, return request as-is
        var authenticatedRequest = request
        // authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return authenticatedRequest
    }
}

// MARK: - URLSessionDelegate for SSL Pinning

extension NetworkClient: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let pinner = certificatePinner else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if pinner.validate(challenge: challenge) {
            completionHandler(.useCredential, challenge.protectionSpace.serverTrust.map {
                URLCredential(trust: $0)
            })
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
