# Fueki Wallet Integration Patterns

## Overview
Complete integration architecture for Fueki Mobile Wallet iOS application, coordinating all components into a cohesive system.

## Core Integration Components

### 1. AppDelegate
**Location**: `/ios/FuekiWallet/AppDelegate.swift`

**Responsibilities**:
- App lifecycle management
- Push notification configuration
- Firebase initialization
- Dependency injection setup
- Core Data initialization
- Crash reporting configuration
- Analytics setup

**Key Features**:
- Push notification handling (APNS + FCM)
- Background task management
- App state transitions
- Remote notification processing
- Update checking
- Security token management

**Integration Points**:
- DependencyContainer initialization
- AppCoordinator setup
- Service initialization chain
- Background refresh scheduling

---

### 2. SceneDelegate
**Location**: `/ios/FuekiWallet/ios/FuekiWallet/SceneDelegate.swift`

**Responsibilities**:
- Scene lifecycle management
- Deep link handling
- Universal link routing
- Quick action shortcuts
- State restoration

**Deep Link Patterns**:
```swift
fueki://wallet/send?address=0x123&amount=1.5&token=USDT
fueki://wallet/receive
fueki://transaction/0xabc...
fueki://settings
fueki://dapp?url=https://...
```

**Quick Actions**:
- Send transaction
- Receive payment
- Scan QR code
- View portfolio

---

### 3. DependencyContainer
**Location**: `/ios/FuekiWallet/DependencyContainer.swift`

**Responsibilities**:
- Central dependency injection
- Service lifecycle management
- Lazy initialization
- Dependency graph resolution

**Service Categories**:

**Core Services**:
- NetworkingService
- PersistenceService
- SecurityService
- KeychainService
- BiometricService
- EncryptionService

**Blockchain Services**:
- BlockchainService
- WalletService
- TransactionService
- GasEstimationService
- TokenService
- NFTService

**DApp Services**:
- DAppBrowserService
- Web3Bridge
- SignatureService
- WalletConnectService

**Market Data Services**:
- PriceService
- ChartService
- PortfolioService

**Notification Services**:
- NotificationService
- TransactionMonitoringService
- PriceAlertService

**Utility Services**:
- CacheService
- AnalyticsService
- ImageService
- QRCodeService
- ClipboardService
- HapticService
- LocalizationService

**ViewModel Factory Pattern**:
```swift
func makeWalletListViewModel() -> WalletListViewModel
func makeSendViewModel(wallet: Wallet) -> SendViewModel
func makeReceiveViewModel(wallet: Wallet) -> ReceiveViewModel
// ... etc
```

---

### 4. ServiceLocator
**Location**: `/ios/FuekiWallet/ServiceLocator.swift`

**Responsibilities**:
- Alternative dependency injection pattern
- Service registration/resolution
- Thread-safe service access
- Property wrapper for injection

**Usage Pattern**:
```swift
@Injected var walletService: WalletServiceProtocol
```

**Thread Safety**:
- Concurrent dispatch queue
- Barrier writes for registration
- Sync reads for resolution

---

### 5. AppCoordinator
**Location**: `/ios/FuekiWallet/AppCoordinator.swift`

**Responsibilities**:
- Main app navigation flow
- Tab-based architecture coordination
- Onboarding/authentication flow
- Deep link routing
- Scene lifecycle coordination

**Coordinator Hierarchy**:
```
AppCoordinator
├── OnboardingCoordinator (initial setup)
├── AuthenticationCoordinator (PIN/biometric)
├── WalletCoordinator (main wallet tab)
├── DAppCoordinator (browser tab)
├── PortfolioCoordinator (portfolio tab)
└── SettingsCoordinator (settings tab)
```

**Navigation Methods**:
- `navigateToSend(address:amount:token:)`
- `navigateToReceive()`
- `navigateToQRScanner()`
- `navigateToPortfolio()`
- `navigateToSettings()`
- `showTransactionDetails(txHash:)`
- `showTokenDetails(symbol:)`
- `openDApp(url:)`

**Authentication Flow**:
- Session timeout detection
- Privacy screen overlay
- Biometric re-authentication
- Auto-lock mechanism

