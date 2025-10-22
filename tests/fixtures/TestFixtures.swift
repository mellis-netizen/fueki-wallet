import Foundation
@testable import FuekiWallet

/// Centralized test fixtures and mock data for comprehensive test coverage
struct TestFixtures {

    // MARK: - Test Addresses

    static let addresses = TestAddresses()

    struct TestAddresses {
        let valid = [
            "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            "0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359",
            "0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB",
            "0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb"
        ]

        let invalid = [
            "invalid-address",
            "0x123",  // Too short
            "0xZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ",  // Invalid chars
            "",
            "0x"
        ]

        let checksumMismatch = "0x742d35cc6634c0532925a3b844bc9e7595f0beb"  // lowercase
    }

    // MARK: - Test Keys

    static let keys = TestKeys()

    struct TestKeys {
        let ed25519PrivateKey = Data([
            0x9d, 0x61, 0xb1, 0x9d, 0xef, 0xfd, 0x5a, 0x60,
            0xba, 0x84, 0x4a, 0xf4, 0x92, 0xec, 0x2c, 0xc4,
            0x44, 0x49, 0xc5, 0x69, 0x7b, 0x32, 0x69, 0x19,
            0x70, 0x3b, 0xac, 0x03, 0x1c, 0xae, 0x7f, 0x60
        ])

        let ed25519PublicKey = Data([
            0xd7, 0x5a, 0x98, 0x01, 0x82, 0xb1, 0x0a, 0xb7,
            0xd5, 0x4b, 0xfe, 0xd3, 0xc9, 0x64, 0x07, 0x3a,
            0x0e, 0xe1, 0x72, 0xf3, 0xda, 0xa6, 0x23, 0x25,
            0xaf, 0x02, 0x1a, 0x68, 0xf7, 0x07, 0x51, 0x1a
        ])
    }

    // MARK: - Test Mnemonics

    static let mnemonics = TestMnemonics()

    struct TestMnemonics {
        let valid12Word = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

        let valid24Word = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"

        let invalid = [
            "abandon",  // Too few words
            "invalid words that dont exist in bip39 wordlist test wallet",
            ""
        ]
    }

    // MARK: - Test Transactions

    static let transactions = TestTransactions()

    struct TestTransactions {
        let simpleTransfer = TransactionData(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,  // 1 Gwei
            nonce: 0,
            gasPrice: 20_000_000_000,  // 20 Gwei
            gasLimit: 21_000
        )

        let erc20Transfer = TransactionData(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",  // USDC contract
            amount: 0,
            nonce: 1,
            gasPrice: 25_000_000_000,
            gasLimit: 65_000,
            data: "0xa9059cbb0000000000000000000000005aaeb6053f3e94c9b9a09f33669435e7ef1beaed00000000000000000000000000000000000000000000000000000000000f4240"
        )

        let contractDeployment = TransactionData(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: nil,  // Contract deployment
            amount: 0,
            nonce: 2,
            gasPrice: 30_000_000_000,
            gasLimit: 2_000_000,
            data: "0x608060405234801561001057600080fd5b50610150806100206000396000f3fe"
        )

        struct TransactionData {
            let from: String
            let to: String?
            let amount: UInt64
            let nonce: UInt64
            let gasPrice: UInt64
            let gasLimit: UInt64
            let data: String?

            init(from: String, to: String?, amount: UInt64, nonce: UInt64,
                 gasPrice: UInt64, gasLimit: UInt64, data: String? = nil) {
                self.from = from
                self.to = to
                self.amount = amount
                self.nonce = nonce
                self.gasPrice = gasPrice
                self.gasLimit = gasLimit
                self.data = data
            }
        }
    }

    // MARK: - Test Blocks

    static let blocks = TestBlocks()

    struct TestBlocks {
        let genesisBlock = BlockData(
            number: 0,
            hash: "0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3",
            parentHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
            timestamp: 1438269988,
            transactions: []
        )

        struct BlockData {
            let number: UInt64
            let hash: String
            let parentHash: String
            let timestamp: UInt64
            let transactions: [String]
        }
    }

    // MARK: - Test TSS Configurations

    static let tssConfigs = TSSConfigurations()

    struct TSSConfigurations {
        let config2of3 = TSSConfig(threshold: 2, totalShards: 3)
        let config3of5 = TSSConfig(threshold: 3, totalShards: 5)
        let config5of7 = TSSConfig(threshold: 5, totalShards: 7)
        let config7of10 = TSSConfig(threshold: 7, totalShards: 10)

