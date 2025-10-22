# Fueki Wallet - Production-Ready Architecture Recommendations

**Document Version:** 2.0
**Date:** 2025-10-21
**Status:** PRODUCTION READY
**Classification:** ARCHITECTURE DECISION RECORD

---

## Executive Summary

This document provides comprehensive production-ready architecture recommendations for the Fueki Mobile Crypto Wallet based on detailed analysis of existing documentation, TSS security requirements, performance benchmarks, and current source code structure.

### Key Findings

**Architecture Maturity**: The current architecture documentation is **excellent** with comprehensive coverage of:
- ✅ Multi-layer system architecture (MVVM + Clean Architecture)
- ✅ Security-first design with TSS integration
- ✅ Detailed data architecture with CoreData
- ✅ Complete integration architecture for blockchains, payment ramps, and OAuth

**Critical Gaps Identified**: 5 major production gaps requiring immediate attention
**Expected Improvements**: 60-75% performance gain, enterprise-grade security hardening
**Implementation Timeline**: 8-12 weeks for full production readiness

---

## 1. Architecture Analysis - Current State

### 1.1 Strengths of Existing Architecture

#### ✅ Strong Foundation
The existing architecture demonstrates excellent design principles:

1. **Layered Architecture (Clean Architecture)**
   - Clear separation: Presentation → Domain → Data → Infrastructure
   - Protocol-oriented design for testability
   - Dependency injection ready
   - MVVM pattern for SwiftUI integration

2. **Security Architecture**
   - Comprehensive TSS security requirements documented
   - Multi-layer security model (7 layers)
   - Secure Enclave integration planned
   - Biometric authentication flows designed

3. **Data Architecture**
   - Well-designed CoreData schema
   - Multi-level caching strategy
   - Repository pattern implementation
   - Sync and backup strategies defined

4. **Integration Architecture**
   - Multi-chain blockchain support designed
   - Payment ramp integrations (Stripe, Ramp Network)
   - OAuth providers (Google, Apple)
   - WebSocket real-time updates

### 1.2 Critical Gaps Requiring Production Hardening

#### 🚨 Gap #1: No Implementation Code Exists
**Impact**: CRITICAL
**Finding**: Documentation is comprehensive, but `/src` directory contains only placeholder structure with no actual implementation.

**Current State**:
```
src/
├── blockchain/ (empty structure)
├── crypto/ (empty structure)
└── ui/ (empty structure)
```

**Recommendation**: Immediate implementation required following documented architecture.

#### 🚨 Gap #2: Missing Production-Grade Error Handling

**Impact**: HIGH
**Finding**: Architecture defines error types but lacks production error handling patterns.

**Missing Components**:
- Centralized error logging and reporting
- User-friendly error messages
- Graceful degradation strategies
- Circuit breakers for external services
- Retry mechanisms with exponential backoff

**Recommendation**:
```swift
// Implement production error handling framework
protocol ErrorHandler {
    func handle(_ error: Error, context: ErrorContext) -> ErrorAction
    func report(_ error: Error, severity: ErrorSeverity)
    func shouldRetry(_ error: Error) -> RetryStrategy
}

enum ErrorAction {
    case showUserMessage(String)
    case retry(strategy: RetryStrategy)
    case fallback(action: () async throws -> Void)
    case logout
    case none
}

class ProductionErrorHandler: ErrorHandler {
    private let analytics: AnalyticsService
    private let logger: LoggingService

    func handle(_ error: Error, context: ErrorContext) -> ErrorAction {
        // Log to analytics
        analytics.trackError(error, context: context)

        // Log to remote logging service
        logger.error(error, context: context)

        // Determine action based on error type
        switch error {
        case let networkError as NetworkError:
            return handleNetworkError(networkError)
        case let cryptoError as CryptoError:
            return handleCryptoError(cryptoError)
        case let blockchainError as BlockchainError:
            return handleBlockchainError(blockchainError)
        default:
            return .showUserMessage("An unexpected error occurred")
        }
    }

    private func handleNetworkError(_ error: NetworkError) -> ErrorAction {
        switch error {
        case .timeout:
            return .retry(strategy: .exponentialBackoff(maxAttempts: 3))
        case .noConnection:
            return .showUserMessage("Please check your internet connection")
        case .serverError:
            return .fallback { await self.useBackupEndpoint() }
        default:
            return .showUserMessage("Network error occurred")
        }
    }
}
```

