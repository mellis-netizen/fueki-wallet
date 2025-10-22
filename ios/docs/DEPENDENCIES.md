# iOS Dependencies Documentation

## Overview
This document details all production dependencies for the Fueki Mobile Wallet iOS application, including installation instructions, version constraints, and conflict resolution strategies.

## Dependency Management Systems

### CocoaPods (Primary)
- **Version**: 1.16.2+
- **Configuration**: `ios/Podfile`
- **Installation**: Run `pod install` from `ios/` directory

### Swift Package Manager (SPM) (Secondary)
- **Configuration**: `ios/Package.swift`
- **Integration**: Xcode → File → Add Packages
- **Use Case**: Packages not available via CocoaPods

## Production Dependencies

### 1. Core Cryptography

#### CryptoSwift
- **Version**: ~> 1.8.0
- **Purpose**: Cryptographic operations (AES, SHA, HMAC, PBKDF2)
- **Source**: CocoaPods & SPM
- **License**: Open source
- **Usage**: Wallet encryption, key derivation, hashing
```swift
import CryptoSwift
let encrypted = try AES(key: key, blockMode: CBC(iv: iv)).encrypt(data)
```

#### BigInt
- **Version**: ~> 5.3.0
- **Purpose**: Large number arithmetic for blockchain calculations
- **Source**: CocoaPods & SPM
- **License**: Open source
- **Usage**: Token amounts, gas calculations, nonce handling
```swift
import BigInt
let value = BigUInt("1000000000000000000") // 1 ETH in Wei
```

### 2. Secure Storage

#### KeychainAccess
- **Version**: ~> 4.2.2
- **Purpose**: Secure keychain wrapper for sensitive data
- **Source**: CocoaPods & SPM
- **License**: MIT
- **Usage**: Private key storage, seed phrase encryption
- **Why preferred**: Better API than KeychainSwift, more actively maintained
```swift
import KeychainAccess
let keychain = Keychain(service: "io.fueki.wallet")
try keychain.set(privateKey, key: "eth_private_key")
```

### 3. Blockchain Integration

#### Web3.swift
- **Version**: ~> 3.1.0
- **Purpose**: Ethereum blockchain integration
- **Source**: CocoaPods & SPM
- **License**: Apache 2.0
- **Features**:
  - ERC-20/721/1155 token support
  - Smart contract interaction
  - Transaction signing
  - ENS support
```swift
import web3swift
let web3 = try await Web3.new(URL(string: rpcUrl)!)
let balance = try await web3.eth.getBalance(address: ethereumAddress)
```

#### BitcoinKit
- **Version**: ~> 1.1.0
- **Purpose**: Bitcoin blockchain support
- **Source**: SPM (recommended), manual integration
- **License**: MIT
- **Features**:
  - HD wallet (BIP32/39/44)
  - P2PKH, P2SH, SegWit support
  - Transaction building
  - UTXO management
```swift
import BitcoinKit
let mnemonic = Mnemonic.create()
let wallet = HDWallet(mnemonic: mnemonic, passphrase: "")
```

#### Solana.Swift
- **Version**: ~> 1.2.1
- **Purpose**: Solana blockchain integration
- **Source**: SPM (primary)
- **License**: MIT
- **Features**:
  - SPL token support
  - Transaction building
  - Account management
  - RPC client
```swift
import Solana
let solana = Solana(router: NetworkingRouter(endpoint: .mainnetBeta))
let balance = try await solana.api.getBalance(account: publicKey)
```

### 4. Networking

#### Alamofire
- **Version**: ~> 5.8.1
- **Purpose**: HTTP networking framework
- **Source**: CocoaPods & SPM
- **License**: MIT
- **Usage**: API requests, blockchain RPC calls
```swift
import Alamofire
AF.request(url).responseDecodable(of: Response.self) { response in
    // Handle response
}
```

#### SwiftyJSON
- **Version**: ~> 5.0.1
- **Purpose**: JSON parsing helper
- **Source**: CocoaPods
- **License**: MIT
- **Usage**: Simplify JSON handling for complex responses

### 5. Code Quality

#### SwiftLint
- **Version**: ~> 0.54.0
- **Purpose**: Swift code linter and style enforcer
- **Source**: CocoaPods & SPM
- **License**: MIT
- **Configuration**: `.swiftlint.yml`
- **Integration**: Build phase in Xcode
```bash
"${PODS_ROOT}/SwiftLint/swiftlint"
```

### 6. UI Components

#### SkeletonView
- **Version**: ~> 1.31.0
- **Purpose**: Loading skeleton animations
- **Source**: CocoaPods
- **License**: MIT
- **Usage**: Loading states for wallet data

#### Lottie
- **Version**: ~> 4.4.0
- **Purpose**: Animation framework
- **Source**: CocoaPods
- **License**: Apache 2.0
- **Usage**: Animated UI elements, success/error states

#### SwiftQRScanner
- **Version**: ~> 2.0.0
- **Purpose**: QR code scanning
- **Source**: CocoaPods
- **License**: MIT
- **Usage**: Wallet address scanning, transaction QR codes

## Testing Dependencies

### Quick
- **Version**: ~> 7.3.0
- **Purpose**: BDD testing framework
- **Source**: CocoaPods & SPM
- **License**: Apache 2.0

