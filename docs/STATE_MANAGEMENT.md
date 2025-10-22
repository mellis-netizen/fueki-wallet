# State Management Architecture - Fueki Mobile Wallet

## Overview

The Fueki Mobile Wallet implements a comprehensive state management system built on SwiftUI's Combine framework with robust persistence, synchronization, and error recovery capabilities.

## Architecture

### Core Components

```
src/state/
├── stores/              # State stores
│   ├── AppState.swift          # Global application state
│   ├── AuthState.swift         # Authentication state
│   ├── WalletState.swift       # Wallet and balance state
│   ├── TransactionState.swift  # Transaction history state
│   └── SettingsState.swift     # User preferences state
├── StateManager.swift          # State orchestration
├── StateRecovery.swift         # Error recovery
├── middleware/                 # Middleware system
│   ├── StateMiddleware.swift   # Middleware handlers
│   └── StateLogger.swift       # Logging system
├── persistence/               # Persistence layer
│   └── StatePersistence.swift  # Encrypted storage
└── sync/                      # Synchronization
    └── StateSync.swift         # Online/offline sync
```

## State Stores

### 1. AppState (Global State)

**Purpose**: Central coordinator for all state management

**Published Properties**:
- `connectionState: ConnectionState` - Network connectivity
- `syncState: SyncState` - Synchronization status
- `errorState: ErrorState?` - Current error state
- `loadingState: LoadingState` - Loading indicators

**Sub-States**:
- `authState: AuthState`
- `walletState: WalletState`
- `transactionState: TransactionState`
- `settingsState: SettingsState`

**Usage**:
```swift
let appState = AppState.shared

// Monitor connection
appState.updateConnectionState(.online)

// Handle errors
appState.handleError(.networkError("Connection failed"))

// Persist state
try await appState.persistState()

// Restore state
await appState.restoreState()
```

### 2. AuthState

**Purpose**: Authentication and session management

**Published Properties**:
- `isAuthenticated: Bool`
- `currentUser: User?`
- `sessionToken: String?`
- `sessionExpiry: Date?`
- `biometricEnabled: Bool`

**Features**:
- Session timeout management
- Biometric authentication state
- Auto-logout on session expiry
- Background/foreground state handling

**Usage**:
```swift
let authState = AppState.shared.authState

// Login
authState.login(user: user, token: token, method: .google)

// Logout
authState.logout()

// Refresh session
authState.refreshSession(token: newToken)
```

### 3. WalletState

**Purpose**: Multi-wallet and balance management

**Published Properties**:
- `wallets: [Wallet]`
- `activeWallet: Wallet?`
- `balances: [String: Balance]`
- `totalValue: Decimal`
- `preferredCurrency: Currency`

**Features**:
- Multi-wallet support
- Real-time balance updates (30s interval)
- Automatic balance refresh
- Currency conversion
- Asset management

**Usage**:
```swift
let walletState = AppState.shared.walletState

// Add wallet
walletState.addWallet(wallet)

// Refresh balances
await walletState.refreshBalances()

// Update balance
walletState.updateBalance(assetId: "btc", balance: balance)

// Change currency
walletState.setPreferredCurrency(.eur)
```

### 4. TransactionState

**Purpose**: Transaction history and pending transaction tracking

**Published Properties**:
- `transactions: [Transaction]`
- `pendingTransactions: [Transaction]`
- `recentTransactions: [Transaction]`
- `isLoadingHistory: Bool`

**Features**:
- Pagination support
- Transaction filtering
- Pending transaction monitoring
- Search functionality

**Usage**:
```swift
let txState = AppState.shared.transactionState

// Add transaction
txState.addTransaction(transaction)

// Load history
await txState.loadTransactionHistory(walletAddress: address)

// Filter transactions
let pending = txState.getTransactions(status: .pending)

// Search
let results = txState.searchTransactions(query: "0x123")
```

### 5. SettingsState

**Purpose**: User preferences and app configuration

**Published Properties**:
- `biometricEnabled: Bool`
- `currency: Currency`
- `language: AppLanguage`
- `theme: AppTheme`
- `autoLockTimeout: TimeInterval`

**Features**:
- Auto-save to UserDefaults
- Security settings
- Network preferences
- Custom RPC endpoints

**Usage**:
```swift
let settings = AppState.shared.settingsState

// Update settings
settings.updateCurrency(.usd)
settings.updateTheme(.dark)
settings.updateAutoLock(enabled: true, timeout: 300)

// Security
settings.updateSecuritySettings(
    requireBiometric: true,
    maxAmount: 1000
)
```

## State Management

### StateManager

**Purpose**: Orchestrate state mutations with middleware

**Features**:
- Action logging
- Performance tracking
- State history
- Undo/redo support

**Usage**:
```swift
let manager = StateManager.shared

// Execute state mutation
try await manager.execute(
    StateAction(name: "login", category: .auth)
) {
    authState.login(user: user, token: token, method: .email)
}

// Get metrics
let metrics = manager.getPerformanceMetrics()

// Undo last action
await manager.undoLastAction()
```

### Middleware System

**Built-in Middleware**:
1. **LoggingMiddleware** - Logs all state changes
2. **ValidationMiddleware** - Validates actions before execution
3. **PerformanceMiddleware** - Tracks performance metrics
4. **ErrorHandlingMiddleware** - Circuit breaker pattern

