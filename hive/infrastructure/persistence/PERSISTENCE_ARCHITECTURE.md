# Fueki Wallet - Data Persistence Architecture

## Overview
Comprehensive data persistence layer implementing Core Data, UserDefaults, and multi-tier caching for the Fueki Mobile Wallet.

## Architecture Components

### 1. Core Data Stack (`CoreDataStack.swift`)
**Location**: `/ios/FuekiWallet/Persistence/CoreDataStack.swift`

**Features**:
- Singleton pattern for unified data access
- Automatic lightweight migration support
- Background context for heavy operations
- File protection for data security
- Batch operations support (insert, update, delete)
- Merge policy configuration
- Error handling with custom `PersistenceError` types

**Key Methods**:
```swift
- viewContext: NSManagedObjectContext // Main thread context
- newBackgroundContext() -> NSManagedObjectContext
- performBackgroundTask(_:) async throws
- batchInsert(entityName:objects:) async throws
- batchUpdate(entityName:predicate:propertiesToUpdate:) async throws
- batchDelete(entityName:predicate:) async throws
```

### 2. Persistence Controller (`PersistenceController.swift`)
**Location**: `/ios/FuekiWallet/Persistence/PersistenceController.swift`

**Purpose**: Main coordinator for all persistence operations

**Components**:
- Repository instances (Wallet, Transaction, Asset, Settings)
- Cache manager integration
- Import/export functionality
- Backup and restore operations
- Data optimization

**Key Features**:
- Observable properties for reactive UI updates
- Background sync operations
- JSON-based data import/export
- Automatic backup creation with timestamps
- Database optimization and cleanup

### 3. Repository Pattern

#### Wallet Repository (`WalletRepository.swift`)
**Location**: `/ios/FuekiWallet/Persistence/Repositories/WalletRepository.swift`

**Operations**:
- CRUD operations for wallet entities
- Batch balance updates
- Address and ID-based queries
- Active wallet filtering
- Total balance calculations
- Search functionality
- Keychain integration for private keys

**Cache Strategy**:
- Individual wallet caching (5 min TTL)
- Wallet list caching (1 min TTL)
- Cache invalidation on mutations

#### Transaction Repository (`TransactionRepository.swift`)
**Location**: `/ios/FuekiWallet/Persistence/Repositories/TransactionRepository.swift`

**Operations**:
- Transaction creation and tracking
- Status updates (pending → confirmed → failed)
- Confirmation count tracking
- Date range queries
- Pending transaction monitoring
- Old transaction cleanup
- Statistics (total sent/received)

**Query Optimizations**:
- Indexed by hash and timestamp
- Wallet-scoped queries
- Status-based filtering
- Batch status updates

#### Asset Repository (`AssetRepository.swift`)
**Location**: `/ios/FuekiWallet/Persistence/Repositories/AssetRepository.swift`

**Operations**:
- Token/asset management
- Balance and price tracking
- Portfolio value calculations
- Asset allocation analysis
- Top assets by value
- Enable/disable assets

**Advanced Features**:
- Multi-token support (ERC20, ERC721, ERC1155)
- Price caching with update timestamps
- Portfolio analytics
- Asset allocation percentages

#### Settings Repository (`SettingsRepository.swift`)
**Location**: `/ios/FuekiWallet/Persistence/Repositories/SettingsRepository.swift`

**Settings Categories**:
1. **General**: Theme, language, currency
2. **Security**: Biometric auth, auto-lock, confirmations
3. **Network**: Selected network, custom RPC
4. **Display**: Balance visibility, small balance hiding
5. **Notifications**: Push, transaction, price alerts
6. **Backup**: Auto-backup settings, last backup date
7. **Analytics**: Analytics and crash reporting preferences

### 4. Caching System

#### Cache Manager (`CacheManager.swift`)
**Location**: `/ios/FuekiWallet/Persistence/Cache/CacheManager.swift`

**Architecture**:
- Two-tier caching (Memory + Disk)
- Automatic promotion from disk to memory
- Configurable TTL per cache type
- Statistics tracking (hit rate, size)
- Automatic cleanup and optimization

**Configuration**:
```swift
CacheConfiguration(
  memoryMaxSize: 50MB,
  diskMaxSize: 200MB,
  defaultTTL: 5 minutes,
  imageTTL: 1 hour,
  apiResponseTTL: 1 minute
)
```

