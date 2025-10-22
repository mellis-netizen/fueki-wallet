# Fueki Wallet - Technology Stack Decision Records

## Overview

This document contains all Architecture Decision Records (ADRs) for technology choices in the Fueki Mobile Crypto Wallet project.

---

## ADR-001: React Native Framework

**Date:** 2025-10-21
**Status:** Accepted
**Decision Maker:** System Architect

### Context

Need to build a cross-platform mobile wallet for iOS and Android with:
- Native performance for cryptographic operations
- Access to hardware security features (Keychain, Biometrics)
- Fast development cycle
- Code sharing between platforms
- Large ecosystem of crypto libraries

### Decision

**Chosen: React Native 0.73+**

### Alternatives Considered

| Option | Pros | Cons | Score |
|--------|------|------|-------|
| **React Native** | 80-90% code sharing, huge ecosystem, native modules available, team expertise | Slightly larger bundle, requires native bridges | ⭐⭐⭐⭐⭐ |
| **Native (Swift/Kotlin)** | Best performance, full platform access | 2x development cost, 2x maintenance | ⭐⭐⭐ |
| **Flutter** | Good performance, growing ecosystem | Smaller crypto library ecosystem, Dart learning curve | ⭐⭐⭐ |
| **Ionic/Capacitor** | Web technologies, fast development | Poor performance for crypto, limited native access | ⭐⭐ |

### Rationale

1. **Code Sharing**: 85% code reuse between iOS and Android
2. **Crypto Libraries**: Excellent ecosystem (ethers.js, bitcoinjs-lib, @solana/web3.js)
3. **Native Access**: Full access to Keychain, Keystore, Biometrics via native modules
4. **Performance**: React Native Hermes engine provides near-native performance
5. **Team Expertise**: JavaScript/TypeScript skills readily available
6. **Community**: Large community, mature tooling, extensive documentation

### Consequences

**Positive:**
- Faster time to market
- Lower development costs
- Single codebase to maintain
- Access to npm ecosystem

**Negative:**
- Bundle size slightly larger than native
- Some features require native module development
- Performance overhead for UI rendering (mitigated by Reanimated)

**Mitigation:**
- Use Hermes engine for optimization
- Implement performance-critical code in native modules if needed
- Regular performance monitoring

---

## ADR-002: TypeScript

**Date:** 2025-10-21
**Status:** Accepted

### Context

Need type safety for financial application with complex data flows, transaction handling, and multi-chain operations.

### Decision

**Chosen: TypeScript 5.3+**

### Rationale

1. **Type Safety**: Catch errors at compile time, especially critical for financial operations
2. **Better IDE Support**: IntelliSense, auto-completion, refactoring
3. **Self-Documenting**: Types serve as inline documentation
4. **Safer Refactoring**: Type system catches breaking changes
5. **Industry Standard**: Used by all major crypto libraries

### Consequences

**Positive:**
- Fewer runtime errors
- Better developer experience
- Easier onboarding for new developers
- Improved code quality

**Negative:**
- Slightly longer initial setup
- Learning curve for pure JS developers
- More verbose code

---

## ADR-003: Redux Toolkit for State Management

**Date:** 2025-10-21
**Status:** Accepted

### Context

Complex global state with:
- Multiple wallets and accounts
- Real-time balance updates
- Transaction history
- Network state
- User settings

Need predictable state updates and excellent debugging tools.

### Decision

**Chosen: Redux Toolkit 2.0+**

### Alternatives Considered

| Option | Pros | Cons | Score |
|--------|------|------|-------|
| **Redux Toolkit** | Predictable, dev tools, middleware, persistence | Learning curve, boilerplate | ⭐⭐⭐⭐⭐ |
| **Zustand** | Lightweight, simple API | Less tooling, no time-travel debugging | ⭐⭐⭐⭐ |
| **MobX** | Less boilerplate, automatic tracking | Less predictable, harder debugging | ⭐⭐⭐ |
| **Context API** | Built-in, simple | Not suitable for complex state, performance issues | ⭐⭐ |

### Rationale

1. **Redux DevTools**: Time-travel debugging crucial for financial app
2. **RTK Query**: Built-in data fetching and caching
3. **Predictable**: Strict unidirectional data flow
4. **Middleware**: Easy to add logging, encryption, persistence
5. **Redux Toolkit**: Dramatically reduces boilerplate vs vanilla Redux

