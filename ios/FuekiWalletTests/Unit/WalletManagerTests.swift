import XCTest
import ComposableArchitecture
@testable import FuekiWallet

@MainActor
final class WalletManagerTests: XCTestCase {

    var mockKeyManager: MockKeyManager!
    var mockSecureStorage: MockSecureStorage!
    var mockBlockchainProvider: MockBlockchainProvider!
    var walletManager: WalletManager!

    override func setUp() async throws {
        try await super.setUp()
        mockKeyManager = MockKeyManager()
        mockSecureStorage = MockSecureStorage()
        mockBlockchainProvider = MockBlockchainProvider()
        walletManager = WalletManager(
            keyManager: mockKeyManager,
            secureStorage: mockSecureStorage,
            blockchainProvider: mockBlockchainProvider
        )
    }

    override func tearDown() async throws {
        mockKeyManager = nil
        mockSecureStorage = nil
        mockBlockchainProvider = nil
        walletManager = nil
        try await super.tearDown()
    }

    // MARK: - Wallet Creation Tests

    func testCreateWallet_Success() async throws {
        // Given
        let mnemonic = "test word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12"
        mockKeyManager.mockMnemonic = mnemonic
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)
        mockKeyManager.mockPublicKey = Data(repeating: 0x02, count: 33)
        mockKeyManager.mockAddress = "tb1qtest123456789"

        // When
        let result = try await walletManager.createWallet(password: "TestPassword123!")

