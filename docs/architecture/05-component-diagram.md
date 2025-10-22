# Fueki Wallet - Component Diagram

## C4 Model Architecture Diagrams

This document presents the Fueki Wallet architecture using the C4 model (Context, Container, Component, Code).

## Level 1: System Context Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                         Mobile User                              │
│              (Cryptocurrency wallet user)                        │
│                                                                  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ Uses
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                    Fueki Mobile Wallet                           │
│          (iOS cryptocurrency wallet application)                 │
│                                                                  │
│     Features: Multi-chain support, TSS security,                │
│     Biometric auth, Fiat on/off ramps, Social recovery         │
│                                                                  │
└────┬─────────┬──────────┬──────────┬──────────┬────────────────┘
     │         │          │          │          │
     │         │          │          │          │
     ↓         ↓          ↓          ↓          ↓
┌─────────┐ ┌──────┐ ┌──────────┐ ┌──────┐ ┌──────────┐
│Bitcoin  │ │Ethereum│ │Payment  │ │OAuth │ │Push      │
│Network  │ │Network │ │Ramps    │ │Providers│ │Notification│
│         │ │        │ │(Stripe, │ │(Google,│ │Service   │
│         │ │        │ │ Ramp)   │ │ Apple) │ │(APNS)    │
└─────────┘ └────────┘ └──────────┘ └────────┘ └──────────┘
```

## Level 2: Container Diagram

```
┌────────────────── iOS Device ──────────────────────────────┐
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            Fueki Wallet iOS App                       │  │
│  │                (SwiftUI)                              │  │
│  │                                                       │  │
│  │  Presents UI, manages user interactions,             │  │
│  │  handles navigation and state management             │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │                                     │
│                       │ Reads/Writes                        │
│                       ↓                                     │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Local Storage                            │  │
│  │                                                       │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │  │
│  │  │  CoreData    │  │  Keychain    │  │ UserDefaults│ │  │
│  │  │              │  │              │  │            │ │  │
│  │  │ Transaction  │  │ Private Keys │  │ Settings   │ │  │
│  │  │ History,     │  │ Key Shares   │  │ Preferences│ │  │
│  │  │ Wallet Data  │  │ Auth Tokens  │  │            │ │  │
│  │  └──────────────┘  └──────────────┘  └────────────┘ │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          Secure Enclave (Hardware)                    │  │
│  │                                                       │  │
│  │  Primary TSS key share, biometric keys               │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
                       │
                       │ HTTPS/WSS
                       ↓
┌──────────────────────────────────────────────────────────────┐
│                  External Services                            │
│                                                              │
│  ┌────────────┐  ┌────────────┐  ┌───────────┐  ┌────────┐ │
│  │ Blockchain │  │  Payment   │  │   OAuth   │  │  APNS  │ │
│  │   Nodes    │  │   Ramps    │  │ Providers │  │        │ │
│  │            │  │            │  │           │  │        │ │
│  │ Bitcoin,   │  │ Stripe,    │  │ Google,   │  │ Push   │ │
│  │ Ethereum,  │  │ Ramp       │  │ Apple     │  │ Notify │ │
│  │ Others     │  │ Network    │  │           │  │        │ │
│  └────────────┘  └────────────┘  └───────────┘  └────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## Level 3: Component Diagram

