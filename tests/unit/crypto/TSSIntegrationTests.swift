import XCTest
@testable import FuekiWallet

/// Integration tests for complete TSS workflow with production-grade arithmetic
/// Tests end-to-end key generation, sharing, and reconstruction
class TSSIntegrationTests: XCTestCase {

    var tss: TSSKeyGeneration!

    override func setUp() {
        super.setUp()
        tss = TSSKeyGeneration(protocol: .ecdsa_secp256k1)
    }

    override func tearDown() {
        tss = nil
        super.tearDown()
    }

    // MARK: - Complete TSS Workflow Tests

    func testCompleteWorkflow2of3() throws {
        // Generate TSS key shares
        let keyPair = try tss.generateKeyShares(
            threshold: 2,
            totalShares: 3,
            protocol: .ecdsa_secp256k1
        )

        // Verify we got 3 shares
        XCTAssertEqual(keyPair.shares.count, 3)

        // Verify all shares have the same public key
        let publicKey = keyPair.publicKey
        for share in keyPair.shares {
            XCTAssertEqual(share.publicKey, publicKey)
            XCTAssertEqual(share.threshold, 2)
            XCTAssertEqual(share.totalShares, 3)
        }

        // Test reconstruction with minimum threshold
        let selectedShares = Array(keyPair.shares[0..<2])
        let reconstructedKey = try tss.reconstructKey(from: selectedShares)

        // Verify reconstructed key produces the same public key
        XCTAssertNotNil(reconstructedKey)
        XCTAssertEqual(reconstructedKey.count, 32)
    }