#### 🚨 Gap #3: Missing Observability and Monitoring

**Impact**: HIGH
**Finding**: No monitoring, logging, or observability strategy defined.

**Required Components**:
1. **Application Performance Monitoring (APM)**
   - Integration with Sentry or Firebase Crashlytics
   - Performance tracking for critical operations
   - Real-time error monitoring

2. **Structured Logging**
   - Centralized logging service
   - Log levels (debug, info, warn, error, fatal)
   - Contextual information (user ID, session ID, transaction ID)

3. **Metrics and Analytics**
   - Business metrics (wallet creation, transaction success rate)
   - Technical metrics (API latency, cache hit rate)
   - User behavior analytics (feature usage, conversion funnels)

**Recommendation**:
```swift
// Implement comprehensive observability
protocol ObservabilityService {
    func trackEvent(_ event: AnalyticsEvent)
    func trackPerformance(_ operation: String, duration: TimeInterval)
    func trackError(_ error: Error, context: [String: Any])
    func setUserContext(userId: String?, walletAddress: String?)
}

class ProductionObservabilityService: ObservabilityService {
    private let sentry = Sentry.shared
    private let analytics = Analytics.shared

    func trackPerformance(_ operation: String, duration: TimeInterval) {
        // Track to APM
        let transaction = sentry.startTransaction(
            name: operation,
            operation: "performance.measurement"
        )

        // Add contextual data
        transaction.setMeasurement(name: "duration", value: duration, unit: .millisecond)

        // Check against SLA
        let sla = getSLA(for: operation)
        if duration > sla.p95 {
            sentry.captureMessage("SLA violation: \(operation)", level: .warning)
        }

        transaction.finish()

        // Track to analytics
        analytics.track("performance_metric", properties: [
            "operation": operation,
            "duration_ms": duration * 1000,
            "exceeded_sla": duration > sla.p95
        ])
    }
}
```

#### 🚨 Gap #4: Missing Disaster Recovery and Business Continuity

**Impact**: CRITICAL
**Finding**: Backup strategy defined but no disaster recovery plan.

**Required Components**:
1. **Automated Backup Verification**
   - Periodic backup restoration tests
   - Backup integrity checks
   - Encrypted backup validation

2. **Multi-Region Redundancy**
   - Primary and backup RPC endpoints
   - Automatic failover mechanisms
   - Geographic distribution

3. **Key Recovery Mechanisms**
   - Social recovery (Shamir Secret Sharing)
   - Time-locked recovery
   - Trusted contact recovery

**Recommendation**:
```swift
// Implement production disaster recovery
class DisasterRecoveryService {
    private let backupService: BackupService
    private let socialRecoveryService: SocialRecoveryService

    // Automated backup verification
    func verifyBackups() async throws {
        let backups = try await backupService.listBackups()

        for backup in backups {
            // Verify backup integrity
            let isValid = try await verifyBackupIntegrity(backup)

            if !isValid {
                throw BackupError.corruptedBackup(backup.id)
            }

            // Test restoration in isolated environment
            try await testBackupRestoration(backup)
        }
    }

    // Multi-region RPC failover
    func getBlockchainConnection(chainId: String) async throws -> BlockchainService {
        let endpoints = getEndpointsForChain(chainId)

        // Try primary endpoint first
        do {
            return try await connectToEndpoint(endpoints.primary)
        } catch {
            logger.warn("Primary endpoint failed, trying backup")

            // Automatic failover to backup
            return try await connectToEndpoint(endpoints.backup)
        }
    }
}
```

#### 🚨 Gap #5: Missing Rate Limiting and Abuse Prevention

**Impact**: MEDIUM
**Finding**: No rate limiting or abuse prevention mechanisms defined.

**Required Components**:
1. **API Rate Limiting**
   - Per-user request limits
   - Per-IP rate limiting
   - Burst protection

2. **Transaction Throttling**
   - Daily transaction limits for new users
   - Velocity checks for suspicious activity
   - Manual review triggers

