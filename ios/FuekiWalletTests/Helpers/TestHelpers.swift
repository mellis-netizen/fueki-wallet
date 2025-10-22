import XCTest
@testable import FuekiWallet

/// Utility functions for testing
enum TestHelpers {

    // MARK: - Async Testing

    /// Executes an async operation with a timeout
    static func withTimeout<T>(
        _ seconds: TimeInterval = 5.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TestError.timeout
            }

            guard let result = try await group.next() else {
                throw TestError.noResult
            }

            group.cancelAll()
            return result
        }
    }

    // MARK: - Data Conversion

    /// Converts hex string to Data
    static func dataFromHex(_ hex: String) -> Data {
        let len = hex.count / 2
        var data = Data(capacity: len)

        for i in 0..<len {
            let j = hex.index(hex.startIndex, offsetBy: i * 2)
            let k = hex.index(j, offsetBy: 2)
            let bytes = hex[j..<k]

            if let num = UInt8(bytes, radix: 16) {
                data.append(num)
            }
        }

        return data
    }

    /// Converts Data to hex string
    static func hexFromData(_ data: Data) -> String {
        return data.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - File Management

    /// Creates a temporary test file
    static func createTemporaryFile(
        name: String = "test_file",
        contents: Data = Data()
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(name)

        try contents.write(to: fileURL)

        return fileURL
    }

    /// Deletes a temporary file
    static func deleteTemporaryFile(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Random Data Generation

    /// Generates random data of specified length
    static func randomData(length: Int) -> Data {
        var data = Data(count: length)
        _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!) }
        return data
    }

    /// Generates random string of specified length
    static func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }

    // MARK: - Comparison Helpers

    /// Compares two Data objects securely (constant time)
    static func secureCompare(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }

        var result = 0
        for i in 0..<lhs.count {
            result |= Int(lhs[i] ^ rhs[i])
        }

        return result == 0
    }

    // MARK: - Wait Helpers

    /// Waits for a condition to be true
    static func waitForCondition(
        timeout: TimeInterval = 5.0,
        pollingInterval: TimeInterval = 0.1,
        condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while !condition() {
            if Date() > deadline {
                throw TestError.timeout
            }

            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }
    }

    // MARK: - Mock Expectations

    /// Verifies that a closure was called
    static func expectCall<T>(
        timeout: TimeInterval = 1.0,
        _ closure: @escaping (@escaping (T) -> Void) -> Void
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            var isResolved = false

            closure { value in
                guard !isResolved else { return }
                isResolved = true
                continuation.resume(returning: value)
            }

            Task {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard !isResolved else { return }
                isResolved = true
                continuation.resume(throwing: TestError.timeout)
            }
        }
    }

    // MARK: - Performance Helpers

    /// Measures execution time of an operation
    static func measureTime<T>(_ operation: () throws -> T) rethrows -> (result: T, duration: TimeInterval) {
        let start = Date()
        let result = try operation()
        let duration = Date().timeIntervalSince(start)

        return (result, duration)
    }

    /// Measures async execution time
    static func measureTimeAsync<T>(_ operation: () async throws -> T) async rethrows -> (result: T, duration: TimeInterval) {
        let start = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(start)

        return (result, duration)
    }

    // MARK: - Assertion Helpers

    /// Asserts that an async operation throws an error
    static func assertThrowsAsync<T>(
        _ operation: @autoclosure () async throws -> T,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line,
        errorHandler: (Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected error to be thrown. \(message)", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }

    /// Asserts that two values are approximately equal
    static func assertApproximatelyEqual<T: FloatingPoint>(
        _ lhs: T,
        _ rhs: T,
        tolerance: T,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let difference = abs(lhs - rhs)
        XCTAssertLessThanOrEqual(
            difference,
            tolerance,
            "\(lhs) is not approximately equal to \(rhs) (tolerance: \(tolerance)). \(message)",
            file: file,
            line: line
        )
    }

    // MARK: - Memory Testing

    /// Verifies that sensitive data is zeroed out
    static func assertDataIsZeroed(
        _ data: Data,
        _ message: String = "Data should be zeroed",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            data.allSatisfy { $0 == 0 },
            message,
            file: file,
            line: line
        )
    }

    /// Verifies that data is not all zeros (has entropy)
    static func assertDataHasEntropy(
        _ data: Data,
        _ message: String = "Data should have entropy",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertFalse(
            data.allSatisfy { $0 == 0 },
            message,
            file: file,
            line: line
        )
    }
}

// MARK: - Test Errors

enum TestError: Error {
    case timeout
    case noResult
    case invalidData
    case setupFailed
    case teardownFailed
}

// MARK: - XCTest Extensions

extension XCTestCase {

    /// Adds teardown block that executes even if test fails
    func addAsyncTeardownBlock(_ block: @escaping () async throws -> Void) {
        addTeardownBlock {
            let task = Task {
                try await block()
            }

            _ = await task.result
        }
    }

    /// Waits for expectations with a shorter default timeout
    func waitForExpectations(timeout: TimeInterval = 2.0) async {
        await fulfillment(of: [], timeout: timeout)
    }
}

// MARK: - Data Extension

extension Data {
    /// Creates Data from hex string
    init?(hexString: String) {
        let hex = hexString.replacingOccurrences(of: " ", with: "")
        let len = hex.count / 2
        var data = Data(capacity: len)

        for i in 0..<len {
            let j = hex.index(hex.startIndex, offsetBy: i * 2)
            let k = hex.index(j, offsetBy: 2)
            let bytes = hex[j..<k]

            if let num = UInt8(bytes, radix: 16) {
                data.append(num)
            } else {
                return nil
            }
        }

        self = data
    }

    /// Converts to hex string
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
