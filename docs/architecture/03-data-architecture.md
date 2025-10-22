# Fueki Wallet - Data Architecture

## Data Architecture Overview

The Fueki wallet implements a multi-tier data architecture optimized for performance, security, and offline capability. This document outlines the complete data management strategy including storage, caching, synchronization, and backup mechanisms.

## Data Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│              ViewModel Layer                             │
│         (Observable State, UI Models)                    │
└─────────────────────────────────────────────────────────┘
                          ↓↑
┌─────────────────────────────────────────────────────────┐
│             Repository Layer                             │
│     (Coordination, Business Logic, Caching)             │
└─────────────────────────────────────────────────────────┘
                          ↓↑
        ┌─────────────────┴──────────────────┐
        ↓                                     ↓
┌──────────────────┐              ┌──────────────────┐
│ Local Data Source│              │Remote Data Source│
│  (CoreData/Realm)│              │ (Blockchain APIs)│
└──────────────────┘              └──────────────────┘
        ↓                                     ↓
┌──────────────────┐              ┌──────────────────┐
│  Secure Storage  │              │  Network Layer   │
│(Keychain/Enclave)│              │   (URLSession)   │
└──────────────────┘              └──────────────────┘
```

## Data Storage Strategy

### Storage Classification

| Data Type | Storage Location | Encryption | Sync | Backup |
|-----------|------------------|------------|------|--------|
| Private Keys | Keychain/Secure Enclave | ✅ Hardware | ❌ | Manual only |
| Key Shares (TSS) | Keychain | ✅ AES-256 | ❌ | Encrypted cloud |
| Transaction History | CoreData | ✅ File Protection | ✅ | iCloud/Manual |
| Wallet Metadata | CoreData | ✅ File Protection | ✅ | iCloud/Manual |
| User Settings | UserDefaults | ❌ | ✅ | iCloud |
| Address Book | CoreData | ✅ File Protection | ✅ | iCloud/Manual |
| Price Cache | CoreData | ❌ | ❌ | ❌ |
| Session Data | In-Memory | ❌ | ❌ | ❌ |

### Storage Decision Matrix

```swift
enum StorageStrategy {
    case secureEnclave      // Highest security, hardware-backed
    case keychain           // Secure, OS-managed encryption
    case coreData           // Structured data with relationships
    case userDefaults       // Simple key-value preferences
    case fileSystem         // Large files (encrypted)
    case memory             // Temporary session data
}

protocol DataClassifier {
    func determineStorage(for dataType: DataType) -> StorageStrategy
    func determineEncryption(for dataType: DataType) -> EncryptionLevel
}

enum EncryptionLevel {
    case hardwareBacked     // Secure Enclave
    case systemEncrypted    // iOS file protection
    case appEncrypted       // Custom AES encryption
    case none               // Public data only
}
```

## CoreData Schema Design

### Entity Relationship Diagram

```
┌─────────────┐
│   Wallet    │
│─────────────│
│ id          │
│ name        │
│ type        │
│ chainId     │
│ address     │
│ balance     │
│ createdAt   │
│ updatedAt   │
└─────────────┘
       ↓
       │ 1:N
       ↓
┌─────────────┐
│ Transaction │
│─────────────│
│ id          │
│ walletId    │
│ hash        │
│ from        │
│ to          │
│ amount      │
│ fee         │
│ status      │
│ timestamp   │
│ blockNumber │
│ metadata    │
└─────────────┘
       │
       │ 1:1
       ↓
┌─────────────┐
│TxReceipt    │
│─────────────│
│ id          │
│ txId        │
│ gasUsed     │
│ logs        │
│ success     │
└─────────────┘

┌─────────────┐
│   Asset     │
│─────────────│
│ id          │
│ walletId    │
│ symbol      │
│ name        │
│ balance     │
│ decimals    │
│ contractAddr│
│ type        │
└─────────────┘

┌─────────────┐
│AddressBook  │
│─────────────│
│ id          │
│ name        │
│ address     │
│ chainId     │
│ notes       │
│ createdAt   │
└─────────────┘

┌─────────────┐
│ PriceCache  │
│─────────────│
│ id          │
│ symbol      │
│ price       │
│ currency    │
│ timestamp   │
│ source      │
└─────────────┘
```

### CoreData Model Implementation

```swift
// MARK: - Wallet Entity
@objc(WalletEntity)
public class WalletEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var type: String // "hot", "tss", "hardware"
    @NSManaged public var chainId: String
    @NSManaged public var address: String
    @NSManaged public var balance: Decimal
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var transactions: NSSet?
    @NSManaged public var assets: NSSet?
}

