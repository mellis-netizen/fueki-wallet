# Fueki Wallet - Testing Strategy

## Testing Philosophy

We follow a comprehensive testing strategy with emphasis on:
- **Test-Driven Development (TDD)**: Write tests before implementation
- **High Coverage**: Aim for 80%+ code coverage
- **Automated Testing**: Run tests on every commit
- **Fast Feedback**: Tests should run quickly
- **Maintainable**: Tests are code too - keep them clean

## Test Pyramid

```
        ┌─────────────────┐
        │   UI Tests      │  10% - End-to-end flows
        │   (Slow)        │
        ├─────────────────┤
        │ Integration     │  20% - Component interaction
        │ Tests (Medium)  │
        ├─────────────────┤
        │   Unit Tests    │  70% - Individual components
        │   (Fast)        │
        └─────────────────┘
```

## Unit Testing

### Setup

**Test Target**: `FuekiWalletTests`

**Framework**: XCTest + Quick/Nimble (optional)

```swift
import XCTest
@testable import FuekiWallet

class WalletViewModelTests: XCTestCase {
    var sut: WalletViewModel!
    var mockService: MockWalletService!

    override func setUp() {
        super.setUp()
        mockService = MockWalletService()
        sut = WalletViewModel(walletService: mockService)
    }

    override func tearDown() {
        sut = nil
        mockService = nil
        super.tearDown()
    }

    func testLoadWallets_Success() async {
        // Given
        let expectedWallets = [Wallet.mock(), Wallet.mock()]
        mockService.walletsToReturn = expectedWallets

        // When
        await sut.loadWallets()

        // Then
        XCTAssertEqual(sut.wallets.count, 2)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }

    func testLoadWallets_Failure() async {
        // Given
        mockService.shouldFail = true

        // When
        await sut.loadWallets()

        // Then
        XCTAssertTrue(sut.wallets.isEmpty)
        XCTAssertNotNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }
}
```

### Testing ViewModels

**Pattern**: Arrange-Act-Assert (AAA)

```swift
class TransactionViewModelTests: XCTestCase {
    func testSendTransaction() async throws {
        // Arrange
        let mockService = MockTransactionService()
        let viewModel = TransactionViewModel(service: mockService)
        let recipient = "0x1234..."
        let amount = Decimal(0.5)

        // Act
        try await viewModel.sendTransaction(
            to: recipient,
            amount: amount
        )

        // Assert
        XCTAssertTrue(mockService.sendCalled)
        XCTAssertEqual(mockService.lastRecipient, recipient)
        XCTAssertEqual(mockService.lastAmount, amount)
        XCTAssertTrue(viewModel.transactionSent)
    }
}
```

### Testing Use Cases

```swift
class CreateWalletUseCaseTests: XCTestCase {
    var sut: CreateWalletUseCase!
    var mockRepository: MockWalletRepository!
    var mockKeyManager: MockKeyManager!

    override func setUp() {
        super.setUp()
        mockRepository = MockWalletRepository()
        mockKeyManager = MockKeyManager()
        sut = CreateWalletUseCase(
            repository: mockRepository,
            keyManager: mockKeyManager
        )
    }

    func testExecute_CreatesWalletSuccessfully() async throws {
        // Given
        let name = "Test Wallet"
        let type = WalletType.ethereum

        // When
        let wallet = try await sut.execute(name: name, type: type)

        // Then
        XCTAssertEqual(wallet.name, name)
        XCTAssertEqual(wallet.type, type)
        XCTAssertTrue(mockKeyManager.generateKeyCalled)
        XCTAssertTrue(mockRepository.saveCalled)
    }

    func testExecute_ThrowsError_WhenKeyGenerationFails() async {
        // Given
        mockKeyManager.shouldFailKeyGeneration = true

        // When/Then
        do {
            _ = try await sut.execute(name: "Test", type: .ethereum)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is KeyManagerError)
        }
    }
}
```

### Testing Repository

```swift
class WalletRepositoryTests: XCTestCase {
    var sut: WalletRepository!
    var mockNetwork: MockNetworkManager!
    var mockStorage: MockCoreDataManager!

    func testFetchWallets_ReturnsFromCache_WhenAvailable() async throws {
        // Given
        let cachedWallets = [WalletEntity.mock()]
        mockStorage.entitiesToReturn = cachedWallets

        // When
        let wallets = try await sut.fetchWallets()

        // Then
        XCTAssertEqual(wallets.count, 1)
        XCTAssertFalse(mockNetwork.requestCalled)
    }

    func testFetchWallets_FetchesFromNetwork_WhenCacheEmpty() async throws {
        // Given
        mockStorage.entitiesToReturn = []
        mockNetwork.walletsToReturn = [Wallet.mock()]

        // When
        let wallets = try await sut.fetchWallets()

        // Then
        XCTAssertEqual(wallets.count, 1)
        XCTAssertTrue(mockNetwork.requestCalled)
        XCTAssertTrue(mockStorage.saveCalled)
    }
}
```

