import Foundation
import CryptoKit
import Security

/// Cryptographic Utility Functions
/// Provides common crypto operations for the wallet
public class CryptoUtils {

    // MARK: - Hashing Functions

    /// Compute SHA-256 hash
    public static func sha256(_ data: Data) -> Data {
        var hasher = SHA256()
        hasher.update(data: data)
        return Data(hasher.finalize())
    }

    /// Compute SHA-512 hash
    public static func sha512(_ data: Data) -> Data {
        var hasher = SHA512()
        hasher.update(data: data)
        return Data(hasher.finalize())
    }

    /// Compute RIPEMD-160 hash (Bitcoin hash160)
    public static func ripemd160(_ data: Data) -> Data {
        return RIPEMD160.hash(data)
    }

    /// Compute Bitcoin-style hash160 (SHA-256 followed by RIPEMD-160)
    public static func hash160(_ data: Data) -> Data {
        return ripemd160(sha256(data))
    }

    /// Compute Keccak-256 hash (Ethereum)
    /// Note: This is a placeholder using SHA-256. In production, use proper Keccak library
    public static func keccak256(_ data: Data) -> Data {
        // Placeholder: In production use CryptoSwift or web3swift for proper Keccak-256
        return sha256(data)
    }

    // MARK: - HMAC Functions

    /// Compute HMAC-SHA256
    public static func hmacSHA256(data: Data, key: Data) -> Data {
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        data.withUnsafeBytes { dataBytes in
            key.withUnsafeBytes { keyBytes in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
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

    /// Compute HMAC-SHA512
    public static func hmacSHA512(data: Data, key: Data) -> Data {
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))

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

    // MARK: - Encryption/Decryption

    /// Encrypt data using AES-256-GCM
    public static func encryptAESGCM(data: Data, key: Data, additionalData: Data? = nil) throws -> (ciphertext: Data, nonce: Data, tag: Data) {
        let symmetricKey = SymmetricKey(data: key)
        let nonce = AES.GCM.Nonce()

        let sealedBox: AES.GCM.SealedBox
        if let aad = additionalData {
            sealedBox = try AES.GCM.seal(data, using: symmetricKey, nonce: nonce, authenticating: aad)
        } else {
            sealedBox = try AES.GCM.seal(data, using: symmetricKey, nonce: nonce)
        }

        return (
            ciphertext: sealedBox.ciphertext,
            nonce: Data(nonce),
            tag: sealedBox.tag
        )
    }

    /// Decrypt data using AES-256-GCM
    public static func decryptAESGCM(ciphertext: Data, key: Data, nonce: Data, tag: Data, additionalData: Data? = nil) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let gcmNonce = try AES.GCM.Nonce(data: nonce)

        let sealedBox = try AES.GCM.SealedBox(nonce: gcmNonce, ciphertext: ciphertext, tag: tag)

        if let aad = additionalData {
            return try AES.GCM.open(sealedBox, using: symmetricKey, authenticating: aad)
        } else {
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        }
    }

    /// Encrypt data using ChaCha20-Poly1305
    public static func encryptChaCha20(data: Data, key: Data) throws -> (ciphertext: Data, nonce: Data, tag: Data) {
        let symmetricKey = SymmetricKey(data: key)
        let nonce = ChaChaPoly.Nonce()

        let sealedBox = try ChaChaPoly.seal(data, using: symmetricKey, nonce: nonce)

        return (
            ciphertext: sealedBox.ciphertext,
            nonce: Data(nonce),
            tag: sealedBox.tag
        )
    }

    /// Decrypt data using ChaCha20-Poly1305
    public static func decryptChaCha20(ciphertext: Data, key: Data, nonce: Data, tag: Data) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let chachaNonce = try ChaChaPoly.Nonce(data: nonce)

        let sealedBox = try ChaChaPoly.SealedBox(nonce: chachaNonce, ciphertext: ciphertext, tag: tag)
        return try ChaChaPoly.open(sealedBox, using: symmetricKey)
    }

    // MARK: - Key Derivation

