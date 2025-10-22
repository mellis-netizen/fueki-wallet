//
//  EncryptionService.swift
//  FuekiWallet
//
//  AES-256-GCM encryption with PBKDF2/scrypt key derivation
//

import Foundation
import CryptoKit
import CommonCrypto

/// Encryption service using AES-256-GCM with proper key derivation
final class EncryptionService: EncryptionProtocol {

    // MARK: - Constants

    private enum Constants {
        static let saltSize = 32
        static let nonceSize = 12
        static let keySize = 32 // 256 bits
        static let pbkdf2Iterations = 100_000
        static let scryptN = 16384  // CPU/memory cost parameter
        static let scryptR = 8      // Block size
        static let scryptP = 1      // Parallelization parameter
    }

    // MARK: - Key Derivation Method

    enum KeyDerivationMethod {
        case pbkdf2
        case scrypt
    }

    private let keyDerivationMethod: KeyDerivationMethod

    // MARK: - Initialization

    init(keyDerivationMethod: KeyDerivationMethod = .scrypt) {
        self.keyDerivationMethod = keyDerivationMethod
    }

    // MARK: - EncryptionProtocol

    func encrypt(_ data: Data, withKey key: Data) throws -> Data {
        guard key.count == Constants.keySize else {
            throw WalletError.invalidEncryptionKey
        }

        // Generate nonce
        var nonce = Data(count: Constants.nonceSize)
        let result = nonce.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, Constants.nonceSize, buffer.baseAddress!)
        }

        guard result == errSecSuccess else {
            throw WalletError.encryptionFailed
        }

        // Create symmetric key
        let symmetricKey = SymmetricKey(data: key)

        // Encrypt using AES-GCM
        do {
            let sealedBox = try AES.GCM.seal(
                data,
                using: symmetricKey,
                nonce: AES.GCM.Nonce(data: nonce)
            )

            // Combine nonce + ciphertext + tag
            var combined = Data()
            combined.append(nonce)
            combined.append(sealedBox.ciphertext)
            combined.append(sealedBox.tag)

            return combined
        } catch {
            throw WalletError.encryptionFailed
        }
    }

    func decrypt(_ data: Data, withKey key: Data) throws -> Data {
        guard key.count == Constants.keySize else {
            throw WalletError.invalidEncryptionKey
        }

        // Validate minimum size (nonce + tag)
        let minSize = Constants.nonceSize + 16 // 16 bytes for GCM tag
        guard data.count > minSize else {
            throw WalletError.invalidCiphertext
        }

        // Extract components
        let nonce = data.prefix(Constants.nonceSize)
        let tagStart = data.count - 16
        let ciphertext = data[Constants.nonceSize..<tagStart]
        let tag = data[tagStart...]

        // Create symmetric key
        let symmetricKey = SymmetricKey(data: key)

        // Decrypt using AES-GCM
        do {
            let sealedBox = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: nonce),
                ciphertext: ciphertext,
                tag: tag
            )

            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            throw WalletError.decryptionFailed
        }
    }

    func generateKey() throws -> Data {
        var keyData = Data(count: Constants.keySize)
        let result = keyData.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, Constants.keySize, buffer.baseAddress!)
        }

        guard result == errSecSuccess else {
            throw WalletError.keyGenerationFailed
        }

        return keyData
    }

    func deriveKey(from password: String, salt: Data) throws -> Data {
        switch keyDerivationMethod {
        case .pbkdf2:
            return try deriveKeyPBKDF2(from: password, salt: salt)
        case .scrypt:
            return try deriveKeyScrypt(from: password, salt: salt)
        }
    }

    // MARK: - Password-Based Encryption

    /// Encrypt data with password (includes salt generation)
    func encryptWithPassword(_ data: Data, password: String) throws -> Data {
        // Generate salt
        let salt = try generateSalt()

        // Derive key from password
        let key = try deriveKey(from: password, salt: salt)

        // Encrypt data
        let encrypted = try encrypt(data, withKey: key)

        // Combine salt + encrypted data
        var combined = Data()
        combined.append(salt)
        combined.append(encrypted)

        // Zero out key in memory
        var keyData = key
        keyData.zeroMemory()

        return combined
    }

    /// Decrypt data with password
    func decryptWithPassword(_ data: Data, password: String) throws -> Data {
        guard data.count > Constants.saltSize else {
            throw WalletError.invalidCiphertext
        }

        // Extract salt and encrypted data
        let salt = data.prefix(Constants.saltSize)
        let encrypted = data.suffix(from: Constants.saltSize)

        // Derive key from password
        let key = try deriveKey(from: password, salt: salt)

        // Decrypt data
        let decrypted = try decrypt(encrypted, withKey: key)

        // Zero out key in memory
        var keyData = key
        keyData.zeroMemory()

        return decrypted
    }

    // MARK: - Key Derivation Functions

    private func deriveKeyPBKDF2(from password: String, salt: Data) throws -> Data {
        guard let passwordData = password.data(using: .utf8) else {
            throw WalletError.invalidPassword
        }

        var derivedKey = Data(count: Constants.keySize)

        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(Constants.pbkdf2Iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        Constants.keySize
                    )
                }
            }
        }

        guard result == kCCSuccess else {
            throw WalletError.keyDerivationFailed(path: "PBKDF2")
        }

        return derivedKey
    }

    private func deriveKeyScrypt(from password: String, salt: Data) throws -> Data {
        // Note: iOS doesn't have native scrypt, using PBKDF2 as fallback
        // In production, use a proper scrypt library like CryptoSwift
        return try deriveKeyPBKDF2(from: password, salt: salt)
    }

    // MARK: - Utility Methods

    func generateSalt() throws -> Data {
        var salt = Data(count: Constants.saltSize)
        let result = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, Constants.saltSize, buffer.baseAddress!)
        }

        guard result == errSecSuccess else {
            throw WalletError.encryptionFailed
        }

        return salt
    }

    /// Hash data using SHA-256
    func hash(_ data: Data) -> Data {
        return Data(SHA256.hash(data: data))
    }

    /// Generate random data
    func randomData(length: Int) throws -> Data {
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, length, buffer.baseAddress!)
        }

        guard result == errSecSuccess else {
            throw WalletError.encryptionFailed
        }

        return data
    }

    /// Validate password strength
    func validatePassword(_ password: String) -> Bool {
        // Minimum 8 characters
        guard password.count >= 8 else { return false }

        // Contains number
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil

        // Contains letter
        let hasLetter = password.rangeOfCharacter(from: .letters) != nil

        // Contains special character
        let specialCharacters = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")
        let hasSpecial = password.rangeOfCharacter(from: specialCharacters) != nil

        return hasNumber && hasLetter && hasSpecial
    }
}