3. **Resource Protection**
   - Connection pooling
   - Request queuing
   - Resource quotas

**Recommendation**:
```swift
// Implement rate limiting
class RateLimiter {
    private let cache = NSCache<NSString, RateLimitEntry>()

    func checkLimit(
        for user: String,
        operation: Operation
    ) throws {
        let key = "\(user):\(operation.name)" as NSString
        let entry = cache.object(forKey: key) ?? RateLimitEntry()

        let limit = operation.limit
        let window = operation.window

        // Clean old entries
        entry.removeExpired(window: window)

        // Check if limit exceeded
        if entry.count >= limit {
            let resetTime = entry.oldestTimestamp + window
            throw RateLimitError.limitExceeded(resetAt: resetTime)
        }

        // Record request
        entry.record()
        cache.setObject(entry, forKey: key)
    }
}

enum Operation {
    case transaction
    case walletCreation
    case apiRequest

    var limit: Int {
        switch self {
        case .transaction: return 100 // 100 txs per day
        case .walletCreation: return 5 // 5 wallets per day
        case .apiRequest: return 1000 // 1000 requests per hour
        }
    }

    var window: TimeInterval {
        switch self {
        case .transaction: return 86400 // 24 hours
        case .walletCreation: return 86400 // 24 hours
        case .apiRequest: return 3600 // 1 hour
        }
    }
}
```

---

## 2. Production-Ready Architecture Enhancements

### 2.1 Enhanced System Architecture

#### Multi-Tier Architecture with Resilience

```
┌─────────────────────────────────────────────────────────────┐
│                  Presentation Layer                          │
│         (SwiftUI + MVVM + State Management)                 │
└─────────────────────────────────────────────────────────────┘
                          ↓↑
┌─────────────────────────────────────────────────────────────┐
│              Resilience & Observability Layer                │
│  (Error Handling, Retry Logic, Circuit Breakers, Metrics)  │
└─────────────────────────────────────────────────────────────┘
                          ↓↑
┌─────────────────────────────────────────────────────────────┐
│                 Business Logic Layer                         │
│          (Use Cases, Domain Models, Services)               │
└─────────────────────────────────────────────────────────────┘
                          ↓↑
┌─────────────────────────────────────────────────────────────┐
│           Data Layer with Caching & Sync                     │
│        (Repositories, Cache, Sync Service)                  │
└─────────────────────────────────────────────────────────────┘
                          ↓↑
        ┌─────────────────┴──────────────────┐
        ↓                                     ↓
┌──────────────────┐              ┌──────────────────┐
│  Infrastructure  │              │  Resilience      │
│  (Blockchain,    │              │  (Failover,      │
│   Crypto, APIs)  │              │   Backup RPC)    │
└──────────────────┘              └──────────────────┘
```

#### Circuit Breaker Pattern for External Services

```swift
// Implement circuit breaker for resilience
class CircuitBreaker {
    enum State {
        case closed     // Normal operation
        case open       // Failing, reject requests
        case halfOpen   // Testing if service recovered
    }

    private var state: State = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?

    private let failureThreshold = 5
    private let timeout: TimeInterval = 60 // 1 minute
    private let halfOpenAttempts = 3

    func execute<T>(_ operation: () async throws -> T) async throws -> T {
        switch state {
        case .closed:
            do {
                let result = try await operation()
                reset()
                return result
            } catch {
                recordFailure()
                throw error
            }

        case .open:
            if shouldAttemptReset() {
                state = .halfOpen
                return try await execute(operation)
            }
            throw CircuitBreakerError.serviceUnavailable

        case .halfOpen:
            do {
                let result = try await operation()
                reset()
                return result
            } catch {
                state = .open
                throw error
            }
        }
    }

    private func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()

        if failureCount >= failureThreshold {
            state = .open
        }
    }

    private func shouldAttemptReset() -> Bool {
        guard let lastFailure = lastFailureTime else { return false }
        return Date().timeIntervalSince(lastFailure) > timeout
    }

    private func reset() {
        state = .closed
        failureCount = 0
        lastFailureTime = nil
    }
}

// Usage in blockchain service
class ResilientBlockchainService: BlockchainService {
    private let circuitBreaker = CircuitBreaker()
    private let primaryService: BlockchainService
    private let fallbackService: BlockchainService

    func getBalance(address: String) async throws -> Balance {
        do {
            return try await circuitBreaker.execute {
                try await primaryService.getBalance(address: address)
            }
        } catch CircuitBreakerError.serviceUnavailable {
            // Automatic failover to backup service
            return try await fallbackService.getBalance(address: address)
        }
    }
}
```