    /// Derive key using PBKDF2-HMAC-SHA256
    public static func pbkdf2SHA256(password: Data, salt: Data, iterations: Int, keyLength: Int) throws -> Data {
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
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw CryptoError.keyDerivationFailed
        }

        return derivedKey
    }

    /// Derive key using PBKDF2-HMAC-SHA512
    public static func pbkdf2SHA512(password: Data, salt: Data, iterations: Int, keyLength: Int) throws -> Data {
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
            throw CryptoError.keyDerivationFailed
        }

        return derivedKey
    }

    /// Derive key using HKDF (HMAC-based Extract-and-Expand Key Derivation Function)
    public static func hkdf(inputKeyMaterial: Data, salt: Data, info: Data, outputLength: Int) throws -> Data {
        // Extract
        let prk = hmacSHA256(data: inputKeyMaterial, key: salt)

        // Expand
        var okm = Data()
        var previousBlock = Data()
        var counter: UInt8 = 1

        while okm.count < outputLength {
            var block = previousBlock
            block.append(info)
            block.append(counter)

            previousBlock = hmacSHA256(data: block, key: prk)
            okm.append(previousBlock)
            counter += 1
        }

        return okm.prefix(outputLength)
    }

    // MARK: - Random Generation

    /// Generate cryptographically secure random bytes
    public static func randomBytes(count: Int) throws -> Data {
        var bytes = Data(count: count)
        let status = bytes.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, count, ptr.baseAddress!)
        }

        guard status == errSecSuccess else {
            throw CryptoError.randomGenerationFailed
        }

        return bytes
    }

    /// Generate random number in range
    public static func randomInt(in range: Range<Int>) throws -> Int {
        let count = range.upperBound - range.lowerBound
        guard count > 0 else {
            throw CryptoError.invalidParameter
        }

        let randomBytes = try randomBytes(count: 8)
        let randomValue = randomBytes.withUnsafeBytes { $0.load(as: UInt64.self) }

        return range.lowerBound + Int(randomValue % UInt64(count))
    }

    // MARK: - Secure Memory Operations

    /// Securely wipe data from memory
    public static func secureWipe(_ data: inout Data) {
        data.withUnsafeMutableBytes { ptr in
            memset_s(ptr.baseAddress, ptr.count, 0, ptr.count)
        }
    }

    /// Constant-time comparison to prevent timing attacks
    public static func constantTimeCompare(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }

        var result: UInt8 = 0
        for i in 0..<lhs.count {
            result |= lhs[i] ^ rhs[i]
        }

        return result == 0
    }

    // MARK: - Encoding/Decoding

    /// Base58 encoding (Bitcoin-style)
    public static func base58Encode(_ data: Data) -> String {
        let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        var bytes = Array(data)

        // Count leading zeros
        var leadingZeros = 0
        for byte in bytes {
            if byte == 0 {
                leadingZeros += 1
            } else {
                break
            }
        }

        // Encode using base58
        var encoded = ""

        while !bytes.allSatisfy({ $0 == 0 }) {
            var carry: UInt32 = 0
            for i in 0..<bytes.count {
                carry = (carry << 8) + UInt32(bytes[i])
                bytes[i] = UInt8(carry / 58)
                carry %= 58
            }
            encoded = String(alphabet[alphabet.index(alphabet.startIndex, offsetBy: Int(carry))]) + encoded
        }

        // Add leading '1's for leading zeros
        let prefix = String(repeating: alphabet.first!, count: leadingZeros)
        return prefix + encoded
    }

    /// Base58Check encoding (with double SHA-256 checksum)
    public static func base58CheckEncode(_ data: Data) -> String {
        // Add 4-byte checksum
        let checksum = sha256(sha256(data)).prefix(4)
        let dataWithChecksum = data + checksum
        return base58Encode(dataWithChecksum)
    }

    /// Base58 decoding
    public static func base58Decode(_ string: String) -> Data? {
        let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

        var bytes = [UInt8](repeating: 0, count: string.count)

        for char in string {
            guard let index = alphabet.firstIndex(of: char) else {
                return nil
            }

            var carry = alphabet.distance(from: alphabet.startIndex, to: index)

            for i in (0..<bytes.count).reversed() {
                carry += 58 * Int(bytes[i])
                bytes[i] = UInt8(carry % 256)
                carry /= 256
            }

            guard carry == 0 else {
                return nil
            }
        }

        // Count leading '1's
        var leadingOnes = 0
        for char in string {
            if char == "1" {
                leadingOnes += 1
            } else {
                break
            }
        }

        // Remove leading zeros from bytes
        while bytes.first == 0 && bytes.count > 1 {
            bytes.removeFirst()
        }

        // Add leading zero bytes for leading '1's
        var result = Data(repeating: 0, count: leadingOnes)
        result.append(contentsOf: bytes)

        return result
    }

    /// Base58Check decoding (verifies double SHA-256 checksum)
    public static func base58CheckDecode(_ string: String) -> Data? {
        guard let decoded = base58Decode(string) else {
            return nil
        }

        guard decoded.count >= 4 else {
            return nil
        }

        let payload = decoded.prefix(decoded.count - 4)
        let checksum = decoded.suffix(4)

        let calculatedChecksum = sha256(sha256(payload)).prefix(4)

        guard constantTimeCompare(checksum, calculatedChecksum) else {
            return nil
        }

        return payload
    }

    /// Hex encoding
    public static func hexEncode(_ data: Data) -> String {
        return data.map { String(format: "%02x", $0) }.joined()
    }

    /// Hex decoding
    public static func hexDecode(_ string: String) -> Data? {
        let cleanString = string.hasPrefix("0x") ? String(string.dropFirst(2)) : string
        guard cleanString.count % 2 == 0 else { return nil }

        var data = Data(capacity: cleanString.count / 2)

        var index = cleanString.startIndex
        while index < cleanString.endIndex {
            let nextIndex = cleanString.index(index, offsetBy: 2)
            guard let byte = UInt8(cleanString[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }

        return data
    }

    // MARK: - Address Validation

    /// Validate Bitcoin address checksum
    public static func validateBitcoinAddress(_ address: String) -> Bool {
        // Check for Bech32 address (SegWit)
        if address.lowercased().hasPrefix("bc1") || address.lowercased().hasPrefix("tb1") {
            do {
                _ = try Bech32.decodeSegWitAddress(address)
                return true
            } catch {
                return false
            }
        }

        // Check for Base58Check address (Legacy or P2SH)
        guard let decoded = base58CheckDecode(address) else {
            return false
        }

        // Validate version byte and length
        guard decoded.count == 21 else {
            return false
        }

        let version = decoded[0]

        // Valid version bytes:
        // 0x00 - P2PKH mainnet
        // 0x05 - P2SH mainnet
        // 0x6F - P2PKH testnet
        // 0xC4 - P2SH testnet
        return version == 0x00 || version == 0x05 || version == 0x6F || version == 0xC4
    }

    /// Validate Ethereum address checksum (EIP-55)
    public static func validateEthereumAddress(_ address: String) -> Bool {
        let cleanAddress = address.hasPrefix("0x") ? String(address.dropFirst(2)) : address

        guard cleanAddress.count == 40 else {
            return false
        }

        guard cleanAddress.allSatisfy({ $0.isHexDigit }) else {
            return false
        }

        // If no mixed case, it's valid (no checksum)
        if cleanAddress == cleanAddress.lowercased() ||
           cleanAddress == cleanAddress.uppercased() {
            return true
        }

        // Validate EIP-55 checksum
        let hash = keccak256(cleanAddress.lowercased().data(using: .utf8)!)
        let hashHex = hexEncode(hash)

        for (i, char) in cleanAddress.enumerated() {
            guard let hashValue = Int(String(hashHex[hashHex.index(hashHex.startIndex, offsetBy: i)]), radix: 16) else {
                return false
            }

            if char.isLetter {
                if hashValue >= 8 && !char.isUppercase {
                    return false
                }
                if hashValue < 8 && char.isUppercase {
                    return false
                }
            }
        }

        return true
    }

    // MARK: - Error Types

    public enum CryptoError: Error {
        case keyDerivationFailed
        case randomGenerationFailed
        case invalidParameter
        case encryptionFailed
        case decryptionFailed
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