// MARK: - Transaction Entity
@objc(TransactionEntity)
public class TransactionEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var hash: String
    @NSManaged public var fromAddress: String
    @NSManaged public var toAddress: String
    @NSManaged public var amount: Decimal
    @NSManaged public var fee: Decimal
    @NSManaged public var status: String // "pending", "confirmed", "failed"
    @NSManaged public var timestamp: Date
    @NSManaged public var blockNumber: Int64
    @NSManaged public var nonce: Int64
    @NSManaged public var gasPrice: Decimal?
    @NSManaged public var gasLimit: Int64
    @NSManaged public var data: Data?
    @NSManaged public var wallet: WalletEntity
    @NSManaged public var receipt: TransactionReceiptEntity?
}

// MARK: - Asset Entity
@objc(AssetEntity)
public class AssetEntity: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var symbol: String
    @NSManaged public var name: String
    @NSManaged public var balance: Decimal
    @NSManaged public var decimals: Int16
    @NSManaged public var contractAddress: String?
    @NSManaged public var type: String // "native", "erc20", "erc721", "erc1155"
    @NSManaged public var imageURL: URL?
    @NSManaged public var wallet: WalletEntity
}
```

### CoreData Stack Setup

```swift
class CoreDataStack {
    static let shared = CoreDataStack()

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FuekiWallet")

        // Configure persistent store
        let storeURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("FuekiWallet.sqlite")

        let description = NSPersistentStoreDescription(url: storeURL)

        // Enable file protection
        description.setOption(
            FileProtectionType.completeUntilFirstUserAuthentication as NSObject,
            forKey: NSPersistentStoreFileProtectionKey
        )

        // Enable lightweight migration
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        // Enable persistent history tracking
        description.setOption(
            true as NSObject,
            forKey: NSPersistentHistoryTrackingKey
        )

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
```

## Repository Pattern Implementation

### Repository Protocol

```swift
protocol Repository {
    associatedtype Entity
    associatedtype DomainModel

    func fetch(id: UUID) async throws -> DomainModel?
    func fetchAll() async throws -> [DomainModel]
    func save(_ model: DomainModel) async throws
    func update(_ model: DomainModel) async throws
    func delete(id: UUID) async throws
}
```

### Wallet Repository Implementation

```swift
protocol WalletRepository: Repository where Entity == WalletEntity, DomainModel == Wallet {
    func fetchWallets(for chainId: String) async throws -> [Wallet]
    func fetchWallet(by address: String) async throws -> Wallet?
    func updateBalance(_ balance: Decimal, for walletId: UUID) async throws
}

class DefaultWalletRepository: WalletRepository {
    private let coreDataStack: CoreDataStack
    private let cache: WalletCache

    init(
        coreDataStack: CoreDataStack = .shared,
        cache: WalletCache = .shared
    ) {
        self.coreDataStack = coreDataStack
        self.cache = cache
    }

    func fetch(id: UUID) async throws -> Wallet? {
        // Check cache first
        if let cached = cache.get(id: id) {
            return cached
        }

        // Fetch from CoreData
        let context = coreDataStack.viewContext
        let fetchRequest: NSFetchRequest<WalletEntity> = WalletEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        let entities = try await context.perform {
            try context.fetch(fetchRequest)
        }

        guard let entity = entities.first else {
            return nil
        }

        let wallet = entity.toDomain()
        cache.set(wallet)
        return wallet
    }

    func fetchAll() async throws -> [Wallet] {
        let context = coreDataStack.viewContext
        let fetchRequest: NSFetchRequest<WalletEntity> = WalletEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let entities = try await context.perform {
            try context.fetch(fetchRequest)
        }

        return entities.map { $0.toDomain() }
    }

    func save(_ model: Wallet) async throws {
        let context = coreDataStack.newBackgroundContext()

        try await context.perform {
            let entity = WalletEntity(context: context)
            entity.update(from: model)
            try context.save()
        }

        cache.set(model)
    }

    func update(_ model: Wallet) async throws {
        let context = coreDataStack.newBackgroundContext()

        try await context.perform {
            let fetchRequest: NSFetchRequest<WalletEntity> = WalletEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", model.id as CVarArg)

            guard let entity = try context.fetch(fetchRequest).first else {
                throw StorageError.entityNotFound
            }

            entity.update(from: model)
            entity.updatedAt = Date()
            try context.save()
        }

        cache.set(model)
    }