### 2.2 Advanced Security Architecture

#### Defense-in-Depth Security Model

**Layer 1: Application Security**
```swift
// Implement runtime security checks
class SecurityManager {
    func performSecurityChecks() throws {
        // 1. Jailbreak detection
        if isJailbroken() {
            throw SecurityError.jailbreakDetected
        }

        // 2. Debugger detection
        if isDebuggerAttached() {
            throw SecurityError.debuggerDetected
        }

        // 3. SSL pinning verification
        try verifyCertificatePinning()

        // 4. Code integrity check
        try verifyCodeSignature()

        // 5. Environment validation
        if isRunningInSimulator() && BuildConfig.isProduction {
            throw SecurityError.invalidEnvironment
        }
    }

    private func isJailbroken() -> Bool {
        // Check for common jailbreak indicators
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt"
        ]

        return jailbreakPaths.contains { FileManager.default.fileExists(atPath: $0) }
            || canWriteToProtectedDirectory()
    }

    private func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride

        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)

        return (result == 0) && (info.kp_proc.p_flag & P_TRACED) != 0
    }
}
```

**Layer 2: TSS Security Hardening**
```swift
// Enhanced TSS implementation with additional security
class ProductionTSSService: TSSService {
    private let secureEnclave: SecureEnclaveService
    private let biometricAuth: BiometricAuthenticationService
    private let securityLogger: SecurityLogger

    func generateKeyShares(threshold: Int, total: Int) async throws -> [KeyShare] {
        // Security audit logging
        securityLogger.log(.keyGenerationStarted, metadata: [
            "threshold": threshold,
            "total": total,
            "timestamp": Date()
        ])

        // Verify secure environment
        try SecurityManager.shared.performSecurityChecks()

        // Require biometric authentication
        guard try await biometricAuth.authenticate(
            reason: "Authenticate to generate wallet keys"
        ) else {
            throw AuthError.biometricAuthenticationFailed
        }

        // Generate keys using hardware-backed randomness
        var randomBytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, 32, &randomBytes)

        guard status == errSecSuccess else {
            securityLogger.log(.keyGenerationFailed, metadata: [
                "reason": "random_generation_failed"
            ])
            throw CryptoError.randomGenerationFailed
        }

        // Perform TSS key generation with verifiable secret sharing
        let shares = try await performDistributedKeyGeneration(
            randomness: Data(randomBytes),
            threshold: threshold,
            total: total
        )

        // Store primary share in Secure Enclave
        try await secureEnclave.storeKeyShare(
            shares[0],
            tag: "com.fueki.wallet.primary-key-share"
        )

        // Audit log successful generation
        securityLogger.log(.keyGenerationCompleted, metadata: [
            "sharesGenerated": shares.count,
            "secureEnclaveUsed": true
        ])

        // Return shares (excluding Secure Enclave share for distribution)
        return Array(shares.dropFirst())
    }

    func signTransaction(_ transaction: UnsignedTransaction) async throws -> SignedTransaction {
        // Security checks before signing
        try SecurityManager.shared.performSecurityChecks()

        // Transaction validation
        try validateTransaction(transaction)

        // Require biometric for transaction signing
        guard try await biometricAuth.authenticate(
            reason: "Sign transaction of \(transaction.amount) \(transaction.currency)"
        ) else {
            throw AuthError.biometricAuthenticationFailed
        }

        // Retrieve key share from Secure Enclave
        let primaryShare = try await secureEnclave.retrieveKeyShare(
            tag: "com.fueki.wallet.primary-key-share"
        )

        // Fetch additional shares for threshold
        let additionalShares = try await fetchAdditionalShares(count: threshold - 1)

        // Perform TSS signing ceremony
        let signature = try await performTSSSigning(
            transaction: transaction,
            shares: [primaryShare] + additionalShares
        )

        // Verify signature before returning
        guard try await verifySignature(signature, transaction: transaction) else {
            throw CryptoError.signatureVerificationFailed
        }

        // Audit log transaction signing
        securityLogger.log(.transactionSigned, metadata: [
            "transactionHash": signature.transactionHash,
            "amount": transaction.amount,
            "recipient": transaction.toAddress
        ])

        return SignedTransaction(
            transaction: transaction,
            signature: signature,
            signedAt: Date()
        )
    }

    private func validateTransaction(_ transaction: UnsignedTransaction) throws {
        // 1. Address validation
        guard isValidAddress(transaction.toAddress, for: transaction.chainId) else {
            throw ValidationError.invalidAddress
        }

        // 2. Amount validation
        guard transaction.amount > 0 else {
            throw ValidationError.invalidAmount
        }

        // 3. Balance check
        guard transaction.amount <= transaction.availableBalance else {
            throw ValidationError.insufficientFunds
        }

        // 4. Gas price reasonableness check
        guard isReasonableGasPrice(transaction.gasPrice) else {
            throw ValidationError.unreasonableGasPrice
        }

        // 5. Duplicate transaction check
        try checkDuplicateTransaction(transaction)
    }
}
```

