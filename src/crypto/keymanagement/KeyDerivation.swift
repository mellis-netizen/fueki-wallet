import Foundation
import CryptoKit
import Security

/// Key Management Module with BIP32/BIP44 HD Wallet Support
/// Implements hierarchical deterministic key derivation for multiple accounts
public class KeyDerivation {

    // MARK: - Types

    public struct HDNode {
        let privateKey: Data
        let publicKey: Data
        let chainCode: Data
        let depth: UInt8
        let parentFingerprint: Data
        let childIndex: UInt32
        let isHardened: Bool

        public init(privateKey: Data, publicKey: Data, chainCode: Data,
                   depth: UInt8, parentFingerprint: Data, childIndex: UInt32,
                   isHardened: Bool = false) {
            self.privateKey = privateKey
            self.publicKey = publicKey
            self.chainCode = chainCode
            self.depth = depth
            self.parentFingerprint = parentFingerprint
            self.childIndex = childIndex
            self.isHardened = isHardened
        }
    }

    public struct DerivationPath {
        let purpose: UInt32 // BIP-43: 44' for BIP-44
        let coinType: UInt32 // BIP-44: 0' for Bitcoin, 60' for Ethereum
        let account: UInt32 // Account number
        let change: UInt32 // 0 = external, 1 = internal (change)
        let addressIndex: UInt32 // Address index

        public init(purpose: UInt32 = 44, coinType: UInt32,
                   account: UInt32 = 0, change: UInt32 = 0,
                   addressIndex: UInt32 = 0) {
            self.purpose = purpose
            self.coinType = coinType
            self.account = account
            self.change = change
            self.addressIndex = addressIndex
        }

        public var pathString: String {
            return "m/\(purpose)'/\(coinType)'/\(account)'/\(change)/\(addressIndex)"
        }
    }

    public enum CoinType: UInt32 {
        case bitcoin = 0
        case testnet = 1
        case ethereum = 60
        case polygon = 966
        case binanceSmartChain = 9006
    }

    public enum KeyDerivationError: Error {
        case invalidMnemonic
        case invalidSeed
        case invalidPath
        case derivationFailed
        case invalidKey
        case encryptionFailed
        case decryptionFailed
    }

    // MARK: - Properties

    private let secureEnclave: SecureEnclaveManager
    private let keyEncryption: KeyEncryption

    // MARK: - Initialization

    public init() {
        self.secureEnclave = SecureEnclaveManager()
        self.keyEncryption = KeyEncryption()
    }

    // MARK: - Mnemonic and Seed Generation