```
┌──────────────────── Fueki Wallet iOS App ────────────────────────┐
│                                                                   │
│  ┌─────────────────── Presentation Layer ─────────────────────┐ │
│  │                                                             │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐ │ │
│  │  │ Onboarding   │  │   Wallet     │  │  Transactions   │ │ │
│  │  │   Views      │  │   Views      │  │     Views       │ │ │
│  │  └──────┬───────┘  └──────┬───────┘  └────────┬────────┘ │ │
│  │         │                  │                   │          │ │
│  │         ↓                  ↓                   ↓          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐ │ │
│  │  │ Onboarding   │  │   Wallet     │  │  Transactions   │ │ │
│  │  │ ViewModels   │  │ ViewModels   │  │   ViewModels    │ │ │
│  │  └──────────────┘  └──────────────┘  └─────────────────┘ │ │
│  │                                                             │ │
│  └─────────────────────────┬───────────────────────────────────┘ │
│                            │                                     │
│                            │ Calls                               │
│                            ↓                                     │
│  ┌───────────────────── Domain Layer ─────────────────────────┐ │
│  │                                                             │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐  │ │
│  │  │   Wallet    │  │Transaction  │  │  Authentication  │  │ │
│  │  │  Use Cases  │  │ Use Cases   │  │    Use Cases     │  │ │
│  │  └──────┬──────┘  └──────┬──────┘  └────────┬─────────┘  │ │
│  │         │                 │                  │            │ │
│  │         │                 │                  │            │ │
│  │  ┌──────┴─────────────────┴──────────────────┴─────────┐ │ │
│  │  │            Repository Protocols                      │ │ │
│  │  │  (WalletRepository, TransactionRepository, etc.)    │ │ │
│  │  └───────────────────────┬──────────────────────────────┘ │ │
│  │                                                             │ │
│  └─────────────────────────┬───────────────────────────────────┘ │
│                            │                                     │
│                            │ Implements                          │
│                            ↓                                     │
│  ┌────────────────────── Data Layer ──────────────────────────┐ │
│  │                                                             │ │
│  │  ┌──────────────────────────────────────────────────────┐ │ │
│  │  │         Repository Implementations                    │ │ │
│  │  │                                                       │ │ │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │ │ │
│  │  │  │   Wallet    │  │Transaction  │  │   Asset     │ │ │ │
│  │  │  │ Repository  │  │ Repository  │  │ Repository  │ │ │ │
│  │  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘ │ │ │
│  │  └─────────┼─────────────────┼─────────────────┼────────┘ │ │
│  │            │                 │                 │          │ │
│  │            ↓                 ↓                 ↓          │ │
│  │  ┌─────────────────┐  ┌─────────────────────────────┐   │ │
│  │  │  Local Data     │  │  Remote Data Sources        │   │ │
│  │  │  Sources        │  │                             │   │ │
│  │  │                 │  │  ┌──────────────────────┐  │   │ │
│  │  │ ┌────────────┐  │  │  │  Blockchain API      │  │   │ │
│  │  │ │  CoreData  │  │  │  │  Clients             │  │   │ │
│  │  │ └────────────┘  │  │  └──────────────────────┘  │   │ │
│  │  │                 │  │                             │   │ │
│  │  │ ┌────────────┐  │  │  ┌──────────────────────┐  │   │ │
│  │  │ │  Keychain  │  │  │  │  Payment Ramp        │  │   │ │
│  │  │ └────────────┘  │  │  │  Clients             │  │   │ │
│  │  │                 │  │  └──────────────────────┘  │   │ │
│  │  │ ┌────────────┐  │  │                             │   │ │
│  │  │ │   Cache    │  │  │  ┌──────────────────────┐  │   │ │
│  │  │ └────────────┘  │  │  │  Price Feed APIs     │  │   │ │
│  │  │                 │  │  └──────────────────────┘  │   │ │
│  │  └─────────────────┘  └─────────────────────────────┘   │ │
│  │                                                             │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌───────────────── Infrastructure Layer ──────────────────────┐ │
│  │                                                             │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐ │ │
│  │  │  Blockchain  │  │ Cryptography │  │    Security     │ │ │
│  │  │   Services   │  │   Services   │  │    Services     │ │ │
│  │  │              │  │              │  │                 │ │ │
│  │  │ • Bitcoin    │  │ • TSS        │  │ • Keychain      │ │ │
│  │  │ • Ethereum   │  │ • Signing    │  │ • Secure Enclave│ │ │
│  │  │ • Polygon    │  │ • Key Mgmt   │  │ • Biometrics    │ │ │
│  │  └──────────────┘  └──────────────┘  └─────────────────┘ │ │
│  │                                                             │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐ │ │
│  │  │   Network    │  │  Third Party │  │   Analytics     │ │ │
│  │  │   Services   │  │     SDKs     │  │    Services     │ │ │
│  │  │              │  │              │  │                 │ │ │
│  │  │ • HTTP Client│  │ • Stripe SDK │  │ • Firebase      │ │ │
│  │  │ • WebSocket  │  │ • Ramp SDK   │  │ • Sentry        │ │ │
│  │  │ • TLS/Pinning│  │ • OAuth SDKs │  │                 │ │ │
│  │  └──────────────┘  └──────────────┘  └─────────────────┘ │ │
│  │                                                             │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

## Key Component Interactions

### 1. Wallet Creation Sequence

```
User
  │
  │ tap "Create Wallet"
  ↓
WalletCreationView
  │
  │ trigger action
  ↓
WalletCreationViewModel
  │
  │ call createWallet()
  ↓
CreateWalletUseCase
  │
  ├──→ TSSService.generateKeyShares()
  │    │
  │    └──→ SecureEnclaveService.storeKeyShare(share1)
  │    └──→ KeychainService.storeKeyShare(share2)
  │    └──→ CloudBackupService.storeKeyShare(share3)
  │
  └──→ BlockchainService.deriveAddress()
       │
       └──→ WalletRepository.save(wallet)
            │
            └──→ CoreData.insert(walletEntity)
```

### 2. Send Transaction Sequence

```
User
  │
  │ enter transaction details
  ↓