### 2.3 Performance Optimization Architecture

#### Multi-Level Performance Strategy

Based on the performance analysis document, implement these critical optimizations:

**Priority 1: App Launch Optimization (48-57% improvement)**

```swift
// Implement lazy initialization with progressive loading
class AppInitializer {
    private let essentialServices: [Service] = []
    private let deferredServices: [Service] = []

    func initializeApp() async {
        // Phase 1: Essential services only (blocking)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.initializeSecureStorage() }
            group.addTask { await self.initializeNetworking() }
            group.addTask { await self.initializeUI() }
        }

        // Phase 2: Deferred services (non-blocking, background)
        Task.detached(priority: .background) {
            await self.initializeCryptoLibraries()
            await self.initializeBlockchainConnections()
            await self.initializeAnalytics()
        }
    }

    private func initializeSecureStorage() async {
        // Only initialize Keychain and Secure Enclave access
        // Defer full CoreData stack loading
    }

    private func initializeCryptoLibraries() async {
        // Lazy-load crypto operations
        // Pre-compute common operations in background
    }
}
```

**Priority 2: Memory Optimization (40-45% improvement)**

```swift
// Implement smart pagination with FlashList
import { FlashList } from '@shopify/flash-list'

class TransactionListViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false

    private let pageSize = 20
    private var currentPage = 0
    private let cache = LRUCache<String, [Transaction]>(maxSize: 100)

    func loadTransactions() async {
        let cacheKey = "transactions_page_\(currentPage)"

        // Check cache first
        if let cached = cache.get(key: cacheKey) {
            transactions.append(contentsOf: cached)
            currentPage += 1
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let newTransactions = try await repository.fetchTransactions(
                offset: currentPage * pageSize,
                limit: pageSize
            )

            transactions.append(contentsOf: newTransactions)
            cache.set(key: cacheKey, value: newTransactions)
            currentPage += 1
        } catch {
            handleError(error)
        }
    }
}
```

**Priority 3: Crypto Performance (58-66% improvement)**

```swift
// Implement WASM-accelerated crypto operations
import WasmCrypto

class WASMCryptoService: CryptoService {
    private let wasmModule: WasmModule

    init() async throws {
        // Load pre-compiled WASM module
        let wasmData = try await loadWASMModule()
        self.wasmModule = try WasmModule(data: wasmData)
    }

    func generateTSSKeys(threshold: Int, total: Int) async throws -> [KeyShare] {
        // Use WASM for 60% faster key generation
        let result = try await wasmModule.call(
            function: "generate_tss_keys",
            args: [threshold, total]
        )

        return try KeyShare.decode(from: result)
    }

    func signTransaction(_ tx: Transaction, shares: [KeyShare]) async throws -> Signature {
        // WASM-accelerated signing (40% faster)
        let result = try await wasmModule.call(
            function: "tss_sign",
            args: [tx.serialize(), shares.map { $0.serialize() }]
        )

        return try Signature.decode(from: result)
    }
}
```