#### Memory Cache (`MemoryCache.swift`)
**Location**: `/ios/FuekiWallet/Persistence/Cache/MemoryCache.swift`

**Features**:
- Thread-safe with concurrent dispatch queue
- LRU eviction policy
- Access count tracking
- Expiration date enforcement
- Size-based eviction

**Performance**:
- O(1) get/set operations
- Automatic cleanup of expired entries
- Memory pressure handling

#### Disk Cache (`DiskCache.swift`)
**Location**: `/ios/FuekiWallet/Persistence/Cache/DiskCache.swift`

**Features**:
- File-based persistence
- Complete file protection
- Metadata tracking (JSON)
- LRU eviction on disk
- Compaction support

**Storage**:
- Location: `~/Library/Caches/FuekiWallet/`
- Metadata: `metadata.json`
- Individual cache files with percent-encoded names

### 5. UserDefaults Management

#### UserDefaults Manager (`UserDefaultsManager.swift`)
**Location**: `/ios/FuekiWallet/Persistence/UserDefaults/UserDefaultsManager.swift`

**Features**:
- Type-safe accessors
- Default value registration
- Codable array/dictionary support
- Key-value observation
- Domain-based reset

#### App Settings (`AppSettings.swift`)
**Location**: `/ios/FuekiWallet/Persistence/UserDefaults/AppSettings.swift`

**Purpose**: SwiftUI-friendly ObservableObject wrapper

**Features**:
- @Published properties for reactive UI
- Automatic UserDefaults synchronization
- Computed properties (shouldShowBackupReminder)
- Settings export/import

### 6. Migration System

#### Migration Manager (`MigrationManager.swift`)
**Location**: `/ios/FuekiWallet/Persistence/Migrations/MigrationManager.swift`

**Features**:
- Progressive migration support
- Automatic backup before migration
- Version detection
- Rollback capability
- Custom mapping model support

**Process**:
1. Check if migration needed
2. Create backup of current store
3. Load source and destination models
4. Create/infer mapping model
5. Perform migration to temporary location
6. Replace original store with migrated version

#### Migration v1 → v2 (`Migration_v1_to_v2.swift`)
**Location**: `/ios/FuekiWallet/Persistence/Migrations/Migration_v1_to_v2.swift`

**Changes**:
- Added `metadata` field to Transaction entity
- Added `isEnabled`, `priceUSD`, `lastPriceUpdate` to Asset entity
- Added `type` field to Wallet entity

**Custom Policies**:
- `WalletMigrationPolicy`: Sets default type = "imported"
- `AssetMigrationPolicy`: Initializes new fields with defaults
- `TransactionMigrationPolicy`: Creates empty metadata dictionary

### 7. Database Models

#### Entity Definitions (`DatabaseModels.swift`)
**Location**: `/ios/FuekiWallet/Persistence/DatabaseModels.swift`

**Entities**:

1. **WalletEntity**
   - Properties: id, name, address, type, balance, isActive, createdAt, updatedAt
   - Relationships: assets (1:many), transactions (1:many)

2. **TransactionEntity**
   - Properties: id, hash, fromAddress, toAddress, amount, fee, type, status, confirmations, timestamp, confirmedAt, metadata
   - Relationships: wallet (many:1)

3. **AssetEntity**
   - Properties: id, symbol, name, contractAddress, decimals, balance, priceUSD, lastPriceUpdate, isEnabled, metadata, createdAt, updatedAt
   - Relationships: wallet (many:1)

4. **ContactEntity**
   - Properties: id, name, address, note, createdAt, updatedAt
   - No relationships

**Indexing Strategy**:
- Primary keys (id) on all entities
- address on WalletEntity
- hash, timestamp on TransactionEntity
- symbol, contractAddress on AssetEntity
- name, address on ContactEntity

## Data Flow

### Write Operations
```
User Action
  ↓
Repository (validation)
  ↓
Core Data Context (in-memory changes)
  ↓
Save Operation
  ↓
Persistent Store (SQLite)
  ↓
Cache Invalidation
```

