//
//  TestConfiguration.swift
//  FuekiWalletTests
//
//  Configuration and setup for tests
//

import Foundation
@testable import FuekiWallet

enum TestConfiguration {

    // MARK: - Test Data

    static let testPassword = "SecureTestPassword123!"
    static let testMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    static let testAddresses = [
        "ethereum": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
        "bitcoin": "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
        "solana": "7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK"
    ]

    static let testPrivateKey = Data(repeating: 0x01, count: 32)
    static let testPublicKey = Data(repeating: 0x02, count: 33)

    // MARK: - Test Wallets

    static func createTestWallet() -> Wallet {
        return Wallet(
            id: UUID().uuidString,
            name: "Test Wallet",
            address: testAddresses["ethereum"]!,
            createdAt: Date(),
            isActive: true
        )
    }

    static func createTestTransaction(type: TransactionType = .sent) -> Transaction {
        return Transaction(
            id: UUID().uuidString,
            hash: "0xtest\(Int.random(in: 1000...9999))",
            from: testAddresses["ethereum"]!,
            to: "0x1234567890123456789012345678901234567890",
            amount: Decimal(100000),
            timestamp: Date(),
            status: .confirmed,
            type: type
        )
    }

    // MARK: - Mock Responses

    static let mockBalanceResponse = """
    {
        "result": "0x16345785d8a0000"
    }
    """

    static let mockTransactionResponse = """
    {
        "result": [
            {
                "hash": "0xabc123",
                "from": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
                "to": "0x1234567890123456789012345678901234567890",
                "value": "0x16345785d8a0000",
                "blockNumber": "0x1234"
            }
        ]
    }
    """

    static let mockGasEstimateResponse = """
    {
        "result": "0x5208"
    }
    """

    // MARK: - Test Environment

    static var isRunningTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static var isUITesting: Bool {
        return ProcessInfo.processInfo.arguments.contains("UI-Testing")
    }

    static var shouldUseMockData: Bool {
        return ProcessInfo.processInfo.arguments.contains("MockData-Enabled")
    }

    // MARK: - Cleanup

    static func cleanupTestData() async throws {
        // Clear keychain test data
        let keychain = KeychainManager()
        try? keychain.clear()

        // Clear UserDefaults test data
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        // Clear CoreData test data
        // Implementation would go here
    }
}

// MARK: - Transaction Type Extension

enum TransactionType {
    case sent
    case received
    case pending
}

// MARK: - Test Assertions

extension XCTestCase {

    func assertNoThrow<T>(
        _ expression: @autoclosure () throws -> T,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            _ = try expression()
        } catch {
            XCTFail("Unexpected error: \(error). \(message)", file: file, line: line)
        }
    }

    func assertThrows<T, E: Error>(
        _ expression: @autoclosure () throws -> T,
        expectedError: E,
        file: StaticString = #filePath,
        line: UInt = #line
    ) where E: Equatable {
        do {
            _ = try expression()
            XCTFail("Expected to throw error but succeeded", file: file, line: line)
        } catch let error as E {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } catch {
            XCTFail("Threw wrong error type: \(error)", file: file, line: line)
        }
    }
}

// MARK: - Async Testing Helpers

extension XCTestCase {

    func waitFor(
        timeout: TimeInterval = 5.0,
        condition: @escaping () async -> Bool
    ) async throws {
        let startTime = Date()

        while !await condition() {
            if Date().timeIntervalSince(startTime) > timeout {
                throw TestError.timeout
            }

            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
    }
}

enum TestError: Error {
    case timeout
    case invalidTestData
    case setupFailed
}

// MARK: - Data Extension

extension Data {
    mutating func zeroMemory() {
        self.withUnsafeMutableBytes { bytes in
            memset(bytes.baseAddress!, 0, bytes.count)
        }
    }
}