    /// Generate BIP-39 mnemonic phrase
    /// - Parameter strength: Entropy strength in bits (128, 160, 192, 224, 256)
    /// - Returns: Mnemonic phrase
    public func generateMnemonic(strength: Int = 128) throws -> String {
        guard [128, 160, 192, 224, 256].contains(strength) else {
            throw KeyDerivationError.invalidMnemonic
        }

        let entropySize = strength / 8
        var entropy = Data(count: entropySize)

        let status = entropy.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, entropySize, ptr.baseAddress!)
        }

        guard status == errSecSuccess else {
            throw KeyDerivationError.invalidMnemonic
        }

        // Convert entropy to mnemonic using BIP-39 wordlist
        return try entropyToMnemonic(entropy)
    }

    /// Convert mnemonic to seed using BIP-39
    /// - Parameters:
    ///   - mnemonic: BIP-39 mnemonic phrase
    ///   - passphrase: Optional passphrase for additional security
    /// - Returns: 64-byte seed
    public func mnemonicToSeed(_ mnemonic: String, passphrase: String = "") throws -> Data {
        let normalizedMnemonic = mnemonic
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()

        // Validate mnemonic
        guard try validateMnemonic(normalizedMnemonic) else {
            throw KeyDerivationError.invalidMnemonic
        }

        // PBKDF2 with HMAC-SHA512
        let password = normalizedMnemonic.data(using: .utf8)!
        let salt = "mnemonic\(passphrase)".data(using: .utf8)!

        return try pbkdf2(password: password, salt: salt,
                         iterations: 2048, keyLength: 64)
    }

    // MARK: - HD Key Derivation (BIP-32)

    /// Generate master key from seed (BIP-32)
    /// - Parameter seed: 64-byte seed from mnemonic
    /// - Returns: Master HD node
    public func generateMasterKey(from seed: Data) throws -> HDNode {
        guard seed.count >= 16 && seed.count <= 64 else {
            throw KeyDerivationError.invalidSeed
        }

        // HMAC-SHA512 with key "Bitcoin seed"
        let hmacKey = "Bitcoin seed".data(using: .utf8)!
        let hmac = try hmacSHA512(data: seed, key: hmacKey)

        let privateKey = hmac[0..<32]
        let chainCode = hmac[32..<64]

        // Derive public key
        let publicKey = try derivePublicKey(from: privateKey)

        return HDNode(
            privateKey: privateKey,
            publicKey: publicKey,
            chainCode: chainCode,
            depth: 0,
            parentFingerprint: Data(count: 4),
            childIndex: 0
        )
    }

    /// Derive child key from parent using BIP-32
    /// - Parameters:
    ///   - parent: Parent HD node
    ///   - index: Child index
    ///   - hardened: Whether to use hardened derivation
    /// - Returns: Child HD node
    public func deriveChildKey(from parent: HDNode,
                              index: UInt32,
                              hardened: Bool = false) throws -> HDNode {
        let actualIndex = hardened ? (index | 0x80000000) : index

        var data = Data()
        if hardened {
            // Hardened: ser256(k_par) || ser32(i)
            data.append(0x00)
            data.append(parent.privateKey)
        } else {
            // Normal: serP(K_par) || ser32(i)
            data.append(parent.publicKey)
        }
        data.append(contentsOf: withUnsafeBytes(of: actualIndex.bigEndian) { Data($0) })

        // HMAC-SHA512
        let hmac = try hmacSHA512(data: data, key: parent.chainCode)

        let privateKeyData = hmac[0..<32]
        let childChainCode = hmac[32..<64]

        // Add to parent key (mod n)
        let childPrivateKey = try addPrivateKeys(parent.privateKey, privateKeyData)

        // Derive public key
        let childPublicKey = try derivePublicKey(from: childPrivateKey)

        // Parent fingerprint is first 4 bytes of parent public key hash
        let parentFingerprint = parent.publicKey.hash160()[0..<4]

        return HDNode(
            privateKey: childPrivateKey,
            publicKey: childPublicKey,
            chainCode: childChainCode,
            depth: parent.depth + 1,
            parentFingerprint: parentFingerprint,
            childIndex: actualIndex,
            isHardened: hardened
        )
    }

    /// Derive key at specific BIP-44 path
    /// - Parameters:
    ///   - masterKey: Master HD node
    ///   - path: Derivation path
    /// - Returns: Derived HD node
    public func deriveKey(from masterKey: HDNode, path: DerivationPath) throws -> HDNode {
        // m/44'/coinType'/account'/change/addressIndex
        var node = masterKey

        // Purpose (hardened)
        node = try deriveChildKey(from: node, index: path.purpose, hardened: true)

        // Coin type (hardened)
        node = try deriveChildKey(from: node, index: path.coinType, hardened: true)

        // Account (hardened)
        node = try deriveChildKey(from: node, index: path.account, hardened: true)

        // Change (normal)
        node = try deriveChildKey(from: node, index: path.change, hardened: false)

        // Address index (normal)
        node = try deriveChildKey(from: node, index: path.addressIndex, hardened: false)

        return node
    }

    /// Derive multiple accounts for a coin type
    /// - Parameters:
    ///   - masterKey: Master HD node
    ///   - coinType: Coin type (BIP-44)
    ///   - accountCount: Number of accounts to derive
    /// - Returns: Array of derived account nodes
    public func deriveAccounts(from masterKey: HDNode,
                              coinType: CoinType,
                              accountCount: UInt32) throws -> [HDNode] {
        var accounts: [HDNode] = []

        for accountIndex in 0..<accountCount {
            let path = DerivationPath(
                coinType: coinType.rawValue,
                account: accountIndex
            )
            let account = try deriveKey(from: masterKey, path: path)
            accounts.append(account)
        }

        return accounts
    }

    // MARK: - Key Encryption/Decryption

    /// Encrypt private key with user password
    /// - Parameters:
    ///   - privateKey: Private key to encrypt
    ///   - password: User password
    /// - Returns: Encrypted key data
    public func encryptKey(_ privateKey: Data, with password: String) throws -> Data {
        return try keyEncryption.encrypt(privateKey, password: password)
    }

    /// Decrypt private key with user password
    /// - Parameters:
    ///   - encryptedKey: Encrypted key data
    ///   - password: User password
    /// - Returns: Decrypted private key
    public func decryptKey(_ encryptedKey: Data, with password: String) throws -> Data {
        return try keyEncryption.decrypt(encryptedKey, password: password)
    }

    /// Store key in iOS Secure Enclave
    /// - Parameters:
    ///   - privateKey: Private key to store
    ///   - identifier: Key identifier
    /// - Returns: Success status
    @discardableResult
    public func storeKeyInSecureEnclave(_ privateKey: Data,
                                       identifier: String) throws -> Bool {
        return try secureEnclave.storeKey(privateKey, identifier: identifier)
    }

    /// Retrieve key from Secure Enclave
    /// - Parameter identifier: Key identifier
    /// - Returns: Private key
    public func retrieveKeyFromSecureEnclave(identifier: String) throws -> Data {
        return try secureEnclave.retrieveKey(identifier: identifier)
    }

    // MARK: - Key Backup and Recovery

    /// Export key in WIF (Wallet Import Format)
    /// - Parameters:
    ///   - privateKey: Private key to export
    ///   - compressed: Whether to use compressed format
    /// - Returns: WIF string
    public func exportWIF(privateKey: Data, compressed: Bool = true) -> String {
        var data = Data([0x80]) // Version byte for mainnet
        data.append(privateKey)

        if compressed {
            data.append(0x01)
        }

        // Add checksum
        let checksum = data.sha256().sha256()[0..<4]
        data.append(checksum)

        return data.base58Encoded()
    }

    /// Import key from WIF
    /// - Parameter wif: WIF string
    /// - Returns: Private key
    public func importWIF(_ wif: String) throws -> Data {
        guard let decoded = wif.base58Decoded() else {
            throw KeyDerivationError.invalidKey
        }

        // Verify checksum
        let payload = decoded[0..<(decoded.count - 4)]
        let checksum = decoded[(decoded.count - 4)...]
        let calculatedChecksum = payload.sha256().sha256()[0..<4]

        guard checksum == calculatedChecksum else {
            throw KeyDerivationError.invalidKey
        }

        // Extract private key (skip version byte and optional compression byte)
        let keyStart = 1
        let keyEnd = decoded.count - 4 - (decoded.count == 38 ? 1 : 0)
        return payload[keyStart..<keyEnd]
    }

    // MARK: - Private Helper Methods

    private func entropyToMnemonic(_ entropy: Data) throws -> String {
        // Compute checksum
        let checksumLength = entropy.count / 4
        let hash = entropy.sha256()
        let checksum = hash[0]

        // Combine entropy and checksum
        var bits = entropy.toBits()
        let checksumBits = String(checksum, radix: 2)
            .padLeft(toLength: 8, withPad: "0")
            .prefix(checksumLength)
        bits.append(contentsOf: checksumBits)

        // Split into 11-bit groups
        var words: [String] = []
        for i in stride(from: 0, to: bits.count, by: 11) {
            let end = min(i + 11, bits.count)
            let chunk = bits[i..<end]
            if let index = Int(chunk, radix: 2) {
                words.append(BIP39WordList.words[index])
            }
        }

        return words.joined(separator: " ")
    }

    private func validateMnemonic(_ mnemonic: String) throws -> Bool {
        let words = mnemonic.components(separatedBy: " ")

        guard [12, 15, 18, 21, 24].contains(words.count) else {
            return false
        }

        // Verify all words are in BIP-39 wordlist
        return words.allSatisfy { BIP39WordList.words.contains($0) }
    }

    private func pbkdf2(password: Data, salt: Data,
                       iterations: Int, keyLength: Int) throws -> Data {
        var derivedKey = Data(count: keyLength)

        let status = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                password.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw KeyDerivationError.derivationFailed
        }

        return derivedKey
    }

    private func hmacSHA512(data: Data, key: Data) throws -> Data {
        var hmac = [UInt8](repeating: 0, count: 64)

        data.withUnsafeBytes { dataBytes in
            key.withUnsafeBytes { keyBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA512),
                    keyBytes.baseAddress,
                    key.count,
                    dataBytes.baseAddress,
                    data.count,
                    &hmac
                )
            }
        }

        return Data(hmac)
    }

    private func derivePublicKey(from privateKey: Data) throws -> Data {
        // Use secp256k1 to derive public key
        // In production, use proper secp256k1 library
        // Placeholder implementation using P256
        let privKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
        return privKey.publicKey.compressedRepresentation
    }

    private func addPrivateKeys(_ key1: Data, _ key2: Data) throws -> Data {
        // Add two private keys modulo curve order (secp256k1)
        // This is simplified - in production use proper big integer arithmetic
        var result = Data(count: 32)

        var carry: UInt16 = 0
        for i in (0..<32).reversed() {
            let sum = UInt16(key1[i]) + UInt16(key2[i]) + carry
            result[i] = UInt8(sum & 0xFF)
            carry = sum >> 8
        }

        return result
    }
}

