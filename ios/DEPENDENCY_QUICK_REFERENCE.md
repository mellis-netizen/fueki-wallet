# iOS Dependencies - Quick Reference

## ✅ Status: CONFIGURED (Pending Xcode Project Fix)

### 📦 Production Dependencies (10)

| Dependency | Version | Purpose |
|------------|---------|---------|
| CryptoSwift | 1.8.0 | Cryptographic operations |
| BigInt | 5.3.0 | Large number arithmetic |
| web3swift | 3.1.0 | Ethereum blockchain |
| KeychainAccess | 4.2.2 | Secure storage |
| SwiftLint | 0.54.0 | Code quality |
| Alamofire | 5.8.1 | HTTP networking |
| SwiftyJSON | 5.0.1 | JSON parsing |
| SkeletonView | 1.31.0 | Loading animations |
| Lottie | 4.4.0 | Animations |
| SwiftQRScanner | 2.0.0 | QR code scanning |

### 🧪 Test Dependencies (3)

| Dependency | Version | Purpose |
|------------|---------|---------|
| Quick | 7.3.0 | BDD testing |
| Nimble | 13.0.0 | Test matchers |
| OHHTTPStubs | 9.1.0 | HTTP stubbing |

### 🔗 SPM-Only Dependencies (2)

| Dependency | Version | Purpose |
|------------|---------|---------|
| BitcoinKit | 1.1.0 | Bitcoin blockchain |
| Solana.Swift | 1.2.1 | Solana blockchain |

## 🚀 Quick Start

```bash
# Fix Xcode project first
open ios/FuekiWallet.xcodeproj  # Let Xcode auto-fix

# Then install dependencies
cd ios
pod install

# Open workspace
open FuekiWallet.xcworkspace
```

## 📁 Key Files

- `/ios/Podfile` - CocoaPods configuration
- `/ios/Package.swift` - SPM configuration
- `/ios/docs/DEPENDENCIES.md` - Full documentation
- `/ios/docs/XCODE_PROJECT_FIX.md` - Fix corrupted project
- `/ios/scripts/dependency-check.sh` - Verification script

## ⚠️ Important

**BLOCKER**: Xcode project file is corrupted
**FIX**: Open in Xcode, let it auto-repair, then run `pod install`
**TIME**: 5-10 minutes

## 💾 Memory Key

`swarm/implementation/dependencies` - Stored in `.swarm/memory.db`

## 📚 Documentation

- **Complete Guide**: `docs/DEPENDENCIES.md`
- **Implementation Summary**: `docs/DEPENDENCY_SUMMARY.md`
- **Troubleshooting**: `docs/XCODE_PROJECT_FIX.md`
- **This File**: Quick reference for developers

---

**Updated**: 2025-10-21
**Status**: Dependencies configured, awaiting Xcode fix
