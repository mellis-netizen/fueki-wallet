# State Management Architecture

## Overview
Redux-inspired state management system for predictable, unidirectional data flow in Fueki Wallet.

## Core Principles

### 1. Single Source of Truth
- **AppState**: Root state containing all app data
- **Store**: Single store instance managing entire state tree
- **Immutability**: State is never mutated directly

### 2. Unidirectional Data Flow
```
Action → Reducer → State → View
    ↑                        ↓
    └────── User Interaction ─┘
```

### 3. Pure Functions
- **Reducers**: Pure functions that produce new state
- **Selectors**: Pure functions that derive data from state
- **No side effects**: All side effects handled in middleware

## Architecture Components

### State Structure
```
AppState
├── WalletState
│   ├── accounts: [WalletAccount]
│   ├── selectedAccountId: String?
│   ├── balance: Balance
│   ├── isLoading: Bool
│   └── error: ErrorState?
├── TransactionState
│   ├── pending: [Transaction]
│   ├── confirmed: [Transaction]
│   ├── failed: [Transaction]
│   ├── filter: TransactionFilter
│   └── ...
├── SettingsState
│   ├── currency: Currency
│   ├── language: Language
│   ├── theme: Theme
│   └── ...
├── AuthState
│   ├── isAuthenticated: Bool
│   ├── isLocked: Bool
│   ├── sessionExpiry: Date?
│   └── ...
└── UIState
    ├── activeSheet: SheetType?
    ├── activeAlert: AlertType?
    └── ...
```

### Actions
```
WalletAction
├── createAccount(name: String)
├── accountCreated(account: WalletAccount)
├── fetchBalance
├── balanceFetched(balance: Balance)
└── ...

TransactionAction
├── fetchTransactions
├── transactionsFetched(transactions: [Transaction])
├── createTransaction(...)
└── ...

SettingsAction
├── setCurrency(Currency)
├── setTheme(Theme)
└── ...

AuthAction
├── authenticate(method: AuthMethod)
├── authenticationSucceeded(...)
├── lock/unlock
└── ...
```

### Reducers
- **appReducer**: Root reducer combining all sub-reducers
- **walletReducer**: Handles wallet state changes
- **transactionReducer**: Handles transaction state changes
- **settingsReducer**: Handles settings state changes
- **authReducer**: Handles authentication state changes

### Middleware
1. **LoggingMiddleware**: Logs all actions and state changes
2. **AnalyticsMiddleware**: Tracks user actions for analytics
3. **PersistenceMiddleware**: Automatically saves state to disk

### Selectors
- **WalletSelectors**: Derive wallet-related data
- **TransactionSelectors**: Derive transaction-related data
- Memoized for performance
- Composable for complex queries

## Key Features

### Time-Travel Debugging
```swift
// Enable time-travel
store.enableTimeTravel(true)

// Rewind to previous state
store.rewindToState(at: 5)

// View history
let history = store.getStateHistory()
```

### State Persistence
```swift
// Automatic persistence via middleware
// Manual save/load
StatePersistence.shared.saveState(state)
let state = StatePersistence.shared.loadState()

// Backups
let backupURL = StatePersistence.shared.createBackup()
StatePersistence.shared.restoreFromBackup(url: backupURL)
```

### State Snapshots
```swift
// Create snapshot
StateSnapshotManager.shared.createSnapshot(state: state, name: "before_migration")

// Load snapshot
let snapshot = StateSnapshotManager.shared.loadSnapshot(from: url)

// List all snapshots
let snapshots = StateSnapshotManager.shared.listSnapshots()
```

### Advanced Logging
```swift
// Get detailed logs
let logs = StateLogger.shared.getLogs(type: .action, limit: 100)

// Export logs
let logsURL = StateLogger.shared.exportLogs()

// Print summary
StateLogger.shared.printSummary()
```

## Usage Patterns

### Dispatching Actions
```swift
// Single action
AppStore.shared.dispatch(WalletAction.fetchBalance)

// Batch actions
AppStore.shared.batchDispatch([
    WalletAction.fetchBalance,
    TransactionAction.fetchTransactions
])
```

### Observing State
```swift
// Observe entire state
AppStore.shared.observeState()
    .sink { state in
        // Handle state change
    }

// Observe specific slice
AppStore.shared.observe(\.wallet.balance)
    .sink { balance in
        // Handle balance change
    }

// Convenience observers
AppStore.shared.observeWallet()
    .sink { walletState in
        // Handle wallet state change
    }
```