        // Then
        XCTAssertEqual(result.mnemonic, mnemonic)
        XCTAssertEqual(result.address, "tb1qtest123456789")
        XCTAssertTrue(mockSecureStorage.storeWasCalled)
        XCTAssertNotNil(mockSecureStorage.storedData["privateKey"])
    }

    func testCreateWallet_WeakPassword_ThrowsError() async {
        // Given
        let weakPassword = "123"

        // When/Then
        do {
            _ = try await walletManager.createWallet(password: weakPassword)
            XCTFail("Should throw error for weak password")
        } catch WalletError.weakPassword {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateWallet_KeyGenerationFails_ThrowsError() async {
        // Given
        mockKeyManager.shouldFailKeyGeneration = true

        // When/Then
        do {
            _ = try await walletManager.createWallet(password: "TestPassword123!")
            XCTFail("Should throw error when key generation fails")
        } catch {
            XCTAssertTrue(error is WalletError)
        }
    }

    // MARK: - Wallet Import Tests

    func testImportWallet_ValidMnemonic_Success() async throws {
        // Given
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        mockKeyManager.shouldValidateMnemonic = true
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)
        mockKeyManager.mockPublicKey = Data(repeating: 0x02, count: 33)
        mockKeyManager.mockAddress = "tb1qimported123"

        // When
        let result = try await walletManager.importWallet(
            mnemonic: mnemonic,
            password: "TestPassword123!"
        )

        // Then
        XCTAssertEqual(result.address, "tb1qimported123")
        XCTAssertTrue(mockSecureStorage.storeWasCalled)
    }

    func testImportWallet_InvalidMnemonic_ThrowsError() async {
        // Given
        let invalidMnemonic = "invalid mnemonic phrase"
        mockKeyManager.shouldValidateMnemonic = false

        // When/Then
        do {
            _ = try await walletManager.importWallet(
                mnemonic: invalidMnemonic,
                password: "TestPassword123!"
            )
            XCTFail("Should throw error for invalid mnemonic")
        } catch WalletError.invalidMnemonic {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testImportWallet_EmptyMnemonic_ThrowsError() async {
        // When/Then
        do {
            _ = try await walletManager.importWallet(
                mnemonic: "",
                password: "TestPassword123!"
            )
            XCTFail("Should throw error for empty mnemonic")
        } catch WalletError.invalidMnemonic {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Wallet Unlock Tests

    func testUnlockWallet_CorrectPassword_Success() async throws {
        // Given
        mockSecureStorage.storedData["encryptedPrivateKey"] = Data(repeating: 0x01, count: 32)
        mockKeyManager.shouldDecryptSuccessfully = true
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)

        // When
        let result = try await walletManager.unlockWallet(password: "TestPassword123!")

        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(walletManager.isUnlocked)
    }

    func testUnlockWallet_IncorrectPassword_ThrowsError() async {
        // Given
        mockSecureStorage.storedData["encryptedPrivateKey"] = Data(repeating: 0x01, count: 32)
        mockKeyManager.shouldDecryptSuccessfully = false

        // When/Then
        do {
            _ = try await walletManager.unlockWallet(password: "WrongPassword")
            XCTFail("Should throw error for incorrect password")
        } catch WalletError.incorrectPassword {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUnlockWallet_NoStoredWallet_ThrowsError() async {
        // Given - empty storage

        // When/Then
        do {
            _ = try await walletManager.unlockWallet(password: "TestPassword123!")
            XCTFail("Should throw error when no wallet is stored")
        } catch WalletError.walletNotFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Lock Wallet Tests

    func testLockWallet_Success() async {
        // Given
        walletManager.isUnlocked = true

        // When
        await walletManager.lockWallet()

        // Then
        XCTAssertFalse(walletManager.isUnlocked)
        XCTAssertTrue(mockKeyManager.clearKeysWasCalled)
    }

    // MARK: - Balance Tests

    func testGetBalance_Success() async throws {
        // Given
        mockBlockchainProvider.mockBalance = 100000000 // 1 BTC in satoshis
        walletManager.isUnlocked = true
        mockKeyManager.mockAddress = "tb1qtest123"

        // When
        let balance = try await walletManager.getBalance()

        // Then
        XCTAssertEqual(balance, 100000000)
        XCTAssertTrue(mockBlockchainProvider.getBalanceWasCalled)
    }

    func testGetBalance_WalletLocked_ThrowsError() async {
        // Given
        walletManager.isUnlocked = false

        // When/Then
        do {
            _ = try await walletManager.getBalance()
            XCTFail("Should throw error when wallet is locked")
        } catch WalletError.walletLocked {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testGetBalance_NetworkError_ThrowsError() async {
        // Given
        walletManager.isUnlocked = true
        mockKeyManager.mockAddress = "tb1qtest123"
        mockBlockchainProvider.shouldFailGetBalance = true

        // When/Then
        do {
            _ = try await walletManager.getBalance()
            XCTFail("Should throw error when network fails")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    // MARK: - Transaction History Tests

    func testGetTransactionHistory_Success() async throws {
        // Given
        walletManager.isUnlocked = true
        mockKeyManager.mockAddress = "tb1qtest123"
        mockBlockchainProvider.mockTransactions = [
            Transaction(
                id: "tx1",
                amount: 50000,
                type: .received,
                timestamp: Date(),
                confirmations: 6
            ),
            Transaction(
                id: "tx2",
                amount: 25000,
                type: .sent,
                timestamp: Date().addingTimeInterval(-3600),
                confirmations: 3
            )
        ]

        // When
        let transactions = try await walletManager.getTransactionHistory()

        // Then
        XCTAssertEqual(transactions.count, 2)
        XCTAssertEqual(transactions[0].id, "tx1")
        XCTAssertEqual(transactions[0].type, .received)
    }

    func testGetTransactionHistory_EmptyHistory_ReturnsEmptyArray() async throws {
        // Given
        walletManager.isUnlocked = true
        mockKeyManager.mockAddress = "tb1qtest123"
        mockBlockchainProvider.mockTransactions = []

        // When
        let transactions = try await walletManager.getTransactionHistory()

        // Then
        XCTAssertTrue(transactions.isEmpty)
    }

    // MARK: - Send Transaction Tests

    func testSendTransaction_Success() async throws {
        // Given
        walletManager.isUnlocked = true
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)
        mockBlockchainProvider.mockTransactionID = "newtxid123"

        let recipient = "tb1qrecipient123"
        let amount: UInt64 = 50000
        let fee: UInt64 = 1000

        // When
        let txID = try await walletManager.sendTransaction(
            to: recipient,
            amount: amount,
            fee: fee
        )

        // Then
        XCTAssertEqual(txID, "newtxid123")
        XCTAssertTrue(mockBlockchainProvider.broadcastWasCalled)
    }

    func testSendTransaction_InsufficientBalance_ThrowsError() async {
        // Given
        walletManager.isUnlocked = true
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)
        mockBlockchainProvider.mockBalance = 1000

        // When/Then
        do {
            _ = try await walletManager.sendTransaction(
                to: "tb1qrecipient123",
                amount: 50000,
                fee: 1000
            )
            XCTFail("Should throw error for insufficient balance")
        } catch WalletError.insufficientBalance {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendTransaction_InvalidAddress_ThrowsError() async {
        // Given
        walletManager.isUnlocked = true
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)

        // When/Then
        do {
            _ = try await walletManager.sendTransaction(
                to: "invalid_address",
                amount: 50000,
                fee: 1000
            )
            XCTFail("Should throw error for invalid address")
        } catch WalletError.invalidAddress {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Backup Tests

    func testBackupWallet_Success() async throws {
        // Given
        walletManager.isUnlocked = true
        mockKeyManager.mockMnemonic = "test mnemonic phrase"
        mockSecureStorage.storedData["encryptedMnemonic"] = Data("encrypted".utf8)

        // When
        let backup = try await walletManager.backupWallet()

        // Then
        XCTAssertNotNil(backup.mnemonic)
        XCTAssertNotNil(backup.encryptedData)
        XCTAssertNotNil(backup.createdAt)
    }

    func testRestoreFromBackup_Success() async throws {
        // Given
        let backupData = WalletBackup(
            mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
            encryptedData: Data("encrypted".utf8),
            createdAt: Date()
        )
        mockKeyManager.shouldValidateMnemonic = true

        // When
        try await walletManager.restoreFromBackup(backupData, password: "TestPassword123!")

        // Then
        XCTAssertTrue(mockSecureStorage.storeWasCalled)
    }

    // MARK: - Edge Cases

    func testConcurrentOperations_Success() async throws {
        // Given
        walletManager.isUnlocked = true
        mockKeyManager.mockAddress = "tb1qtest123"
        mockBlockchainProvider.mockBalance = 100000

        // When - run multiple operations concurrently
        async let balance1 = walletManager.getBalance()
        async let balance2 = walletManager.getBalance()
        async let transactions = walletManager.getTransactionHistory()

        let results = try await (balance1, balance2, transactions)

        // Then
        XCTAssertEqual(results.0, 100000)
        XCTAssertEqual(results.1, 100000)
        XCTAssertNotNil(results.2)
    }

    func testWalletStateTransitions() async throws {
        // Test: Created -> Locked -> Unlocked -> Locked

        // Initial state
        XCTAssertFalse(walletManager.isUnlocked)

        // Create and unlock
        mockKeyManager.mockMnemonic = "test mnemonic"
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)
        mockKeyManager.mockAddress = "tb1qtest"
        _ = try await walletManager.createWallet(password: "TestPassword123!")

        XCTAssertTrue(mockSecureStorage.storeWasCalled)

        // Lock
        await walletManager.lockWallet()
        XCTAssertFalse(walletManager.isUnlocked)

        // Unlock
        mockSecureStorage.storedData["encryptedPrivateKey"] = Data(repeating: 0x01, count: 32)
        mockKeyManager.shouldDecryptSuccessfully = true
        _ = try await walletManager.unlockWallet(password: "TestPassword123!")
        XCTAssertTrue(walletManager.isUnlocked)
    }

    // MARK: - Memory Management Tests

    func testSecureDataCleanup_OnLock() async {
        // Given
        walletManager.isUnlocked = true
        mockKeyManager.mockPrivateKey = Data(repeating: 0xFF, count: 32)

        // When
        await walletManager.lockWallet()

        // Then
        XCTAssertTrue(mockKeyManager.clearKeysWasCalled)
        XCTAssertNil(mockKeyManager.mockPrivateKey)
    }

    // MARK: - Performance Tests

    func testWalletCreationPerformance() throws {
        measure {
            Task {
                mockKeyManager.mockMnemonic = "test mnemonic"
                mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)
                mockKeyManager.mockAddress = "tb1qtest"

                _ = try? await walletManager.createWallet(password: "TestPassword123!")
            }
        }
    }

    func testBalanceCheckPerformance() throws {
        walletManager.isUnlocked = true
        mockKeyManager.mockAddress = "tb1qtest123"
        mockBlockchainProvider.mockBalance = 100000

        measure {
            Task {
                _ = try? await walletManager.getBalance()
            }
        }
    }
}
