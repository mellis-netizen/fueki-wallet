import XCTest
@testable import FuekiWallet

final class MnemonicGeneratorTests: XCTestCase {

    var mnemonicGenerator: MnemonicGenerator!

    override func setUp() {
        super.setUp()
        mnemonicGenerator = MnemonicGenerator()
    }

    override func tearDown() {
        mnemonicGenerator = nil
        super.tearDown()
    }

    // MARK: - Mnemonic Generation Tests

    func testGenerateMnemonic_12Words_Success() throws {
        // When
        let mnemonic = try mnemonicGenerator.generate(wordCount: 12)

        // Then
        let words = mnemonic.split(separator: " ")
        XCTAssertEqual(words.count, 12, "Should generate exactly 12 words")
        XCTAssertTrue(words.allSatisfy { !$0.isEmpty }, "All words should be non-empty")
    }

    func testGenerateMnemonic_15Words_Success() throws {
        // When
        let mnemonic = try mnemonicGenerator.generate(wordCount: 15)

        // Then
        let words = mnemonic.split(separator: " ")
        XCTAssertEqual(words.count, 15, "Should generate exactly 15 words")
    }

    func testGenerateMnemonic_18Words_Success() throws {
        // When
        let mnemonic = try mnemonicGenerator.generate(wordCount: 18)

        // Then
        let words = mnemonic.split(separator: " ")
        XCTAssertEqual(words.count, 18, "Should generate exactly 18 words")
    }

    func testGenerateMnemonic_21Words_Success() throws {
        // When
        let mnemonic = try mnemonicGenerator.generate(wordCount: 21)

        // Then
        let words = mnemonic.split(separator: " ")
        XCTAssertEqual(words.count, 21, "Should generate exactly 21 words")
    }

    func testGenerateMnemonic_24Words_Success() throws {
        // When
        let mnemonic = try mnemonicGenerator.generate(wordCount: 24)

        // Then
        let words = mnemonic.split(separator: " ")
        XCTAssertEqual(words.count, 24, "Should generate exactly 24 words")
    }

    func testGenerateMnemonic_InvalidWordCount_ThrowsError() {
        // Given
        let invalidCounts = [11, 13, 16, 25, 0, -1]

        // When/Then
        for count in invalidCounts {
            XCTAssertThrowsError(try mnemonicGenerator.generate(wordCount: count)) { error in
                XCTAssertTrue(error is MnemonicError.invalidWordCount)
            }
        }
    }

    func testGenerateMnemonic_Uniqueness() throws {
        // When
        let mnemonic1 = try mnemonicGenerator.generate(wordCount: 12)
        let mnemonic2 = try mnemonicGenerator.generate(wordCount: 12)

        // Then
        XCTAssertNotEqual(mnemonic1, mnemonic2, "Generated mnemonics should be unique")
    }

    func testGenerateMnemonic_AllWordsFromWordlist() throws {
        // Given
        let mnemonic = try mnemonicGenerator.generate(wordCount: 12)
        let words = mnemonic.split(separator: " ").map(String.init)

        // When/Then
        for word in words {
            XCTAssertTrue(
                mnemonicGenerator.wordlist.contains(word),
                "Word '\(word)' should be from BIP39 wordlist"
            )
        }
    }

    // MARK: - Mnemonic Validation Tests