    func delete(id: UUID) async throws {
        let context = coreDataStack.newBackgroundContext()

        try await context.perform {
            let fetchRequest: NSFetchRequest<WalletEntity> = WalletEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try context.fetch(fetchRequest).first else {
                throw StorageError.entityNotFound
            }

            context.delete(entity)
            try context.save()
        }

        cache.remove(id: id)
    }
}
```

### Transaction Repository Implementation

```swift
protocol TransactionRepository: Repository where Entity == TransactionEntity, DomainModel == Transaction {
    func fetchTransactions(
        for walletId: UUID,
        limit: Int,
        offset: Int
    ) async throws -> [Transaction]

    func fetchPendingTransactions() async throws -> [Transaction]
    func updateStatus(_ status: TransactionStatus, for txHash: String) async throws
}

class DefaultTransactionRepository: TransactionRepository {
    private let coreDataStack: CoreDataStack

    func fetchTransactions(
        for walletId: UUID,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [Transaction] {
        let context = coreDataStack.viewContext
        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()

        fetchRequest.predicate = NSPredicate(
            format: "wallet.id == %@",
            walletId as CVarArg
        )
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "timestamp", ascending: false)
        ]
        fetchRequest.fetchLimit = limit
        fetchRequest.fetchOffset = offset

        // Prefetch relationships for performance
        fetchRequest.relationshipKeyPathsForPrefetching = ["wallet", "receipt"]

        let entities = try await context.perform {
            try context.fetch(fetchRequest)
        }

        return entities.map { $0.toDomain() }
    }

    func fetchPendingTransactions() async throws -> [Transaction] {
        let context = coreDataStack.viewContext
        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()

        fetchRequest.predicate = NSPredicate(format: "status == %@", "pending")
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "timestamp", ascending: true)
        ]

        let entities = try await context.perform {
            try context.fetch(fetchRequest)
        }

        return entities.map { $0.toDomain() }
    }
}
```

## Caching Strategy

### Multi-Level Cache Architecture

```
┌─────────────────────────────────────────┐
│         Memory Cache (L1)               │
│  (NSCache, Fast access, Limited size)   │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│          Disk Cache (L2)                │
│ (CoreData/FileSystem, Persistent)       │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│         Remote Source (L3)              │
│     (Blockchain nodes, APIs)            │
└─────────────────────────────────────────┘
```

### Cache Implementation

```swift
protocol Cache {
    associatedtype Value

    func get(key: String) -> Value?
    func set(_ value: Value, for key: String)
    func remove(key: String)
    func clear()
}

class MemoryCache<T>: Cache {
    typealias Value = T

    private let cache = NSCache<NSString, CacheEntry<T>>()
    private let ttl: TimeInterval

    init(ttl: TimeInterval = 300, maxCount: Int = 100) {
        self.ttl = ttl
        cache.countLimit = maxCount
    }

    func get(key: String) -> T? {
        guard let entry = cache.object(forKey: key as NSString) else {
            return nil
        }

        // Check expiration
        if Date() > entry.expiresAt {
            remove(key: key)
            return nil
        }

        return entry.value
    }

    func set(_ value: T, for key: String) {
        let entry = CacheEntry(
            value: value,
            expiresAt: Date().addingTimeInterval(ttl)
        )
        cache.setObject(entry, forKey: key as NSString)
    }

    func remove(key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }
}

class CacheEntry<T> {
    let value: T
    let expiresAt: Date

    init(value: T, expiresAt: Date) {
        self.value = value
        self.expiresAt = expiresAt
    }
}
```

### Cache Policies

```swift
enum CachePolicy {
    case networkFirst       // Try network, fallback to cache
    case cacheFirst         // Try cache, fallback to network
    case networkOnly        // Always fetch from network
    case cacheOnly          // Only use cached data
    case cacheAndNetwork    // Return cache immediately, update from network
}

protocol CacheableRepository {
    func fetch<T>(
        key: String,
        policy: CachePolicy,
        networkFetch: () async throws -> T
    ) async throws -> T
}

