# Fueki Wallet - System Architecture

## Executive Summary

Fueki is a non-custodial, multi-chain mobile wallet leveraging Threshold Signature Scheme (TSS) technology for enhanced security and user experience. This document outlines the complete system architecture for the iOS implementation.

## Architecture Overview

### Layered Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Presentation Layer                      │
│              (SwiftUI Views + ViewModels)                │
└─────────────────────────────────────────────────────────┘
                          ↓↑
┌─────────────────────────────────────────────────────────┐
│                 Business Logic Layer                     │
│         (Use Cases, Domain Models, Services)             │
└─────────────────────────────────────────────────────────┘
                          ↓↑
┌─────────────────────────────────────────────────────────┐
│                    Data Layer                            │
│        (Repositories, Data Sources, Cache)               │
└─────────────────────────────────────────────────────────┘
                          ↓↑
┌─────────────────────────────────────────────────────────┐
│                 Infrastructure Layer                     │
│    (Blockchain Clients, APIs, Storage, Crypto)          │
└─────────────────────────────────────────────────────────┘
```

## Core Architecture Patterns

### 1. MVVM (Model-View-ViewModel)

**Rationale**: SwiftUI's declarative nature aligns perfectly with MVVM, providing:
- Clear separation of concerns
- Testable business logic
- Reactive data flow with Combine framework
- SwiftUI's @Published and @StateObject integration

**Structure**:
```
View → ViewModel → UseCase → Repository → DataSource
  ↑        ↓
  └────────┘ (Combine Publishers)
```

### 2. Clean Architecture Principles

**Dependency Rule**: Dependencies point inward
- Domain layer has no dependencies
- Data layer depends on Domain
- Presentation layer depends on Domain
- Infrastructure implements Domain interfaces

### 3. Repository Pattern

**Purpose**: Abstract data access logic
- Single source of truth for data operations
- Coordinate between local and remote data sources
- Handle caching strategy
- Manage data synchronization

## Module Structure

```
FuekiWallet/
├── Presentation/
│   ├── Common/
│   │   ├── Components/
│   │   ├── Themes/
│   │   └── Extensions/
│   ├── Onboarding/
│   │   ├── Views/
│   │   └── ViewModels/
│   ├── Wallet/
│   │   ├── Views/
│   │   └── ViewModels/
│   ├── Transactions/
│   │   ├── Views/
│   │   └── ViewModels/
│   ├── Settings/
│   │   ├── Views/
│   │   └── ViewModels/
│   └── Send/
│       ├── Views/
│       └── ViewModels/
├── Domain/
│   ├── Models/
│   │   ├── Wallet.swift
│   │   ├── Transaction.swift
│   │   ├── Asset.swift
│   │   └── Account.swift
│   ├── UseCases/
│   │   ├── Wallet/
│   │   ├── Transaction/
│   │   ├── Authentication/
│   │   └── KeyManagement/
│   └── Repositories/
│       └── Protocols/
├── Data/
│   ├── Repositories/
│   │   └── Implementations/
│   ├── DataSources/
│   │   ├── Local/
│   │   └── Remote/
│   ├── Models/
│   │   └── DTOs/
│   └── Persistence/
│       ├── CoreData/
│       └── Keychain/
├── Infrastructure/
│   ├── Blockchain/
│   │   ├── Bitcoin/
│   │   ├── Ethereum/
│   │   └── Common/
│   ├── Cryptography/
│   │   ├── TSS/
│   │   ├── KeyManagement/
│   │   └── Signing/
│   ├── Network/
│   │   ├── API/
│   │   └── WebSocket/
│   ├── Security/
│   │   ├── Keychain/
│   │   ├── SecureEnclave/
│   │   └── Biometrics/
│   └── ThirdParty/
│       ├── PaymentRamps/
│       ├── OAuth/
│       └── Analytics/
└── Core/
    ├── DI/
    │   └── Container/
    ├── Configuration/
    └── Extensions/
```

## State Management Architecture

### Global State Management

**Approach**: Combine with @StateObject and @EnvironmentObject

```swift
// Global App State
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var wallets: [Wallet] = []
    @Published var selectedWallet: Wallet?
    @Published var networkConnectivity: NetworkStatus
    @Published var biometricAuthEnabled: Bool
}

