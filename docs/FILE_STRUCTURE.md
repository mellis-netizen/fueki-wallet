# Fueki Mobile Wallet - Complete File Structure

## Overview

This document provides the complete file and directory structure for the Fueki Mobile Crypto Wallet application.

---

## Root Directory Structure

```
Fueki-Mobile-Wallet/
├── android/                    # Android native code
├── ios/                        # iOS native code
├── src/                        # Application source code
├── assets/                     # Static assets (images, fonts)
├── __tests__/                  # Test files
├── docs/                       # Documentation
├── scripts/                    # Build and utility scripts
├── .github/                    # GitHub workflows
├── config/                     # Configuration files
├── .env.example                # Environment variables template
├── .eslintrc.js               # ESLint configuration
├── .prettierrc.js             # Prettier configuration
├── .gitignore                 # Git ignore rules
├── .watchmanconfig            # Watchman configuration
├── app.json                   # React Native app configuration
├── babel.config.js            # Babel configuration
├── index.js                   # Entry point
├── metro.config.js            # Metro bundler configuration
├── package.json               # Dependencies and scripts
├── tsconfig.json              # TypeScript configuration
└── README.md                  # Project README
```

---

## Android Directory (`android/`)

```
android/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/fueki/
│   │   │   │   ├── MainActivity.java
│   │   │   │   ├── MainApplication.java
│   │   │   │   └── modules/
│   │   │   │       ├── KeystoreModule.java          # Android Keystore bridge
│   │   │   │       ├── BiometricModule.java         # Biometric auth bridge
│   │   │   │       └── SecurityModule.java          # Security checks
│   │   │   ├── res/
│   │   │   │   ├── drawable/                        # App icons
│   │   │   │   ├── mipmap-*/                        # Launcher icons
│   │   │   │   ├── values/
│   │   │   │   │   ├── strings.xml
│   │   │   │   │   ├── styles.xml
│   │   │   │   │   └── colors.xml
│   │   │   │   └── xml/
│   │   │   │       └── network_security_config.xml  # SSL pinning
│   │   │   └── AndroidManifest.xml
│   │   └── debug/
│   │       └── AndroidManifest.xml
│   ├── build.gradle                                 # App build configuration
│   └── proguard-rules.pro                          # ProGuard configuration
├── gradle/
│   └── wrapper/
│       └── gradle-wrapper.properties
├── build.gradle                                    # Project build configuration
├── gradle.properties                               # Gradle properties
└── settings.gradle                                 # Project settings
```

---

## iOS Directory (`ios/`)

```
ios/
├── Fueki/
│   ├── AppDelegate.h
│   ├── AppDelegate.mm
│   ├── Info.plist                                  # App configuration
│   ├── LaunchScreen.storyboard                     # Splash screen
│   ├── Images.xcassets/                            # App icons and images
│   │   └── AppIcon.appiconset/
│   ├── Modules/
│   │   ├── KeychainModule.h/.m                     # iOS Keychain bridge
│   │   ├── BiometricModule.h/.m                    # Biometric auth bridge
│   │   └── SecurityModule.h/.m                     # Security checks
│   └── Fueki.entitlements                          # App capabilities
├── Fueki.xcodeproj/                                # Xcode project
│   ├── project.pbxproj
│   └── xcshareddata/
├── Fueki.xcworkspace/                              # Xcode workspace (with Pods)
├── FuekiTests/                                     # Unit tests
│   └── FuekiTests.m
├── Podfile                                         # CocoaPods dependencies
└── Podfile.lock                                    # Locked pod versions
```

---

## Source Directory (`src/`)