### Using Selectors
```swift
// Get derived data
let selectedAccount = WalletSelectors.selectedAccount(from: state)
let recentTransactions = TransactionSelectors.recentTransactions(limit: 10)(state)

// Chain selectors
let accountsWithBalance = WalletSelectors.accountsWithMinimumBalance(100)(state)
```

### SwiftUI Integration
```swift
struct WalletView: View {
    @ObservedObject var store = AppStore.shared

    var body: some View {
        VStack {
            Text(store.state.wallet.balance.formattedAmount)

            Button("Fetch Balance") {
                store.dispatch(WalletAction.fetchBalance)
            }
        }
    }
}
```

## Thread Safety

### Queue-Based Synchronization
- All state updates happen on dedicated queue
- Published state updates on main thread
- Thread-safe read access via selectors

### Concurrent Access
```swift
// Safe concurrent reads
let balance = store.state.wallet.balance
let transactions = store.state.transactions.pending

// Safe concurrent writes (serialized)
store.dispatch(WalletAction.updateBalance(...))
store.dispatch(TransactionAction.createTransaction(...))
```

## Performance Optimizations

### 1. Selector Memoization
- Selectors compute derived data once
- Cached until state changes
- Use `removeDuplicates()` in Combine

### 2. Batch Updates
- Batch multiple actions together
- Reduces number of state updates
- Better performance for bulk operations

### 3. Lazy State Access
- State only published when changed
- KeyPath-based observation
- Minimal re-renders in SwiftUI

## Best Practices

### 1. Action Design
- Use descriptive action names
- Include all necessary data in actions
- Separate request/success/failure actions

### 2. Reducer Design
- Keep reducers pure and simple
- No side effects in reducers
- Handle all action cases

### 3. Selector Design
- Keep selectors composable
- Use selectors for all derived data
- Avoid complex logic in views

### 4. Middleware Usage
- Use middleware for side effects
- Keep middleware focused and single-purpose
- Return new actions from middleware if needed

### 5. State Structure
- Keep state normalized
- Avoid deep nesting
- Use IDs for relationships

## Testing

### Unit Testing Reducers
```swift
func testWalletReducer() {
    var state = WalletState()
    let action = WalletAction.accountCreated(account: mockAccount)

    walletReducer(state: &state, action: action)

    XCTAssertEqual(state.accounts.count, 1)
    XCTAssertEqual(state.accounts[0].id, mockAccount.id)
}
```

### Testing Selectors
```swift
func testSelectedAccountSelector() {
    let state = AppState(wallet: mockWalletState)
    let account = WalletSelectors.selectedAccount(from: state)

    XCTAssertNotNil(account)
    XCTAssertEqual(account?.id, "test-id")
}
```

### Integration Testing
```swift
func testStoreIntegration() {
    let store = Store(initialState: AppState.initial, reducer: appReducer)

    let expectation = XCTestExpectation(description: "State updated")

    store.observe(\.wallet.accounts.count)
        .sink { count in
            if count == 1 {
                expectation.fulfill()
            }
        }
        .store(in: &cancellables)

    store.dispatch(WalletAction.createAccount(name: "Test"))

    wait(for: [expectation], timeout: 1.0)
}
```

## Migration Strategy

### Version Compatibility
- State schema version tracking
- Automatic migration between versions
- Backward compatibility support

### Data Migration
```swift
func migrateState(from: AppState, version: Int) -> AppState {
    var state = from

    switch version {
    case 1:
        // Migrate from v1 to v2
        state = migrateV1ToV2(state)
    case 2:
        // Migrate from v2 to v3
        state = migrateV2ToV3(state)
    default:
        break
    }

    return state
}
```

## Error Handling

### Error State
- All errors stored in `ErrorState`
- Includes error code, message, timestamp
- Recoverable vs non-recoverable errors

### Error Recovery
```swift
// Automatic retry in middleware
if action is WalletAction.fetchBalance,
   state.wallet.error?.recoverable == true {
    return Just(WalletAction.fetchBalance)
        .delay(for: .seconds(5), scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
}
```

## Metrics and Monitoring

### Performance Metrics
- Action processing time
- State update frequency
- Memory usage
- Persistence latency

### Analytics Events
- User actions tracked
- State transitions logged
- Error occurrences monitored