### Mock Objects

```swift
class MockWalletService: WalletServiceProtocol {
    var walletsToReturn: [Wallet] = []
    var shouldFail = false
    var fetchCalled = false

    func fetchWallets() async throws -> [Wallet] {
        fetchCalled = true

        if shouldFail {
            throw WalletServiceError.fetchFailed
        }

        return walletsToReturn
    }

    func createWallet(name: String) async throws -> Wallet {
        if shouldFail {
            throw WalletServiceError.createFailed
        }
        return Wallet.mock(name: name)
    }
}

extension Wallet {
    static func mock(
        id: UUID = UUID(),
        name: String = "Test Wallet",
        address: String = "0x1234567890abcdef",
        type: WalletType = .ethereum
    ) -> Wallet {
        Wallet(
            id: id,
            name: name,
            address: address,
            type: type,
            balance: 0,
            createdAt: Date()
        )
    }
}
```

## Integration Testing

### Network Integration Tests

```swift
class NetworkIntegrationTests: XCTestCase {
    var networkManager: NetworkManager!

    override func setUp() {
        super.setUp()
        // Use test environment
        networkManager = NetworkManager(
            baseURL: URL(string: "https://api-staging.fueki.io")!
        )
    }

    func testFetchWalletBalance() async throws {
        // Given
        let address = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"

        // When
        let balance: WalletBalance = try await networkManager.request(
            .walletBalance(address: address)
        )

        // Then
        XCTAssertGreaterThanOrEqual(balance.amount, 0)
        XCTAssertEqual(balance.address.lowercased(), address.lowercased())
    }

    func testInvalidAddress_ReturnsError() async {
        // Given
        let invalidAddress = "invalid"

        // When/Then
        do {
            let _: WalletBalance = try await networkManager.request(
                .walletBalance(address: invalidAddress)
            )
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }
}
```

### Storage Integration Tests

```swift
class CoreDataIntegrationTests: XCTestCase {
    var coreDataManager: CoreDataManager!

    override func setUp() {
        super.setUp()
        // Use in-memory store for tests
        coreDataManager = CoreDataManager(inMemory: true)
    }

    func testSaveAndFetchWallet() throws {
        // Given
        let wallet = Wallet.mock()
        let entity = WalletEntity(context: coreDataManager.context)
        entity.id = wallet.id
        entity.name = wallet.name
        entity.address = wallet.address

        // When
        try coreDataManager.save(entity)
        let fetched: [WalletEntity] = try coreDataManager.fetch()

        // Then
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, wallet.id)
    }
}
```

## UI Testing

### Setup

**Test Target**: `FuekiWalletUITests`

```swift
import XCTest

class WalletFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launchEnvironment = [
            "MOCK_DATA": "true",
            "SKIP_BIOMETRICS": "true"
        ]
        app.launch()
    }

    func testCreateWallet() {
        // Navigate to create wallet
        app.buttons["Create Wallet"].tap()

        // Fill in wallet name
        let nameField = app.textFields["Wallet Name"]
        nameField.tap()
        nameField.typeText("My Test Wallet")

        // Select wallet type
        app.buttons["Ethereum"].tap()

        // Create wallet
        app.buttons["Create"].tap()

        // Verify wallet created
        XCTAssertTrue(app.staticTexts["My Test Wallet"].exists)
    }

    func testSendTransaction() {
        // Given wallet exists
        let wallet = app.cells.firstMatch
        wallet.tap()

        // When sending transaction
        app.buttons["Send"].tap()

        let recipientField = app.textFields["Recipient Address"]
        recipientField.tap()
        recipientField.typeText("0x1234567890abcdef")

        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("0.5")

        app.buttons["Send Transaction"].tap()

        // Verify confirmation
        XCTAssertTrue(app.alerts["Transaction Sent"].exists)
    }
}
```

### Page Object Pattern

```swift
class WalletListScreen {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    var createWalletButton: XCUIElement {
        app.buttons["Create Wallet"]
    }

    func walletCell(named name: String) -> XCUIElement {
        app.cells.containing(.staticText, identifier: name).element
    }

    @discardableResult
    func tapCreateWallet() -> CreateWalletScreen {
        createWalletButton.tap()
        return CreateWalletScreen(app: app)
    }

    @discardableResult
    func tapWallet(named name: String) -> WalletDetailScreen {
        walletCell(named: name).tap()
        return WalletDetailScreen(app: app)
    }
}

// Usage
func testWalletFlow() {
    let walletList = WalletListScreen(app: app)
    walletList
        .tapCreateWallet()
        .enterName("Test Wallet")
        .selectType(.ethereum)
        .create()

    XCTAssertTrue(walletList.walletCell(named: "Test Wallet").exists)
}
```

## Snapshot Testing

### Setup

```bash
# Install SnapshotTesting library
# Add to Package.swift or Podfile
.package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.12.0")
```

### Usage

