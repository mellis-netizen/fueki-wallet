import Foundation
import XCTest
@testable import FuekiWallet

/// Helper utilities for testing
class TestHelpers {

    // MARK: - Test Data Generation

    /// Generate test mnemonic phrases
    static func generateTestMnemonic(wordCount: Int = 12) -> String {
        let words = [
            "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract",
            "absurd", "abuse", "access", "accident", "account", "accuse", "achieve", "acid"
        ]

        return (0..<wordCount).map { _ in words.randomElement()! }.joined(separator: " ")
    }

    /// Generate test Ethereum addresses
    static func generateTestAddress() -> String {
        let hex = "0123456789abcdef"
        var address = "0x"
        for _ in 0..<40 {
            address += String(hex.randomElement()!)
        }
        return address
    }

    /// Generate test transaction hash
    static func generateTestTxHash() -> String {
        let hex = "0123456789abcdef"
        var hash = "0x"
        for _ in 0..<64 {
            hash += String(hex.randomElement()!)
        }
        return hash
    }

    /// Generate test private key (32 bytes)
    static func generateTestPrivateKey() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        for i in 0..<32 {
            bytes[i] = UInt8.random(in: 1...255) // Avoid all zeros
        }
        return Data(bytes)
    }

    // MARK: - Mock Objects

    /// Create mock wallet for testing
    static func createMockWallet(name: String = "Test Wallet") -> Wallet {
        return Wallet(
            id: UUID(),
            name: name,
            address: generateTestAddress(),
            createdAt: Date(),
            isBackedUp: false
        )
    }

    /// Create mock transaction
    static func createMockTransaction(
        from: String? = nil,
        to: String? = nil,
        amount: UInt64 = 1_000_000
    ) -> Transaction {
        return Transaction(
            from: from ?? generateTestAddress(),
            to: to ?? generateTestAddress(),
            amount: amount,
            nonce: UInt64.random(in: 0...100),
            gasPrice: 20_000_000_000,
            gasLimit: 21_000,
            timestamp: Date()
        )
    }

    /// Create mock transaction receipt
    static func createMockTransactionReceipt(
        status: TransactionStatus = .success
    ) -> TransactionReceipt {
        return TransactionReceipt(
            transactionHash: generateTestTxHash(),
            blockNumber: UInt64.random(in: 1_000_000...2_000_000),
            blockHash: generateTestTxHash(),
            gasUsed: 21_000,
            status: status,
            timestamp: Date()
        )
    }

    // MARK: - Async Testing Helpers

    /// Wait for async condition with timeout
    static func waitForCondition(
        timeout: TimeInterval = 5.0,
        pollingInterval: TimeInterval = 0.1,
        condition: @escaping () -> Bool
    ) async throws {
        let startTime = Date()

        while !condition() {
            if Date().timeIntervalSince(startTime) > timeout {
                throw TestError.timeout
            }
            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }
    }

    /// Execute async code with timeout
    static func withTimeout<T>(
        _ timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TestError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - Assertion Helpers

    /// Assert that two Data values are equal
    static func assertEqual(_ lhs: Data, _ rhs: Data, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(lhs.count, rhs.count, "Data lengths differ", file: file, line: line)
        for i in 0..<lhs.count {
            XCTAssertEqual(lhs[i], rhs[i], "Data differs at byte \(i)", file: file, line: line)
        }
    }

    /// Assert that async operation throws specific error
    static func assertThrowsErrorAsync<T>(
        _ operation: @autoclosure () async throws -> T,
        errorType: Error.Type,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected error of type \(errorType) but succeeded", file: file, line: line)
        } catch {
            XCTAssertTrue(type(of: error) == errorType, "Expected \(errorType) but got \(type(of: error))", file: file, line: line)
        }
    }

    // MARK: - Performance Helpers

    /// Measure average execution time
    static func measureAverageTime(iterations: Int = 100, operation: () throws -> Void) -> TimeInterval {
        var totalTime: TimeInterval = 0

        for _ in 0..<iterations {
            let start = Date()
            try? operation()
            totalTime += Date().timeIntervalSince(start)
        }

        return totalTime / Double(iterations)
    }

    /// Measure memory usage
    static func measureMemoryUsage(_ operation: () throws -> Void) -> UInt64 {
        let before = reportMemory()
        try? operation()
        let after = reportMemory()
        return after - before
    }

    static func reportMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }

    // MARK: - Network Mocking

    /// Mock network response
    static func mockNetworkResponse(data: Data, statusCode: Int = 200) -> URLResponse {
        return HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    /// Create mock JSON response
    static func mockJSONResponse<T: Encodable>(_ object: T) throws -> Data {
        return try JSONEncoder().encode(object)
    }
}

// MARK: - Test Errors

enum TestError: Error {
    case timeout
    case setupFailed
    case mockDataUnavailable
    case assertionFailed(String)
}

// MARK: - XCTest Extensions

extension XCTestCase {

    /// Wait for multiple expectations concurrently
    func fulfillment(of expectations: [XCTestExpectation], timeout: TimeInterval) async {
        await withCheckedContinuation { continuation in
            wait(for: expectations, timeout: timeout)
            continuation.resume()
        }
    }

    /// Create expectation with auto-generated description
    func expectation() -> XCTestExpectation {
        return expectation(description: "Expectation at \(#file):\(#line)")
    }
}

// MARK: - Data Extensions

extension Data {
    /// Create Data from hex string
    init?(hexString: String) {
        let hex = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
        guard hex.count % 2 == 0 else { return nil }

        var data = Data(capacity: hex.count / 2)

        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }

        self = data
    }

    /// Convert Data to hex string
    var hexString: String {
        return "0x" + map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - String Extensions

extension String {
    /// Validate Ethereum address format
    var isValidEthereumAddress: Bool {
        let pattern = "^0x[0-9a-fA-F]{40}$"
        return range(of: pattern, options: .regularExpression) != nil
    }

    /// Checksum Ethereum address
    func toChecksumAddress() -> String {
        // Simplified checksum implementation
        guard isValidEthereumAddress else { return self }
        return self // Full implementation would use Keccak256
    }
}