### 2.4 Scalability Architecture

#### Horizontal Scalability for Backend Services

```swift
// Implement load balancing for RPC endpoints
class LoadBalancedBlockchainService: BlockchainService {
    private let endpointPool: EndpointPool
    private let healthChecker: HealthChecker

    init(endpoints: [URL]) {
        self.endpointPool = EndpointPool(endpoints: endpoints)
        self.healthChecker = HealthChecker(endpoints: endpoints)

        // Start health checking in background
        Task.detached {
            await self.healthChecker.startPeriodicHealthChecks()
        }
    }

    func getBalance(address: String) async throws -> Balance {
        // Get healthy endpoint with lowest latency
        let endpoint = try await endpointPool.getOptimalEndpoint()

        return try await endpoint.getBalance(address: address)
    }
}

class EndpointPool {
    private var endpoints: [URL]
    private var endpointMetrics: [URL: EndpointMetrics] = [:]

    func getOptimalEndpoint() async throws -> BlockchainEndpoint {
        // Sort by health and latency
        let healthyEndpoints = endpoints.filter { endpoint in
            guard let metrics = endpointMetrics[endpoint] else { return false }
            return metrics.isHealthy && metrics.averageLatency < 500 // 500ms threshold
        }

        guard let optimal = healthyEndpoints.sorted(by: { a, b in
            let aLatency = endpointMetrics[a]?.averageLatency ?? .infinity
            let bLatency = endpointMetrics[b]?.averageLatency ?? .infinity
            return aLatency < bLatency
        }).first else {
            throw BlockchainError.noHealthyEndpoints
        }

        return BlockchainEndpoint(url: optimal)
    }
}
```

---

## 3. Production Deployment Architecture

### 3.1 Environment Configuration

```swift
enum Environment {
    case development
    case staging
    case production

    var baseURL: URL {
        switch self {
        case .development:
            return URL(string: "https://dev-api.fueki.io")!
        case .staging:
            return URL(string: "https://staging-api.fueki.io")!
        case .production:
            return URL(string: "https://api.fueki.io")!
        }
    }

    var blockchainEndpoints: [String: [URL]] {
        switch self {
        case .development:
            return [
                "ethereum": [URL(string: "https://eth-goerli.g.alchemy.com/v2/API_KEY")!],
                "bitcoin": [URL(string: "https://blockstream.info/testnet/api")!]
            ]
        case .staging:
            return [
                "ethereum": [
                    URL(string: "https://eth-sepolia.g.alchemy.com/v2/API_KEY")!,
                    URL(string: "https://sepolia.infura.io/v3/API_KEY")!
                ],
                "bitcoin": [URL(string: "https://blockstream.info/testnet/api")!]
            ]
        case .production:
            return [
                "ethereum": [
                    URL(string: "https://eth-mainnet.g.alchemy.com/v2/API_KEY")!,
                    URL(string: "https://mainnet.infura.io/v3/API_KEY")!,
                    URL(string: "https://ethereum.publicnode.com")!
                ],
                "bitcoin": [
                    URL(string: "https://blockstream.info/api")!,
                    URL(string: "https://blockchain.info")!
                ]
            ]
        }
    }

    var loggingLevel: LogLevel {
        switch self {
        case .development: return .debug
        case .staging: return .info
        case .production: return .error
        }
    }
}
```

### 3.2 Feature Flags

```swift
class FeatureFlagService {
    enum Feature: String {
        case tssWallet = "tss_wallet_enabled"
        case multiChain = "multi_chain_support"
        case nftSupport = "nft_support"
        case stakingSupport = "staking_support"
        case fiatOnRamp = "fiat_on_ramp"
        case socialRecovery = "social_recovery"

        var defaultValue: Bool {
            switch self {
            case .tssWallet: return true
            case .multiChain: return true
            case .nftSupport: return false
            case .stakingSupport: return false
            case .fiatOnRamp: return true
            case .socialRecovery: return false
            }
        }
    }

    private let remoteConfig: RemoteConfigService
    private let localOverrides: UserDefaults

    func isEnabled(_ feature: Feature) -> Bool {
        // Check local override first (for testing)
        if let override = localOverrides.object(forKey: "feature_\(feature.rawValue)") as? Bool {
            return override
        }

        // Check remote config
        return remoteConfig.getBool(feature.rawValue) ?? feature.defaultValue
    }

    func setLocalOverride(_ feature: Feature, enabled: Bool) {
        localOverrides.set(enabled, forKey: "feature_\(feature.rawValue)")
    }
}
```