// Feature-Specific State
class WalletViewModel: ObservableObject {
    @Published var balance: Balance?
    @Published var transactions: [Transaction] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let walletUseCase: WalletUseCaseProtocol
    private var cancellables = Set<AnyCancellable>()
}
```

### State Persistence Strategy

1. **In-Memory State**: Current session data (ViewModels)
2. **UserDefaults**: App preferences, settings
3. **CoreData/Realm**: Transaction history, wallet metadata
4. **Keychain**: Sensitive data (keys, seeds, tokens)
5. **Secure Enclave**: TSS key shares (when available)

## Component Communication Patterns

### 1. Parent-Child Communication
```swift
// Parent passes data down via @Binding
struct ParentView: View {
    @State private var amount: String = ""

    var body: some View {
        AmountInput(amount: $amount)
    }
}
```

### 2. Cross-Module Communication
```swift
// Use Combine Publishers for async events
protocol TransactionEventPublisher {
    var transactionCompleted: AnyPublisher<Transaction, Never> { get }
    var transactionFailed: AnyPublisher<Error, Never> { get }
}
```

### 3. Deep Linking & Navigation
```swift
// Coordinator pattern with NavigationPath
class AppCoordinator: ObservableObject {
    @Published var navigationPath = NavigationPath()

    func navigate(to destination: AppDestination) {
        navigationPath.append(destination)
    }
}
```

## Dependency Injection Architecture

### DI Container Pattern

```swift
protocol DependencyContainer {
    // Use Cases
    var walletUseCase: WalletUseCaseProtocol { get }
    var transactionUseCase: TransactionUseCaseProtocol { get }
    var authUseCase: AuthenticationUseCaseProtocol { get }

    // Repositories
    var walletRepository: WalletRepositoryProtocol { get }
    var transactionRepository: TransactionRepositoryProtocol { get }

    // Services
    var blockchainService: BlockchainServiceProtocol { get }
    var cryptoService: CryptographyServiceProtocol { get }
}

class DefaultDependencyContainer: DependencyContainer {
    // Singleton instances
    static let shared = DefaultDependencyContainer()

    // Lazy initialization
    lazy var walletUseCase: WalletUseCaseProtocol = {
        DefaultWalletUseCase(
            repository: walletRepository,
            cryptoService: cryptoService
        )
    }()
}
```

## Error Handling Architecture

### Hierarchical Error Model

```swift
enum FuekiError: Error {
    case network(NetworkError)
    case blockchain(BlockchainError)
    case crypto(CryptoError)
    case storage(StorageError)
    case authentication(AuthError)
    case validation(ValidationError)
}

// Layer-specific errors
enum BlockchainError: Error {
    case insufficientFunds
    case invalidAddress
    case transactionFailed(reason: String)
    case networkTimeout
    case unsupportedChain
}

enum CryptoError: Error {
    case keyGenerationFailed
    case signingFailed
    case tssReconstructionFailed
    case invalidKeyShare
    case secureEnclaveUnavailable
}
```

### Error Handling Strategy

1. **ViewModel Level**: Catch and convert to user-friendly messages
2. **UseCase Level**: Business logic validation
3. **Repository Level**: Data access error recovery
4. **Infrastructure Level**: Low-level error logging and reporting

## Performance Optimization Strategies

### 1. Lazy Loading
- Load transaction history on-demand with pagination
- Defer blockchain connection until needed
- Progressive image loading for NFTs

### 2. Caching Strategy
```swift
protocol CachePolicy {
    var ttl: TimeInterval { get }
    var maxSize: Int { get }
    var evictionPolicy: EvictionPolicy { get }
}

// Multi-level cache
class DataCache {
    private let memoryCache: NSCache
    private let diskCache: DiskCache
    private let policy: CachePolicy
}
```

### 3. Background Processing
- Transaction broadcasting
- Balance updates
- Price fetching
- Transaction history sync

### 4. Database Optimization
```swift
// CoreData performance optimizations
- Batch fetching
- Faulting optimization
- Predicate indexing
- Relationship prefetching
```

## Testing Architecture

### Test Pyramid Strategy

```
                    /\
                   /  \
                  /UI  \
                 /Tests \
                /________\
               /          \
              / Integration\
             /    Tests     \
            /______________\
           /                \
          /   Unit Tests     \
         /                    \
        /______________________\