extension CacheableRepository {
    func fetch<T>(
        key: String,
        policy: CachePolicy,
        networkFetch: () async throws -> T
    ) async throws -> T {
        switch policy {
        case .networkFirst:
            do {
                let data = try await networkFetch()
                // Cache the result
                return data
            } catch {
                // Fallback to cache
                if let cached = getFromCache(key: key) as? T {
                    return cached
                }
                throw error
            }

        case .cacheFirst:
            if let cached = getFromCache(key: key) as? T {
                return cached
            }
            let data = try await networkFetch()
            // Cache the result
            return data

        case .networkOnly:
            return try await networkFetch()

        case .cacheOnly:
            guard let cached = getFromCache(key: key) as? T else {
                throw CacheError.dataNotFound
            }
            return cached

        case .cacheAndNetwork:
            // Return cached data immediately if available
            if let cached = getFromCache(key: key) as? T {
                Task {
                    // Update cache in background
                    _ = try? await networkFetch()
                }
                return cached
            }
            // No cache, fetch from network
            return try await networkFetch()
        }
    }

    private func getFromCache(key: String) -> Any? {
        // Implementation
        return nil
    }
}
```

## Data Synchronization Architecture

### Sync Strategy

```swift
protocol SyncService {
    func sync() async throws
    func syncWalletBalances() async throws
    func syncTransactionHistory() async throws
    func syncPriceData() async throws
}

class DefaultSyncService: SyncService {
    private let walletRepository: WalletRepository
    private let transactionRepository: TransactionRepository
    private let blockchainService: BlockchainService

    func sync() async throws {
        // Parallel sync of independent data
        async let balances = syncWalletBalances()
        async let transactions = syncTransactionHistory()
        async let prices = syncPriceData()

        _ = try await (balances, transactions, prices)
    }

    func syncWalletBalances() async throws {
        let wallets = try await walletRepository.fetchAll()

        await withTaskGroup(of: Void.self) { group in
            for wallet in wallets {
                group.addTask {
                    do {
                        let balance = try await self.blockchainService
                            .getBalance(address: wallet.address, chainId: wallet.chainId)

                        try await self.walletRepository.updateBalance(
                            balance,
                            for: wallet.id
                        )
                    } catch {
                        print("Failed to sync balance for wallet \(wallet.id): \(error)")
                    }
                }
            }
        }
    }

    func syncTransactionHistory() async throws {
        let wallets = try await walletRepository.fetchAll()

        for wallet in wallets {
            let remoteTransactions = try await blockchainService
                .getTransactions(address: wallet.address, chainId: wallet.chainId)

            let localTransactions = try await transactionRepository
                .fetchTransactions(for: wallet.id, limit: 1000, offset: 0)

            let localHashes = Set(localTransactions.map { $0.hash })

            // Save new transactions
            for tx in remoteTransactions where !localHashes.contains(tx.hash) {
                try await transactionRepository.save(tx)
            }
        }
    }
}
```

### Background Sync

```swift
class BackgroundSyncManager {
    private let syncService: SyncService

    func setupBackgroundSync() {
        // Register background task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.fueki.wallet.sync",
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
    }

    private func handleBackgroundSync(task: BGAppRefreshTask) {
        let syncTask = Task {
            do {
                try await syncService.sync()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            syncTask.cancel()
        }

        // Schedule next background sync
        scheduleNextBackgroundSync()
    }

    private func scheduleNextBackgroundSync() {
        let request = BGAppRefreshTaskRequest(
            identifier: "com.fueki.wallet.sync"
        )
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background sync: \(error)")
        }
    }
}
```

## Backup and Recovery Architecture

### Backup Strategy

```swift
protocol BackupService {
    func createBackup() async throws -> BackupBundle
    func restoreBackup(_ bundle: BackupBundle) async throws
    func exportToiCloud() async throws
    func importFromiCloud() async throws
}

struct BackupBundle {
    let version: String
    let timestamp: Date
    let wallets: [Wallet]
    let encryptedKeyShares: [EncryptedKeyShare]
    let transactionHistory: [Transaction]
    let addressBook: [Contact]
    let settings: UserSettings
    let checksum: Data
}

class DefaultBackupService: BackupService {
    private let walletRepository: WalletRepository
    private let transactionRepository: TransactionRepository
    private let encryptionService: EncryptionService
    private let keychainService: KeychainService

    func createBackup() async throws -> BackupBundle {
        // Fetch all data
        let wallets = try await walletRepository.fetchAll()
        let transactions = try await fetchAllTransactions()

        // Retrieve and encrypt key shares
        let keyShares = try retrieveKeyShares()
        let encryptedShares = try encryptKeyShares(keyShares)

        // Create backup bundle
        let bundle = BackupBundle(
            version: "1.0",
            timestamp: Date(),
            wallets: wallets,
            encryptedKeyShares: encryptedShares,
            transactionHistory: transactions,
            addressBook: [],
            settings: UserSettings(),
            checksum: Data()
        )

        // Calculate checksum
        let checksumData = try JSONEncoder().encode(bundle)
        let checksum = SHA256.hash(data: checksumData)

        return bundle
    }