### Consequences

**Positive:**
- Excellent debugging capabilities
- Predictable state updates
- Easy to test
- Large ecosystem of middleware

**Negative:**
- Initial learning curve
- More verbose than simpler solutions
- Requires understanding of Redux patterns

---

## ADR-004: ethers.js v6 for Ethereum

**Date:** 2025-10-21
**Status:** Accepted

### Context

Need robust Ethereum library with:
- EIP-1559 transaction support
- Contract ABI encoding/decoding
- ENS resolution
- TypeScript support
- Tree-shakeable for smaller bundle

### Decision

**Chosen: ethers.js v6**

### Alternatives Considered

| Option | Pros | Cons | Score |
|--------|------|------|-------|
| **ethers.js v6** | Lightweight, TypeScript, tree-shakeable, secure | Requires polyfills | ⭐⭐⭐⭐⭐ |
| **web3.js** | Established, large ecosystem | Heavier, less TypeScript support | ⭐⭐⭐ |
| **viem** | Modern, excellent TypeScript | Newer, smaller ecosystem | ⭐⭐⭐⭐ |

### Rationale

1. **Bundle Size**: Much smaller than web3.js (important for mobile)
2. **TypeScript**: First-class TypeScript support
3. **Security**: Fewer dependencies = smaller attack surface
4. **Documentation**: Excellent documentation and examples
5. **EIP-1559**: Full support for modern Ethereum transactions

### Required Polyfills

```typescript
// Required for React Native
import 'react-native-get-random-values';
import { Buffer } from 'buffer';
global.Buffer = Buffer;
```

### Consequences

**Positive:**
- Smaller bundle size
- Better type safety
- Cleaner API
- Active maintenance

**Negative:**
- Need polyfills for React Native
- Different API from web3.js (no migration path)

---

## ADR-005: bitcoinjs-lib for Bitcoin

**Date:** 2025-10-21
**Status:** Accepted

### Context

Need Bitcoin library with:
- UTXO management
- Multiple address formats (P2PKH, P2SH, P2WPKH)
- Transaction building and signing
- BIP-32 key derivation

### Decision

**Chosen: bitcoinjs-lib 6.x + bip32 4.x**

### Rationale

1. **Battle-Tested**: Used in production by major wallets
2. **Complete**: Full Bitcoin protocol support
3. **SegWit**: Native SegWit (Bech32) support
4. **Flexible**: Support for all address types
5. **Active**: Well-maintained, regular updates

### Consequences

**Positive:**
- Comprehensive Bitcoin support
- Proven reliability
- Good documentation

**Negative:**
- Complex UTXO management
- Need separate library for BIP-32

---

## ADR-006: @solana/web3.js for Solana

**Date:** 2025-10-21
**Status:** Accepted

### Context

Need Solana support with:
- Transaction building
- SPL token support
- RPC client
- Ed25519 signatures

### Decision

**Chosen: @solana/web3.js 1.87+**

### Rationale

1. **Official**: Official Solana SDK
2. **Complete**: Full Solana protocol support
3. **SPL Tokens**: Built-in token support
4. **Active**: Regular updates from Solana Labs

### Consequences

**Positive:**
- Official SDK, guaranteed compatibility
- Comprehensive features
- Good documentation

**Negative:**
- Larger bundle size
- More dependencies than Ethereum libraries

---

## ADR-007: @scure/bip39 for Mnemonics

**Date:** 2025-10-21
**Status:** Accepted

### Context

Need BIP-39 implementation that is:
- Secure (audited)
- Lightweight
- TypeScript-native
- No dependencies

### Decision

**Chosen: @scure/bip39 1.2+ (@noble ecosystem)**

### Alternatives Considered

| Option | Pros | Cons | Score |
|--------|------|------|-------|
| **@scure/bip39** | Audited, zero dependencies, TypeScript | Newer library | ⭐⭐⭐⭐⭐ |
| **bip39** (npm) | Established, widely used | Many dependencies, larger bundle | ⭐⭐⭐⭐ |

### Rationale

1. **Security**: Audited by Trail of Bits
2. **No Dependencies**: Zero dependencies = smaller attack surface
3. **TypeScript**: Written in TypeScript
4. **Performance**: Optimized for modern JS engines
5. **Noble Ecosystem**: Part of @noble crypto suite (all audited)

### Consequences

**Positive:**
- Higher security confidence
- Smaller bundle size
- Better tree-shaking