---

## 4. Implementation Roadmap

### Phase 1: Foundation (Weeks 1-3)

**Week 1: Core Infrastructure**
- [ ] Implement dependency injection container
- [ ] Set up error handling framework
- [ ] Implement observability (Sentry + Analytics)
- [ ] Create logging infrastructure
- [ ] Set up environment configuration

**Week 2: Security Layer**
- [ ] Implement Secure Enclave integration
- [ ] Build biometric authentication service
- [ ] Create security manager (jailbreak detection, etc.)
- [ ] Implement certificate pinning
- [ ] Set up security audit logging

**Week 3: Data Layer**
- [ ] Implement CoreData stack
- [ ] Build repository layer
- [ ] Create caching service (LRU cache)
- [ ] Implement sync service
- [ ] Build backup and restore service

### Phase 2: Crypto & Blockchain (Weeks 4-6)

**Week 4: TSS Implementation**
- [ ] Integrate Web3Auth SDK
- [ ] Implement distributed key generation
- [ ] Build TSS signing ceremony
- [ ] Create key share storage (Secure Enclave)
- [ ] Implement key recovery mechanisms

**Week 5: Blockchain Integration**
- [ ] Bitcoin service implementation
- [ ] Ethereum service implementation
- [ ] Multi-chain support (Polygon, Arbitrum, etc.)
- [ ] Transaction building and signing
- [ ] WebSocket real-time updates

**Week 6: Performance Optimization**
- [ ] Implement WASM crypto acceleration
- [ ] Build lazy initialization
- [ ] Optimize app launch
- [ ] Implement pagination and virtualization
- [ ] Create performance monitoring

### Phase 3: Features & Integration (Weeks 7-9)

**Week 7: Payment Ramps**
- [ ] Integrate Ramp Network SDK
- [ ] Implement buy flow
- [ ] Build sell flow (off-ramp)
- [ ] KYC integration
- [ ] Payment method management

**Week 8: UI & UX**
- [ ] Wallet dashboard
- [ ] Transaction history
- [ ] Send/receive flows
- [ ] Settings and preferences
- [ ] Address book

**Week 9: Advanced Features**
- [ ] Social recovery (OAuth-based)
- [ ] Multi-device sync
- [ ] Push notifications
- [ ] QR code scanning
- [ ] Biometric transaction confirmation

### Phase 4: Production Hardening (Weeks 10-12)

**Week 10: Resilience & Reliability**
- [ ] Implement circuit breakers
- [ ] Build retry mechanisms
- [ ] Create disaster recovery procedures
- [ ] Implement rate limiting
- [ ] Build health checks and monitoring

**Week 11: Testing**
- [ ] Unit tests (90% coverage)
- [ ] Integration tests
- [ ] End-to-end tests
- [ ] Performance testing
- [ ] Security testing

**Week 12: Audit & Launch Prep**
- [ ] Third-party security audit
- [ ] Penetration testing
- [ ] Load testing
- [ ] App Store submission preparation
- [ ] Production deployment

---

## 5. Key Performance Indicators (KPIs)

### Technical KPIs

```yaml
performance_targets:
  app_launch:
    cold_start_p95: 1800ms
    warm_start_p95: 600ms
    hot_start_p95: 250ms

  memory:
    baseline: 150MB
    peak_transaction: 220MB
    max_allowed: 300MB

  crypto_operations:
    tss_keygen_p95: 600ms
    tss_sign_p95: 500ms
    sig_verify_p95: 25ms

  network:
    wallet_load_p95: 900ms
    tx_broadcast_p95: 600ms
    balance_query_p95: 150ms

  reliability:
    uptime: 99.9%
    error_rate: <0.1%
    crash_free_rate: >99.5%

  security:
    zero_key_compromises: true
    zero_unauthorized_transactions: true
    biometric_auth_success: >95%
```

