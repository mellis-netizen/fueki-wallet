import Foundation
@testable import FuekiWallet

/// Mock implementations of services for testing

// MARK: - Mock Crypto Service

class MockCryptoService: CryptoService {

    var generateKeyPairCalled = false
    var signCalled = false
    var verifyCalled = false
    var mockKeyPair: KeyPair?
    var mockSignature: Data?
    var mockVerifyResult = true

    override func generateEd25519KeyPair() throws -> KeyPair {
        generateKeyPairCalled = true
        if let mockKeyPair = mockKeyPair {
            return mockKeyPair
        }
        return try super.generateEd25519KeyPair()
    }

    override func sign(_ message: Data, with privateKey: Data) throws -> Data {
        signCalled = true
        if let mockSignature = mockSignature {
            return mockSignature
        }
        return try super.sign(message, with: privateKey)
    }

    override func verify(_ signature: Data, for message: Data, publicKey: Data) throws -> Bool {
        verifyCalled = true
        return mockVerifyResult
    }
}

// MARK: - Mock Blockchain Service

class MockBlockchainService: BlockchainService {

    var connectCalled = false
    var getBalanceCalled = false
    var sendTransactionCalled = false

    var mockBalance: UInt64 = 1_000_000_000 // 1 ETH
    var mockTxHash: String = TestHelpers.generateTestTxHash()
    var mockChainId: Int = 1
    var mockBlockNumber: UInt64 = 15_000_000

    var shouldFailConnection = false
    var shouldFailTransaction = false

    override func connect() async throws -> Bool {
        connectCalled = true
        if shouldFailConnection {
            throw BlockchainError.connectionFailed
        }
        return true
    }

    override func getBalance(for address: String) async throws -> UInt64 {
        getBalanceCalled = true
        return mockBalance
    }

    override func sendTransaction(_ transaction: SignedTransaction) async throws -> String {
        sendTransactionCalled = true
        if shouldFailTransaction {
            throw BlockchainError.transactionFailed
        }
        return mockTxHash
    }

    override func getChainId() async throws -> Int {
        return mockChainId
    }

    override func getLatestBlockNumber() async throws -> UInt64 {
        return mockBlockNumber
    }
}

// MARK: - Mock Secure Storage Service

class MockSecureStorageService: SecureStorageService {

    var storage: [String: Data] = [:]
    var storeCalled = false
    var retrieveCalled = false
    var deleteCalled = false

    override func store(_ data: Data, forKey key: String, accessibility: KeychainAccessibility = .whenUnlockedThisDeviceOnly) throws {
        storeCalled = true
        storage[key] = data
    }

    override func retrieve(forKey key: String, context: LAContext? = nil) throws -> Data {
        retrieveCalled = true
        guard let data = storage[key] else {
            throw SecureStorageError.itemNotFound
        }
        return data
    }

    override func delete(forKey key: String) throws {
        deleteCalled = true
        storage.removeValue(forKey: key)
    }

    override func deleteAll(prefix: String) throws {
        let keysToDelete = storage.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToDelete {
            storage.removeValue(forKey: key)
        }
    }
}

// MARK: - Mock TSS Service

class MockTSSService: TSSService {

    var generateShardsCalled = false
    var reconstructSecretCalled = false
    var mockShards: [TSSShard] = []
    var mockReconstructedSecret: Data?

    override func generateShards(from secret: Data, threshold: Int, totalShards: Int) throws -> [TSSShard] {
        generateShardsCalled = true

        if !mockShards.isEmpty {
            return mockShards
        }

        // Generate mock shards
        var shards: [TSSShard] = []
        for i in 0..<totalShards {
            let shard = TSSShard(
                id: i,
                data: TestHelpers.generateTestPrivateKey(),
                threshold: threshold,
                totalShards: totalShards
            )
            shards.append(shard)
        }

        return shards
    }

    override func reconstructSecret(from shards: [TSSShard]) throws -> Data {
        reconstructSecretCalled = true

        if let mockSecret = mockReconstructedSecret {
            return mockSecret
        }

        // Return mock secret
        return TestHelpers.generateTestPrivateKey()
    }
}

// MARK: - Mock Transaction Service

class MockTransactionService: TransactionService {

    var createTransactionCalled = false
    var signCalled = false
    var serializeCalled = false

    var mockTransaction: Transaction?
    var mockSignedTransaction: SignedTransaction?