        struct TSSConfig {
            let threshold: UInt
            let totalShards: UInt
        }
    }

    // MARK: - Test Network Configurations

    static let networks = TestNetworks()

    struct TestNetworks {
        let ethereum = NetworkConfig(
            name: "Ethereum Mainnet",
            chainId: 1,
            rpcUrl: "https://mainnet.infura.io/v3/YOUR-PROJECT-ID",
            symbol: "ETH",
            decimals: 18
        )

        let sepolia = NetworkConfig(
            name: "Sepolia Testnet",
            chainId: 11155111,
            rpcUrl: "https://sepolia.infura.io/v3/YOUR-PROJECT-ID",
            symbol: "ETH",
            decimals: 18
        )

        let polygon = NetworkConfig(
            name: "Polygon",
            chainId: 137,
            rpcUrl: "https://polygon-rpc.com",
            symbol: "MATIC",
            decimals: 18
        )

        struct NetworkConfig {
            let name: String
            let chainId: Int
            let rpcUrl: String
            let symbol: String
            let decimals: Int
        }
    }

    // MARK: - Mock Services

    static func createMockWallet() throws -> Wallet {
        let cryptoService = CryptoService()
        let keyPair = try cryptoService.generateEd25519KeyPair()

        return Wallet(
            id: UUID().uuidString,
            name: "Test Wallet",
            address: addresses.valid[0],
            publicKey: keyPair.publicKey,
            createdAt: Date()
        )
    }

    static func createMockTransaction() throws -> Transaction {
        let tx = transactions.simpleTransfer
        return Transaction(
            from: tx.from,
            to: tx.to!,
            amount: tx.amount,
            nonce: tx.nonce,
            gasPrice: tx.gasPrice,
            gasLimit: tx.gasLimit
        )
    }

    // MARK: - Test Data Generators

    static func generateRandomAddress() -> String {
        let bytes = (0..<20).map { _ in UInt8.random(in: 0...255) }
        return "0x" + bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func generateRandomHash() -> String {
        let bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        return "0x" + bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func generateRandomData(length: Int) -> Data {
        var data = Data(count: length)
        _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!) }
        return data
    }
}

// MARK: - Mock Network Service

class MockBlockchainService: BlockchainService {
    var mockBalance: UInt64 = 1_000_000_000_000  // 1 ETH in Wei
    var mockNonce: UInt64 = 0
    var mockGasPrice: UInt64 = 20_000_000_000  // 20 Gwei
    var mockTransactionHash: String = TestFixtures.generateRandomHash()
    var shouldFail = false

    override func getBalance(for address: String) async throws -> UInt64 {
        if shouldFail {
            throw BlockchainError.networkError
        }
        return mockBalance
    }

    override func getTransactionCount(for address: String) async throws -> UInt64 {
        if shouldFail {
            throw BlockchainError.networkError
        }
        return mockNonce
    }

    override func sendTransaction(_ transaction: SignedTransaction) async throws -> String {
        if shouldFail {
            throw BlockchainError.transactionFailed
        }
        return mockTransactionHash
    }
}

// MARK: - Mock Crypto Service

class MockCryptoService {
    func generateMockKeyPair() throws -> (privateKey: Data, publicKey: Data) {
        return (
            privateKey: TestFixtures.keys.ed25519PrivateKey,
            publicKey: TestFixtures.keys.ed25519PublicKey
        )
    }

    func generateMockSignature() -> Data {
        return Data(repeating: 0xAB, count: 64)
    }
}

// MARK: - Test Assertions Helpers

extension XCTestCase {
    func XCTAssertValidAddress(_ address: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(address.hasPrefix("0x"), "Address should start with 0x", file: file, line: line)
        XCTAssertEqual(address.count, 42, "Address should be 42 characters", file: file, line: line)
    }

    func XCTAssertValidHash(_ hash: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(hash.hasPrefix("0x"), "Hash should start with 0x", file: file, line: line)
        XCTAssertEqual(hash.count, 66, "Hash should be 66 characters", file: file, line: line)
    }

    func XCTAssertValidSignature(_ signature: Data, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(signature.count, 64, "Ed25519 signature should be 64 bytes", file: file, line: line)
    }
}