    func exportToiCloud() async throws {
        let backup = try await createBackup()
        let data = try JSONEncoder().encode(backup)

        // Upload to iCloud Drive
        let ubiquityURL = FileManager.default.url(
            forUbiquityContainerIdentifier: nil
        )

        guard let cloudURL = ubiquityURL else {
            throw BackupError.iCloudNotAvailable
        }

        let backupURL = cloudURL
            .appendingPathComponent("Backups")
            .appendingPathComponent("backup-\(Date().timeIntervalSince1970).json")

        try data.write(to: backupURL)
    }
}
```

### Recovery Flow

```
User Initiates Recovery
          ↓
┌─────────────────────────────────┐
│  Select Backup Source           │
│  (iCloud, Manual File)          │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│  Verify Backup Integrity        │
│  (Check checksum)               │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│  Authenticate User              │
│  (Biometric/PIN)                │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│  Decrypt Key Shares             │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│  Restore Wallets                │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│  Restore Transaction History    │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│  Sync with Blockchain           │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│  Restore Complete               │
└─────────────────────────────────┘
```

## Data Migration Strategy

### Migration Manager

```swift
protocol MigrationManager {
    func performMigrations() throws
    func currentVersion() -> Int
}

class CoreDataMigrationManager: MigrationManager {
    private let stack: CoreDataStack

    func performMigrations() throws {
        let sourceVersion = try detectSourceVersion()
        let destinationVersion = currentVersion()

        if sourceVersion < destinationVersion {
            try performMigration(from: sourceVersion, to: destinationVersion)
        }
    }

    func currentVersion() -> Int {
        return 1 // Current schema version
    }

    private func performMigration(from source: Int, to destination: Int) throws {
        // Implement step-by-step migrations
        for version in source..<destination {
            try migrateToVersion(version + 1)
        }
    }

    private func migrateToVersion(_ version: Int) throws {
        switch version {
        case 1:
            // Initial version, no migration needed
            break
        case 2:
            // Add new fields, migrate existing data
            try migrateV1ToV2()
        default:
            throw MigrationError.unknownVersion
        }
    }
}
```

## Performance Optimization

### Database Optimization Strategies

1. **Indexing**
```swift
// Add indices to frequently queried fields
entity.addIndex(on: "address")
entity.addIndex(on: "timestamp")
entity.addIndex(on: "status")
```

2. **Batch Operations**
```swift
func batchInsertTransactions(_ transactions: [Transaction]) async throws {
    let context = coreDataStack.newBackgroundContext()

    try await context.perform {
        for tx in transactions {
            let entity = TransactionEntity(context: context)
            entity.update(from: tx)
        }
        try context.save()
    }
}
```

3. **Pagination**
```swift
func fetchTransactionsPaginated(
    walletId: UUID,
    page: Int,
    pageSize: Int = 50
) async throws -> [Transaction] {
    let offset = page * pageSize
    return try await fetchTransactions(
        for: walletId,
        limit: pageSize,
        offset: offset
    )
}
```

## Data Validation

```swift
protocol DataValidator {
    func validate(_ data: Any) throws
}

struct TransactionValidator: DataValidator {
    func validate(_ data: Any) throws {
        guard let transaction = data as? Transaction else {
            throw ValidationError.invalidType
        }

        // Validate address format
        guard isValidAddress(transaction.toAddress) else {
            throw ValidationError.invalidAddress
        }

        // Validate amount
        guard transaction.amount > 0 else {
            throw ValidationError.invalidAmount
        }

        // Validate chain ID
        guard !transaction.chainId.isEmpty else {
            throw ValidationError.invalidChainId
        }
    }

    private func isValidAddress(_ address: String) -> Bool {
        // Implement address validation logic
        return true
    }
}
```

## Monitoring and Analytics

```swift
protocol DataAnalytics {
    func trackDataOperation(_ operation: DataOperation)
    func trackSyncDuration(_ duration: TimeInterval)
    func trackCacheHitRate()
}

enum DataOperation {
    case read(entity: String, duration: TimeInterval)
    case write(entity: String, duration: TimeInterval)
    case delete(entity: String, duration: TimeInterval)
    case sync(entity: String, duration: TimeInterval)
}
```

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-21 | CryptoArchitect Agent | Initial data architecture |
