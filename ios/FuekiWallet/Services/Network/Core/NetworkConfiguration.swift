//
//  NetworkConfiguration.swift
//  FuekiWallet
//
//  Created by Backend API Developer
//

import Foundation

/// Network configuration for RPC clients
public struct NetworkConfiguration {
    // Timeout settings
    public let requestTimeout: TimeInterval
    public let resourceTimeout: TimeInterval

    // Retry configuration
    public let maxRetries: Int
    public let retryDelay: TimeInterval
    public let exponentialBackoff: Bool
    public let backoffMultiplier: Double

    // Connection pool
    public let maxConcurrentRequests: Int
    public let connectionPoolSize: Int

    // WebSocket configuration
    public let webSocketPingInterval: TimeInterval
    public let webSocketReconnectDelay: TimeInterval
    public let webSocketMaxReconnectAttempts: Int

    // Cache settings
    public let cachePolicy: URLRequest.CachePolicy
    public let cacheTTL: TimeInterval

    // Rate limiting
    public let rateLimitPerSecond: Int?
    public let burstLimit: Int?

    // Headers
    public let customHeaders: [String: String]

    // Logging
    public let enableLogging: Bool
    public let logLevel: LogLevel

    public enum LogLevel: Int {
        case none = 0
        case error = 1
        case warning = 2
        case info = 3
        case debug = 4
    }

    public init(
        requestTimeout: TimeInterval = 30.0,
        resourceTimeout: TimeInterval = 60.0,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 2.0,
        exponentialBackoff: Bool = true,
        backoffMultiplier: Double = 2.0,
        maxConcurrentRequests: Int = 10,
        connectionPoolSize: Int = 5,
        webSocketPingInterval: TimeInterval = 30.0,
        webSocketReconnectDelay: TimeInterval = 5.0,
        webSocketMaxReconnectAttempts: Int = 5,
        cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData,
        cacheTTL: TimeInterval = 300.0,
        rateLimitPerSecond: Int? = nil,
        burstLimit: Int? = nil,
        customHeaders: [String: String] = [:],
        enableLogging: Bool = true,
        logLevel: LogLevel = .info
    ) {
        self.requestTimeout = requestTimeout
        self.resourceTimeout = resourceTimeout
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.exponentialBackoff = exponentialBackoff
        self.backoffMultiplier = backoffMultiplier
        self.maxConcurrentRequests = maxConcurrentRequests
        self.connectionPoolSize = connectionPoolSize
        self.webSocketPingInterval = webSocketPingInterval
        self.webSocketReconnectDelay = webSocketReconnectDelay
        self.webSocketMaxReconnectAttempts = webSocketMaxReconnectAttempts
        self.cachePolicy = cachePolicy
        self.cacheTTL = cacheTTL
        self.rateLimitPerSecond = rateLimitPerSecond
        self.burstLimit = burstLimit
        self.customHeaders = customHeaders
        self.enableLogging = enableLogging
        self.logLevel = logLevel
    }

    public static let `default` = NetworkConfiguration()

    public static let production = NetworkConfiguration(
        requestTimeout: 30.0,
        maxRetries: 5,
        exponentialBackoff: true,
        maxConcurrentRequests: 20,
        connectionPoolSize: 10,
        enableLogging: false,
        logLevel: .error
    )

    public static let development = NetworkConfiguration(
        requestTimeout: 60.0,
        maxRetries: 3,
        enableLogging: true,
        logLevel: .debug
    )
}

/// Endpoint configuration with fallback support
public struct EndpointConfiguration {
    public let primaryURL: URL
    public let fallbackURLs: [URL]
    public let apiKey: String?
    public let requiresAuth: Bool

    public var allURLs: [URL] {
        [primaryURL] + fallbackURLs
    }

    public init(
        primaryURL: URL,
        fallbackURLs: [URL] = [],
        apiKey: String? = nil,
        requiresAuth: Bool = false
    ) {
        self.primaryURL = primaryURL
        self.fallbackURLs = fallbackURLs
        self.apiKey = apiKey
        self.requiresAuth = requiresAuth
    }
}