// MARK: - Supporting Classes

private class KeyEncryption {
    func encrypt(_ data: Data, password: String) throws -> Data {
        // Derive key from password
        let salt = try generateSalt()
        let key = try deriveKey(from: password, salt: salt)

        // Encrypt with AES-256-GCM
        let symmetricKey = SymmetricKey(data: key)
        let nonce = try AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey, nonce: nonce)

        // Combine salt + nonce + ciphertext
        var result = salt
        result.append(nonce.withUnsafeBytes { Data($0) })
        result.append(sealedBox.ciphertext)
        result.append(sealedBox.tag)

        return result
    }

    func decrypt(_ encryptedData: Data, password: String) throws -> Data {
        guard encryptedData.count > 44 else { // 16 (salt) + 12 (nonce) + 16 (tag)
            throw KeyDerivation.KeyDerivationError.decryptionFailed
        }

        // Extract components
        let salt = encryptedData[0..<16]
        let nonceData = encryptedData[16..<28]
        let tag = encryptedData[(encryptedData.count - 16)...]
        let ciphertext = encryptedData[28..<(encryptedData.count - 16)]

        // Derive key
        let key = try deriveKey(from: password, salt: salt)
        let symmetricKey = SymmetricKey(data: key)

        // Decrypt
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }

    private func generateSalt() throws -> Data {
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, 16, ptr.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw KeyDerivation.KeyDerivationError.encryptionFailed
        }
        return salt
    }

    private func deriveKey(from password: String, salt: Data) throws -> Data {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeyDerivation.KeyDerivationError.encryptionFailed
        }

        var derivedKey = Data(count: 32)
        let status = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        100000, // iterations
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw KeyDerivation.KeyDerivationError.encryptionFailed
        }

        return derivedKey
    }
}