    func testValidateMnemonic_Valid12Words_ReturnsTrue() {
        // Given - known valid BIP39 mnemonic
        let validMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

        // When
        let isValid = mnemonicGenerator.validate(mnemonic: validMnemonic)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateMnemonic_Valid24Words_ReturnsTrue() {
        // Given
        let validMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"

        // When
        let isValid = mnemonicGenerator.validate(mnemonic: validMnemonic)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateMnemonic_InvalidChecksum_ReturnsFalse() {
        // Given - valid words but invalid checksum
        let invalidMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon"

        // When
        let isValid = mnemonicGenerator.validate(mnemonic: invalidMnemonic)

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateMnemonic_WrongWordCount_ReturnsFalse() {
        // Given
        let invalidMnemonic = "abandon abandon abandon abandon abandon" // Only 5 words

        // When
        let isValid = mnemonicGenerator.validate(mnemonic: invalidMnemonic)

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateMnemonic_WordNotInWordlist_ReturnsFalse() {
        // Given
        let invalidMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon invalidword"

        // When
        let isValid = mnemonicGenerator.validate(mnemonic: invalidMnemonic)

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateMnemonic_EmptyString_ReturnsFalse() {
        // When
        let isValid = mnemonicGenerator.validate(mnemonic: "")

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateMnemonic_ExtraSpaces_HandledCorrectly() {
        // Given - valid mnemonic with extra spaces
        let mnemonicWithSpaces = "  abandon  abandon  abandon  abandon  abandon  abandon  abandon  abandon  abandon  abandon  abandon  about  "

        // When
        let isValid = mnemonicGenerator.validate(mnemonic: mnemonicWithSpaces)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateMnemonic_MixedCase_HandledCorrectly() {
        // Given
        let mixedCaseMnemonic = "Abandon Abandon Abandon Abandon Abandon Abandon Abandon Abandon Abandon Abandon Abandon About"

        // When
        let isValid = mnemonicGenerator.validate(mnemonic: mixedCaseMnemonic)

        // Then
        XCTAssertTrue(isValid)
    }

    // MARK: - Seed Generation Tests

    func testGenerateSeed_FromMnemonic_Success() throws {
        // Given
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let passphrase = ""

        // When
        let seed = try mnemonicGenerator.generateSeed(from: mnemonic, passphrase: passphrase)

        // Then
        XCTAssertEqual(seed.count, 64, "Seed should be 64 bytes (512 bits)")
    }

    func testGenerateSeed_WithPassphrase_DifferentFromWithout() throws {
        // Given
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

        // When
        let seedWithoutPassphrase = try mnemonicGenerator.generateSeed(from: mnemonic, passphrase: "")
        let seedWithPassphrase = try mnemonicGenerator.generateSeed(from: mnemonic, passphrase: "TREZOR")

        // Then
        XCTAssertNotEqual(seedWithoutPassphrase, seedWithPassphrase, "Passphrases should generate different seeds")
    }

    func testGenerateSeed_KnownVector_MatchesExpected() throws {
        // Given - BIP39 test vector
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let passphrase = ""
        let expectedSeedHex = "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4"

        // When
        let seed = try mnemonicGenerator.generateSeed(from: mnemonic, passphrase: passphrase)
        let seedHex = seed.map { String(format: "%02x", $0) }.joined()

        // Then
        XCTAssertEqual(seedHex, expectedSeedHex, "Seed should match BIP39 test vector")
    }

    func testGenerateSeed_InvalidMnemonic_ThrowsError() {
        // Given
        let invalidMnemonic = "invalid mnemonic phrase"

        // When/Then
        XCTAssertThrowsError(try mnemonicGenerator.generateSeed(from: invalidMnemonic)) { error in
            XCTAssertTrue(error is MnemonicError)
        }
    }

    func testGenerateSeed_Consistency() throws {
        // Given
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

        // When
        let seed1 = try mnemonicGenerator.generateSeed(from: mnemonic, passphrase: "")
        let seed2 = try mnemonicGenerator.generateSeed(from: mnemonic, passphrase: "")

        // Then
        XCTAssertEqual(seed1, seed2, "Same mnemonic should generate same seed")
    }

    // MARK: - Entropy Tests

    func testGenerateEntropy_128Bits_Success() throws {
        // When
        let entropy = try mnemonicGenerator.generateEntropy(bits: 128)

        // Then
        XCTAssertEqual(entropy.count, 16, "128 bits = 16 bytes")
    }

    func testGenerateEntropy_256Bits_Success() throws {
        // When
        let entropy = try mnemonicGenerator.generateEntropy(bits: 256)

        // Then
        XCTAssertEqual(entropy.count, 32, "256 bits = 32 bytes")
    }

    func testGenerateEntropy_Uniqueness() throws {
        // When
        let entropy1 = try mnemonicGenerator.generateEntropy(bits: 128)
        let entropy2 = try mnemonicGenerator.generateEntropy(bits: 128)

        // Then
        XCTAssertNotEqual(entropy1, entropy2, "Generated entropy should be unique")
    }

    func testEntropyToMnemonic_128Bits_12Words() throws {
        // Given
        let entropy = try mnemonicGenerator.generateEntropy(bits: 128)

        // When
        let mnemonic = try mnemonicGenerator.entropyToMnemonic(entropy)

        // Then
        let words = mnemonic.split(separator: " ")
        XCTAssertEqual(words.count, 12)
    }

    func testEntropyToMnemonic_256Bits_24Words() throws {
        // Given
        let entropy = try mnemonicGenerator.generateEntropy(bits: 256)

        // When
        let mnemonic = try mnemonicGenerator.entropyToMnemonic(entropy)

        // Then
        let words = mnemonic.split(separator: " ")
        XCTAssertEqual(words.count, 24)
    }

    func testMnemonicToEntropy_RoundTrip() throws {
        // Given
        let originalEntropy = try mnemonicGenerator.generateEntropy(bits: 128)

        // When
        let mnemonic = try mnemonicGenerator.entropyToMnemonic(originalEntropy)
        let recoveredEntropy = try mnemonicGenerator.mnemonicToEntropy(mnemonic)

        // Then
        XCTAssertEqual(originalEntropy, recoveredEntropy, "Round-trip should preserve entropy")
    }

    // MARK: - Language Support Tests

    func testWordlist_Contains2048Words() {
        // Then
        XCTAssertEqual(mnemonicGenerator.wordlist.count, 2048, "BIP39 wordlist should contain exactly 2048 words")
    }

    func testWordlist_AllWordsUnique() {
        // When
        let uniqueWords = Set(mnemonicGenerator.wordlist)

        // Then
        XCTAssertEqual(uniqueWords.count, mnemonicGenerator.wordlist.count, "All words should be unique")
    }

    func testWordlist_AllWordsLowercase() {
        // When/Then
        for word in mnemonicGenerator.wordlist {
            XCTAssertEqual(word, word.lowercased(), "All words should be lowercase")
        }
    }

    func testFindWord_ExactMatch_Success() {
        // Given
        let searchWord = "abandon"

        // When
        let index = mnemonicGenerator.findWordIndex(searchWord)

        // Then
        XCTAssertNotNil(index)
        XCTAssertEqual(mnemonicGenerator.wordlist[index!], searchWord)
    }

    func testFindWord_NotInList_ReturnsNil() {
        // Given
        let searchWord = "notinwordlist"

        // When
        let index = mnemonicGenerator.findWordIndex(searchWord)

        // Then
        XCTAssertNil(index)
    }

    // MARK: - Checksum Tests

    func testChecksum_Valid_Success() throws {
        // Given
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

        // When
        let hasValidChecksum = try mnemonicGenerator.verifyChecksum(mnemonic)

        // Then
        XCTAssertTrue(hasValidChecksum)
    }

    func testChecksum_Invalid_ReturnsFalse() throws {
        // Given - modified last word to break checksum
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon"

        // When
        let hasValidChecksum = try mnemonicGenerator.verifyChecksum(mnemonic)

        // Then
        XCTAssertFalse(hasValidChecksum)
    }

    // MARK: - Edge Cases

    func testGenerateMnemonic_MultipleGenerations_AllUnique() throws {
        // When
        let mnemonics = try (0..<50).map { _ in
            try mnemonicGenerator.generate(wordCount: 12)
        }

        // Then
        let uniqueMnemonics = Set(mnemonics)
        XCTAssertEqual(uniqueMnemonics.count, mnemonics.count, "All generated mnemonics should be unique")
    }

    func testValidateMnemonic_UnicodeCharacters_HandledCorrectly() {
        // Given
        let mnemonicWithUnicode = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon 你好"

        // When
        let isValid = mnemonicGenerator.validate(mnemonic: mnemonicWithUnicode)

        // Then
        XCTAssertFalse(isValid, "Non-BIP39 words should be invalid")
    }

    func testGenerateSeed_LongPassphrase_Success() throws {
        // Given
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let longPassphrase = String(repeating: "a", count: 1000)

        // When
        let seed = try mnemonicGenerator.generateSeed(from: mnemonic, passphrase: longPassphrase)

        // Then
        XCTAssertEqual(seed.count, 64)
    }

    func testGenerateSeed_SpecialCharactersInPassphrase() throws {
        // Given
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let specialPassphrase = "!@#$%^&*()_+-={}[]|:;<>?,./~`"

        // When
        let seed = try mnemonicGenerator.generateSeed(from: mnemonic, passphrase: specialPassphrase)

        // Then
        XCTAssertEqual(seed.count, 64)
    }

    func testConcurrentGeneration() throws {
        let expectation = XCTestExpectation(description: "Concurrent mnemonic generation")
        expectation.expectedFulfillmentCount = 20

        DispatchQueue.concurrentPerform(iterations: 20) { _ in
            do {
                let mnemonic = try mnemonicGenerator.generate(wordCount: 12)
                XCTAssertFalse(mnemonic.isEmpty)
                expectation.fulfill()
            } catch {
                XCTFail("Generation failed: \(error)")
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Performance Tests

    func testGenerateMnemonicPerformance() {
        measure {
            _ = try? mnemonicGenerator.generate(wordCount: 12)
        }
    }

    func testValidateMnemonicPerformance() {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

        measure {
            _ = mnemonicGenerator.validate(mnemonic: mnemonic)
        }
    }

    func testGenerateSeedPerformance() {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

        measure {
            _ = try? mnemonicGenerator.generateSeed(from: mnemonic, passphrase: "")
        }
    }

    func testEntropyGenerationPerformance() {
        measure {
            _ = try? mnemonicGenerator.generateEntropy(bits: 256)
        }
    }
}
