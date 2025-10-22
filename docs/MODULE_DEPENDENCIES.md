# Fueki Wallet - Module Dependencies

## Dependency Graph

This document details the exact dependencies between modules to ensure proper layering and prevent circular dependencies.

## Layer Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│ Layer 4: UI (Presentation)                                        │
│ Dependencies: Services, State, Utils                              │
└──────────────────────────────────────────────────────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│ Layer 3: Services (Application Logic)                            │
│ Dependencies: Core, Blockchain, State, Utils                     │
└──────────────────────────────────────────────────────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│ Layer 2: Core Business Logic                                     │
│ Dependencies: Blockchain, Utils                                  │
└──────────────────────────────────────────────────────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│ Layer 1: Blockchain Adapters                                     │
│ Dependencies: Utils only                                         │
└──────────────────────────────────────────────────────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────────┐
│ Layer 0: Utilities & Configuration                               │
│ Dependencies: None                                               │
└──────────────────────────────────────────────────────────────────┘
```

## Detailed Module Dependencies

### UI Layer

#### screens/
**Imports from:**
- `ui/components/*` - UI components
- `ui/navigation/*` - Navigation helpers
- `state/slices/*` - Redux actions/selectors
- `services/auth/*` - Authentication services
- `services/network/*` - Network services
- `utils/*` - Utility functions

**Exports:**
- Screen components (WalletScreen, SendScreen, etc.)

**No imports from:**
- `core/*` - Business logic should go through services
- `chains/*` - Chain operations should go through services

#### components/
**Imports from:**
- `state/selectors/*` - State selectors
- `utils/formatting.ts` - Display formatting
- `utils/validation.ts` - Input validation

**Exports:**
- Reusable UI components

**No imports from:**
- `services/*` - Components should be pure, connected in screens
- `core/*`
- `chains/*`

### Services Layer

#### services/auth/
**Imports from:**
- `core/crypto/KeyManager` - Key operations
- `core/storage/SecureStorage` - Secure storage
- `utils/errors` - Error types

**Exports:**
- `BiometricService` - Biometric authentication
- `PINService` - PIN management
- `AuthManager` - Auth orchestration

#### services/network/
**Imports from:**
- `chains/base/IBlockchainAdapter` - Blockchain interface
- `config/rpcs` - RPC configuration
- `utils/logger` - Logging

**Exports:**
- `RPCManager` - RPC connection management
- `NetworkMonitor` - Connection monitoring
- `FallbackHandler` - Automatic failover

#### services/price/
**Imports from:**
- `config/app` - App configuration
- `utils/logger` - Logging

**Exports:**
- `PriceService` - Price feed
- `CurrencyConverter` - Fiat conversion

### Core Layer

#### core/wallet/
**Imports from:**
- `core/crypto/KeyManager` - Key operations
- `core/storage/SecureStorage` - Storage
- `chains/base/IBlockchainAdapter` - Chain interface
- `utils/validation` - Validation

**Exports:**
- `WalletManager` - Main wallet coordinator
- `AccountManager` - Account management
- `BalanceTracker` - Balance tracking

**No circular dependencies with:**
- `services/*` - Services depend on core, not vice versa

#### core/crypto/
**Imports from:**
- `utils/errors` - Error types
- External: `@scure/bip39`, `@noble/secp256k1`

**Exports:**
- `KeyManager` - Key generation/derivation
- `Mnemonic` - BIP-39 operations
- `Signer` - Transaction signing
- `Encryptor` - Encryption utilities

**No dependencies on:**
- Any internal modules except utils

#### core/transactions/
**Imports from:**
- `chains/base/IBlockchainAdapter` - Chain interface
- `core/crypto/Signer` - Signing operations
- `utils/validation` - Validation

**Exports:**
- `TransactionBuilder` - Build transactions
- `TransactionBroadcaster` - Broadcast transactions
- `FeeEstimator` - Fee calculation
- `TransactionHistory` - History tracking

#### core/storage/
**Imports from:**
- `core/crypto/Encryptor` - Encryption
- External: `react-native-mmkv`, `@nozbe/watermelondb`

**Exports:**
- `SecureStorage` - Encrypted storage
- `Cache` - In-memory cache
- `Database` - SQLite wrapper

**No dependencies on:**
- Other core modules (lowest level of core)

### Blockchain Layer

#### chains/base/
**Imports from:**
- `utils/errors` - Error types
- `utils/logger` - Logging

**Exports:**
- `IBlockchainAdapter` - Abstract interface
- `BaseAdapter` - Common functionality
- Types and interfaces

**No dependencies on:**
- Any higher-level modules

#### chains/ethereum/
**Imports from:**
- `chains/base/IBlockchainAdapter` - Base interface
- `chains/base/BaseAdapter` - Common functionality
- `utils/*` - Utilities
- External: `ethers`

**Exports:**
- `EthereumAdapter` - Ethereum implementation
- `EthereumRPC` - RPC client
- `ERC20Handler` - Token support
- `GasEstimator` - Gas estimation

#### chains/bitcoin/
**Imports from:**
- `chains/base/IBlockchainAdapter` - Base interface
- `chains/base/BaseAdapter` - Common functionality
- `utils/*` - Utilities
- External: `bitcoinjs-lib`, `bip32`

**Exports:**
- `BitcoinAdapter` - Bitcoin implementation
- `UTXOManager` - UTXO selection
- `AddressGenerator` - Address formats
- `FeeCalculator` - Fee estimation

#### chains/solana/
**Imports from:**
- `chains/base/IBlockchainAdapter` - Base interface
- `chains/base/BaseAdapter` - Common functionality
- `utils/*` - Utilities
- External: `@solana/web3.js`

**Exports:**
- `SolanaAdapter` - Solana implementation
- `SolanaRPC` - RPC client
- `SPLTokenHandler` - Token support
- `PriorityFeeEstimator` - Fee estimation

### State Layer

#### state/store.ts
**Imports from:**
- `state/slices/*` - All slices
- `state/middleware/*` - Middleware
- External: `@reduxjs/toolkit`

**Exports:**
- Redux store
- RootState type
- AppDispatch type

#### state/slices/
**Imports from:**
- `types/*` - Type definitions
- External: `@reduxjs/toolkit`

**Exports:**
- Slice reducers
- Actions
- Selectors

**No dependencies on:**
- `services/*` - Thunks call services, but slices don't import them directly
- `core/*`
- `chains/*`

#### state/middleware/
**Imports from:**
- `core/storage/SecureStorage` - For persistence
- `core/crypto/Encryptor` - For encryption

**Exports:**
- `persistMiddleware` - State persistence
- `encryptionMiddleware` - State encryption

### Utils Layer

#### utils/*
**Imports from:**
- External libraries only

**Exports:**
- `validation.ts` - Input validation
- `formatting.ts` - Display formatting
- `constants.ts` - App constants
- `logger.ts` - Logging utility
- `errors.ts` - Error definitions

**No dependencies on:**
- Any internal modules (pure utilities)

## Import Rules

### ✅ Allowed Patterns

```typescript
// UI importing from Services
import { AuthManager } from '@/services/auth/AuthManager';

// Services importing from Core
import { WalletManager } from '@/core/wallet/WalletManager';

// Core importing from Blockchain
import { IBlockchainAdapter } from '@/chains/base/IBlockchainAdapter';

// Any layer importing from Utils
import { formatAddress } from '@/utils/formatting';

// State importing types
import { Wallet } from '@/types/wallet.types';
```

### ❌ Forbidden Patterns

```typescript
// Core importing from Services (upward dependency)
import { AuthManager } from '@/services/auth/AuthManager'; // ❌

// Blockchain importing from Core (upward dependency)
import { WalletManager } from '@/core/wallet/WalletManager'; // ❌

// Utils importing from anything (should be pure)
import { SecureStorage } from '@/core/storage/SecureStorage'; // ❌

// Components importing from Services (should go through screens)
import { AuthManager } from '@/services/auth/AuthManager'; // ❌
```

## Dependency Injection

To maintain proper layering and testability, use dependency injection:

```typescript
// ✅ Good: Inject dependencies
class WalletManager {
  constructor(
    private keyManager: KeyManager,
    private storage: SecureStorage,
    private chainAdapter: IBlockchainAdapter
  ) {}
}

// ❌ Bad: Direct instantiation creates tight coupling
class WalletManager {
  private keyManager = new KeyManager();
  private storage = new SecureStorage();
}
```

## Module Initialization Order

1. **Config & Utils** - Load configuration, initialize logging
2. **Storage** - Initialize secure storage and database
3. **Crypto** - Initialize crypto utilities
4. **Blockchain** - Initialize chain adapters
5. **Core** - Initialize wallet manager and services
6. **Services** - Initialize application services
7. **State** - Initialize Redux store with persisted state
8. **UI** - Render application

## Testing Dependencies

```
Unit Tests
└── Mock all external dependencies
    └── Use dependency injection
        └── Test pure logic in isolation

Integration Tests
└── Use real implementations
    └── Mock only external APIs (RPC, price feeds)
        └── Test component interactions

E2E Tests
└── Use real app build
    └── Test against testnet
        └── Verify complete user flows
```

## Circular Dependency Prevention

**Automatic Detection:**
```json
// package.json
{
  "scripts": {
    "check-deps": "madge --circular --extensions ts,tsx src/"
  }
}
```

**Pre-commit Hook:**
```bash
#!/bin/bash
npm run check-deps
if [ $? -ne 0 ]; then
  echo "❌ Circular dependencies detected!"
  exit 1
fi
```

## External Dependencies

### Production Dependencies (package.json)

```json
{
  "dependencies": {
    // Framework
    "react": "18.2.0",
    "react-native": "0.73.0",

    // State Management
    "@reduxjs/toolkit": "2.0.0",
    "react-redux": "9.0.0",

    // Navigation
    "@react-navigation/native": "6.1.0",
    "@react-navigation/stack": "6.3.0",
    "@react-navigation/bottom-tabs": "6.5.0",

    // Blockchain Libraries
    "ethers": "6.9.0",
    "@ethereumjs/tx": "5.0.0",
    "bitcoinjs-lib": "6.1.0",
    "bip32": "4.0.0",
    "@solana/web3.js": "1.87.0",
    "@scure/bip39": "1.2.0",
    "@noble/hashes": "1.3.0",
    "@noble/secp256k1": "2.0.0",

    // Security
    "react-native-keychain": "8.1.0",
    "react-native-biometrics": "3.0.0",
    "react-native-get-random-values": "1.9.0",
    "crypto-js": "4.2.0",

    // Storage
    "react-native-mmkv": "2.11.0",
    "@nozbe/watermelondb": "0.27.0",

    // UI
    "react-native-paper": "5.11.0",
    "react-native-vector-icons": "10.0.0",
    "react-native-camera": "4.2.0",
    "react-native-qrcode-svg": "6.2.0",
    "react-native-reanimated": "3.6.0",
    "react-native-gesture-handler": "2.14.0",
    "react-native-safe-area-context": "4.8.0",

    // Networking
    "axios": "1.6.0",

    // Utilities
    "buffer": "6.0.3"
  }
}
```

## Dependency Update Strategy

1. **Security Updates**: Apply immediately
2. **Patch Updates**: Apply weekly
3. **Minor Updates**: Apply monthly with testing
4. **Major Updates**: Quarterly, with full regression testing

## Bundle Analysis

```bash
# Analyze bundle size
npx react-native-bundle-visualizer

# Check for duplicate dependencies
npm dedupe

# Audit dependencies
npm audit
```