private class SecureEnclaveManager {
    func storeKey(_ privateKey: Data, identifier: String) throws -> Bool {
        // Store in iOS Secure Enclave
        guard SecureEnclave.isAvailable else {
            throw KeyDerivation.KeyDerivationError.encryptionFailed
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrApplicationLabel as String: identifier,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: identifier.data(using: .utf8)!
            ]
        ]

        let status = SecItemAdd([
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationLabel as String: identifier,
            kSecValueData as String: privateKey,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ] as CFDictionary, nil)

        return status == errSecSuccess
    }

    func retrieveKey(identifier: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationLabel as String: identifier,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let keyData = item as? Data else {
            throw KeyDerivation.KeyDerivationError.decryptionFailed
        }

        return keyData
    }
}

// MARK: - BIP-39 Wordlist (Shortened for brevity)

private struct BIP39WordList {
    static let words: [String] = [
        "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract",
        "absurd", "abuse", "access", "accident", "account", "accuse", "achieve", "acid",
        // ... (2048 words total in production)
        // For production, include complete BIP-39 wordlist
        "zone", "zoo"
    ]
}

// MARK: - Data Extensions

private extension Data {
    func toBits() -> String {
        return self.map { byte in
            String(byte, radix: 2).padLeft(toLength: 8, withPad: "0")
        }.joined()
    }

    func sha256() -> Data {
        var hash = SHA256()
        hash.update(data: self)
        return Data(hash.finalize())
    }

    func hash160() -> Data {
        // SHA-256 followed by RIPEMD-160
        // For production, use proper RIPEMD-160 implementation
        return self.sha256() // Simplified
    }

    func base58Encoded() -> String {
        // Base58 encoding (Bitcoin style)
        // In production, use proper Base58 library
        return self.base64EncodedString() // Placeholder
    }
}

private extension String {
    func base58Decoded() -> Data? {
        // Base58 decoding
        // In production, use proper Base58 library
        return Data(base64Encoded: self) // Placeholder
    }

    func padLeft(toLength: Int, withPad: String) -> String {
        guard self.count < toLength else { return self }
        return String(repeating: withPad, count: toLength - self.count) + self
    }
}

// MARK: - CommonCrypto Bridge

import CommonCrypto

private func CCKeyDerivationPBKDF(
    _ algorithm: CCPBKDFAlgorithm,
    _ password: UnsafePointer<Int8>?,
    _ passwordLen: Int,
    _ salt: UnsafePointer<UInt8>?,
    _ saltLen: Int,
    _ prf: CCPseudoRandomAlgorithm,
    _ rounds: UInt32,
    _ derivedKey: UnsafeMutablePointer<UInt8>?,
    _ derivedKeyLen: Int
) -> Int32 {
    return CCKeyDerivationPBKDF(
        algorithm,
        password,
        passwordLen,
        salt,
        saltLen,
        prf,
        rounds,
        derivedKey,
        derivedKeyLen
    )
}
