//
//  MnemonicGenerator.swift
//  FuekiWallet
//
//  BIP39 mnemonic generation and validation with cryptographic security
//

import Foundation
import CryptoKit
import CommonCrypto

/// BIP39 compliant mnemonic phrase generator and validator
final class MnemonicGenerator: MnemonicProtocol {

    // MARK: - Properties

    private let wordlist: [String]
    private let language: MnemonicLanguage

    // MARK: - Types

    enum MnemonicLanguage {
        case english

        var wordlistFileName: String {
            switch self {
            case .english:
                return "english"
            }
        }
    }

    // MARK: - Initialization

    init(language: MnemonicLanguage = .english) {
        self.language = language
        self.wordlist = Self.loadWordlist(for: language)
    }

    // MARK: - MnemonicProtocol

    func generate(strength: MnemonicStrength) throws -> String {
        // Generate entropy
        let entropyBytes = strength.entropyBits / 8
        var entropy = Data(count: entropyBytes)

        let result = entropy.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, entropyBytes, buffer.baseAddress!)
        }

        guard result == errSecSuccess else {
            throw WalletError.mnemonicGenerationFailed
        }

        // Calculate checksum
        let hash = SHA256.hash(data: entropy)
        let checksumBits = entropyBytes / 4 // CS = ENT / 32

        // Convert entropy to mnemonic
        return try entropyToMnemonic(entropy: entropy, checksumBits: checksumBits)
    }

    func validate(_ mnemonic: String) throws -> Bool {
        let words = mnemonic.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Validate word count
        guard [12, 15, 18, 21, 24].contains(words.count) else {
            throw WalletError.invalidMnemonicWordCount
        }

        // Validate all words are in wordlist
        for word in words {
            guard wordlist.contains(word) else {
                throw WalletError.invalidMnemonic
            }
        }

        // Calculate expected entropy and checksum bits
        let totalBits = words.count * 11
        let checksumBits = words.count / 3
        let entropyBits = totalBits - checksumBits

        // Convert mnemonic to entropy
        var bits = ""
        for word in words {
            guard let index = wordlist.firstIndex(of: word) else {
                throw WalletError.invalidMnemonic
            }
            bits += String(format: "%011b", index)
        }

        // Split entropy and checksum
        let entropyBitsString = String(bits.prefix(entropyBits))
        let checksumBitsString = String(bits.suffix(checksumBits))

        // Convert entropy bits to bytes
        let entropy = try bitsToData(entropyBitsString)

        // Calculate checksum
        let hash = SHA256.hash(data: entropy)
        let hashBits = Data(hash).toBinaryString()
        let calculatedChecksum = String(hashBits.prefix(checksumBits))

        // Validate checksum
        guard checksumBitsString == calculatedChecksum else {
            throw WalletError.invalidMnemonicChecksum
        }

        return true
    }

    func toSeed(_ mnemonic: String, passphrase: String = "") throws -> Data {
        // Validate mnemonic first
        guard try validate(mnemonic) else {
            throw WalletError.invalidMnemonic
        }

        // Normalize mnemonic
        let normalizedMnemonic = mnemonic.decomposedStringWithCompatibilityMapping

        // Create salt (PBKDF2 salt = "mnemonic" + passphrase)
        let normalizedPassphrase = passphrase.decomposedStringWithCompatibilityMapping
        let salt = "mnemonic" + normalizedPassphrase

        // Derive seed using PBKDF2-HMAC-SHA512
        guard let mnemonicData = normalizedMnemonic.data(using: .utf8),
              let saltData = salt.data(using: .utf8) else {
            throw WalletError.seedGenerationFailed
        }

        var seed = Data(count: 64) // 512 bits

        let result = seed.withUnsafeMutableBytes { seedBytes in
            saltData.withUnsafeBytes { saltBytes in
                mnemonicData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        mnemonicData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        saltData.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                        2048, // BIP39 specifies 2048 iterations
                        seedBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        64
                    )
                }
            }
        }

        guard result == kCCSuccess else {
            throw WalletError.seedGenerationFailed
        }

        return seed
    }

    // MARK: - Private Methods

    private func entropyToMnemonic(entropy: Data, checksumBits: Int) throws -> String {
        // Calculate checksum
        let hash = SHA256.hash(data: entropy)
        let hashBits = Data(hash).toBinaryString()
        let checksum = String(hashBits.prefix(checksumBits))

        // Combine entropy and checksum bits
        let entropyBits = entropy.toBinaryString()
        let bits = entropyBits + checksum

        // Convert to words (every 11 bits = 1 word)
        var words: [String] = []
        for i in stride(from: 0, to: bits.count, by: 11) {
            let endIndex = min(i + 11, bits.count)
            let wordBits = String(bits[bits.index(bits.startIndex, offsetBy: i)..<bits.index(bits.startIndex, offsetBy: endIndex)])

            guard let index = Int(wordBits, radix: 2), index < wordlist.count else {
                throw WalletError.mnemonicGenerationFailed
            }

            words.append(wordlist[index])
        }

        return words.joined(separator: " ")
    }

    private func bitsToData(_ bits: String) throws -> Data {
        var data = Data()

        for i in stride(from: 0, to: bits.count, by: 8) {
            let endIndex = min(i + 8, bits.count)
            let byteBits = String(bits[bits.index(bits.startIndex, offsetBy: i)..<bits.index(bits.startIndex, offsetBy: endIndex)])

            guard let byte = UInt8(byteBits, radix: 2) else {
                throw WalletError.invalidMnemonic
            }

            data.append(byte)
        }

        return data
    }

    // MARK: - Wordlist Loading

    private static func loadWordlist(for language: MnemonicLanguage) -> [String] {
        // BIP39 English wordlist (2048 words)
        // In production, this should be loaded from a file or embedded resource
        // For now, returning a placeholder that should be replaced with actual BIP39 wordlist
        return Self.bip39EnglishWordlist
    }

    // MARK: - BIP39 English Wordlist (First 100 words shown, full list required in production)
    private static let bip39EnglishWordlist: [String] = [
        "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse",
        "access", "accident", "account", "accuse", "achieve", "acid", "acoustic", "acquire", "across", "act",
        "action", "actor", "actress", "actual", "adapt", "add", "addict", "address", "adjust", "admit",
        "adult", "advance", "advice", "aerobic", "affair", "afford", "afraid", "again", "age", "agent",
        "agree", "ahead", "aim", "air", "airport", "aisle", "alarm", "album", "alcohol", "alert",
        "alien", "all", "alley", "allow", "almost", "alone", "alpha", "already", "also", "alter",
        "always", "amateur", "amazing", "among", "amount", "amused", "analyst", "anchor", "ancient", "anger",
        "angle", "angry", "animal", "ankle", "announce", "annual", "another", "answer", "antenna", "antique",
        "anxiety", "any", "apart", "apology", "appear", "apple", "approve", "april", "arch", "arctic",
        "area", "arena", "argue", "arm", "armed", "armor", "army", "around", "arrange", "arrest",
        "arrive", "arrow", "art", "artefact", "artist", "artwork", "ask", "aspect", "assault", "asset",
        "assist", "assume", "asthma", "athlete", "atom", "attack", "attend", "attitude", "attract", "auction",
        "audit", "august", "aunt", "author", "auto", "autumn", "average", "avocado", "avoid", "awake",
        "aware", "away", "awesome", "awful", "awkward", "axis", "baby", "bachelor", "bacon", "badge",
        // ... (Full 2048 words required - this is abbreviated for space)
        // NOTE: In production, include all 2048 BIP39 words or load from embedded resource file
        "zone", "zoo"
    ]
}

