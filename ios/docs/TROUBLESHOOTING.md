# Fueki Wallet - Troubleshooting Guide

## Common Issues and Solutions

This guide covers common issues you might encounter while developing or using Fueki Wallet.

## Table of Contents

1. [Build Issues](#build-issues)
2. [Runtime Issues](#runtime-issues)
3. [Testing Issues](#testing-issues)
4. [Dependency Issues](#dependency-issues)
5. [Code Signing Issues](#code-signing-issues)
6. [Network Issues](#network-issues)
7. [Storage Issues](#storage-issues)
8. [UI Issues](#ui-issues)

## Build Issues

### Issue: Build Fails with "Command CompileSwift failed"

**Symptoms**: Swift compilation errors, module not found

**Solutions**:

```bash
# 1. Clean build folder
Product > Clean Build Folder (⇧⌘K)

# Or via command line
xcodebuild clean -workspace FuekiWallet.xcworkspace -scheme FuekiWallet

# 2. Delete Derived Data
rm -rf ~/Library/Developer/Xcode/DerivedData

# 3. Reset package caches
File > Packages > Reset Package Caches

# 4. Rebuild
xcodebuild build -workspace FuekiWallet.xcworkspace -scheme FuekiWallet
```

### Issue: "No such module" Error

**Symptoms**: Import statements fail, module not found

**Solutions**:

```bash
# 1. Verify dependencies installed
cd ios
pod install

# 2. Open correct workspace (not project)
open FuekiWallet.xcworkspace  # ✅
# NOT: open FuekiWallet.xcodeproj  # ❌

# 3. Check import statements
import FuekiCore  # Module name must match

# 4. Verify scheme settings
Edit Scheme > Build > Check all targets are included
```

### Issue: SwiftLint Warnings/Errors

**Symptoms**: Build fails due to SwiftLint rules

**Solutions**:

```bash
# 1. Run SwiftLint manually
swiftlint

# 2. Auto-fix issues
swiftlint --fix

# 3. Temporarily disable rule
// swiftlint:disable:next force_cast
let value = obj as! String

// 4. Disable for file
// swiftlint:disable force_cast

# 5. Update .swiftlint.yml if rule is too strict
```

### Issue: Code Signing Failed

**Symptoms**: "Code signing is required for product type 'Application'"

See [Code Signing Issues](#code-signing-issues) section below.

### Issue: Missing GoogleService-Info.plist

**Symptoms**: Firebase configuration error

**Solutions**:

```bash
# 1. Download from Firebase Console
# https://console.firebase.google.com/

# 2. Add to Xcode project
# Drag into project, ensure "Copy items if needed" is checked

# 3. Verify in Build Phases
# Build Phases > Copy Bundle Resources
# GoogleService-Info.plist should be listed
```

## Runtime Issues

### Issue: App Crashes on Launch

**Symptoms**: App crashes immediately after launch

**Solutions**:

1. **Check Console for Crash Logs**
   ```
   Window > Devices and Simulators > View Device Logs
   ```

2. **Common Causes**:

   ```swift
   // ❌ Force unwrapping nil
   let value = dictionary["key"]!  // Crashes if nil

   // ✅ Safe unwrapping
   guard let value = dictionary["key"] else { return }

   // ❌ Array index out of bounds
   let item = array[5]  // Crashes if array.count < 6

   // ✅ Safe access
   guard array.indices.contains(5) else { return }
   let item = array[5]
   ```

3. **Check Initialization**:
   ```swift
   // Ensure all dependencies are initialized
   class AppDelegate: UIResponder, UIApplicationDelegate {
       func application(
           _ application: UIApplication,
           didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
       ) -> Bool {
           // Initialize services
           DependencyContainer.shared.initialize()
           return true
       }
   }
   ```

### Issue: "Keychain Item Not Found"

**Symptoms**: KeychainError when retrieving data

**Solutions**:

```swift
// 1. Check if item exists before retrieving
func retrieveSecurely(key: String) throws -> Data? {
    do {
        return try KeychainManager.shared.retrieve(key: key)
    } catch KeychainError.itemNotFound {
        // Item doesn't exist, handle gracefully
        return nil
    } catch {
        throw error
    }
}

// 2. Verify accessibility level
// Some levels prevent access when device is locked
try KeychainManager.shared.store(
    data,
    key: "key",
    accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
)

// 3. Check entitlements
// Keychain Sharing must be enabled in capabilities
```

### Issue: Face ID / Touch ID Not Working

**Symptoms**: Biometric authentication fails or not available

**Solutions**:

1. **Check Info.plist**:
   ```xml
   <key>NSFaceIDUsageDescription</key>
   <string>Fueki uses Face ID to secure your wallet</string>
   ```

2. **Verify Device Support**:
   ```swift
   let context = LAContext()
   var error: NSError?

   if !context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
       // Check error
       if let error = error {
           switch error.code {
           case LAError.biometryNotAvailable.rawValue:
               // Device doesn't support biometrics
           case LAError.biometryNotEnrolled.rawValue:
               // User hasn't enrolled
           default:
               // Other error
           }
       }
   }
   ```

3. **Simulator Limitations**:
   ```
   Simulator > Features > Face ID > Enrolled
   ```

### Issue: Network Requests Timeout

**Symptoms**: URLError.timedOut, requests never complete

**Solutions**:

```swift
// 1. Increase timeout
var request = URLRequest(url: url)
request.timeoutInterval = 60  // seconds

// 2. Check network configuration
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 30
configuration.timeoutIntervalForResource = 60

// 3. Verify ATS settings in Info.plist
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>  <!-- Set to true only for development -->
</dict>

// 4. Test connection
func testConnection() async throws {
    let url = URL(string: "https://api.fueki.io/health")!
    let (_, response) = try await URLSession.shared.data(from: url)
    print("Connection OK: \(response)")
}
```

### Issue: Memory Leaks

**Symptoms**: Memory usage grows over time, app crashes with memory warnings

**Solutions**:

```swift
// 1. Use weak references in closures
class ViewModel {
    func fetchData() {
        service.fetch { [weak self] result in
            guard let self = self else { return }
            self.process(result)
        }
    }
}

// 2. Break retain cycles
class Parent {
    var child: Child?
}

class Child {
    weak var parent: Parent?  // ✅ Weak reference
}

// 3. Use Instruments to detect leaks
Product > Profile > Leaks

// 4. Cancel tasks when view disappears
class ViewModel {
    private var task: Task<Void, Never>?

    func load() {
        task = Task {
            await fetchData()
        }
    }

    func cancel() {
        task?.cancel()
    }
}
```

## Testing Issues

### Issue: Tests Fail with "Module Not Found"

**Symptoms**: `@testable import FuekiWallet` fails

**Solutions**:

```bash
# 1. Ensure test target has host application set
Test Target > General > Testing > Host Application

# 2. Check scheme
Edit Scheme > Test > Info > Executable

# 3. Verify test target membership
Select test file > File Inspector > Target Membership
```

### Issue: Async Tests Timeout

**Symptoms**: `XCTestExpectation` timeout, tests never complete

**Solutions**:

```swift
// ❌ Bad - No await
func testAsync() {
    Task {
        await viewModel.fetch()
    }
    XCTAssertTrue(viewModel.loaded)  // Fails - not loaded yet
}

// ✅ Good - Properly await
func testAsync() async {
    await viewModel.fetch()
    XCTAssertTrue(viewModel.loaded)
}

// ✅ Good - Using expectations
func testAsync() {
    let expectation = expectation(description: "Fetch completes")

    Task {
        await viewModel.fetch()
        expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
    XCTAssertTrue(viewModel.loaded)
}
```

### Issue: UI Tests Can't Find Elements

**Symptoms**: `XCUIElement` not found or not hittable

**Solutions**:

```swift
// 1. Add accessibility identifiers
Button("Create") {
    // Action
}
.accessibilityIdentifier("createButton")

// 2. Wait for element to exist
let button = app.buttons["createButton"]
XCTAssertTrue(button.waitForExistence(timeout: 5))

// 3. Check if element is hittable
XCTAssertTrue(button.isHittable)

// 4. Scroll to element if needed
let element = app.staticTexts["Detail"]
while !element.isHittable {
    app.swipeUp()
}
```

## Dependency Issues

### Issue: CocoaPods Installation Fails

**Symptoms**: `pod install` errors

**Solutions**:

```bash
# 1. Update CocoaPods
sudo gem install cocoapods

# 2. Update repo
pod repo update

# 3. Deintegrate and reinstall
pod deintegrate
pod install

# 4. Clear cache
rm -rf ~/Library/Caches/CocoaPods
pod install

# 5. Use verbose output for debugging
pod install --verbose
```

### Issue: Swift Package Manager Errors

**Symptoms**: Package resolution fails, packages not downloading

**Solutions**:

```bash
# 1. Reset package caches
File > Packages > Reset Package Caches

# 2. Resolve versions manually
File > Packages > Resolve Package Versions

# 3. Update to latest versions
File > Packages > Update to Latest Package Versions

# 4. Clear SPM cache
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/Developer/Xcode/DerivedData

# 5. Check Package.swift dependencies
.package(url: "https://github.com/example/package", from: "1.0.0")
```

### Issue: Version Conflicts

**Symptoms**: Multiple packages require different versions of same dependency

**Solutions**:

```ruby
# In Podfile
# 1. Specify exact versions
pod 'Alamofire', '5.6.0'

# 2. Use version ranges
pod 'Alamofire', '~> 5.6'

# 3. Resolve conflicts
pod update Alamofire
```

## Code Signing Issues

### Issue: Provisioning Profile Errors

**Symptoms**: "No matching provisioning profile found"

**Solutions**:

```bash
# 1. Refresh profiles in Xcode
Xcode > Preferences > Accounts > Download Manual Profiles

# 2. Delete expired profiles
~/Library/MobileDevice/Provisioning Profiles
# Delete old .mobileprovision files

# 3. Use automatic signing (development)
Project > Signing & Capabilities > Automatically manage signing

# 4. Verify bundle identifier matches
# Must match exactly (case-sensitive)
com.fueki.wallet  # ✅
com.Fueki.Wallet  # ❌ Different
```

### Issue: "Certificate Not Trusted"

**Symptoms**: Code signing fails, certificate errors

**Solutions**:

```bash
# 1. Check certificate validity
security find-identity -v -p codesigning

# 2. Download certificate from Apple Developer
https://developer.apple.com/account/resources/certificates

# 3. Install certificate
# Double-click .cer file, add to "login" keychain

# 4. Verify certificate in Keychain Access
Keychain Access > My Certificates
# Should show "Apple Development" or "Apple Distribution"
```

### Issue: Using Fastlane Match

**Symptoms**: Match setup or sync issues

**Solutions**:

```bash
# 1. Initialize match
fastlane match init

# 2. Generate new certificates
fastlane match development
fastlane match appstore

# 3. Refresh certificates
fastlane match development --readonly

# 4. Force new certificates
fastlane match development --force_for_new_devices

# 5. Nuke and recreate
fastlane match nuke development
fastlane match development
```

## Network Issues

### Issue: API Requests Return 401 Unauthorized

**Symptoms**: Authentication failures

**Solutions**:

```swift
// 1. Verify API key
let apiKey = Configuration.apiKey
print("Using API key: \(apiKey)")

// 2. Check headers
var request = URLRequest(url: url)
request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

// 3. Token expiration
if tokenExpired {
    await refreshToken()
    // Retry request
}

// 4. Debug request
print("Request headers: \(request.allHTTPHeaderFields)")
```

### Issue: Certificate Pinning Failures

**Symptoms**: SSL errors, connection rejected

**Solutions**:

```swift
// 1. Verify certificate file
guard let certPath = Bundle.main.path(forResource: "cert", ofType: "cer") else {
    print("Certificate not found")
    return
}

// 2. Check certificate expiration
let certificate = SecCertificateCreateWithData(nil, certData as CFData)
// Verify valid dates

// 3. Disable pinning for testing (development only!)
#if DEBUG
    let pinnedCerts: [Data] = []  // No pinning in debug
#else
    let pinnedCerts = loadCertificates()
#endif

// 4. Update certificates
// Download new .cer file and replace in bundle
```

### Issue: Websocket Connection Drops

**Symptoms**: Websocket disconnects, no updates received

**Solutions**:

```swift
// 1. Implement reconnection logic
class WebSocketManager {
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    func connect() {
        task = session.webSocketTask(with: url)
        task?.resume()
        receive()
    }

    func reconnect() {
        guard reconnectAttempts < maxReconnectAttempts else { return }

        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 32.0)

        Task {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            connect()
        }
    }

    func receive() {
        task?.receive { [weak self] result in
            switch result {
            case .success:
                self?.reconnectAttempts = 0
                self?.receive()  // Continue receiving
            case .failure:
                self?.reconnect()
            }
        }
    }
}

// 2. Handle app backgrounding
NotificationCenter.default.addObserver(
    forName: UIApplication.didEnterBackgroundNotification
) { [weak self] _ in
    self?.disconnect()
}

NotificationCenter.default.addObserver(
    forName: UIApplication.willEnterForegroundNotification
) { [weak self] _ in
    self?.connect()
}
```

## Storage Issues

### Issue: Core Data Migration Failed

**Symptoms**: App crashes on launch after update, persistent store incompatible

**Solutions**:

```swift
// 1. Enable lightweight migration
let container = NSPersistentContainer(name: "FuekiWallet")
let description = container.persistentStoreDescriptions.first

description?.shouldMigrateStoreAutomatically = true
description?.shouldInferMappingModelAutomatically = true

// 2. Create mapping model for complex migrations
// Create .xcmappingmodel file in Xcode

// 3. Delete and recreate store (development only!)
try? FileManager.default.removeItem(at: storeURL)

// 4. Version model properly
// Create new model version before changing entities
Editor > Add Model Version
```

### Issue: User Defaults Not Persisting

**Symptoms**: Settings not saved between launches

**Solutions**:

```swift
// 1. Call synchronize (though usually not needed)
UserDefaults.standard.set(value, forKey: "key")
UserDefaults.standard.synchronize()

// 2. Use correct defaults instance
let defaults = UserDefaults.standard  // ✅
// NOT: UserDefaults()  // ❌ Different instance

// 3. Check app group for extensions
let defaults = UserDefaults(suiteName: "group.com.fueki.wallet")

// 4. Verify not exceeding limits
// UserDefaults has size limits, use for small data only
```

## UI Issues

### Issue: SwiftUI View Not Updating

**Symptoms**: UI doesn't refresh when data changes

**Solutions**:

```swift
// 1. Ensure using @Published
@MainActor
class ViewModel: ObservableObject {
    @Published var data: [Item] = []  // ✅

    func load() async {
        data = await fetchData()  // UI updates
    }
}

// 2. Use correct property wrapper
struct ContentView: View {
    @StateObject private var viewModel = ViewModel()  // ✅ For creation
    // @ObservedObject for passing in
    // @EnvironmentObject for dependency injection
}

// 3. Ensure on main actor
@MainActor
func updateUI() {
    // UI updates
}

// Or explicitly
Task { @MainActor in
    viewModel.data = newData
}
```

### Issue: List Performance Issues

**Symptoms**: Scrolling is laggy, list is slow

**Solutions**:

```swift
// 1. Use id for ForEach
ForEach(items, id: \.id) { item in  // ✅
    ItemRow(item: item)
}

// 2. Extract rows into separate views
struct ItemRow: View {
    let item: Item

    var body: some View {
        // Row content
    }
}

// 3. Use LazyVStack for long lists
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemRow(item: item)
        }
    }
}

// 4. Limit data
let displayedItems = items.prefix(100)
```

---

## Getting Help

If you encounter issues not covered here:

1. **Check Logs**: Look at console and crash logs
2. **Search Issues**: Check GitHub issues
3. **Ask for Help**: Create new issue with:
   - Description of problem
   - Steps to reproduce
   - Environment details (iOS version, Xcode version)
   - Relevant logs or screenshots

## Useful Debugging Commands

```bash
# View all simulators
xcrun simctl list

# Reset simulator
xcrun simctl erase all

# View device logs
xcrun simctl spawn booted log stream --level debug

# Check code signing
codesign -vv -d YourApp.app

# View crash logs
~/Library/Logs/DiagnosticReports

# Clean all caches
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/CocoaPods
rm -rf ~/Library/Caches/org.swift.swiftpm
```

---

For additional help, see other documentation files or contact the development team.
