//
//  NetworkLogger.swift
//  FuekiWallet
//
//  Request/response logging for debugging
//

import Foundation
import os.log

/// Network request and response logger
public final class NetworkLogger {

    // MARK: - Properties

    private let enabled: Bool
    private let logger: Logger
    private let sensitiveHeaders: Set<String>
    private let maxDataLogSize: Int

    // MARK: - Initialization

    public init(
        enabled: Bool = true,
        maxDataLogSize: Int = 1024,
        sensitiveHeaders: Set<String> = ["Authorization", "X-API-Key", "X-Auth-Token"]
    ) {
        self.enabled = enabled
        self.maxDataLogSize = maxDataLogSize
        self.sensitiveHeaders = sensitiveHeaders

        #if DEBUG
        self.logger = Logger(subsystem: "io.fueki.wallet", category: "Network")
        #else
        self.logger = Logger(subsystem: "io.fueki.wallet", category: "Network")
        #endif
    }

    // MARK: - Public Methods

    /// Log HTTP request
    public func logRequest(_ request: URLRequest) {
        #if DEBUG
        guard enabled else { return }

        var logMessage = """

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        ➡️  REQUEST
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """

        // Method and URL
        if let method = request.httpMethod, let url = request.url {
            logMessage += "\n\(method) \(url.absoluteString)"
        }

        // Headers
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            logMessage += "\n\nHeaders:"
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                let displayValue = sensitiveHeaders.contains(key) ? "[REDACTED]" : value
                logMessage += "\n  \(key): \(displayValue)"
            }
        }

        // Body
        if let body = request.httpBody {
            logMessage += "\n\nBody:"
            logMessage += "\n\(prettyPrintedBody(body))"
        }

        logMessage += "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

        logger.debug("\(logMessage)")
        #endif
    }

    /// Log HTTP response
    public func logResponse(_ response: URLResponse, data: Data?) {
        #if DEBUG
        guard enabled else { return }

        var logMessage = """

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        ⬅️  RESPONSE
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """

        // Status code and URL
        if let httpResponse = response as? HTTPURLResponse {
            let statusEmoji = httpResponse.statusCode < 400 ? "✅" : "❌"
            logMessage += "\n\(statusEmoji) \(httpResponse.statusCode) - \(response.url?.absoluteString ?? "unknown")"

            // Headers
            if !httpResponse.allHeaderFields.isEmpty {
                logMessage += "\n\nHeaders:"
                for (key, value) in httpResponse.allHeaderFields.sorted(by: { "\($0.key)" < "\($1.key)" }) {
                    logMessage += "\n  \(key): \(value)"
                }
            }
        }

        // Response body
        if let data = data, !data.isEmpty {
            logMessage += "\n\nBody:"
            logMessage += "\n\(prettyPrintedBody(data))"
        }

        logMessage += "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

        logger.debug("\(logMessage)")
        #endif
    }

    /// Log network error
    public func logError(_ error: NetworkError, for request: URLRequest? = nil) {
        guard enabled else { return }

        var logMessage = """

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        ❌ NETWORK ERROR
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """

        if let request = request, let url = request.url {
            logMessage += "\nRequest: \(request.httpMethod ?? "GET") \(url.absoluteString)"
        }

        logMessage += "\nError: \(error.errorDescription ?? "Unknown error")"

        if let statusCode = error.statusCode {
            logMessage += "\nStatus Code: \(statusCode)"
        }

        logMessage += "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

        logger.error("\(logMessage)")
    }

    /// Log cache hit
    public func logCacheHit(endpoint: APIEndpoint) {
        #if DEBUG
        guard enabled else { return }
        logger.debug("💾 Cache HIT: \(endpoint.path)")
        #endif
    }

    /// Log retry attempt
    public func logRetry(attempt: Int, error: NetworkError, delay: TimeInterval) {
        #if DEBUG
        guard enabled else { return }
        logger.warning("🔄 Retry attempt \(attempt) after \(String(format: "%.2f", delay))s - Error: \(error.errorDescription ?? "unknown")")
        #endif
    }

    // MARK: - Private Methods

    private func prettyPrintedBody(_ data: Data) -> String {
        // Limit data size for logging
        let dataToLog = data.prefix(maxDataLogSize)

        // Try to parse as JSON for pretty printing
        if let json = try? JSONSerialization.jsonObject(with: dataToLog),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {

            if data.count > maxDataLogSize {
                return prettyString + "\n... (\(data.count - maxDataLogSize) bytes truncated)"
            }
            return prettyString
        }

        // Fallback to raw string
        if let string = String(data: dataToLog, encoding: .utf8) {
            if data.count > maxDataLogSize {
                return string + "\n... (\(data.count - maxDataLogSize) bytes truncated)"
            }
            return string
        }

        // Last resort: hex dump
        return dataToLog.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Performance Metrics
public extension NetworkLogger {
    /// Log performance metrics for a request
    func logPerformance(
        endpoint: APIEndpoint,
        duration: TimeInterval,
        dataSize: Int,
        fromCache: Bool
    ) {
        #if DEBUG
        guard enabled else { return }

        let throughput = Double(dataSize) / duration / 1024.0 // KB/s
        let source = fromCache ? "💾 Cache" : "🌐 Network"

        logger.info("""
        📊 Performance Metrics
           Endpoint: \(endpoint.path)
           Duration: \(String(format: "%.3f", duration))s
           Data Size: \(formatBytes(dataSize))
           Throughput: \(String(format: "%.2f", throughput)) KB/s
           Source: \(source)
        """)
        #endif
    }

    private func formatBytes(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024 {
            return String(format: "%.2f KB", kb)
        }
        let mb = kb / 1024.0
        return String(format: "%.2f MB", mb)
    }
}