// MARK: - Data Extensions

extension Data {
    /// Convert data to binary string representation
    func toBinaryString() -> String {
        return self.map { String(format: "%08b", $0) }.joined()
    }
}

// MARK: - Mnemonic Utilities

extension MnemonicGenerator {
    /// Get word at index
    func word(at index: Int) -> String? {
        guard index >= 0 && index < wordlist.count else {
            return nil
        }
        return wordlist[index]
    }

    /// Get index of word
    func index(of word: String) -> Int? {
        return wordlist.firstIndex(of: word)
    }

    /// Calculate entropy from mnemonic word count
    static func entropyBits(for wordCount: Int) -> Int? {
        switch wordCount {
        case 12: return 128
        case 15: return 160
        case 18: return 192
        case 21: return 224
        case 24: return 256
        default: return nil
        }
    }

    /// Suggest similar words for typo correction
    func suggestWords(for partial: String) -> [String] {
        return wordlist.filter { $0.hasPrefix(partial.lowercased()) }
    }
}

// MARK: - Security Audit

extension MnemonicGenerator {
    /// Audit mnemonic strength and quality
    struct MnemonicAudit {
        let isValid: Bool
        let wordCount: Int
        let strength: MnemonicStrength?
        let hasTypos: Bool
        let suggestions: [String: [String]] // word -> suggestions

        var securityLevel: SecurityLevel {
            guard isValid else { return .invalid }

            switch strength {
            case .word12, .word15:
                return .moderate
            case .word18:
                return .strong
            case .word21, .word24:
                return .veryStrong
            case .none:
                return .invalid
            }
        }

        enum SecurityLevel {
            case invalid
            case moderate
            case strong
            case veryStrong
        }
    }

    /// Perform comprehensive mnemonic audit
    func audit(_ mnemonic: String) -> MnemonicAudit {
        let words = mnemonic.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var hasTypos = false
        var suggestions: [String: [String]] = [:]

        // Check for typos
        for word in words {
            if !wordlist.contains(word) {
                hasTypos = true
                suggestions[word] = suggestWords(for: String(word.prefix(3)))
            }
        }

        let isValid = (try? validate(mnemonic)) ?? false

        let strength: MnemonicStrength?
        switch words.count {
        case 12: strength = .word12
        case 15: strength = .word15
        case 18: strength = .word18
        case 21: strength = .word21
        case 24: strength = .word24
        default: strength = nil
        }

        return MnemonicAudit(
            isValid: isValid,
            wordCount: words.count,
            strength: strength,
            hasTypos: hasTypos,
            suggestions: suggestions
        )
    }
}
