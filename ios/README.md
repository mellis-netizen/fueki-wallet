# Fueki Wallet - iOS Application

## Project Overview

This is the iOS implementation of the Fueki Wallet, a secure cryptocurrency wallet application built with SwiftUI.

## Project Structure

```
ios/
├── FuekiWallet.xcodeproj/          # Xcode project file
├── FuekiWallet/                    # Main application target
│   ├── FuekiWalletApp.swift       # App entry point
│   ├── ContentView.swift          # Main content view
│   ├── Info.plist                 # App configuration
│   ├── FuekiWallet.entitlements   # App capabilities
│   ├── LaunchScreen.storyboard    # Launch screen
│   └── Resources/                 # Assets and resources
├── FuekiWalletTests/              # Unit tests
├── FuekiWalletUITests/            # UI tests
├── Podfile                         # CocoaPods dependencies
└── .swiftlint.yml                 # SwiftLint configuration
```

## Requirements

- **Xcode**: 15.0+
- **iOS**: 15.0+
- **Swift**: 5.9+
- **CocoaPods**: 1.12+

## Setup Instructions

### 1. Install Dependencies

```bash
cd ios
pod install
```

### 2. Open Project

```bash
open FuekiWallet.xcworkspace
```

**Important**: Always use `.xcworkspace` file, not `.xcodeproj` when using CocoaPods.

### 3. Configure Code Signing

1. Open the project in Xcode
2. Select the "FuekiWallet" target
3. Go to "Signing & Capabilities"
4. Select your development team
5. Xcode will automatically manage provisioning profiles

## Build Configurations

### Debug Configuration
- Optimization: None (-Onone)
- Bitcode: Disabled
- Debug symbols: Enabled
- Testability: Enabled

### Release Configuration
- Optimization: Whole Module (-O)
- Bitcode: Disabled
- Debug symbols: dwarf-with-dsym
- Hardened runtime: Enabled

## Permissions & Capabilities

The app requires the following permissions (configured in Info.plist):

- **Camera**: For QR code scanning
- **Face ID**: For biometric authentication
- **Photo Library**: For saving QR codes
- **Network**: For blockchain connectivity

## Entitlements

Configured capabilities:
- Keychain Access Groups
- App Groups
- Push Notifications
- Network Extensions
- App Attest (for security)

## Dependencies (CocoaPods)

### Production Dependencies
- **CryptoSwift**: Cryptographic operations
- **web3swift**: Blockchain interaction
- **Alamofire**: Networking
- **KeychainSwift**: Secure storage
- **SwiftQRScanner**: QR code scanning
- **SkeletonView**: Loading states
- **Lottie**: Animations

### Testing Dependencies
- **Quick**: BDD testing framework
- **Nimble**: Matcher framework

## Build Targets

### FuekiWallet (Main App)
- Bundle ID: `com.fueki.wallet`
- Supported devices: iPhone, iPad
- Deployment target: iOS 15.0

### FuekiWalletTests (Unit Tests)
- Bundle ID: `com.fueki.wallet.tests`
- Test host: FuekiWallet

### FuekiWalletUITests (UI Tests)
- Bundle ID: `com.fueki.wallet.uitests`
- Test target: FuekiWallet

## Build Phases

### 1. Sources
Compiles all Swift source files

### 2. Frameworks
Links required frameworks and libraries

### 3. Resources
Copies assets, storyboards, and resource files

### 4. SwiftLint (Custom)
Runs SwiftLint for code quality checks

## Code Quality

### SwiftLint Rules
- Line length: 120 characters (warning), 200 (error)
- File length: 500 lines (warning), 1000 (error)
- Function body: 50 lines (warning), 100 (error)
- Type body: 300 lines (warning), 500 (error)

### Enabled Rules
- Empty count
- Empty string
- Explicit init
- First where
- Modifier order
- Closure spacing

## Building the App

### Command Line Build
```bash
xcodebuild -workspace FuekiWallet.xcworkspace \
           -scheme FuekiWallet \
           -configuration Debug \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           build
```

### Running Tests
```bash
xcodebuild test -workspace FuekiWallet.xcworkspace \
                -scheme FuekiWallet \
                -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Architecture

### App Lifecycle
- SwiftUI App lifecycle
- Scene-based architecture
- State management via ObservableObject

### Design Patterns
- MVVM (Model-View-ViewModel)
- Dependency Injection
- Repository pattern for data access
- Combine for reactive programming

### Security Features
- Keychain for sensitive data storage
- Biometric authentication (Face ID/Touch ID)
- Secure Enclave for cryptographic operations
- App Attest for integrity verification
- Network security with ATS enabled

## Asset Management

### App Icons
Required sizes (located in Assets.xcassets):
- 1024x1024 (App Store)
- 180x180 (@3x iPhone)
- 120x120 (@2x iPhone)
- 167x167 (@2x iPad Pro)
- 152x152 (@2x iPad)
- And various other sizes

### Launch Screen
- Custom storyboard with app branding
- Supports light and dark mode
- Optimized for all device sizes

## Localization

Currently configured for:
- English (Base language)
- Ready for additional localizations

## Deployment

### TestFlight (Beta)
1. Archive the app (Product > Archive)
2. Distribute to App Store Connect
3. Submit for beta review
4. Add testers in TestFlight

### App Store Release
1. Increment version and build number
2. Archive with Release configuration
3. Upload to App Store Connect
4. Complete app metadata
5. Submit for review

## Troubleshooting

### Common Issues

**Pod install fails**
```bash
pod repo update
pod install --repo-update
```

**Code signing errors**
- Verify development team is selected
- Check provisioning profile validity
- Clean build folder (Cmd+Shift+K)

**Build errors after updating dependencies**
```bash
pod deintegrate
pod install
```

## CI/CD Integration

The project is ready for CI/CD with:
- Automatic code signing
- Build scripts support
- Test automation
- SwiftLint integration

## Performance Optimization

- Whole module optimization in Release
- Asset catalog optimization
- Launch time optimization
- Memory management best practices

## Security Considerations

1. Never commit sensitive data (API keys, certificates)
2. Use environment variables for configuration
3. Enable App Transport Security (ATS)
4. Implement certificate pinning for production
5. Use secure coding practices (SwiftLint enforced)

## Next Steps

1. Install CocoaPods dependencies: `pod install`
2. Open workspace: `open FuekiWallet.xcworkspace`
3. Configure code signing
4. Build and run on simulator/device
5. Start implementing wallet features

## Support

For issues or questions about the iOS implementation, refer to the main project documentation or contact the development team.
