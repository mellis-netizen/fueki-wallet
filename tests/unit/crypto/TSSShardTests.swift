import XCTest
@testable import FuekiWallet

/// Unit tests for Threshold Signature Scheme (TSS) shard management
/// Tests shard generation, distribution, and reconstruction
class TSSShardTests: XCTestCase {

    var tssService: TSSService!
    var cryptoService: CryptoService!

    override func setUp() {
        super.setUp()
        tssService = TSSService()
        cryptoService = CryptoService()
    }

    override func tearDown() {
        tssService = nil
        cryptoService = nil
        super.tearDown()
    }

    // MARK: - Shard Generation Tests

    func testGenerateShards2of3() throws {
        // Arrange
        let secret = try cryptoService.generateEd25519KeyPair().privateKey
        let threshold = 2
        let totalShards = 3

        // Act
        let shards = try tssService.generateShards(
            from: secret,
            threshold: threshold,
            totalShards: totalShards
        )

        // Assert
        XCTAssertEqual(shards.count, totalShards, "Should generate correct number of shards")
        XCTAssertEqual(Set(shards.map { $0.id }).count, totalShards, "Each shard should have unique ID")

        // Verify each shard has metadata
        for shard in shards {
            XCTAssertEqual(shard.threshold, threshold)
            XCTAssertEqual(shard.totalShards, totalShards)
            XCTAssertNotNil(shard.data)
        }
    }

    func testGenerateShards3of5() throws {
        // Arrange
        let secret = try cryptoService.generateEd25519KeyPair().privateKey

        // Act
        let shards = try tssService.generateShards(from: secret, threshold: 3, totalShards: 5)

        // Assert
        XCTAssertEqual(shards.count, 5)
        XCTAssertTrue(shards.allSatisfy { $0.threshold == 3 })
    }

    func testShardUniqueness() throws {
        // Arrange
        let secret = try cryptoService.generateEd25519KeyPair().privateKey

        // Act
        let shards = try tssService.generateShards(from: secret, threshold: 2, totalShards: 3)

        // Assert - Each shard should be unique
        let shard1Data = shards[0].data
        let shard2Data = shards[1].data
        let shard3Data = shards[2].data

        XCTAssertNotEqual(shard1Data, shard2Data)
        XCTAssertNotEqual(shard2Data, shard3Data)
        XCTAssertNotEqual(shard1Data, shard3Data)
    }

    // MARK: - Secret Reconstruction Tests

    func testReconstructSecretWithMinimumShards() throws {
        // Arrange
        let originalSecret = try cryptoService.generateEd25519KeyPair().privateKey
        let shards = try tssService.generateShards(from: originalSecret, threshold: 2, totalShards: 3)

        // Act - Use exactly threshold number of shards
        let selectedShards = Array(shards[0..<2])
        let reconstructedSecret = try tssService.reconstructSecret(from: selectedShards)

        // Assert
        XCTAssertEqual(reconstructedSecret, originalSecret, "Reconstructed secret should match original")
    }

    func testReconstructSecretWithExtraShards() throws {
        // Arrange
        let originalSecret = try cryptoService.generateEd25519KeyPair().privateKey
        let shards = try tssService.generateShards(from: originalSecret, threshold: 2, totalShards: 3)

        // Act - Use all shards (more than threshold)
        let reconstructedSecret = try tssService.reconstructSecret(from: shards)

        // Assert
        XCTAssertEqual(reconstructedSecret, originalSecret, "Should reconstruct with extra shards")
    }

    func testReconstructSecretWithDifferentShardCombinations() throws {
        // Arrange
        let originalSecret = try cryptoService.generateEd25519KeyPair().privateKey
        let shards = try tssService.generateShards(from: originalSecret, threshold: 2, totalShards: 4)

        // Act - Try different combinations
        let combo1 = try tssService.reconstructSecret(from: [shards[0], shards[1]])
        let combo2 = try tssService.reconstructSecret(from: [shards[0], shards[2]])
        let combo3 = try tssService.reconstructSecret(from: [shards[1], shards[3]])
        let combo4 = try tssService.reconstructSecret(from: [shards[2], shards[3]])

        // Assert - All combinations should yield the same secret
        XCTAssertEqual(combo1, originalSecret)
        XCTAssertEqual(combo2, originalSecret)
        XCTAssertEqual(combo3, originalSecret)
        XCTAssertEqual(combo4, originalSecret)
    }