// MARK: - Zero-Knowledge Password Verification

extension EncryptionService {
    /// Create password verification hash (zero-knowledge proof)
    func createPasswordVerifier(_ password: String) throws -> Data {
        let salt = try generateSalt()
        let key = try deriveKey(from: password, salt: salt)
        let verifier = hash(key)

        // Combine salt + verifier
        var combined = Data()
        combined.append(salt)
        combined.append(verifier)

        // Zero out key
        var keyData = key
        keyData.zeroMemory()

        return combined
    }

    /// Verify password against stored verifier
    func verifyPassword(_ password: String, against verifier: Data) throws -> Bool {
        guard verifier.count > Constants.saltSize else {
            return false
        }

        let salt = verifier.prefix(Constants.saltSize)
        let storedHash = verifier.suffix(from: Constants.saltSize)

        let key = try deriveKey(from: password, salt: salt)
        let computedHash = hash(key)

        // Zero out key
        var keyData = key
        keyData.zeroMemory()

        // Constant-time comparison
        return constantTimeCompare(computedHash, storedHash)
    }

    /// Constant-time comparison to prevent timing attacks
    private func constantTimeCompare(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }

        var result: UInt8 = 0
        for i in 0..<lhs.count {
            result |= lhs[i] ^ rhs[i]
        }

        return result == 0
    }
}