---

### 6. AppConfiguration
**Location**: `/ios/FuekiWallet/AppConfiguration.swift`

**Responsibilities**:
- Environment-specific configuration
- Feature flags
- API endpoints
- Security settings
- Third-party service keys

**Environments**:
1. **Development**:
   - Local testnet (http://localhost:8545)
   - Chain ID: 1337
   - Debug features enabled
   - Extended auth timeout (5 min)

2. **Staging**:
   - Public testnet (Mumbai)
   - Chain ID: 80001
   - Testing features enabled
   - Standard auth timeout (3 min)

3. **Production**:
   - Mainnet (Polygon)
   - Chain ID: 137
   - Production security
   - Strict auth timeout (1 min)

**Feature Flags**:
- Analytics enabled
- Crash reporting enabled
- Debug menu enabled
- Testnet support
- DApp browser
- NFT support
- WalletConnect
- Staking
- Token swap

**Configuration Groups**:
- API endpoints
- Blockchain settings
- Security parameters
- Network timeouts
- Cache settings
- Third-party keys
- Gas limits
- Transaction fees
- Update intervals

---

### 7. Constants
**Location**: `/ios/FuekiWallet/Constants.swift`

**Responsibilities**:
- App-wide constant definitions
- Keychain keys
- UserDefaults keys
- Notification names
- Regex patterns
- Error/success messages
- Analytics event names

**Constant Categories**:
- Keychain (security storage keys)
- UserDefaults (preference keys)
- Notifications (system events)
- Blockchain (addresses, limits, gas)
- Wallet (validation, constraints)
- Transaction (limits, timeouts)
- Token (standards, ABIs)
- NFT (standards, gateways)
- DApp (defaults, limits)
- Price (currencies, thresholds)
- UI (dimensions, durations)
- API (endpoints, headers)
- Cache (keys, expiration)
- Regex (validation patterns)
- Messages (user-facing text)
- Analytics (events, properties)

**ABI Definitions**:
- ERC20 ABI (token standard)
- ERC721 ABI (NFT standard)

---

### 8. Theme
**Location**: `/ios/FuekiWallet/Theme.swift`

**Responsibilities**:
- Design system implementation
- Color palette management
- Typography system
- Spacing/sizing standards
- Shadow/border styles
- Animation durations

**Design Token Structure**:

**Colors**:
- Primary (Indigo #6366F1)
- Secondary (Green #10B981)
- Accent (Amber #F59E0B)
- Status (success, warning, error, info)
- Neutral (background, surface, borders)
- Text (primary, secondary, tertiary)
- Dark mode variants
- Chart colors
- Transaction-specific colors

**Typography**:
- Display (57/45/36pt bold)
- Headline (32/24/20pt semibold)
- Title (22/18/16pt medium)
- Body (16/14/12pt regular)
- Label (14/12/11pt medium)
- Monospace (addresses/hashes)
- Number (amounts with tabular figures)

**Spacing Scale**:
- xxs: 4pt
- xs: 8pt
- sm: 12pt
- md: 16pt
- lg: 24pt
- xl: 32pt
- xxl: 48pt

**Corner Radius**:
- xs: 4pt
- sm: 8pt
- md: 12pt
- lg: 16pt
- xl: 24pt
- full: 999pt

**Shadow Styles**:
- Small (offset 1, radius 2, opacity 0.05)
- Medium (offset 2, radius 4, opacity 0.1)
- Large (offset 4, radius 8, opacity 0.15)

**Border Widths**:
- Thin: 0.5pt
- Regular: 1pt
- Thick: 2pt

**Animations**:
- Fast: 0.2s
- Normal: 0.3s
- Slow: 0.5s

**Theme Application**:
- Navigation bar styling
- Tab bar styling
- Button appearance
- TextField appearance
- TableView appearance

**Helper Methods**:
- `applyShadow(to:style:)`
- `applyCornerRadius(to:radius:corners:)`
- `applyBorder(to:color:width:)`

---

## Integration Flows

### App Launch Flow
```
1. AppDelegate.didFinishLaunching
   ├── Initialize DependencyContainer
   ├── Configure Firebase
   ├── Setup Push Notifications
   ├── Configure Appearance (Theme)
   ├── Initialize Core Data
   ├── Configure Analytics
   └── Setup AppCoordinator

2. AppCoordinator.start()
   ├── Check Onboarding Status
   │   ├── [New User] → OnboardingCoordinator
   │   ├── [PIN Set] → AuthenticationCoordinator
   │   └── [Authenticated] → Main Interface
   └── Show Main Interface
       ├── WalletCoordinator (Tab 1)
       ├── DAppCoordinator (Tab 2)
       ├── PortfolioCoordinator (Tab 3)
       └── SettingsCoordinator (Tab 4)
```

### Dependency Injection Flow
```
DependencyContainer
  ├── Core Services (Networking, Security, Persistence)
  │   └── Used by Blockchain Services
  │
  ├── Blockchain Services (Wallet, Transaction, Token)
  │   └── Used by DApp Services
  │
  ├── DApp Services (Browser, Web3, WalletConnect)
  │   └── Used by ViewModels
  │
  ├── Market Services (Price, Chart, Portfolio)
  │   └── Used by ViewModels
  │
  └── ViewModels (Created via Factory Methods)
      └── Injected into ViewControllers
```

### Navigation Flow
```
AppCoordinator
  ├── Deep Link → Parse → Route to Coordinator
  ├── Push Notification → Handle → Navigate
  ├── Quick Action → Execute → Navigate
  └── User Interaction → Coordinator → Navigate

Tab-Based Navigation:
  ├── Wallet Tab: WalletCoordinator
  │   ├── Wallet List
  │   ├── Wallet Detail
  │   ├── Send/Receive
  │   ├── Transaction History
  │   └── Token/NFT Management
  │
  ├── DApp Tab: DAppCoordinator
  │   ├── Browser
  │   ├── Bookmarks
  │   └── WalletConnect Sessions
  │
  ├── Portfolio Tab: PortfolioCoordinator
  │   ├── Portfolio Overview
  │   ├── Asset Details
  │   └── Performance Charts
  │
  └── Settings Tab: SettingsCoordinator
      ├── Security Settings
      ├── Backup/Recovery
      ├── Network Settings
      └── About/Support
```

---

## Configuration Management

### Environment Variables
```bash
# Development
DEV_API_KEY=dev_key_123
INFURA_PROJECT_ID=dev_infura_id

# Staging
STAGING_API_KEY=staging_key_456
INFURA_PROJECT_ID=staging_infura_id

# Production
PROD_API_KEY=prod_key_789
INFURA_PROJECT_ID=prod_infura_id
MIXPANEL_TOKEN=mixpanel_token
SENTRY_DSN=sentry_dsn
WALLETCONNECT_PROJECT_ID=wc_project_id
ALCHEMY_API_KEY=alchemy_key
COINGECKO_API_KEY=coingecko_key
```

### Build Configurations
- Debug → Development environment
- Staging → Staging environment
- Release → Production environment

---

## Security Integration

### Keychain Storage
```swift
Keychain.Keys.privateKey → Encrypted private keys
Keychain.Keys.mnemonic → Encrypted seed phrases
Keychain.Keys.pin → Hashed PIN codes
Keychain.Keys.deviceToken → APNS tokens
Keychain.Keys.fcmToken → FCM tokens
```

### Biometric Authentication
- Touch ID / Face ID integration
- Fallback to PIN authentication
- Session timeout enforcement
- Privacy screen on background

### Data Protection
- Core Data encryption
- Memory clearing on background
- Sensitive data wiping
- Secure enclave usage

---

## Monitoring & Analytics

### Analytics Events
```swift
Analytics.Events.appLaunched
Analytics.Events.walletCreated
Analytics.Events.transactionSent
Analytics.Events.dappOpened
Analytics.Events.errorOccurred
```

### Crash Reporting
- Sentry integration (production)
- Stack trace collection
- User context attachment
- Breadcrumb tracking

### Performance Monitoring
- App launch time
- Screen render time
- Network request duration
- Database query performance

---

## Best Practices

### Dependency Injection
1. Use DependencyContainer for service creation
2. Inject dependencies via initializers
3. Avoid service locator in business logic
4. Use protocols for all service interfaces

### Coordinator Pattern
1. One coordinator per feature
2. Coordinators own navigation
3. ViewControllers are dumb
4. Delegate pattern for coordinator communication

### Configuration
1. Never hardcode secrets
2. Use environment variables
3. Feature flags for gradual rollout
4. Environment-specific settings

### Theme
1. Use Theme constants exclusively
2. No hardcoded colors/fonts
3. Support dark mode
4. Consistent spacing/sizing

### Constants
1. Define all magic strings
2. Group by domain
3. Document purpose
4. Use strongly-typed values

---

## Testing Integration

### Unit Tests
- Service layer tests
- ViewModel tests
- Utility function tests
- Business logic tests

### Integration Tests
- API integration tests
- Blockchain integration tests
- Database integration tests
- Push notification tests

### UI Tests
- Navigation flow tests
- User journey tests
- Critical path tests
- Accessibility tests

---

## Maintenance

### Adding New Services
1. Create protocol in Services/Protocols
2. Implement in Services/Implementations
3. Add to DependencyContainer
4. Register in ServiceLocator (optional)
5. Inject into ViewModels

### Adding New Features
1. Create feature coordinator
2. Add to AppCoordinator hierarchy
3. Create ViewModels with dependencies
4. Update navigation methods
5. Add analytics events
6. Update constants

### Environment Changes
1. Update AppConfiguration
2. Add environment variables
3. Update CI/CD secrets
4. Test all environments
5. Document changes

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        AppDelegate                          │
│  - App Lifecycle                                            │
│  - Push Notifications                                       │
│  - Initialization                                           │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│                   DependencyContainer                       │
│  - Service Creation                                         │
│  - Dependency Resolution                                    │
│  - Lifecycle Management                                     │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│                      AppCoordinator                         │
│  - Navigation Flow                                          │
│  - Child Coordinators                                       │
│  - Deep Link Routing                                        │
└─┬───────┬───────┬───────┬────────────────────────────────────┘
  │       │       │       │
  ▼       ▼       ▼       ▼
┌───┐   ┌───┐   ┌───┐   ┌───┐
│ W │   │ D │   │ P │   │ S │  Feature Coordinators
│ a │   │ A │   │ o │   │ e │
│ l │   │ p │   │ r │   │ t │
│ l │   │ p │   │ t │   │ t │
│ e │   │   │   │ f │   │ i │
│ t │   │   │   │ o │   │ n │
│   │   │   │   │ l │   │ g │
│   │   │   │   │ i │   │ s │
│   │   │   │   │ o │   │   │
└─┬─┘   └─┬─┘   └─┬─┘   └─┬─┘
  │       │       │       │
  ▼       ▼       ▼       ▼
ViewControllers + ViewModels
  │       │       │       │
  ▼       ▼       ▼       ▼
┌─────────────────────────────────────────────────────────────┐
│                    Service Layer                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │Blockchain│  │   DApp   │  │  Market  │  │ Security │   │
│  │ Services │  │ Services │  │ Services │  │ Services │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│                   Infrastructure Layer                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │Networking│  │Persistence│  │ Keychain │  │  Cache   │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Integration Checklist

- [x] AppDelegate configured with all services
- [x] SceneDelegate handles deep links and quick actions
- [x] DependencyContainer manages all dependencies
- [x] ServiceLocator provides alternative DI pattern
- [x] AppCoordinator orchestrates navigation
- [x] AppConfiguration manages environments
- [x] Constants define all magic values
- [x] Theme provides consistent design system
- [x] Push notifications configured
- [x] Analytics integrated
- [x] Crash reporting enabled
- [x] Biometric authentication supported
- [x] Core Data initialized
- [x] Keychain security implemented
- [x] Environment-specific settings
- [x] Feature flags defined
- [x] Deep link routing functional
- [x] Tab-based navigation implemented
- [x] State restoration supported
- [x] Background task handling
- [x] Privacy screen protection
- [x] Auto-lock mechanism
- [x] Update checking
- [x] Multi-environment support

---

*Integration architecture completed and documented for Fueki Mobile Wallet*
