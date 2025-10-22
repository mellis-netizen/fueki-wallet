import XCTest
@testable import FuekiWallet

extension XCTestCase {

    // MARK: - Async Assertion Helpers

    /// Asserts that an async operation throws a specific error type
    func assertThrowsErrorAsync<T, E: Error>(
        _ expression: @autoclosure () async throws -> T,
        errorType: E.Type,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error of type \(errorType) but succeeded. \(message)", file: file, line: line)
        } catch let error as E {
            // Success - correct error type was thrown
        } catch {
            XCTFail("Expected error of type \(errorType) but got \(type(of: error)). \(message)", file: file, line: line)
        }
    }

    /// Asserts that an async operation does not throw
    func assertNoThrowAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) async -> T? {
        do {
            return try await expression()
        } catch {
            XCTFail("Unexpected error: \(error). \(message)", file: file, line: line)
            return nil
        }
    }

    // MARK: - Data Assertions

    /// Asserts that data is valid (not empty, has entropy)
    func assertValidData(
        _ data: Data?,
        expectedMinLength: Int = 1,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(data, "Data should not be nil", file: file, line: line)

        guard let data = data else { return }

        XCTAssertGreaterThanOrEqual(
            data.count,
            expectedMinLength,
            "Data length should be at least \(expectedMinLength) bytes",
            file: file,
            line: line
        )

        XCTAssertFalse(
            data.allSatisfy { $0 == 0 },
            "Data should have entropy (not all zeros)",
            file: file,
            line: line
        )
    }

    /// Asserts that two Data objects are equal
    func assertDataEqual(
        _ lhs: Data?,
        _ rhs: Data?,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(lhs, rhs, message, file: file, line: line)
    }

    // MARK: - Bitcoin-Specific Assertions

    /// Asserts that a Bitcoin address is valid
    func assertValidBitcoinAddress(
        _ address: String?,
        network: BitcoinNetwork,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(address, "Address should not be nil", file: file, line: line)

        guard let address = address else { return }

        XCTAssertFalse(address.isEmpty, "Address should not be empty", file: file, line: line)

        let prefix = network == .testnet ? "tb1" : "bc1"
        XCTAssertTrue(
            address.starts(with: prefix) || address.starts(with: "m") || address.starts(with: "n") || address.starts(with: "1"),
            "Address should start with valid prefix for \(network)",
            file: file,
            line: line
        )
    }

    /// Asserts that a transaction ID is valid
    func assertValidTransactionID(
        _ txid: String?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(txid, "Transaction ID should not be nil", file: file, line: line)

        guard let txid = txid else { return }

        XCTAssertFalse(txid.isEmpty, "Transaction ID should not be empty", file: file, line: line)
        XCTAssertEqual(txid.count, 64, "Transaction ID should be 64 characters (32 bytes hex)", file: file, line: line)

        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        XCTAssertTrue(
            txid.unicodeScalars.allSatisfy { hexCharacters.contains($0) },
            "Transaction ID should only contain hex characters",
            file: file,
            line: line
        )
    }

    /// Asserts that a mnemonic is valid
    func assertValidMnemonic(
        _ mnemonic: String?,
        expectedWordCount: Int? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(mnemonic, "Mnemonic should not be nil", file: file, line: line)

        guard let mnemonic = mnemonic else { return }

        XCTAssertFalse(mnemonic.isEmpty, "Mnemonic should not be empty", file: file, line: line)

        let words = mnemonic.split(separator: " ")

        if let expectedCount = expectedWordCount {
            XCTAssertEqual(
                words.count,
                expectedCount,
                "Mnemonic should have \(expectedCount) words",
                file: file,
                line: line
            )
        } else {
            let validCounts = [12, 15, 18, 21, 24]
            XCTAssertTrue(
                validCounts.contains(words.count),
                "Mnemonic should have 12, 15, 18, 21, or 24 words",
                file: file,
                line: line
            )
        }

        XCTAssertTrue(
            words.allSatisfy { !$0.isEmpty },
            "All mnemonic words should be non-empty",
            file: file,
            line: line
        )
    }

    // MARK: - Amount Assertions

    /// Asserts that an amount is within valid Bitcoin range
    func assertValidBitcoinAmount(
        _ amount: UInt64?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(amount, "Amount should not be nil", file: file, line: line)

        guard let amount = amount else { return }

        XCTAssertGreaterThanOrEqual(
            amount,
            0,
            "Amount should be non-negative",
            file: file,
            line: line
        )

        let maxBitcoin: UInt64 = 21_000_000 * 100_000_000 // 21M BTC in satoshis
        XCTAssertLessThanOrEqual(
            amount,
            maxBitcoin,
            "Amount should not exceed total Bitcoin supply",
            file: file,
            line: line
        )
    }

    /// Asserts that an amount is above dust threshold
    func assertAboveDustThreshold(
        _ amount: UInt64?,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(amount, "Amount should not be nil", file: file, line: line)

        guard let amount = amount else { return }

        let dustThreshold: UInt64 = 546
        XCTAssertGreaterThanOrEqual(
            amount,
            dustThreshold,
            "Amount should be above dust threshold (546 satoshis)",
            file: file,
            line: line
        )
    }

    // MARK: - Performance Assertions

    /// Asserts that an operation completes within a time limit
    func assertCompletesFast<T>(
        _ maxDuration: TimeInterval,
        _ operation: () throws -> T,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) rethrows -> T {
        let start = Date()
        let result = try operation()
        let duration = Date().timeIntervalSince(start)

        XCTAssertLessThan(
            duration,
            maxDuration,
            "Operation took \(duration)s but should complete within \(maxDuration)s. \(message)",
            file: file,
            line: line
        )

        return result
    }

    /// Asserts that an async operation completes within a time limit
    func assertCompletesFastAsync<T>(
        _ maxDuration: TimeInterval,
        _ operation: () async throws -> T,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) async rethrows -> T {
        let start = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(start)

        XCTAssertLessThan(
            duration,
            maxDuration,
            "Operation took \(duration)s but should complete within \(maxDuration)s. \(message)",
            file: file,
            line: line
        )

        return result
    }

    // MARK: - Collection Assertions

    /// Asserts that a collection has expected count
    func assertCount<T: Collection>(
        _ collection: T?,
        expected: Int,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(collection, "Collection should not be nil. \(message)", file: file, line: line)

        guard let collection = collection else { return }

        XCTAssertEqual(
            collection.count,
            expected,
            "Collection should have \(expected) elements. \(message)",
            file: file,
            line: line
        )
    }

    /// Asserts that a collection is not empty
    func assertNotEmpty<T: Collection>(
        _ collection: T?,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertNotNil(collection, "Collection should not be nil. \(message)", file: file, line: line)

        guard let collection = collection else { return }

        XCTAssertFalse(
            collection.isEmpty,
            "Collection should not be empty. \(message)",
            file: file,
            line: line
        )
    }
}