```
src/
├── core/                       # Core business logic
│   ├── wallet/
│   │   ├── WalletManager.ts                        # Main wallet coordinator
│   │   ├── AccountManager.ts                       # Multi-account management
│   │   ├── BalanceTracker.ts                       # Real-time balance updates
│   │   ├── WalletFactory.ts                        # Wallet creation
│   │   ├── types.ts                                # Type definitions
│   │   └── __tests__/
│   │       ├── WalletManager.test.ts
│   │       └── AccountManager.test.ts
│   │
│   ├── crypto/
│   │   ├── KeyManager.ts                           # Key generation/derivation
│   │   ├── Mnemonic.ts                             # BIP-39 implementation
│   │   ├── KeyDerivation.ts                        # BIP-32 key derivation
│   │   ├── Signer.ts                               # Transaction signing
│   │   ├── Encryptor.ts                            # Encryption utilities
│   │   ├── types.ts
│   │   └── __tests__/
│   │       ├── KeyManager.test.ts
│   │       ├── Mnemonic.test.ts
│   │       └── Signer.test.ts
│   │
│   ├── transactions/
│   │   ├── TransactionBuilder.ts                   # Build transactions
│   │   ├── TransactionBroadcaster.ts              # Broadcast to network
│   │   ├── FeeEstimator.ts                        # Dynamic fee calculation
│   │   ├── TransactionHistory.ts                  # Transaction tracking
│   │   ├── TransactionValidator.ts                # Validate transactions
│   │   ├── types.ts
│   │   └── __tests__/
│   │       └── TransactionBuilder.test.ts
│   │
│   └── storage/
│       ├── SecureStorage.ts                        # Encrypted local storage
│       ├── Cache.ts                                # In-memory cache
│       ├── Database.ts                             # WatermelonDB wrapper
│       ├── schema.ts                               # Database schema
│       ├── migrations.ts                           # Database migrations
│       └── __tests__/
│           └── SecureStorage.test.ts
│
├── chains/                     # Blockchain implementations
│   ├── base/
│   │   ├── IBlockchainAdapter.ts                   # Abstract interface
│   │   ├── BaseAdapter.ts                          # Common functionality
│   │   ├── types.ts                                # Shared types
│   │   └── __tests__/
│   │       └── BaseAdapter.test.ts
│   │
│   ├── ethereum/
│   │   ├── EthereumAdapter.ts                      # Ethereum implementation
│   │   ├── EthereumRPC.ts                          # RPC client
│   │   ├── ERC20Handler.ts                         # ERC-20 token support
│   │   ├── GasEstimator.ts                         # EIP-1559 gas estimation
│   │   ├── ABIDecoder.ts                           # Decode contract calls
│   │   ├── types.ts
│   │   └── __tests__/
│   │       ├── EthereumAdapter.test.ts
│   │       └── ERC20Handler.test.ts
│   │
│   ├── bitcoin/
│   │   ├── BitcoinAdapter.ts                       # Bitcoin implementation
│   │   ├── BitcoinRPC.ts                           # RPC client
│   │   ├── UTXOManager.ts                          # UTXO selection
│   │   ├── AddressGenerator.ts                     # Address formats
│   │   ├── FeeCalculator.ts                        # Mempool fee estimation
│   │   ├── types.ts
│   │   └── __tests__/
│   │       ├── BitcoinAdapter.test.ts
│   │       └── UTXOManager.test.ts
│   │
│   └── solana/
│       ├── SolanaAdapter.ts                        # Solana implementation
│       ├── SolanaRPC.ts                            # RPC client
│       ├── SPLTokenHandler.ts                      # SPL token support
│       ├── PriorityFeeEstimator.ts                # Dynamic compute units
│       ├── types.ts
│       └── __tests__/
│           └── SolanaAdapter.test.ts
│
├── services/                   # Application services
│   ├── auth/
│   │   ├── BiometricService.ts                     # Biometric authentication
│   │   ├── PINService.ts                           # PIN management
│   │   ├── AuthManager.ts                          # Auth coordinator
│   │   └── __tests__/
│   │       └── BiometricService.test.ts
│   │
│   ├── network/
│   │   ├── RPCManager.ts                           # RPC endpoint management
│   │   ├── NetworkMonitor.ts                       # Connection health
│   │   ├── FallbackHandler.ts                      # Automatic failover
│   │   ├── types.ts
│   │   └── __tests__/
│   │       └── RPCManager.test.ts
│   │
│   ├── price/
│   │   ├── PriceService.ts                         # Price feed aggregator
│   │   ├── CurrencyConverter.ts                    # Fiat conversion
│   │   └── __tests__/
│   │       └── PriceService.test.ts
│   │
│   └── notifications/
│       ├── NotificationService.ts                  # Push notifications
│       ├── TransactionWatcher.ts                   # Monitor pending TXs
│       └── __tests__/
│           └── NotificationService.test.ts
│
├── state/                      # State management (Redux)
│   ├── store.ts                                    # Redux store configuration
│   ├── rootReducer.ts                              # Root reducer
│   ├── hooks.ts                                    # Typed hooks
│   │
│   ├── slices/
│   │   ├── walletSlice.ts                          # Wallet state
│   │   ├── accountsSlice.ts                        # Accounts state
│   │   ├── transactionsSlice.ts                    # Transaction state
│   │   ├── settingsSlice.ts                        # User settings
│   │   ├── networkSlice.ts                         # Network state
│   │   └── __tests__/
│   │       └── walletSlice.test.ts
│   │
│   ├── middleware/
│   │   ├── persistMiddleware.ts                    # State persistence
│   │   ├── encryptionMiddleware.ts                 # Encrypt sensitive state
│   │   └── loggingMiddleware.ts                    # Redux logging
│   │
│   ├── selectors/
│   │   ├── walletSelectors.ts
│   │   ├── transactionSelectors.ts
│   │   └── __tests__/
│   │       └── walletSelectors.test.ts
│   │
│   └── thunks/
│       ├── walletThunks.ts                         # Async wallet operations
│       └── transactionThunks.ts                    # Async transaction operations
│
├── ui/                         # UI components
│   ├── screens/
│   │   ├── WalletScreen.tsx                        # Main wallet view
│   │   ├── SendScreen.tsx                          # Send transaction
│   │   ├── ReceiveScreen.tsx                       # Receive (QR code)
│   │   ├── SettingsScreen.tsx                      # App settings
│   │   ├── BackupScreen.tsx                        # Backup mnemonic
│   │   ├── RestoreScreen.tsx                       # Restore wallet
│   │   ├── TransactionDetailScreen.tsx             # Transaction details
│   │   ├── CreateWalletScreen.tsx                  # Wallet creation flow
│   │   ├── SecurityScreen.tsx                      # Security settings
│   │   └── __tests__/
│   │       └── WalletScreen.test.tsx
│   │
│   ├── components/
│   │   ├── WalletCard.tsx                          # Wallet overview card
│   │   ├── TransactionList.tsx                     # Transaction history
│   │   ├── TransactionItem.tsx                     # Single transaction
│   │   ├── QRScanner.tsx                           # QR code scanner
│   │   ├── QRDisplay.tsx                           # Display QR code
│   │   ├── NetworkSwitcher.tsx                     # Network selector
│   │   ├── TokenList.tsx                           # Token balances
│   │   ├── TokenItem.tsx                           # Single token
│   │   ├── FeeSelector.tsx                         # Transaction fee UI
│   │   ├── AddressInput.tsx                        # Address input field
│   │   ├── AmountInput.tsx                         # Amount input field
│   │   ├── Button.tsx                              # Custom button
│   │   ├── Card.tsx                                # Card container
│   │   ├── Loading.tsx                             # Loading indicator
│   │   └── __tests__/
│   │       └── WalletCard.test.tsx
│   │
│   ├── navigation/
│   │   ├── RootNavigator.tsx                       # Root navigation
│   │   ├── MainNavigator.tsx                       # Main tab navigation
│   │   ├── AuthNavigator.tsx                       # Auth flow navigation
│   │   ├── types.ts                                # Navigation types
│   │   └── linking.ts                              # Deep linking config
│   │
│   └── theme/
│       ├── colors.ts                               # Color palette
│       ├── typography.ts                           # Font styles
│       ├── spacing.ts                              # Spacing constants
│       └── theme.ts                                # Theme configuration
│
├── utils/                      # Utility functions
│   ├── validation.ts                               # Input validation
│   ├── formatting.ts                               # Display formatting
│   ├── constants.ts                                # App constants
│   ├── logger.ts                                   # Logging utility
│   ├── errors.ts                                   # Error definitions
│   ├── crypto-utils.ts                             # Crypto helpers
│   └── __tests__/
│       ├── validation.test.ts
│       └── formatting.test.ts
│
├── config/                     # Configuration
│   ├── chains.ts                                   # Chain configurations
│   ├── rpcs.ts                                     # RPC endpoints
│   ├── app.ts                                      # App configuration
│   └── env.ts                                      # Environment variables
│
├── types/                      # Global TypeScript types
│   ├── wallet.types.ts
│   ├── transaction.types.ts
│   ├── blockchain.types.ts
│   └── index.ts
│
└── App.tsx                     # Root React component
```