**Negative:**
- Newer library (less battle-tested than bip39)

---

## ADR-008: WatermelonDB for Local Storage

**Date:** 2025-10-21
**Status:** Accepted

### Context

Need local database for:
- Transaction history (1000+ records)
- Token metadata
- Address book
- Settings

Requirements:
- Reactive (auto-update UI)
- Fast queries
- Lazy loading
- React Native optimized

### Decision

**Chosen: WatermelonDB 0.27+**

### Alternatives Considered

| Option | Pros | Cons | Score |
|--------|------|------|-------|
| **WatermelonDB** | Reactive, lazy loading, RN optimized | Learning curve | ⭐⭐⭐⭐⭐ |
| **Realm** | Mature, feature-rich | Heavy, licensing concerns | ⭐⭐⭐ |
| **SQLite (raw)** | Lightweight, proven | No reactivity, more boilerplate | ⭐⭐⭐ |
| **AsyncStorage** | Simple, built-in | Too slow for large datasets | ⭐⭐ |

### Rationale

1. **Performance**: Built for React Native performance
2. **Reactive**: Automatic UI updates on data changes
3. **Lazy Loading**: Only loads visible data
4. **SQLite**: Built on proven SQLite database
5. **TypeScript**: Full TypeScript support

### Consequences

**Positive:**
- Excellent performance with large datasets
- Reactive queries reduce boilerplate
- Optimized for mobile

**Negative:**
- Learning curve for WatermelonDB API
- Must define schemas upfront

---

## ADR-009: react-native-keychain for Secure Storage

**Date:** 2025-10-21
**Status:** Accepted

### Context

Need secure storage for:
- Encrypted seed phrase
- User credentials
- Authentication tokens

Requirements:
- Hardware-backed encryption
- Biometric protection
- iOS Keychain + Android Keystore

### Decision

**Chosen: react-native-keychain 8.x**

### Rationale

1. **Hardware-Backed**: Uses iOS Keychain and Android Keystore
2. **Biometric**: Integrated biometric authentication
3. **Battle-Tested**: Used by many production wallets
4. **Cross-Platform**: Single API for iOS and Android

### Configuration

```typescript
await Keychain.setGenericPassword(username, password, {
  service: 'com.fueki.wallet',
  accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
  accessControl: Keychain.ACCESS_CONTROL.BIOMETRY_CURRENT_SET,
  securityLevel: Keychain.SECURITY_LEVEL.SECURE_HARDWARE,
});
```

### Consequences

**Positive:**
- Maximum security (hardware-backed)
- Native biometric integration
- Platform-specific optimizations

**Negative:**
- Different behavior on iOS vs Android
- Must handle biometric availability

---

## ADR-010: react-native-mmkv for Fast Cache

**Date:** 2025-10-21
**Status:** Accepted

### Context

Need fast key-value storage for:
- Balance cache
- Price cache
- Settings
- Session data

Requirements:
- Very fast (synchronous)
- Encrypted
- Small footprint

### Decision

**Chosen: react-native-mmkv 2.x**

### Alternatives Considered

| Option | Pros | Cons | Score |
|--------|------|------|-------|
| **react-native-mmkv** | 30x faster than AsyncStorage, encrypted | New storage format | ⭐⭐⭐⭐⭐ |
| **AsyncStorage** | Built-in, stable | Slow, not encrypted | ⭐⭐ |

### Rationale

1. **Speed**: 30x faster than AsyncStorage
2. **Synchronous**: No async overhead for simple gets
3. **Encryption**: Built-in encryption support
4. **Proven**: Based on Tencent's MMKV (used by WeChat)

### Consequences

**Positive:**
- Dramatically faster app startup
- Better UX (instant data access)
- Built-in encryption

**Negative:**
- Different storage format (no migration from AsyncStorage)

---

## ADR-011: React Navigation 6

**Date:** 2025-10-21
**Status:** Accepted

### Context

Need navigation solution for:
- Tab navigation (main screens)
- Stack navigation (drill-down)
- Modal screens
- Deep linking

### Decision

**Chosen: React Navigation 6.x**

### Alternatives Considered

| Option | Pros | Cons | Score |
|--------|------|------|-------|
| **React Navigation** | Most mature, extensive features | Purely JS-based | ⭐⭐⭐⭐⭐ |
| **React Native Navigation** | Native navigation, better performance | More complex setup | ⭐⭐⭐⭐ |