**Custom Middleware**:
```swift
class CustomMiddleware: MiddlewareHandler {
    func preExecution(_ action: StateAction) async throws {
        // Pre-execution logic
    }

    func postExecution(_ action: StateAction, duration: TimeInterval, success: Bool) async {
        // Post-execution logic
    }
}

// Register
StateMiddleware.shared.register(CustomMiddleware())
```

## State Persistence

### StatePersistence

**Features**:
- AES-256 encryption
- Automatic backups
- Backup rotation (keep last 10)
- State restoration

**Usage**:
```swift
let persistence = StatePersistence.shared

// Save state
try await persistence.saveAppState(snapshot)

// Restore state
let snapshot = try await persistence.restoreAppState()

// Create backup
try await persistence.createBackup()

// Restore from backup
try await persistence.restoreFromBackup()

// List backups
let backups = try persistence.listBackups()
```

## State Synchronization

### StateSync

**Features**:
- Network monitoring
- Offline queue
- Auto-sync on reconnection
- Configurable sync strategies

**Sync Strategies**:
- `.immediate` - Sync immediately when online
- `.scheduled` - Sync on schedule
- `.adaptive` - Adapt based on network
- `.manual` - Only sync when requested

**Usage**:
```swift
let sync = StateSync.shared

// Sync all states
try await sync.syncAllStates()

// Queue offline operation
sync.queueOperation(operation)

// Set strategy
sync.setSyncStrategy(.adaptive)
```

## State Recovery

### StateRecovery

**Features**:
- Automatic error recovery
- Circuit breaker pattern
- State validation
- Backup restoration

**Recovery Strategies**:
- `.retry(maxAttempts:delay:)` - Retry with exponential backoff
- `.restoreFromBackup` - Restore from last backup
- `.queueAndRetry` - Queue for later retry
- `.resetInvalidState` - Reset corrupted state

**Usage**:
```swift
let recovery = StateRecovery.shared

// Attempt recovery
let result = await recovery.attemptRecovery(
    from: error,
    context: context
)

// Validate state
let validation = await recovery.validateStateIntegrity()

// Recover from corruption
let success = await recovery.recoverFromCorruptedState()
```

## Integration with ViewModels

### Example: AuthenticationViewModel

```swift
@MainActor
class AuthenticationViewModel: ObservableObject {
    private let appState = AppState.shared
    private let stateManager = StateManager.shared

    func login(email: String, password: String) async {
        let user = try await authService.login(email, password)

        // Update state through manager
        await stateManager.execute(
            StateAction(name: "login", category: .auth)
        ) {
            appState.authState.login(
                user: user,
                token: token,
                method: .email
            )
        }
    }

    private func syncWithAppState() {
        // Observe state changes
        appState.authState.$isAuthenticated
            .sink { [weak self] isAuth in
                self?.isAuthenticated = isAuth
            }
            .store(in: &cancellables)
    }
}
```

## Best Practices

### 1. State Updates
- Always use `StateManager.execute()` for mutations
- Keep state updates atomic
- Avoid nested state updates

### 2. Error Handling
- Use `AppState.handleError()` for centralized error handling
- Implement recovery strategies
- Log all errors

### 3. Performance
- Use debouncing for frequent updates
- Batch related state changes
- Monitor performance metrics

### 4. Persistence
- Auto-save on state changes (debounced)
- Create periodic backups
- Validate restored state

### 5. Testing
- Test state transitions
- Mock persistence layer
- Verify error recovery

## Notifications

### System Notifications
- `.networkStatusChanged` - Connection state changed
- `.stateDidChange` - Any state changed
- `.syncDidComplete` - Sync completed
- `.authStateChanged` - Auth state changed
- `.walletStateChanged` - Wallet state changed
- `.transactionStateChanged` - Transaction state changed
- `.settingsStateChanged` - Settings changed

## Performance Considerations

### Optimization Strategies
1. **Debouncing**: Auto-save debounced to 1 second
2. **Pagination**: Transaction history loaded in pages
3. **Lazy Loading**: Heavy operations deferred
4. **Caching**: Balance updates cached for 30s
5. **Background Processing**: Network monitoring on background queue

### Memory Management
- Limit state history to 50 snapshots
- Limit log size to 500 entries
- Trim sync queue to 100 operations
- Clean old backups (keep 10)

## Security

### Encryption
- State files encrypted with AES-256-GCM
- Encryption key stored in Keychain
- Secure key generation

### Session Management
- Automatic session timeout
- Background/foreground handling
- Biometric authentication support

## Troubleshooting

### Common Issues

**State not persisting**:
- Check file permissions
- Verify encryption key in Keychain
- Review persistence logs

**Sync not working**:
- Verify network connection
- Check sync queue
- Review sync logs

**Performance issues**:
- Check performance metrics
- Review slow actions
- Optimize frequent updates

## Future Enhancements

1. **Cloud Sync** - Sync state across devices
2. **State Migration** - Version migration system
3. **Undo/Redo** - Full undo/redo stack
4. **State Snapshots** - Manual snapshot creation
5. **Analytics** - Enhanced state analytics

## References

- [Combine Framework](https://developer.apple.com/documentation/combine)
- [SwiftUI State Management](https://developer.apple.com/documentation/swiftui/state-and-data-flow)
- [CryptoKit](https://developer.apple.com/documentation/cryptokit)