---

## Assets Directory (`assets/`)

```
assets/
├── images/
│   ├── logo.png
│   ├── logo@2x.png
│   ├── logo@3x.png
│   ├── splash.png
│   └── backgrounds/
│       └── gradient-bg.png
│
├── icons/
│   ├── ethereum.png
│   ├── bitcoin.png
│   ├── solana.png
│   └── tokens/                # Token icons
│       ├── usdt.png
│       ├── usdc.png
│       └── dai.png
│
└── fonts/
    ├── Inter-Regular.ttf
    ├── Inter-Medium.ttf
    ├── Inter-SemiBold.ttf
    └── Inter-Bold.ttf
```

---

## Tests Directory (`__tests__/`)

```
__tests__/
├── unit/                       # Unit tests
│   ├── core/
│   │   ├── wallet/
│   │   ├── crypto/
│   │   └── transactions/
│   ├── chains/
│   │   ├── ethereum/
│   │   ├── bitcoin/
│   │   └── solana/
│   └── services/
│       ├── auth/
│       └── network/
│
├── integration/                # Integration tests
│   ├── wallet-creation.test.ts
│   ├── transaction-flow.test.ts
│   ├── balance-update.test.ts
│   └── network-switching.test.ts
│
├── e2e/                        # End-to-end tests (Detox)
│   ├── wallet-creation.e2e.ts
│   ├── send-transaction.e2e.ts
│   ├── receive-transaction.e2e.ts
│   └── backup-restore.e2e.ts
│
├── fixtures/                   # Test data
│   ├── wallets.json
│   ├── transactions.json
│   └── mock-responses.json
│
└── helpers/                    # Test utilities
    ├── setup.ts
    ├── mocks.ts
    └── test-utils.tsx
```