SendTransactionView
  │
  │ submit transaction
  ↓
SendTransactionViewModel
  │
  │ call sendTransaction()
  ↓
SendTransactionUseCase
  │
  ├──→ ValidateTransaction()
  │
  ├──→ BiometricAuthService.authenticate()
  │
  ├──→ EstimateGasUseCase.estimate()
  │    │
  │    └──→ BlockchainService.estimateFee()
  │
  └──→ SignTransactionUseCase.sign()
       │
       ├──→ TSSService.retrieveKeyShares()
       │    │
       │    ├──→ SecureEnclaveService.getKeyShare()
       │    └──→ KeychainService.getKeyShare()
       │
       ├──→ TSSService.reconstructKey()
       │
       ├──→ TSSService.signTransaction()
       │
       └──→ BlockchainService.broadcastTransaction()
            │
            └──→ TransactionRepository.save(transaction)
                 │
                 └──→ CoreData.insert(transactionEntity)
```

### 3. Balance Sync Sequence

```
Timer / Background Refresh
  │
  ↓
SyncService.sync()
  │
  └──→ WalletRepository.fetchAll()
       │
       └──→ For each wallet:
            │
            ├──→ BlockchainService.getBalance(address)
            │    │
            │    └──→ HTTP Request → Blockchain Node
            │
            ├──→ Compare with cached balance
            │
            └──→ If changed:
                 │
                 ├──→ WalletRepository.updateBalance()
                 │    │
                 │    └──→ CoreData.update(walletEntity)
                 │
                 └──→ NotificationCenter.post(balanceUpdated)
                      │
                      └──→ WalletViewModel updates @Published property
                           │
                           └──→ SwiftUI View refreshes
```

## Component Responsibilities

### Presentation Layer Components

| Component | Responsibility | Dependencies |
|-----------|---------------|--------------|
| Views | UI rendering, user input | ViewModels |
| ViewModels | Presentation logic, state management | Use Cases |
| Navigation | Screen routing, deep linking | Coordinator |
| Theming | Colors, fonts, styles | None |

### Domain Layer Components

| Component | Responsibility | Dependencies |
|-----------|---------------|--------------|
| Use Cases | Business logic orchestration | Repositories |
| Domain Models | Business entities | None |
| Repository Protocols | Data access interfaces | None |
| Validators | Business rule validation | Domain Models |

### Data Layer Components

| Component | Responsibility | Dependencies |
|-----------|---------------|--------------|
| Repositories | Data coordination, caching | Data Sources |
| Local Data Source | Local persistence | CoreData, Keychain |
| Remote Data Source | API communication | Network Services |
| DTOs | Data transfer objects | None |
| Cache | In-memory caching | NSCache |

### Infrastructure Layer Components

| Component | Responsibility | Dependencies |
|-----------|---------------|--------------|
| Blockchain Services | Blockchain interaction | RPC Clients |
| Cryptography Services | Crypto operations | CryptoKit |
| Security Services | Auth, key storage | Keychain, SE |
| Network Services | HTTP, WebSocket | URLSession |
| Third Party SDKs | External integrations | Vendor SDKs |

## Data Flow Patterns

### Read Operations

```
View Request
     ↓
ViewModel
     ↓
Use Case
     ↓
Repository
     ↓
┌────┴────┐
│         │
Cache   Data Source
│         │
└────┬────┘
     ↓
Return Data
     ↓
Transform to Domain Model
     ↓
Update ViewModel State
     ↓
SwiftUI Auto-Refresh View
```

### Write Operations

```
User Action
     ↓
ViewModel
     ↓
Use Case (validate)
     ↓
Repository
     ↓
Data Source (persist)
     ↓
┌────┴────────────┐
│                 │
Local Storage   Remote API
│                 │
└────┬────────────┘
     ↓
Update Cache
     ↓
Publish Change Event
     ↓
ViewModels Subscribe
     ↓