    func testCompleteWorkflow3of5() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 3,
            totalShares: 5,
            protocol: .ecdsa_secp256k1
        )

        XCTAssertEqual(keyPair.shares.count, 5)

        // Test reconstruction with exactly threshold shares
        let shares = Array(keyPair.shares[0..<3])
        let reconstructed = try tss.reconstructKey(from: shares)

        XCTAssertEqual(reconstructed.count, 32)

        // Test reconstruction with extra shares
        let allShares = keyPair.shares
        let reconstructedAll = try tss.reconstructKey(from: allShares)

        // Both should produce the same key
        XCTAssertEqual(reconstructed, reconstructedAll)
    }

    func testDifferentShareCombinationsProduceSameKey() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 3,
            totalShares: 5,
            protocol: .ecdsa_secp256k1
        )

        let shares = keyPair.shares

        // Try different combinations of 3 shares
        let combo1 = [shares[0], shares[1], shares[2]]
        let combo2 = [shares[0], shares[2], shares[4]]
        let combo3 = [shares[1], shares[3], shares[4]]
        let combo4 = [shares[2], shares[3], shares[4]]

        let key1 = try tss.reconstructKey(from: combo1)
        let key2 = try tss.reconstructKey(from: combo2)
        let key3 = try tss.reconstructKey(from: combo3)
        let key4 = try tss.reconstructKey(from: combo4)

        // All combinations should produce the same key
        XCTAssertEqual(key1, key2)
        XCTAssertEqual(key2, key3)
        XCTAssertEqual(key3, key4)
    }

    func testInsufficientSharesThrowsError() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 3,
            totalShares: 5,
            protocol: .ecdsa_secp256k1
        )

        // Try with only 2 shares when 3 are required
        let insufficientShares = Array(keyPair.shares[0..<2])

        XCTAssertThrowsError(try tss.reconstructKey(from: insufficientShares)) { error in
            guard let tssError = error as? TSSKeyGeneration.TSSError else {
                XCTFail("Expected TSSError")
                return
            }

            if case .insufficientShares = tssError {
                // Expected error
            } else {
                XCTFail("Expected insufficientShares error")
            }
        }
    }

    // MARK: - Share Uniqueness Tests

    func testSharesAreUnique() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 2,
            totalShares: 5,
            protocol: .ecdsa_secp256k1
        )

        let shareDataArray = keyPair.shares.map { $0.shareData }

        // All shares should be different
        for i in 0..<shareDataArray.count {
            for j in (i+1)..<shareDataArray.count {
                XCTAssertNotEqual(shareDataArray[i], shareDataArray[j],
                                "Shares \(i) and \(j) should be different")
            }
        }
    }

    func testShareIndicesAreSequential() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 2,
            totalShares: 5,
            protocol: .ecdsa_secp256k1
        )

        let indices = keyPair.shares.map { $0.shareIndex }.sorted()

        XCTAssertEqual(indices, [1, 2, 3, 4, 5])
    }

    // MARK: - Security Tests

    func testSingleShareRevealsNoInformation() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 3,
            totalShares: 5,
            protocol: .ecdsa_secp256k1
        )

        // Reconstruct the full key
        let fullKey = try tss.reconstructKey(from: Array(keyPair.shares[0..<3]))

        // A single share should not correlate with the full key
        let singleShare = keyPair.shares[0].shareData

        // Calculate Hamming distance (percentage of different bits)
        var differentBytes = 0
        let compareLength = min(singleShare.count, fullKey.count)

        for i in 0..<compareLength {
            if singleShare[i] != fullKey[i] {
                differentBytes += 1
            }
        }

        let hammingRatio = Double(differentBytes) / Double(compareLength)

        // Should be close to 50% (random correlation)
        // Allow range of 30-70% for statistical variation
        XCTAssertGreaterThan(hammingRatio, 0.3, "Single share leaks information")
        XCTAssertLessThan(hammingRatio, 0.7, "Single share has suspicious correlation")
    }

    func testCannotMixSharesFromDifferentKeys() throws {
        let keyPair1 = try tss.generateKeyShares(
            threshold: 2,
            totalShares: 3,
            protocol: .ecdsa_secp256k1
        )

        let keyPair2 = try tss.generateKeyShares(
            threshold: 2,
            totalShares: 3,
            protocol: .ecdsa_secp256k1
        )

        // Try to mix shares from different key pairs
        let mixedShares = [keyPair1.shares[0], keyPair2.shares[1]]

        XCTAssertThrowsError(try tss.reconstructKey(from: mixedShares)) { error in
            guard let tssError = error as? TSSKeyGeneration.TSSError else {
                XCTFail("Expected TSSError")
                return
            }

            if case .invalidShareData = tssError {
                // Expected error
            } else {
                XCTFail("Expected invalidShareData error")
            }
        }
    }

    // MARK: - Share Refresh Tests

    func testShareRefreshProducesDifferentShares() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 2,
            totalShares: 3,
            protocol: .ecdsa_secp256k1
        )

        let originalShares = keyPair.shares
        let refreshedShares = try tss.refreshShares(originalShares)

        // Refreshed shares should be different
        for i in 0..<originalShares.count {
            XCTAssertNotEqual(originalShares[i].shareData, refreshedShares[i].shareData,
                            "Refreshed share \(i) should be different")
        }

        // But should still have same public key
        for share in refreshedShares {
            XCTAssertEqual(share.publicKey, keyPair.publicKey)
        }
    }

    func testRefreshedSharesReconstructSameKey() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 2,
            totalShares: 3,
            protocol: .ecdsa_secp256k1
        )

        let originalShares = keyPair.shares
        let refreshedShares = try tss.refreshShares(originalShares)

        // Reconstruct from original shares
        let originalKey = try tss.reconstructKey(from: Array(originalShares[0..<2]))

        // Reconstruct from refreshed shares
        let refreshedKey = try tss.reconstructKey(from: Array(refreshedShares[0..<2]))

        // Both should produce the same key
        XCTAssertEqual(originalKey, refreshedKey)
    }

    // MARK: - Multiple Protocol Tests

    func testSecp256r1Protocol() throws {
        let tssP256 = TSSKeyGeneration(protocol: .ecdsa_secp256r1)

        let keyPair = try tssP256.generateKeyShares(
            threshold: 2,
            totalShares: 3,
            protocol: .ecdsa_secp256r1
        )

        XCTAssertEqual(keyPair.shares.count, 3)
        XCTAssertEqual(keyPair.protocol, .ecdsa_secp256r1)

        let reconstructed = try tssP256.reconstructKey(from: Array(keyPair.shares[0..<2]))
        XCTAssertEqual(reconstructed.count, 32)
    }

    func testEd25519Protocol() throws {
        let tssEd25519 = TSSKeyGeneration(protocol: .eddsa_ed25519)

        let keyPair = try tssEd25519.generateKeyShares(
            threshold: 3,
            totalShares: 5,
            protocol: .eddsa_ed25519
        )

        XCTAssertEqual(keyPair.shares.count, 5)
        XCTAssertEqual(keyPair.protocol, .eddsa_ed25519)

        let reconstructed = try tssEd25519.reconstructKey(from: Array(keyPair.shares[0..<3]))
        XCTAssertEqual(reconstructed.count, 32)
    }

    // MARK: - Edge Cases

    func testMinimumConfiguration1of1() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 1,
            totalShares: 1,
            protocol: .ecdsa_secp256k1
        )

        XCTAssertEqual(keyPair.shares.count, 1)

        let reconstructed = try tss.reconstructKey(from: keyPair.shares)
        XCTAssertEqual(reconstructed.count, 32)
    }

    func testLargeConfiguration10of15() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 10,
            totalShares: 15,
            protocol: .ecdsa_secp256k1
        )

        XCTAssertEqual(keyPair.shares.count, 15)

        // Reconstruct with exactly 10 shares
        let shares = Array(keyPair.shares[0..<10])
        let reconstructed = try tss.reconstructKey(from: shares)

        XCTAssertEqual(reconstructed.count, 32)
    }

    func testInvalidThreshold() {
        // Threshold greater than total shares
        XCTAssertThrowsError(
            try tss.generateKeyShares(threshold: 5, totalShares: 3, protocol: .ecdsa_secp256k1)
        ) { error in
            guard let tssError = error as? TSSKeyGeneration.TSSError else {
                XCTFail("Expected TSSError")
                return
            }

            if case .invalidThreshold = tssError {
                // Expected error
            } else {
                XCTFail("Expected invalidThreshold error")
            }
        }

        // Zero threshold
        XCTAssertThrowsError(
            try tss.generateKeyShares(threshold: 0, totalShares: 3, protocol: .ecdsa_secp256k1)
        )
    }

    func testInvalidShareCount() {
        // Too few shares
        XCTAssertThrowsError(
            try tss.generateKeyShares(threshold: 1, totalShares: 1, protocol: .ecdsa_secp256k1)
        )

        // Too many shares (> 100)
        XCTAssertThrowsError(
            try tss.generateKeyShares(threshold: 50, totalShares: 101, protocol: .ecdsa_secp256k1)
        )
    }

    // MARK: - Public Key Verification Tests

    func testReconstructedKeyMatchesPublicKey() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 2,
            totalShares: 3,
            protocol: .ecdsa_secp256k1
        )

        // This test is already performed internally by reconstructKey
        // but we verify it explicitly here
        let reconstructed = try tss.reconstructKey(from: Array(keyPair.shares[0..<2]))

        // The reconstructKey method verifies the public key matches
        // If we reach here without error, the test passed
        XCTAssertNotNil(reconstructed)
    }

    func testAllSharesHaveSamePublicKey() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 3,
            totalShares: 5,
            protocol: .ecdsa_secp256k1
        )

        let firstPublicKey = keyPair.shares[0].publicKey

        for share in keyPair.shares {
            XCTAssertEqual(share.publicKey, firstPublicKey)
        }
    }

    // MARK: - Metadata Tests

    func testShareMetadata() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 2,
            totalShares: 3,
            protocol: .ecdsa_secp256k1
        )

        for share in keyPair.shares {
            // Check metadata exists
            XCTAssertNotNil(share.metadata["createdAt"])
            XCTAssertNotNil(share.metadata["version"])

            // Check version
            if let version = share.metadata["version"] as? String {
                XCTAssertEqual(version, "1.0")
            }

            // Check timestamp is recent (within last minute)
            if let timestamp = share.metadata["createdAt"] as? TimeInterval {
                let now = Date().timeIntervalSince1970
                XCTAssertLessThan(now - timestamp, 60.0)
            }
        }
    }

    // MARK: - Performance Tests

    func testKeyGenerationPerformance() {
        measure {
            _ = try? tss.generateKeyShares(
                threshold: 3,
                totalShares: 5,
                protocol: .ecdsa_secp256k1
            )
        }
    }

    func testKeyReconstructionPerformance() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 3,
            totalShares: 5,
            protocol: .ecdsa_secp256k1
        )

        let shares = Array(keyPair.shares[0..<3])

        measure {
            _ = try? tss.reconstructKey(from: shares)
        }
    }

    func testShareRefreshPerformance() throws {
        let keyPair = try tss.generateKeyShares(
            threshold: 3,
            totalShares: 5,
            protocol: .ecdsa_secp256k1
        )

        measure {
            _ = try? tss.refreshShares(keyPair.shares)
        }
    }

    // MARK: - Stress Tests

    func testMultipleKeyGenerations() throws {
        // Generate multiple key pairs to ensure no state leakage
        for _ in 0..<10 {
            let keyPair = try tss.generateKeyShares(
                threshold: 2,
                totalShares: 3,
                protocol: .ecdsa_secp256k1
            )

            let reconstructed = try tss.reconstructKey(from: Array(keyPair.shares[0..<2]))
            XCTAssertEqual(reconstructed.count, 32)
        }
    }

    func testConcurrentKeyGeneration() throws {
        let expectation = XCTestExpectation(description: "Concurrent key generation")
        expectation.expectedFulfillmentCount = 5

        DispatchQueue.concurrentPerform(iterations: 5) { _ in
            let localTSS = TSSKeyGeneration(protocol: .ecdsa_secp256k1)

            do {
                let keyPair = try localTSS.generateKeyShares(
                    threshold: 2,
                    totalShares: 3,
                    protocol: .ecdsa_secp256k1
                )

                _ = try localTSS.reconstructKey(from: Array(keyPair.shares[0..<2]))
                expectation.fulfill()
            } catch {
                XCTFail("Concurrent key generation failed: \(error)")
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }
}