---

## Documentation Directory (`docs/`)

```
docs/
├── ARCHITECTURE.md             # System architecture (this document)
├── MODULE_DEPENDENCIES.md      # Module dependency graph
├── SECURITY_DESIGN.md          # Security specifications
├── TECH_STACK_DECISIONS.md     # Technology ADRs
├── FILE_STRUCTURE.md           # This file
├── API.md                      # API documentation
├── DEVELOPMENT.md              # Development guide
├── TESTING.md                  # Testing guide
├── DEPLOYMENT.md               # Deployment guide
├── CONTRIBUTING.md             # Contribution guidelines
└── diagrams/                   # Architecture diagrams
    ├── system-architecture.png
    ├── security-model.png
    └── data-flow.png
```

---

## Scripts Directory (`scripts/`)

```
scripts/
├── build/
│   ├── build-android.sh        # Android build script
│   ├── build-ios.sh            # iOS build script
│   └── clean.sh                # Clean build artifacts
│
├── deploy/
│   ├── deploy-android.sh       # Deploy to Google Play
│   └── deploy-ios.sh           # Deploy to App Store
│
├── setup/
│   ├── setup-dev.sh            # Developer environment setup
│   └── install-deps.sh         # Install dependencies
│
└── test/
    ├── run-unit-tests.sh
    ├── run-e2e-tests.sh
    └── test-coverage.sh
```

