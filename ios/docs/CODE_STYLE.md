# Fueki Wallet - Swift Code Style Guide

## Overview

This guide defines the coding standards for Fueki Wallet iOS app. Consistent code style improves readability, maintainability, and collaboration.

## Table of Contents

1. [General Principles](#general-principles)
2. [Naming Conventions](#naming-conventions)
3. [Code Organization](#code-organization)
4. [Formatting](#formatting)
5. [Best Practices](#best-practices)
6. [SwiftUI Guidelines](#swiftui-guidelines)
7. [Async/Await Patterns](#asyncawait-patterns)

## General Principles

### Clarity Over Brevity

```swift
// ✅ Good - Clear and descriptive
func fetchWalletBalance(for address: String) async throws -> Decimal

// ❌ Bad - Too abbreviated
func getWB(addr: String) async throws -> Decimal
```

### Consistency

- Follow existing patterns in the codebase
- Use the same approach for similar problems
- Maintain consistent file structure

### Simplicity

- Favor simple, readable code over clever solutions
- Break complex logic into smaller functions
- Use meaningful variable names

## Naming Conventions

### Types

**Classes, Structs, Enums, Protocols** - `UpperCamelCase`

```swift
// ✅ Good
class WalletManager { }
struct TransactionDetail { }
enum NetworkType { }
protocol WalletServiceProtocol { }

// ❌ Bad
class walletManager { }
struct transaction_detail { }
enum network_type { }
```

### Variables and Functions

**Variables, Constants, Functions** - `lowerCamelCase`

```swift
// ✅ Good
let walletAddress: String
var currentBalance: Decimal
func fetchTransactionHistory() { }

// ❌ Bad
let WalletAddress: String
var current_balance: Decimal
func FetchTransactionHistory() { }
```

### Constants

**Global Constants** - `lowerCamelCase` or `UpperCamelCase` for types

```swift
// ✅ Good
let maximumRetryCount = 3
enum Configuration {
    static let apiBaseURL = "https://api.fueki.io"
}

// ❌ Bad
let MAXIMUM_RETRY_COUNT = 3
let max_retry_count = 3
```

### Protocols

**Protocol Names**

```swift
// ✅ Good - Describes capability
protocol WalletServiceProtocol { }
protocol Codable { }

// ✅ Good - Is/Can/Has prefix for state
protocol Hashable { }

// ❌ Bad - Too generic
protocol WalletProtocol { }
```

### Enums

**Enum Cases** - `lowerCamelCase`

```swift
// ✅ Good
enum WalletType {
    case ethereum
    case bitcoin
    case solana
}

// ❌ Bad
enum WalletType {
    case Ethereum
    case BITCOIN
    case solana_mainnet
}
```

### Booleans

**Boolean Variables** - Use `is`, `has`, `should`

```swift
// ✅ Good
var isLoading: Bool
var hasWallet: Bool
var shouldRefresh: Bool

// ❌ Bad
var loading: Bool
var wallet: Bool
var refresh: Bool
```

### Abbreviations

**Avoid Abbreviations**

```swift
// ✅ Good
let transactionIdentifier: String
let maximumConnectionCount: Int

// ❌ Bad
let txId: String
let maxConnCnt: Int

// Exception: Well-known abbreviations OK
let url: URL  // ✅
let id: UUID  // ✅
```

## Code Organization

### File Structure

```swift
// MARK: - Imports
import Foundation
import Combine
import SwiftUI

// MARK: - Protocol Definitions
protocol WalletServiceProtocol {
    func fetchWallets() async throws -> [Wallet]
}

// MARK: - Type Definitions
struct Wallet: Identifiable, Codable {
    let id: UUID
    let name: String
}

// MARK: - Implementation
class WalletService: WalletServiceProtocol {
    // MARK: - Properties
    private let networkManager: NetworkManager

    // MARK: - Initialization
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }

    // MARK: - Public Methods
    func fetchWallets() async throws -> [Wallet] {
        // Implementation
    }

    // MARK: - Private Methods
    private func validateWallet(_ wallet: Wallet) -> Bool {
        // Implementation
    }
}

// MARK: - Extensions
extension WalletService {
    func refreshWallets() async {
        // Implementation
    }
}

// MARK: - Helper Types
private extension WalletService {
    struct Constants {
        static let cacheKey = "wallets"
    }
}
```

### MARK Comments

Use MARK comments to organize code:

```swift
class ViewController: UIViewController {
    // MARK: - Properties
    private let viewModel: ViewModel

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup
    private func setupUI() { }

    // MARK: - Actions
    @objc private func buttonTapped() { }

    // MARK: - Helper Methods
    private func updateBalance() { }
}
```

### Access Control

**Use Appropriate Access Levels**

```swift
// ✅ Good - Explicit access control
public class WalletManager {
    private let storage: Storage
    internal var cache: [String: Wallet] = [:]
    public private(set) var currentWallet: Wallet?

    public func createWallet() { }
    private func validateAddress() { }
}

// ❌ Bad - Everything public
class WalletManager {
    var storage: Storage
    var cache: [String: Wallet] = [:]
    var currentWallet: Wallet?

    func createWallet() { }
    func validateAddress() { }
}
```

**Access Level Order**:
1. `public` / `open`
2. `internal` (default)
3. `fileprivate`
4. `private`

### File Organization

```
FuekiWallet/
├── Features/
│   ├── Wallet/
│   │   ├── Views/
│   │   │   ├── WalletView.swift
│   │   │   └── WalletRowView.swift
│   │   ├── ViewModels/
│   │   │   └── WalletViewModel.swift
│   │   ├── Models/
│   │   │   └── Wallet.swift
│   │   └── Services/
│   │       └── WalletService.swift
│   └── Transaction/
│       └── ...
```

## Formatting

### Line Length

- **Maximum**: 120 characters
- Break long lines at logical points

```swift
// ✅ Good
let wallet = Wallet(
    id: UUID(),
    name: "My Wallet",
    address: "0x1234567890abcdef",
    type: .ethereum
)

// ❌ Bad - Line too long
let wallet = Wallet(id: UUID(), name: "My Wallet", address: "0x1234567890abcdef", type: .ethereum)
```

### Spacing

**Operators**

```swift
// ✅ Good
let sum = a + b
let product = x * y
let range = 0..<10

// ❌ Bad
let sum = a+b
let product = x*y
let range = 0 ..< 10
```

**Colons**

```swift
// ✅ Good - Space after colon
let dict: [String: Int] = [:]
func process(value: String) { }

// ❌ Bad
let dict : [String : Int] = [:]
let dict :[String:Int] = [:]
```

**Braces**

```swift
// ✅ Good - Opening brace on same line
func fetchWallet() {
    // Implementation
}

if condition {
    // Code
} else {
    // Code
}

// ❌ Bad - Opening brace on new line
func fetchWallet()
{
    // Implementation
}
```

### Indentation

- Use **4 spaces** (not tabs)
- Xcode default settings

### Blank Lines

```swift
// ✅ Good - Logical grouping
import Foundation
import Combine

class WalletManager {
    private let storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    func fetchWallets() async throws -> [Wallet] {
        let data = try await storage.load()
        return try decode(data)
    }

    private func decode(_ data: Data) throws -> [Wallet] {
        // Implementation
    }
}

// ❌ Bad - Too many or too few blank lines
import Foundation


import Combine
class WalletManager {

    private let storage: Storage
    init(storage: Storage) {
        self.storage = storage
    }
    func fetchWallets() async throws -> [Wallet] {
        let data = try await storage.load()
        return try decode(data)
    }
    private func decode(_ data: Data) throws -> [Wallet] {
        // Implementation
    }
}
```

## Best Practices

### Optionals

**Use Optional Chaining**

```swift
// ✅ Good
let balance = wallet?.balance ?? 0

// ❌ Bad
var balance: Decimal = 0
if let wallet = wallet {
    balance = wallet.balance
}
```

**Guard for Early Returns**

```swift
// ✅ Good
func processWallet(_ wallet: Wallet?) {
    guard let wallet = wallet else { return }
    // Process wallet
}

// ❌ Bad
func processWallet(_ wallet: Wallet?) {
    if let wallet = wallet {
        // Process wallet
    }
}
```

### Type Inference

**Leverage Type Inference**

```swift
// ✅ Good
let name = "My Wallet"
let balance: Decimal = 0  // Explicit when needed
let wallets = [Wallet]()

// ❌ Bad - Unnecessary type annotation
let name: String = "My Wallet"
let wallets: [Wallet] = [Wallet]()
```

### Constants

**Use Let When Possible**

```swift
// ✅ Good
let apiKey = Configuration.apiKey
let url = URL(string: "https://api.fueki.io")!

// ❌ Bad
var apiKey = Configuration.apiKey
var url = URL(string: "https://api.fueki.io")!
```

### Arrays and Dictionaries

**Use Type Annotation Syntax**

```swift
// ✅ Good
var wallets: [Wallet] = []
var balances: [String: Decimal] = [:]

// ❌ Bad
var wallets: Array<Wallet> = []
var balances: Dictionary<String, Decimal> = [:]
```

### Error Handling

**Use Swift Error Handling**

```swift
// ✅ Good
enum WalletError: Error {
    case invalidAddress
    case insufficientBalance(required: Decimal, available: Decimal)
}

func sendTransaction() throws {
    guard isValidAddress else {
        throw WalletError.invalidAddress
    }
}

// ❌ Bad
func sendTransaction() -> (success: Bool, error: String?) {
    if !isValidAddress {
        return (false, "Invalid address")
    }
    return (true, nil)
}
```

### Closures

**Trailing Closure Syntax**

```swift
// ✅ Good
wallets.map { $0.balance }

UIView.animate(withDuration: 0.3) {
    view.alpha = 0
}

// ❌ Bad
wallets.map({ $0.balance })

UIView.animate(withDuration: 0.3, animations: {
    view.alpha = 0
})
```

**Implicit Returns**

```swift
// ✅ Good - Single expression
let doubled = numbers.map { $0 * 2 }

// ✅ Good - Multiple statements
let processed = numbers.map { number in
    let doubled = number * 2
    return doubled * 3
}
```

### Extensions

**Organize with Extensions**

```swift
// ✅ Good
class WalletViewController: UIViewController {
    // Core implementation
}

extension WalletViewController: UITableViewDelegate {
    // Table view delegate methods
}

extension WalletViewController: UITableViewDataSource {
    // Table view data source methods
}

// ❌ Bad - All in one class
class WalletViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    // Everything mixed together
}
```

### Protocols

**Protocol Conformance in Extensions**

```swift
// ✅ Good
struct Wallet {
    let id: UUID
    let name: String
}

extension Wallet: Codable { }
extension Wallet: Equatable { }

// ❌ Bad
struct Wallet: Codable, Equatable {
    let id: UUID
    let name: String
}
```

## SwiftUI Guidelines

### View Structure

```swift
// ✅ Good
struct WalletView: View {
    @StateObject private var viewModel: WalletViewModel

    var body: some View {
        content
    }

    private var content: some View {
        List {
            ForEach(viewModel.wallets) { wallet in
                WalletRow(wallet: wallet)
            }
        }
        .navigationTitle("Wallets")
    }
}

// ❌ Bad - Everything in body
struct WalletView: View {
    @StateObject private var viewModel: WalletViewModel

    var body: some View {
        List {
            ForEach(viewModel.wallets) { wallet in
                HStack {
                    VStack {
                        Text(wallet.name)
                        Text(wallet.address)
                    }
                    Spacer()
                    Text("\(wallet.balance)")
                }
            }
        }
        .navigationTitle("Wallets")
    }
}
```

### Property Wrappers

```swift
// ✅ Good - Appropriate property wrappers
struct WalletView: View {
    @StateObject private var viewModel: WalletViewModel
    @State private var showingDetail = false
    @Binding var selectedWallet: Wallet?
    @Environment(\.dismiss) private var dismiss
}
```

### ViewModifiers

```swift
// ✅ Good - Extract complex modifiers
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// Usage
Text("Hello").cardStyle()
```

## Async/Await Patterns

### Async Functions

```swift
// ✅ Good
func fetchWallets() async throws -> [Wallet] {
    let response = try await networkManager.request(.wallets)
    return response.data
}

// ❌ Bad - Missing async/throws
func fetchWallets() -> [Wallet] {
    // Synchronous code
}
```

### Task Management

```swift
// ✅ Good
.task {
    await viewModel.loadData()
}

// ✅ Good - Cancellation handling
.task {
    for await value in stream {
        if Task.isCancelled { break }
        process(value)
    }
}
```

### MainActor

```swift
// ✅ Good - UI updates on main actor
@MainActor
class WalletViewModel: ObservableObject {
    @Published var wallets: [Wallet] = []

    func loadWallets() async {
        wallets = try await walletService.fetchWallets()
    }
}
```

## SwiftLint Configuration

**.swiftlint.yml**

```yaml
disabled_rules:
  - trailing_whitespace
  - force_cast
  - force_try

opt_in_rules:
  - empty_count
  - explicit_init
  - first_where
  - sorted_imports

included:
  - FuekiWallet

excluded:
  - Pods
  - FuekiWalletTests
  - FuekiWalletUITests

line_length:
  warning: 120
  error: 150

type_body_length:
  warning: 300
  error: 400

file_length:
  warning: 500
  error: 1000

function_body_length:
  warning: 40
  error: 60

identifier_name:
  min_length:
    warning: 2
  max_length:
    warning: 40
    error: 50
```

## Documentation Comments

```swift
/// Manages wallet operations including creation, import, and deletion.
///
/// This service coordinates with the blockchain network and secure storage
/// to provide a high-level wallet management interface.
///
/// - Important: All private key operations use iOS Keychain for security.
///
/// Example:
/// ```swift
/// let manager = WalletManager()
/// let wallet = try await manager.createWallet(name: "My Wallet")
/// ```
class WalletManager {
    /// Creates a new wallet with the specified parameters.
    ///
    /// - Parameters:
    ///   - name: Display name for the wallet
    ///   - type: Blockchain type (Ethereum, Bitcoin, etc.)
    /// - Returns: Newly created wallet
    /// - Throws: `WalletError` if creation fails
    func createWallet(name: String, type: WalletType) async throws -> Wallet {
        // Implementation
    }
}
```

---

This style guide is enforced through SwiftLint and code reviews. When in doubt, follow existing patterns in the codebase.