    func testReconstructSecretFailsWithInsufficientShards() throws {
        // Arrange
        let originalSecret = try cryptoService.generateEd25519KeyPair().privateKey
        let shards = try tssService.generateShards(from: originalSecret, threshold: 3, totalShards: 5)

        // Act & Assert - Only 2 shards when 3 required
        XCTAssertThrowsError(try tssService.reconstructSecret(from: Array(shards[0..<2]))) { error in
            XCTAssertTrue(error is TSSError)
            if let tssError = error as? TSSError {
                XCTAssertEqual(tssError, .insufficientShards)
            }
        }
    }

    // MARK: - Shard Validation Tests

    func testValidateShard() throws {
        // Arrange
        let secret = try cryptoService.generateEd25519KeyPair().privateKey
        let shards = try tssService.generateShards(from: secret, threshold: 2, totalShards: 3)

        // Act & Assert
        for shard in shards {
            XCTAssertTrue(tssService.validateShard(shard), "Valid shard should pass validation")
        }
    }

    func testDetectCorruptedShard() throws {
        // Arrange
        let secret = try cryptoService.generateEd25519KeyPair().privateKey
        var shards = try tssService.generateShards(from: secret, threshold: 2, totalShards: 3)

        // Act - Corrupt a shard
        shards[0].data[0] ^= 0xFF

        // Assert
        XCTAssertFalse(tssService.validateShard(shards[0]), "Corrupted shard should fail validation")
    }

    func testDetectInvalidThreshold() {
        // Arrange & Act & Assert
        XCTAssertThrowsError(try tssService.generateShards(from: Data(repeating: 0, count: 32), threshold: 4, totalShards: 3)) { error in
            XCTAssertTrue(error is TSSError)
            if let tssError = error as? TSSError {
                XCTAssertEqual(tssError, .invalidThreshold)
            }
        }
    }

    // MARK: - Shard Serialization Tests

    func testSerializeAndDeserializeShard() throws {
        // Arrange
        let secret = try cryptoService.generateEd25519KeyPair().privateKey
        let shards = try tssService.generateShards(from: secret, threshold: 2, totalShards: 3)
        let originalShard = shards[0]

        // Act
        let serialized = try tssService.serializeShard(originalShard)
        let deserialized = try tssService.deserializeShard(serialized)

        // Assert
        XCTAssertEqual(deserialized.id, originalShard.id)
        XCTAssertEqual(deserialized.threshold, originalShard.threshold)
        XCTAssertEqual(deserialized.totalShards, originalShard.totalShards)
        XCTAssertEqual(deserialized.data, originalShard.data)
    }

    func testSerializeShardToQRCode() throws {
        // Arrange
        let secret = try cryptoService.generateEd25519KeyPair().privateKey
        let shards = try tssService.generateShards(from: secret, threshold: 2, totalShards: 3)

        // Act
        let qrData = try tssService.encodeShardForQR(shards[0])

        // Assert
        XCTAssertNotNil(qrData)
        // Verify it can be decoded back
        let decodedShard = try tssService.decodeShardFromQR(qrData)
        XCTAssertEqual(decodedShard.id, shards[0].id)
    }

    // MARK: - Distributed Key Generation Tests

    func testDistributedKeyGeneration() throws {
        // Arrange - Simulate 3 parties
        let parties = 3
        let threshold = 2

        // Act - Each party generates their contribution
        var contributions: [DKGContribution] = []
        for i in 0..<parties {
            let contribution = try tssService.generateDKGContribution(partyId: i, totalParties: parties)
            contributions.append(contribution)
        }

        // Each party computes their shard from all contributions
        var shards: [TSSShard] = []
        for i in 0..<parties {
            let shard = try tssService.computeDKGShard(forParty: i, contributions: contributions, threshold: threshold)
            shards.append(shard)
        }

        // Assert - Any 2 shards should be able to reconstruct
        let secret = try tssService.reconstructSecret(from: Array(shards[0..<2]))
        XCTAssertNotNil(secret)
        XCTAssertEqual(secret.count, 32)
    }

    // MARK: - Threshold Signature Tests

    func testThresholdSignature() throws {
        // Arrange
        let keyPair = try cryptoService.generateEd25519KeyPair()
        let shards = try tssService.generateShards(from: keyPair.privateKey, threshold: 2, totalShards: 3)
        let message = "Test transaction".data(using: .utf8)!

        // Act - Create partial signatures with 2 shards
        let partialSig1 = try tssService.createPartialSignature(message, with: shards[0])
        let partialSig2 = try tssService.createPartialSignature(message, with: shards[1])

        // Combine partial signatures
        let fullSignature = try tssService.combinePartialSignatures([partialSig1, partialSig2])

        // Assert - Verify combined signature
        let isValid = try cryptoService.verify(fullSignature, for: message, publicKey: keyPair.publicKey)
        XCTAssertTrue(isValid, "Combined threshold signature should be valid")
    }