---

## GitHub Workflows (`.github/workflows/`)

```
.github/
└── workflows/
    ├── ci.yml                  # Continuous integration
    ├── release-android.yml     # Android release
    ├── release-ios.yml         # iOS release
    └── security-audit.yml      # Security scanning
```

---

## Configuration Files (Root)

```
# Environment Variables
.env.example                    # Template for environment variables
.env                            # Local environment (gitignored)
.env.development
.env.staging
.env.production

# TypeScript
tsconfig.json                   # TypeScript configuration

# Babel
babel.config.js                 # Babel transpiler config

# Metro Bundler
metro.config.js                 # React Native bundler

# ESLint
.eslintrc.js                    # Linting rules
.eslintignore

# Prettier
.prettierrc.js                  # Code formatting rules
.prettierignore

# Git
.gitignore                      # Git ignore rules
.gitattributes

# React Native
app.json                        # App configuration
index.js                        # Entry point

# Package Management
package.json                    # Dependencies and scripts
package-lock.json              # Locked versions
yarn.lock                      # Yarn lock file (if using Yarn)

# Watchman
.watchmanconfig                 # File watching config

# Jest
jest.config.js                  # Test configuration

# Detox
.detoxrc.js                     # E2E test configuration

# EditorConfig
.editorconfig                   # Editor configuration

# Node
.nvmrc                          # Node version
```

---

## File Naming Conventions

### TypeScript Files

- **Components**: PascalCase (e.g., `WalletCard.tsx`)
- **Services/Utilities**: PascalCase (e.g., `KeyManager.ts`)
- **Types**: kebab-case with `.types.ts` suffix (e.g., `wallet.types.ts`)
- **Tests**: Same as source file with `.test.ts` suffix (e.g., `WalletCard.test.tsx`)
- **E2E Tests**: Same with `.e2e.ts` suffix (e.g., `wallet-creation.e2e.ts`)

### Configuration Files

- **Config**: kebab-case (e.g., `babel.config.js`)
- **RC Files**: Prefixed with dot (e.g., `.eslintrc.js`)

### Documentation

- **Docs**: UPPERCASE with dashes (e.g., `ARCHITECTURE.md`)
- **Diagrams**: kebab-case (e.g., `system-architecture.png`)

---

## Directory Organization Principles

1. **By Feature**: Group related files together (e.g., all wallet-related code in `core/wallet/`)
2. **By Layer**: Separate concerns (UI, business logic, data)
3. **Co-location**: Keep tests next to source files
4. **Flat Structure**: Avoid deep nesting (max 3-4 levels)
5. **Clear Naming**: Descriptive, unambiguous names

---

## File Size Guidelines

- **Components**: < 300 lines
- **Services**: < 500 lines
- **Utilities**: < 200 lines
- **Tests**: < 500 lines

**Rationale**: Smaller files are easier to understand, test, and maintain.

---

## Import Path Aliases

Configure in `tsconfig.json`:

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/core/*": ["src/core/*"],
      "@/chains/*": ["src/chains/*"],
      "@/services/*": ["src/services/*"],
      "@/ui/*": ["src/ui/*"],
      "@/state/*": ["src/state/*"],
      "@/utils/*": ["src/utils/*"],
      "@/config/*": ["src/config/*"],
      "@/types/*": ["src/types/*"],
      "@/assets/*": ["assets/*"]
    }
  }
}
```

**Usage:**

```typescript
// ✅ Good: Clear, absolute path
import { WalletManager } from '@/core/wallet/WalletManager';

// ❌ Bad: Relative path, hard to refactor
import { WalletManager } from '../../../core/wallet/WalletManager';
```

---

## Total File Count Estimate

- **Source Files**: ~150 files
- **Test Files**: ~80 files
- **Config Files**: ~30 files
- **Documentation**: ~15 files
- **Native Code**: ~20 files
- **Assets**: ~50 files

**Total**: ~345 files

---

**Document Version:** 1.0.0
**Last Updated:** 2025-10-21