```swift
import SnapshotTesting

class WalletViewSnapshotTests: XCTestCase {
    func testWalletView() {
        let wallet = Wallet.mock()
        let view = WalletView(wallet: wallet)
            .frame(width: 375, height: 812)

        assertSnapshot(matching: view, as: .image)
    }

    func testWalletView_DarkMode() {
        let wallet = Wallet.mock()
        let view = WalletView(wallet: wallet)
            .preferredColorScheme(.dark)
            .frame(width: 375, height: 812)

        assertSnapshot(matching: view, as: .image)
    }
}
```

## Performance Testing

```swift
class PerformanceTests: XCTestCase {
    func testWalletListPerformance() {
        let wallets = (0..<1000).map { Wallet.mock(name: "Wallet \($0)") }
        let viewModel = WalletViewModel()
        viewModel.wallets = wallets

        measure {
            _ = viewModel.filteredWallets(searchText: "Wallet 5")
        }
    }

    func testDatabasePerformance() {
        let coreData = CoreDataManager(inMemory: true)

        measure {
            for i in 0..<100 {
                let entity = WalletEntity(context: coreData.context)
                entity.id = UUID()
                entity.name = "Wallet \(i)"
                try! coreData.save(entity)
            }
        }
    }
}
```

## Code Coverage

### Enable Coverage

```bash
# In Xcode
Edit Scheme > Test > Options > Code Coverage ✓

# Command line
xcodebuild test \
  -workspace FuekiWallet.xcworkspace \
  -scheme FuekiWallet \
  -enableCodeCoverage YES
```

### View Coverage

```bash
# Generate coverage report
xcrun xccov view \
  --report \
  ~/Library/Developer/Xcode/DerivedData/FuekiWallet-*/Logs/Test/*.xcresult

# Or in Xcode
# Show Report Navigator (⌘9) > Coverage tab
```

### Coverage Goals

- **Overall**: 80%+
- **ViewModels**: 90%+
- **Use Cases**: 95%+
- **Repositories**: 85%+
- **UI Layer**: 60%+

## Running Tests

### Xcode

```bash
# All tests
⌘U

# Specific test
Control-click test function > Test "testName"

# All tests in file
Control-click test class > Test "ClassName"
```

### Command Line

```bash
# Run all tests
xcodebuild test \
  -workspace FuekiWallet.xcworkspace \
  -scheme FuekiWallet \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test \
  -workspace FuekiWallet.xcworkspace \
  -scheme FuekiWallet \
  -only-testing:FuekiWalletTests/WalletViewModelTests

# Run with coverage
xcodebuild test \
  -workspace FuekiWallet.xcworkspace \
  -scheme FuekiWallet \
  -enableCodeCoverage YES \
  -resultBundlePath ./TestResults.xcresult
```

### Fastlane

```ruby
lane :test do
  run_tests(
    workspace: "FuekiWallet.xcworkspace",
    scheme: "FuekiWallet",
    devices: ["iPhone 15", "iPad Pro (12.9-inch)"],
    code_coverage: true
  )
end
```

## Continuous Testing

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running tests..."
xcodebuild test \
  -workspace FuekiWallet.xcworkspace \
  -scheme FuekiWallet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -quiet

if [ $? -ne 0 ]; then
    echo "Tests failed. Commit aborted."
    exit 1
fi
```

### GitHub Actions

```yaml
- name: Run Tests
  run: |
    xcodebuild test \
      -workspace ios/FuekiWallet.xcworkspace \
      -scheme FuekiWallet \
      -destination 'platform=iOS Simulator,name=iPhone 15' \
      -enableCodeCoverage YES \
      | xcbeautify

- name: Upload Coverage
  uses: codecov/codecov-action@v3
  with:
    files: ./coverage.xml
    flags: ios
```

## Test Data

### Fixtures

```swift
enum Fixtures {
    static let wallets: [Wallet] = [
        Wallet(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Main Wallet",
            address: "0x1111111111111111111111111111111111111111",
            type: .ethereum,
            balance: 1.5,
            createdAt: Date()
        ),
        // More fixtures...
    ]

    static let transactions: [Transaction] = [
        // Transaction fixtures
    ]
}
```

### Test Doubles Strategy

- **Mocks**: For services that change state
- **Stubs**: For simple data returns
- **Spies**: For verification of calls
- **Fakes**: For complex behavior simulation

## Best Practices

1. **Test Naming**: `test_MethodName_Condition_ExpectedResult`
2. **One Assert Per Test**: Focus on single behavior
3. **Fast Tests**: Keep tests under 100ms when possible
4. **Isolated Tests**: No dependencies between tests
5. **Readable Tests**: Code should be self-documenting
6. **Test Coverage**: Aim for high coverage, but quality over quantity
7. **Mock External Dependencies**: Network, storage, etc.
8. **Test Edge Cases**: Empty states, errors, boundary conditions

---

For security testing procedures, see [SECURITY.md](SECURITY.md).