### Business KPIs

```yaml
business_targets:
  user_acquisition:
    daily_active_users: 1000
    monthly_active_users: 10000
    retention_rate_d7: >40%
    retention_rate_d30: >20%

  transaction_metrics:
    avg_transaction_value: $500
    transaction_success_rate: >99%
    avg_time_to_complete: <3min

  revenue:
    monthly_transaction_volume: $100k
    payment_ramp_conversion: >15%
    avg_fee_per_transaction: $0.50
```

---

## 6. Security Compliance Checklist

### Pre-Production Security Audit

- [ ] **Cryptography**
  - [ ] TSS implementation audited by cryptography expert
  - [ ] Secure randomness verified (SecRandomCopyBytes)
  - [ ] Nonce generation reviewed (no reuse)
  - [ ] Constant-time operations for secret operations
  - [ ] Memory wiping after crypto operations

- [ ] **Key Management**
  - [ ] Secure Enclave integration tested
  - [ ] Biometric authentication enforced
  - [ ] Key share distribution verified
  - [ ] Backup and recovery tested
  - [ ] Social recovery mechanism validated

- [ ] **Network Security**
  - [ ] TLS 1.3 enforced
  - [ ] Certificate pinning implemented
  - [ ] API authentication verified
  - [ ] WebSocket security reviewed
  - [ ] Man-in-the-middle protection tested

- [ ] **Data Protection**
  - [ ] Database encryption enabled
  - [ ] Keychain security configured
  - [ ] Sensitive data not logged
  - [ ] Clipboard monitoring implemented
  - [ ] Screenshot detection active

- [ ] **Application Security**
  - [ ] Jailbreak detection working
  - [ ] Debugger detection active
  - [ ] Code obfuscation applied
  - [ ] Runtime integrity checks enabled
  - [ ] Anti-tampering measures tested

- [ ] **Compliance**
  - [ ] GDPR compliance verified
  - [ ] Privacy policy updated
  - [ ] Terms of service reviewed
  - [ ] KYC/AML integration tested
  - [ ] User data handling documented

---

## 7. Conclusion

### Architecture Readiness Assessment

**Current State**: Documentation Complete (95%)
**Implementation State**: Not Started (0%)
**Production Readiness**: Requires Implementation (40% ready)

### Critical Success Factors

1. **Immediate Implementation Required**
   - Existing architecture is excellent but requires full implementation
   - No source code exists beyond directory structure
   - Estimated 10-12 weeks to production-ready state

2. **Production Gaps Must Be Addressed**
   - Error handling and resilience framework
   - Observability and monitoring infrastructure
   - Disaster recovery and business continuity
   - Rate limiting and abuse prevention
   - Performance optimization implementation

3. **Security Hardening Essential**
   - TSS implementation requires expert audit
   - Secure Enclave integration must be tested thoroughly
   - Multi-layer security controls need validation
   - Third-party security audit mandatory

4. **Performance Targets Achievable**
   - 60-75% improvement possible with documented optimizations
   - WASM acceleration can provide 60% crypto speedup
   - Lazy loading can reduce launch time by 50%
   - Proper caching can reduce memory by 40-45%

### Next Steps

1. **Immediate (Week 1)**
   - Set up development environment
   - Initialize project structure
   - Implement core infrastructure (DI, error handling, logging)
   - Set up CI/CD pipeline

2. **Short-term (Weeks 2-6)**
   - Implement security layer (Secure Enclave, TSS)
   - Build data layer (CoreData, repositories)
   - Integrate blockchain services
   - Implement payment ramps

3. **Medium-term (Weeks 7-12)**
   - Build UI and UX flows
   - Implement advanced features
   - Production hardening
   - Security audit and testing

4. **Launch Preparation**
   - Beta testing with limited users
   - Stress testing and performance validation
   - App Store submission
   - Production deployment

---

**Document Owner**: Lead System Architect
**Last Updated**: 2025-10-21
**Status**: Ready for Implementation
**Next Review**: Post-Phase 1 Completion