    func testThresholdSignatureFailsWithInsufficientPartials() throws {
        // Arrange
        let keyPair = try cryptoService.generateEd25519KeyPair()
        let shards = try tssService.generateShards(from: keyPair.privateKey, threshold: 3, totalShards: 5)
        let message = "Test transaction".data(using: .utf8)!

        // Act - Only 2 partial signatures when 3 required
        let partialSig1 = try tssService.createPartialSignature(message, with: shards[0])
        let partialSig2 = try tssService.createPartialSignature(message, with: shards[1])

        // Assert
        XCTAssertThrowsError(try tssService.combinePartialSignatures([partialSig1, partialSig2])) { error in
            XCTAssertTrue(error is TSSError)
        }
    }

    // MARK: - Shard Refresh Tests

    func testShardRefresh() throws {
        // Arrange - Generate initial shards
        let secret = try cryptoService.generateEd25519KeyPair().privateKey
        let oldShards = try tssService.generateShards(from: secret, threshold: 2, totalShards: 3)

        // Act - Refresh shards (change the shares but keep same secret)
        let newShards = try tssService.refreshShards(oldShards)

        // Assert - New shards should be different but reconstruct to same secret
        XCTAssertNotEqual(oldShards[0].data, newShards[0].data, "Refreshed shards should be different")

        let oldSecret = try tssService.reconstructSecret(from: Array(oldShards[0..<2]))
        let newSecret = try tssService.reconstructSecret(from: Array(newShards[0..<2]))
        XCTAssertEqual(oldSecret, newSecret, "Refreshed shards should reconstruct to same secret")
    }

    // MARK: - Security Tests

    func testSingleShardRevealsNothing() throws {
        // Arrange
        let secret = try cryptoService.generateEd25519KeyPair().privateKey
        let shards = try tssService.generateShards(from: secret, threshold: 3, totalShards: 5)

        // Act - Try to extract information from single shard
        let singleShard = shards[0]

        // Assert - Single shard data should not correlate with secret
        XCTAssertNotEqual(singleShard.data, secret)
        XCTAssertNotEqual(singleShard.data.prefix(secret.count), secret)

        // Hamming distance should be ~50% (no correlation)
        var differences = 0
        let compareLength = min(singleShard.data.count, secret.count)
        for i in 0..<compareLength {
            if singleShard.data[i] != secret[i] {
                differences += 1
            }
        }
        let ratio = Double(differences) / Double(compareLength)
        XCTAssertGreaterThan(ratio, 0.3, "Single shard should not leak secret information")
    }

    func testShardIndependence() throws {
        // Arrange
        let secret1 = try cryptoService.generateEd25519KeyPair().privateKey
        let secret2 = try cryptoService.generateEd25519KeyPair().privateKey

        // Act
        let shards1 = try tssService.generateShards(from: secret1, threshold: 2, totalShards: 3)
        let shards2 = try tssService.generateShards(from: secret2, threshold: 2, totalShards: 3)

        // Assert - Mixing shards from different secrets should fail
        XCTAssertThrowsError(try tssService.reconstructSecret(from: [shards1[0], shards2[1]])) { error in
            XCTAssertTrue(error is TSSError)
        }
    }

    // MARK: - Performance Tests

    func testShardGenerationPerformance() throws {
        let secret = try cryptoService.generateEd25519KeyPair().privateKey

        measure {
            _ = try? tssService.generateShards(from: secret, threshold: 3, totalShards: 5)
        }
    }

    func testSecretReconstructionPerformance() throws {
        let secret = try cryptoService.generateEd25519KeyPair().privateKey
        let shards = try tssService.generateShards(from: secret, threshold: 3, totalShards: 5)

        measure {
            _ = try? tssService.reconstructSecret(from: Array(shards[0..<3]))
        }
    }

    // MARK: - Edge Cases

    func testMinimumConfiguration() throws {
        // 1-of-1 (degenerate case)
        let secret = try cryptoService.generateEd25519KeyPair().privateKey
        let shards = try tssService.generateShards(from: secret, threshold: 1, totalShards: 1)
        let reconstructed = try tssService.reconstructSecret(from: shards)
        XCTAssertEqual(reconstructed, secret)
    }

    func testLargeThreshold() throws {
        // 10-of-15
        let secret = try cryptoService.generateEd25519KeyPair().privateKey
        let shards = try tssService.generateShards(from: secret, threshold: 10, totalShards: 15)
        let reconstructed = try tssService.reconstructSecret(from: Array(shards[0..<10]))
        XCTAssertEqual(reconstructed, secret)
    }
}