### Rationale

1. **Mature**: Most widely used navigation library
2. **Flexible**: Supports all navigation patterns
3. **TypeScript**: Excellent TypeScript support
4. **Community**: Large community, many examples
5. **Deep Linking**: Built-in deep linking support

### Consequences

**Positive:**
- Easy to implement complex navigation
- Great documentation
- Large ecosystem of helpers

**Negative:**
- JS-based (slightly less performant than native navigation)

---

## ADR-012: Jest + React Native Testing Library

**Date:** 2025-10-21
**Status:** Accepted

### Context

Need comprehensive testing:
- Unit tests (business logic)
- Component tests (UI)
- Integration tests (flows)

### Decision

**Chosen: Jest 29+ with React Native Testing Library**

### Rationale

1. **Standard**: Industry standard for React testing
2. **Built-in**: Comes with React Native
3. **Snapshot Testing**: Easy to test component rendering
4. **Mocking**: Excellent mocking capabilities
5. **RNTL**: Encourages testing best practices

### Test Structure

```
__tests__/
├── unit/           # Pure logic tests
├── integration/    # Multi-module tests
└── e2e/           # End-to-end flows (Detox)
```

### Consequences

**Positive:**
- Comprehensive testing capabilities
- Large community
- Good IDE integration

**Negative:**
- Can be slow for large test suites
- Requires careful mocking setup

---

## ADR-013: Detox for E2E Testing

**Date:** 2025-10-21
**Status:** Accepted

### Context

Need end-to-end testing for critical flows:
- Wallet creation
- Transaction sending
- Network switching
- Backup flow

### Decision

**Chosen: Detox**

### Rationale

1. **React Native Focus**: Built specifically for React Native
2. **Gray Box**: Can access app internals for better testing
3. **Flakiness Prevention**: Automatic synchronization
4. **Real Devices**: Test on real devices and simulators

### Consequences

**Positive:**
- Catch integration issues early
- Test critical flows end-to-end
- Automatic synchronization reduces flakiness

**Negative:**
- Slower than unit tests
- More complex setup
- Requires test device/emulator

---

## Summary of Key Technologies

### Core Framework
- **React Native 0.73+**: Cross-platform mobile framework
- **TypeScript 5.3+**: Type-safe development
- **Redux Toolkit 2.0+**: State management

### Blockchain Libraries
- **ethers.js 6.x**: Ethereum support
- **bitcoinjs-lib 6.x**: Bitcoin support
- **@solana/web3.js 1.87+**: Solana support
- **@scure/bip39 1.2+**: Mnemonic generation (audited)
- **@noble/secp256k1 2.0+**: ECDSA signing (audited)

### Security
- **react-native-keychain 8.x**: Hardware-backed storage
- **react-native-biometrics 3.x**: Biometric authentication
- **react-native-get-random-values 1.x**: Secure random numbers

### Storage
- **WatermelonDB 0.27+**: Transaction history database
- **react-native-mmkv 2.x**: Fast encrypted cache

### UI/UX
- **React Navigation 6.x**: Navigation
- **react-native-paper 5.x**: Material Design components
- **react-native-reanimated 3.x**: Smooth animations
- **react-native-camera 4.x**: QR code scanning

### Testing
- **Jest 29+**: Unit and integration testing
- **React Native Testing Library**: Component testing
- **Detox**: E2E testing

### Development
- **ESLint**: Code linting
- **Prettier**: Code formatting
- **Metro**: React Native bundler

---

## Technology Selection Criteria

When evaluating technologies, we prioritized:

1. **Security** ⭐⭐⭐⭐⭐
   - Audited libraries
   - Minimal dependencies
   - Hardware-backed when possible

2. **Performance** ⭐⭐⭐⭐⭐
   - Fast startup time
   - Smooth animations
   - Efficient crypto operations

3. **Reliability** ⭐⭐⭐⭐⭐
   - Battle-tested in production
   - Active maintenance
   - Good track record

4. **Developer Experience** ⭐⭐⭐⭐
   - Good documentation
   - TypeScript support
   - Large community

5. **Bundle Size** ⭐⭐⭐⭐
   - Tree-shakeable
   - Minimal dependencies
   - Mobile-optimized

---

**Document Version:** 1.0.0
**Last Updated:** 2025-10-21
**Next Review:** Q2 2025