Views Auto-Update
```

## Security Component Architecture

```
┌─────────────────────────────────────────────────┐
│          Security Layer                          │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │      Authentication Manager                │ │
│  │                                            │ │
│  │  • Biometric Authentication               │ │
│  │  • PIN Authentication                     │ │
│  │  • Session Management                     │ │
│  └────────────┬───────────────────────────────┘ │
│               │                                  │
│               ↓                                  │
│  ┌────────────────────────────────────────────┐ │
│  │      Key Management Service                │ │
│  │                                            │ │
│  │  ┌──────────────┐  ┌──────────────────┐  │ │
│  │  │ TSS Service  │  │ Secure Enclave   │  │ │
│  │  │              │  │ Service          │  │ │
│  │  │ • Generate   │  │                  │  │ │
│  │  │ • Reconstruct│  │ • Store Keys     │  │ │
│  │  │ • Sign       │  │ • Sign Data      │  │ │
│  │  └──────────────┘  └──────────────────┘  │ │
│  │                                            │ │
│  │  ┌──────────────────────────────────────┐ │ │
│  │  │      Keychain Service                │ │ │
│  │  │                                      │ │ │
│  │  │  • Save Secrets                      │ │ │
│  │  │  • Retrieve Secrets                  │ │ │
│  │  │  • Delete Secrets                    │ │ │
│  │  └──────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │      Network Security                      │ │
│  │                                            │ │
│  │  • TLS 1.3 Enforcement                    │ │
│  │  • Certificate Pinning                    │ │
│  │  • API Authentication                     │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │      Data Protection                       │ │
│  │                                            │ │
│  │  • Database Encryption                    │ │
│  │  • File Protection                        │ │
│  │  • Memory Security                        │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
└──────────────────────────────────────────────────┘
```

## Integration Component Architecture

```
┌────────────────────────────────────────────────┐
│       Integration Facade Layer                  │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │     Blockchain Integration Manager        │  │
│  │                                          │  │
│  │  ┌────────────┐  ┌────────────────────┐ │  │
│  │  │ Bitcoin    │  │ Ethereum           │ │  │
│  │  │ Service    │  │ Service            │ │  │
│  │  │            │  │                    │ │  │
│  │  │ • RPC      │  │ • Web3             │ │  │
│  │  │ • Wallet   │  │ • Smart Contracts  │ │  │
│  │  │ • TX       │  │ • ERC20/721        │ │  │
│  │  └────────────┘  └────────────────────┘ │  │
│  │                                          │  │
│  │  ┌──────────────────────────────────┐   │  │
│  │  │  WebSocket Manager               │   │  │
│  │  │  • Real-time updates             │   │  │
│  │  │  • Block subscriptions           │   │  │
│  │  └──────────────────────────────────┘   │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │     Payment Ramp Integration              │  │
│  │                                          │  │
│  │  ┌────────────┐  ┌────────────────────┐ │  │
│  │  │ Stripe     │  │ Ramp Network       │ │  │
│  │  │ Service    │  │ Service            │ │  │
│  │  └────────────┘  └────────────────────┘ │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │     OAuth Integration                     │  │
│  │                                          │  │
│  │  ┌────────────┐  ┌────────────────────┐ │  │
│  │  │ Google     │  │ Apple Sign-In      │ │  │
│  │  │ OAuth      │  │                    │ │  │
│  │  └────────────┘  └────────────────────┘ │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │     Notification Integration              │  │
│  │                                          │  │
│  │  • APNS Client                           │  │
│  │  • Transaction Monitoring                │  │
│  │  • Alert Management                      │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Deployment Component View

```
┌─────────────────────── iOS Device ───────────────────────┐
│                                                           │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              Application Container                   │ │
│  │                                                      │ │
│  │  App Binary (.ipa)                                  │ │
│  │  Resources (Images, Strings, etc.)                  │ │
│  │  Frameworks (Embedded)                              │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐ │
│  │            Shared Containers                         │ │
│  │                                                      │ │
│  │  App Group Container                                │ │
│  │  iCloud Container (optional)                        │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              System Services                         │ │
│  │                                                      │ │
│  │  Keychain                                           │ │
│  │  Secure Enclave                                     │ │
│  │  LocalAuthentication                                │ │
│  │  UserNotifications                                  │ │
│  │  CoreData                                           │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                           │
└───────────────────────────────────────────────────────────┘
                          │
                          │ Network
                          ↓
┌───────────────────────────────────────────────────────────┐
│                  Cloud Services                            │
│                                                           │
│  • Blockchain Nodes (Bitcoin, Ethereum, etc.)            │
│  • Payment Gateway APIs (Stripe, Ramp)                   │
│  • OAuth Providers (Google, Apple)                       │
│  • APNS (Apple Push Notification Service)                │
│  • Price Feed APIs                                       │
│  • Analytics Services                                    │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

## Technology Stack per Component

| Component | Primary Technologies | Alternatives |
|-----------|---------------------|--------------|
| UI Framework | SwiftUI | UIKit (legacy) |
| Architecture | MVVM + Clean | VIPER, MVC |
| Reactive | Combine | RxSwift |
| Database | CoreData | Realm, SQLite |
| Networking | URLSession | Alamofire |
| Crypto | CryptoKit | OpenSSL |
| Bitcoin | BitcoinKit | Custom |
| Ethereum | Web3.swift | Web3js via WebView |
| Testing | XCTest | Quick/Nimble |

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-21 | CryptoArchitect Agent | Initial component diagrams |
