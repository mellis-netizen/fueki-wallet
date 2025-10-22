# Fueki Wallet - iOS Architecture

## Overview

Fueki Wallet follows Clean Architecture principles with MVVM pattern, ensuring separation of concerns, testability, and maintainability.

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Views     │  │ ViewModels  │  │  Coordinators│         │
│  │  (SwiftUI)  │──│   (MVVM)    │──│  (Navigation)│         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Use Cases  │  │   Entities  │  │ Repositories│         │
│  │ (Business)  │──│   (Models)  │──│ (Protocols) │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Network    │  │   Storage   │  │  Keychain   │         │
│  │  (API)      │  │ (CoreData)  │  │  (Security) │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Presentation Layer

#### Views (SwiftUI)
- Declarative UI components
- State-driven rendering
- Reusable components

```swift
struct WalletView: View {
    @StateObject private var viewModel: WalletViewModel

    var body: some View {
        NavigationView {
            List(viewModel.wallets) { wallet in
                WalletRow(wallet: wallet)
            }
            .navigationTitle("Wallets")
        }
        .task {
            await viewModel.loadWallets()
        }
    }
}
```

#### ViewModels (MVVM)
- Business logic presentation
- State management
- UI event handling

```swift
@MainActor
class WalletViewModel: ObservableObject {
    @Published var wallets: [Wallet] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let walletService: WalletServiceProtocol

    init(walletService: WalletServiceProtocol) {
        self.walletService = walletService
    }

    func loadWallets() async {
        isLoading = true
        defer { isLoading = false }

        do {
            wallets = try await walletService.fetchWallets()
        } catch {
            self.error = error
        }
    }
}
```

#### Coordinators (Navigation)
- Screen flow management
- Deep linking
- Navigation state

```swift
class AppCoordinator {
    private let navigationController: UINavigationController
    private var childCoordinators: [Coordinator] = []

    func start() {
        if userIsAuthenticated {
            showMainFlow()
        } else {
            showOnboarding()
        }
    }
}
```

### 2. Domain Layer

#### Use Cases
- Business logic encapsulation
- Single responsibility
- Testable units

```swift
protocol CreateWalletUseCaseProtocol {
    func execute(name: String, type: WalletType) async throws -> Wallet
}

class CreateWalletUseCase: CreateWalletUseCaseProtocol {
    private let walletRepository: WalletRepositoryProtocol
    private let keyManager: KeyManagerProtocol

    func execute(name: String, type: WalletType) async throws -> Wallet {
        // 1. Generate keys
        let keyPair = try await keyManager.generateKeyPair(type: type)

        // 2. Create wallet entity
        let wallet = Wallet(
            name: name,
            address: keyPair.address,
            type: type
        )

        // 3. Store securely
        try await walletRepository.save(wallet)
        try await keyManager.storeKey(keyPair, for: wallet.id)

        return wallet
    }
}
```

#### Entities
- Business models
- Value objects
- Domain rules

```swift
struct Wallet: Identifiable, Codable {
    let id: UUID
    let name: String
    let address: String
    let type: WalletType
    var balance: Decimal
    let createdAt: Date

    var formattedAddress: String {
        "\(address.prefix(6))...\(address.suffix(4))"
    }
}

enum WalletType: String, Codable {
    case ethereum
    case bitcoin
    case solana
}
```

#### Repository Protocols
- Data source abstraction
- Implementation independent

```swift
protocol WalletRepositoryProtocol {
    func fetchWallets() async throws -> [Wallet]
    func fetchWallet(id: UUID) async throws -> Wallet?
    func save(_ wallet: Wallet) async throws
    func delete(id: UUID) async throws
}
```

### 3. Data Layer

#### Network Layer
- API communication
- Request/response handling
- Error mapping

```swift
class NetworkManager {
    private let session: URLSession
    private let baseURL: URL

    func request<T: Decodable>(
        _ endpoint: Endpoint
    ) async throws -> T {
        let request = try buildRequest(endpoint)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

#### Storage Layer
- Core Data persistence
- Local database
- Cache management

```swift
class CoreDataManager {
    private let container: NSPersistentContainer

    func save<T: NSManagedObject>(_ entity: T) throws {
        let context = container.viewContext
        try context.save()
    }

    func fetch<T: NSManagedObject>(
        predicate: NSPredicate? = nil
    ) throws -> [T] {
        let request = T.fetchRequest()
        request.predicate = predicate
        return try container.viewContext.fetch(request) as! [T]
    }
}
```

#### Keychain Manager
- Secure storage
- Key management
- Biometric protection

```swift
class KeychainManager {
    func store(_ data: Data, key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed
        }
    }
}
```

## Design Patterns

### 1. Dependency Injection

```swift
class DependencyContainer {
    static let shared = DependencyContainer()

    // MARK: - Services
    lazy var networkManager: NetworkManager = {
        NetworkManager(baseURL: Configuration.apiBaseURL)
    }()

    lazy var walletService: WalletServiceProtocol = {
        WalletService(
            repository: walletRepository,
            keyManager: keyManager
        )
    }()