### Read Operations
```
Repository Query
  ↓
Check Memory Cache → Hit? Return
  ↓ Miss
Check Disk Cache → Hit? Promote to Memory, Return
  ↓ Miss
Core Data Fetch
  ↓
Cache Result (both tiers)
  ↓
Return to Caller
```

## Performance Optimizations

### 1. Batch Operations
- Use batch insert/update/delete for bulk operations
- Reduces context save overhead
- Bypasses change tracking for better performance

### 2. Background Context
- Heavy operations execute on background threads
- Prevents UI blocking
- Automatic merging to view context

### 3. Caching Strategy
- Hot data in memory (wallets, recent transactions)
- Warm data on disk (historical data, images)
- Cold data in Core Data (complete history)

### 4. Query Optimization
- Strategic indexing on frequently queried fields
- Fetch request batching
- Predicate optimization
- Sort descriptor efficiency

### 5. Memory Management
- Automatic fault management
- Batch faulting for relationships
- Context reset on low memory

## Security Features

### 1. File Protection
- Complete file protection on SQLite store
- Encrypted at rest when device locked

### 2. Keychain Integration
- Private keys stored in Keychain (not Core Data)
- Secure enclave support for biometric keys

### 3. Data Validation
- Input sanitization in repositories
- Type-safe operations
- Constraint enforcement

### 4. Access Control
- Repository pattern enforces business logic
- No direct Core Data access from UI

## Error Handling

### PersistenceError Types
```swift
enum PersistenceError: LocalizedError {
  case saveFailed(Error)
  case fetchFailed(Error)
  case deleteFailed(Error)
  case batchOperationFailed(Error)
  case resetFailed(Error)
  case migrationFailed(Error)
}
```

### Recovery Strategies
1. **Save Failures**: Retry with exponential backoff
2. **Fetch Failures**: Return cached data if available
3. **Migration Failures**: Rollback to backup
4. **Corruption**: Offer data export and fresh start

## Testing Strategies

### Unit Tests
- Repository CRUD operations
- Cache hit/miss scenarios
- Migration version detection
- Settings persistence

### Integration Tests
- Multi-repository transactions
- Cache coherence
- Background sync
- Import/export round-trips

### Performance Tests
- Batch operation speed
- Cache effectiveness
- Query optimization
- Memory usage under load

## Future Enhancements

### Planned Features
1. **iCloud Sync**: CloudKit integration for multi-device sync
2. **Encryption**: Field-level encryption for sensitive data
3. **Compression**: ZSTD compression for large datasets
4. **Archiving**: Automatic archiving of old transactions
5. **Analytics**: Query performance monitoring
6. **Conflict Resolution**: Multi-device sync conflict handling

### Scalability Improvements
1. **Pagination**: Cursor-based pagination for large datasets
2. **Streaming**: Streaming query results for memory efficiency
3. **Partitioning**: Date-based partitioning for transactions
4. **Denormalization**: Strategic denormalization for read-heavy operations

## Usage Examples

### Creating a Wallet
```swift
let repository = WalletRepository(context: context, cache: cache)
let wallet = try repository.create(
  name: "My Wallet",
  address: "0x1234...",
  privateKey: "0xabcd...",
  type: .imported
)
```

### Fetching Transactions
```swift
let repository = TransactionRepository(context: context, cache: cache)
let transactions = try repository.fetchTransactions(for: wallet, limit: 50)
```

### Batch Balance Update
```swift
let updates = [(walletId1, 1.5), (walletId2, 0.8), (walletId3, 2.3)]
try await repository.batchUpdateBalances(updates)
```

### Cache Usage
```swift
let cache = CacheManager.shared
cache.set(walletData, key: "wallet_123", ttl: 300)
if let cached: WalletData = cache.get(key: "wallet_123") {
  // Use cached data
}
```

## Maintenance Tasks

### Regular Maintenance
1. **Daily**: Remove expired cache entries
2. **Weekly**: Optimize database (VACUUM)
3. **Monthly**: Archive old transactions
4. **On Upgrade**: Check and perform migrations

### Health Checks
- Monitor cache hit rates
- Track database size growth
- Measure query performance
- Detect and handle corruption

---

**Implementation Date**: 2025-10-22
**Schema Version**: 2
**Agent**: Data Persistence Engineer
**Hive Session**: swarm-1761105509434-sbjf7eq65