### Nimble
- **Version**: ~> 13.0.0
- **Purpose**: Matcher framework for Quick
- **Source**: CocoaPods & SPM
- **License**: Apache 2.0

### OHHTTPStubs
- **Version**: ~> 9.1.0
- **Purpose**: HTTP request stubbing for tests
- **Source**: CocoaPods
- **License**: MIT

## Installation Instructions

### Step 1: Install CocoaPods Dependencies
```bash
cd ios
pod install
```

### Step 2: Open Workspace (Not Project!)
```bash
open FuekiWallet.xcworkspace
```

### Step 3: Configure Swift Package Manager (Optional)
For packages not available via CocoaPods:
1. Open Xcode
2. File → Add Packages
3. Enter package URL
4. Select version constraint
5. Choose target (FuekiWallet)

### Step 4: Verify Installation
```bash
pod list
```

## Dependency Version Constraints

| Dependency | Version | Constraint Type | Reason |
|------------|---------|-----------------|--------|
| CryptoSwift | 1.8.x | Minor | Stable crypto API |
| BigInt | 5.3.x | Minor | Backward compatible |
| Web3.swift | 3.1.x | Minor | Active development |
| BitcoinKit | 1.1.x | Minor | Stable Bitcoin support |
| Solana.Swift | 1.2.x | Minor | Regular updates |
| KeychainAccess | 4.2.x | Minor | Security updates |
| Alamofire | 5.8.x | Minor | Stable networking |
| SwiftLint | 0.54.x | Minor | Latest rules |

## Conflict Resolution

### Known Conflicts

#### 1. CryptoSwift Version Conflicts
**Issue**: Multiple dependencies may require different CryptoSwift versions
**Resolution**: Pin to 1.8.x in Podfile
```ruby
pod 'CryptoSwift', '1.8.0'
```

#### 2. web3swift Build Issues
**Issue**: Swift version incompatibility
**Resolution**: Set SWIFT_VERSION in post_install hook
```ruby
config.build_settings['SWIFT_VERSION'] = '5.9'
```

#### 3. BigInt Precision Issues
**Issue**: Different BigInt implementations
**Resolution**: Use attaswift/BigInt consistently
```ruby
pod 'BigInt', '~> 5.3.0'
```

### Xcode Build Settings

Post-install configuration in Podfile:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # iOS deployment target
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'

      # Disable Bitcode
      config.build_settings['ENABLE_BITCODE'] = 'NO'

      # Enable hardened runtime
      config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'YES'

      # Swift optimization
      if config.name == 'Debug'
        config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
      else
        config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-O'
      end

      # Whole module optimization
      config.build_settings['SWIFT_COMPILATION_MODE'] = 'wholemodule'
    end
  end
end
```

## Troubleshooting

### Issue: Pod Install Fails
```bash
# Clear CocoaPods cache
pod cache clean --all
rm -rf ~/Library/Caches/CocoaPods
rm -rf Pods
rm Podfile.lock

# Reinstall
pod install --repo-update
```

### Issue: Build Errors After Pod Install
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Clean build folder in Xcode
# Product → Clean Build Folder (Cmd+Shift+K)
```

### Issue: SwiftLint Not Running
1. Check Build Phases in Xcode
2. Add SwiftLint run script:
```bash
if which swiftlint >/dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed"
fi
```

### Issue: Keychain Access Denied
- Add Keychain Sharing capability in Xcode
- Configure keychain access groups in entitlements

## Security Considerations

### 1. Dependency Auditing
```bash
# Check for known vulnerabilities
pod outdated
```

### 2. Version Pinning
- Production: Pin exact versions
- Development: Use optimistic operators (~>)

### 3. Source Verification
- Only use official package repositories
- Verify checksums for critical dependencies
- Review dependency licenses

## Performance Optimization

### 1. Build Time Optimization
- Use `use_frameworks!` for dynamic linking
- Enable whole module optimization for release builds
- Use modular headers

### 2. App Size Optimization
- Strip debug symbols in release builds
- Enable bitcode (when compatible)
- Use link-time optimization

## Maintenance

### Update Schedule
- **Security updates**: Immediate
- **Minor updates**: Monthly review
- **Major updates**: Quarterly evaluation

### Update Process
```bash
# Check for updates
pod outdated

# Update specific pod
pod update <PodName>

# Update all pods (use with caution)
pod update

# Commit Podfile.lock
git add Podfile.lock
git commit -m "chore: update dependencies"
```

## Additional Resources

- [CocoaPods Documentation](https://guides.cocoapods.org/)
- [Swift Package Manager Documentation](https://swift.org/package-manager/)
- [web3swift Documentation](https://github.com/web3swift-team/web3swift)
- [BitcoinKit Documentation](https://github.com/yenom/BitcoinKit)
- [Solana.Swift Documentation](https://github.com/portto/solana-swift)

## Support

For dependency-related issues:
1. Check GitHub issues for each dependency
2. Review dependency documentation
3. Consult iOS team lead
4. Create issue in project repository

---

**Last Updated**: 2025-10-21
**iOS Deployment Target**: 15.0+
**Xcode Version**: 15.0+
**Swift Version**: 5.9+