```

### Testability Patterns

1. **Protocol-Oriented Design**: All dependencies via protocols
2. **Dependency Injection**: Injectable mock dependencies
3. **Pure Functions**: Business logic without side effects
4. **Observable State**: Test state changes via Combine

```swift
// Example testable ViewModel
class WalletViewModelTests: XCTestCase {
    var sut: WalletViewModel!
    var mockWalletUseCase: MockWalletUseCase!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        mockWalletUseCase = MockWalletUseCase()
        sut = WalletViewModel(walletUseCase: mockWalletUseCase)
        cancellables = Set<AnyCancellable>()
    }

    func testFetchBalance_Success() {
        // Given
        let expectedBalance = Balance(value: 1.5, currency: "BTC")
        mockWalletUseCase.balanceToReturn = expectedBalance

        // When
        sut.fetchBalance()

        // Then
        XCTAssertEqual(sut.balance, expectedBalance)
        XCTAssertFalse(sut.isLoading)
    }
}
```

## Architecture Decision Records (ADRs)

### ADR-001: SwiftUI over UIKit

**Decision**: Use SwiftUI as the primary UI framework

**Rationale**:
- Modern, declarative approach reduces boilerplate
- Better integration with iOS 16+ features
- Built-in state management with Combine
- Improved accessibility support
- Better code maintainability

**Consequences**:
- iOS 15+ minimum deployment target
- Learning curve for UIKit developers
- Limited backward compatibility

### ADR-002: MVVM Pattern

**Decision**: Implement MVVM as the primary architectural pattern

**Rationale**:
- Natural fit with SwiftUI's reactive paradigm
- Clear separation of concerns
- Highly testable business logic
- Industry standard for SwiftUI apps

### ADR-003: Protocol-Oriented Architecture

**Decision**: Use protocols for all major dependencies

**Rationale**:
- Enables easy mocking for testing
- Supports multiple implementations
- Loose coupling between layers
- Aligns with Swift's protocol-oriented design

### ADR-004: CoreData for Local Storage

**Decision**: Use CoreData for transaction history and wallet metadata

**Rationale**:
- Native iOS framework with excellent performance
- Built-in migration support
- iCloud sync capabilities
- Proven reliability for complex data models

**Alternatives Considered**:
- Realm: Third-party dependency, licensing concerns
- SQLite: More manual work, less type-safe

## Scalability Considerations

### Multi-Chain Support

**Strategy**: Plugin architecture for blockchain implementations

```swift
protocol BlockchainPlugin {
    var chainId: String { get }
    var name: String { get }

    func createWallet() async throws -> WalletAddress
    func getBalance(address: String) async throws -> Balance
    func sendTransaction(_ tx: Transaction) async throws -> TransactionHash
    func estimateFee(_ tx: Transaction) async throws -> Fee
}

class BlockchainRegistry {
    private var plugins: [String: BlockchainPlugin] = [:]

    func register(_ plugin: BlockchainPlugin) {
        plugins[plugin.chainId] = plugin
    }
}
```

### Feature Flags

```swift
enum Feature: String {
    case nftSupport
    case stakingSupport
    case fiatOnRamp
    case multiSigWallet
    case tokenSwap
}

class FeatureFlags {
    static func isEnabled(_ feature: Feature) -> Bool {
        // Remote config or local override
    }
}
```

## Security Architecture Integration Points

- **Keychain Integration**: Secure storage for sensitive data
- **Secure Enclave**: Hardware-backed key storage (when available)
- **Biometric Authentication**: Touch ID / Face ID integration
- **App Transport Security**: Enforce HTTPS connections
- **Certificate Pinning**: Prevent MITM attacks
- **Code Obfuscation**: Protect against reverse engineering

## Next Steps

This system architecture serves as the foundation for:
1. Security architecture design
2. Data architecture specifications
3. Integration architecture planning
4. Detailed component design

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-21 | CryptoArchitect Agent | Initial architecture design |