    // MARK: - Repositories
    lazy var walletRepository: WalletRepositoryProtocol = {
        WalletRepository(
            networkManager: networkManager,
            storage: coreDataManager
        )
    }()
}
```

### 2. Repository Pattern

```swift
class WalletRepository: WalletRepositoryProtocol {
    private let networkManager: NetworkManager
    private let storage: CoreDataManager

    func fetchWallets() async throws -> [Wallet] {
        // Try cache first
        if let cached = try? storage.fetch() as [WalletEntity] {
            return cached.map { $0.toDomain() }
        }

        // Fetch from network
        let wallets: [Wallet] = try await networkManager.request(.wallets)

        // Update cache
        try await storage.save(wallets)

        return wallets
    }
}
```

### 3. Observer Pattern

```swift
class WalletBalanceObserver: ObservableObject {
    @Published var balance: Decimal = 0

    private var cancellables = Set<AnyCancellable>()

    func observe(wallet: Wallet) {
        NotificationCenter.default
            .publisher(for: .walletBalanceUpdated)
            .compactMap { $0.object as? Wallet }
            .filter { $0.id == wallet.id }
            .map { $0.balance }
            .assign(to: &$balance)
    }
}
```

### 4. Factory Pattern

```swift
protocol ViewModelFactory {
    func makeWalletViewModel() -> WalletViewModel
    func makeTransactionViewModel() -> TransactionViewModel
}

class DefaultViewModelFactory: ViewModelFactory {
    private let dependencies: DependencyContainer

    func makeWalletViewModel() -> WalletViewModel {
        WalletViewModel(
            walletService: dependencies.walletService,
            priceService: dependencies.priceService
        )
    }
}
```

## Data Flow

### 1. User Action → View → ViewModel → Use Case → Repository → API

```
User Tap Button
    ↓
View.onTapGesture
    ↓
ViewModel.performAction()
    ↓
UseCase.execute()
    ↓
Repository.fetch()
    ↓
NetworkManager.request()
    ↓
API Response
    ↓
Repository.map()
    ↓
UseCase.return
    ↓
ViewModel.@Published property updates
    ↓
View.body re-renders
```

### 2. Background Updates

```swift
class WalletSyncService {
    func startPeriodicSync() {
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.syncWallets()
                }
            }
            .store(in: &cancellables)
    }
}
```

## Module Organization

```
FuekiWallet/
├── App/
│   ├── FuekiWalletApp.swift
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── Core/
│   ├── DependencyInjection/
│   ├── Navigation/
│   ├── Extensions/
│   └── Utils/
├── Features/
│   ├── Onboarding/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Models/
│   ├── Wallet/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── UseCases/
│   ├── Transaction/
│   └── Settings/
├── Domain/
│   ├── Entities/
│   ├── UseCases/
│   └── Repositories/
├── Data/
│   ├── Network/
│   ├── Storage/
│   ├── Keychain/
│   └── Repositories/
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.strings
    └── Info.plist
```

## Communication Patterns

### 1. Async/Await (Primary)
```swift
func fetchData() async throws -> Data {
    try await networkManager.request(.data)
}
```

### 2. Combine (Reactive)
```swift
walletService.walletPublisher
    .sink { wallet in
        // Handle update
    }
    .store(in: &cancellables)
```

### 3. Delegation (Legacy)
```swift
protocol WalletServiceDelegate: AnyObject {
    func walletDidUpdate(_ wallet: Wallet)
}
```

### 4. Notification Center (Cross-module)
```swift
NotificationCenter.default.post(
    name: .walletCreated,
    object: wallet
)
```

## Error Handling

```swift
enum AppError: LocalizedError {
    case network(NetworkError)
    case storage(StorageError)
    case keychain(KeychainError)
    case business(String)

    var errorDescription: String? {
        switch self {
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .storage(let error):
            return "Storage error: \(error.localizedDescription)"
        case .keychain(let error):
            return "Security error: \(error.localizedDescription)"
        case .business(let message):
            return message
        }
    }
}
```

## Testing Architecture

### 1. Unit Tests
- Test ViewModels with mock services
- Test Use Cases with mock repositories
- Test business logic in isolation

### 2. Integration Tests
- Test repository implementations
- Test network layer
- Test storage layer

### 3. UI Tests
- Test user flows
- Test navigation
- Test accessibility

## Performance Considerations

1. **Lazy Loading**: Load data on demand
2. **Caching**: Cache frequently accessed data
3. **Background Processing**: Move heavy operations off main thread
4. **Memory Management**: Use weak references appropriately
5. **Image Optimization**: Compress and cache images

## Security Architecture

1. **Keychain**: Store sensitive data
2. **Biometric Auth**: Protect app access
3. **Certificate Pinning**: Secure API communication
4. **Code Obfuscation**: Protect against reverse engineering
5. **Secure Enclave**: Hardware-backed key storage

---

This architecture provides a solid foundation for a scalable, maintainable, and testable iOS application.