    override func createTransaction(
        from: String,
        to: String,
        amount: UInt64,
        nonce: UInt64,
        gasPrice: UInt64 = 20_000_000_000,
        gasLimit: UInt64 = 21_000
    ) throws -> Transaction {
        createTransactionCalled = true

        if let mockTransaction = mockTransaction {
            return mockTransaction
        }

        return Transaction(
            from: from,
            to: to,
            amount: amount,
            nonce: nonce,
            gasPrice: gasPrice,
            gasLimit: gasLimit
        )
    }

    override func sign(_ transaction: Transaction, with privateKey: Data) throws -> SignedTransaction {
        signCalled = true

        if let mockSignedTransaction = mockSignedTransaction {
            return mockSignedTransaction
        }

        return SignedTransaction(
            transaction: transaction,
            signature: TestHelpers.generateTestPrivateKey(),
            r: TestHelpers.generateTestPrivateKey(),
            s: TestHelpers.generateTestPrivateKey(),
            v: 27
        )
    }

    override func serialize(_ transaction: Transaction) throws -> Data {
        serializeCalled = true
        return Data([0x01, 0x02, 0x03]) // Mock serialized data
    }
}

// MARK: - Mock Wallet Service

class MockWalletService: WalletService {

    var createWalletCalled = false
    var importWalletCalled = false
    var mockWallet: Wallet?

    override func createWallet(name: String) async throws -> Wallet {
        createWalletCalled = true

        if let mockWallet = mockWallet {
            return mockWallet
        }

        return Wallet(
            id: UUID(),
            name: name,
            address: TestHelpers.generateTestAddress(),
            createdAt: Date(),
            isBackedUp: false
        )
    }

    override func importWallet(mnemonic: String, name: String) async throws -> Wallet {
        importWalletCalled = true

        if let mockWallet = mockWallet {
            return mockWallet
        }

        return Wallet(
            id: UUID(),
            name: name,
            address: TestHelpers.generateTestAddress(),
            createdAt: Date(),
            isBackedUp: true
        )
    }
}

// MARK: - Mock Network Service

class MockNetworkService {

    var requestCalled = false
    var mockResponseData: Data?
    var mockError: Error?
    var mockStatusCode = 200

    func request(url: URL) async throws -> (Data, URLResponse) {
        requestCalled = true

        if let error = mockError {
            throw error
        }

        let data = mockResponseData ?? Data()
        let response = HTTPURLResponse(
            url: url,
            statusCode: mockStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!

        return (data, response)
    }
}

// MARK: - Mock Key Derivation Service

class MockKeyDerivationService: KeyDerivationService {

    var generateMasterKeyCalled = false
    var deriveChildKeyCalled = false
    var mockMasterKey: ExtendedKey?
    var mockChildKey: ExtendedKey?

    override func generateMasterKey(from seed: Data) throws -> ExtendedKey {
        generateMasterKeyCalled = true

        if let mockMasterKey = mockMasterKey {
            return mockMasterKey
        }

        return ExtendedKey(
            privateKey: TestHelpers.generateTestPrivateKey(),
            publicKey: TestHelpers.generateTestPrivateKey(),
            chainCode: TestHelpers.generateTestPrivateKey(),
            depth: 0,
            parentFingerprint: Data(repeating: 0, count: 4),
            index: 0
        )
    }

    override func deriveChildKey(from parent: ExtendedKey, index: UInt32, hardened: Bool) throws -> ExtendedKey {
        deriveChildKeyCalled = true

        if let mockChildKey = mockChildKey {
            return mockChildKey
        }

        return ExtendedKey(
            privateKey: TestHelpers.generateTestPrivateKey(),
            publicKey: TestHelpers.generateTestPrivateKey(),
            chainCode: TestHelpers.generateTestPrivateKey(),
            depth: parent.depth + 1,
            parentFingerprint: Data(repeating: 0, count: 4),
            index: hardened ? (index | 0x80000000) : index
        )
    }
}

// MARK: - Test Fixtures

class TestFixtures {

    // Valid test mnemonic (test vector from BIP39)
    static let validMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    // Test addresses
    static let testAddress1 = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
    static let testAddress2 = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"

    // Test transaction hashes
    static let testTxHash1 = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    static let testTxHash2 = "0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321"

    // Test wallet
    static func createTestWallet() -> Wallet {
        return Wallet(
            id: UUID(),
            name: "Test Wallet",
            address: testAddress1,
            createdAt: Date(),
            isBackedUp: false
        )
    }

    // Test transaction
    static func createTestTransaction() -> Transaction {
        return Transaction(
            from: testAddress1,
            to: testAddress2,
            amount: 1_000_000_000,
            nonce: 5,
            gasPrice: 20_000_000_000,
            gasLimit: 21_000
        )
    }
}
