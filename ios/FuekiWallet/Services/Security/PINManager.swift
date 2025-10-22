//
//  PINManager.swift
//  FuekiWallet
//
//  Production-grade PIN management service
//  Handles PIN creation, validation, and security policies
//

import Foundation
import CryptoKit
import Combine

/// PIN-related errors
public enum PINError: LocalizedError {
    case notSet
    case invalid
    case tooShort
    case tooWeak
    case locked
    case tooManyAttempts
    case sequentialDigits
    case repeatingDigits
    case commonPIN
    case storageFailed
    case retrievalFailed
    case hashingFailed
    case invalidLength

    public var errorDescription: String? {
        switch self {
        case .notSet:
            return "PIN is not set"
        case .invalid:
            return "Invalid PIN"
        case .tooShort:
            return "PIN is too short"
        case .tooWeak:
            return "PIN is too weak"
        case .locked:
            return "PIN is locked due to too many attempts"
        case .tooManyAttempts:
            return "Too many failed attempts"
        case .sequentialDigits:
            return "PIN cannot contain sequential digits"
        case .repeatingDigits:
            return "PIN cannot contain repeating digits"
        case .commonPIN:
            return "PIN is too common. Please choose a different PIN"
        case .storageFailed:
            return "Failed to store PIN securely"
        case .retrievalFailed:
            return "Failed to retrieve PIN"
        case .hashingFailed:
            return "Failed to hash PIN"
        case .invalidLength:
            return "PIN must be 4-8 digits"
        }
    }
}

/// PIN validation result
public enum PINValidationResult {
    case valid
    case invalid(PINError)
    case locked(remainingLockTime: TimeInterval)
}

/// PIN strength level
public enum PINStrength {
    case weak
    case medium
    case strong

    var description: String {
        switch self {
        case .weak: return "Weak"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }
}

/// PIN manager for secure PIN operations
public final class PINManager {

    // MARK: - Singleton

    public static let shared = PINManager()

    // MARK: - Properties

    private let secureStorage = SecureStorageService.shared
    private let userDefaults = UserDefaults.standard

    // Keys for storage
    private let pinHashKey = "com.fueki.wallet.pin.hash"
    private let pinSaltKey = "com.fueki.wallet.pin.salt"
    private let pinAttemptsKey = "com.fueki.wallet.pin.attempts"
    private let pinLockTimeKey = "com.fueki.wallet.pin.locktime"
    private let pinLastAttemptKey = "com.fueki.wallet.pin.lastattempt"
    private let pinSetKey = "com.fueki.wallet.pin.isset"
    private let pinLengthKey = "com.fueki.wallet.pin.length"

    // Security configuration
    private let maxAttempts = 5
    private let lockDuration: TimeInterval = 300 // 5 minutes
    private let minPINLength = 4
    private let maxPINLength = 8

    // Common weak PINs to reject
    private let commonPINs = [
        "1234", "0000", "1111", "2222", "3333", "4444", "5555",
        "6666", "7777", "8888", "9999", "1212", "1004", "2000",
        "4321", "6969", "1122", "2580", "5678", "1357", "2468"
    ]

    // Publishers
    private let pinStatusSubject = CurrentValueSubject<Bool, Never>(false)
    public var pinStatusPublisher: AnyPublisher<Bool, Never> {
        pinStatusSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private init() {
        pinStatusSubject.send(isPINSet)
    }

    // MARK: - PIN Status

    /// Check if PIN is set
    public var isPINSet: Bool {
        return userDefaults.bool(forKey: pinSetKey)
    }

    /// Get current PIN length (if set)
    public var pinLength: Int? {
        guard isPINSet else { return nil }
        let length = userDefaults.integer(forKey: pinLengthKey)
        return length > 0 ? length : nil
    }

    /// Check if PIN is currently locked
    public var isLocked: Bool {
        guard let lockTime = userDefaults.object(forKey: pinLockTimeKey) as? Date else {
            return false
        }
        return Date() < lockTime
    }

    /// Get remaining lock time in seconds
    public var remainingLockTime: TimeInterval {
        guard let lockTime = userDefaults.object(forKey: pinLockTimeKey) as? Date else {
            return 0
        }
        let remaining = lockTime.timeIntervalSince(Date())
        return max(0, remaining)
    }

    /// Get current failed attempts count
    public var failedAttempts: Int {
        return userDefaults.integer(forKey: pinAttemptsKey)
    }

    /// Get remaining attempts before lockout
    public var remainingAttempts: Int {
        return max(0, maxAttempts - failedAttempts)
    }

    // MARK: - PIN Creation

    /// Set a new PIN
    /// - Parameter pin: The PIN to set
    /// - Returns: Result with success or error
    public func setPIN(_ pin: String) -> Result<Void, PINError> {
        // Validate PIN
        if let error = validatePINStrength(pin) {
            return .failure(error)
        }

        // Generate salt
        guard let salt = generateSalt() else {
            return .failure(.hashingFailed)
        }

        // Hash PIN with salt
        guard let hashedPIN = hashPIN(pin, salt: salt) else {
            return .failure(.hashingFailed)
        }

        // Store hashed PIN and salt in keychain
        let pinData = hashedPIN.withUnsafeBytes { Data($0) }
        let saltData = salt.withUnsafeBytes { Data($0) }

        guard secureStorage.save(pinData, forKey: pinHashKey) else {
            return .failure(.storageFailed)
        }

        guard secureStorage.save(saltData, forKey: pinSaltKey) else {
            return .failure(.storageFailed)
        }

        // Update metadata
        userDefaults.set(true, forKey: pinSetKey)
        userDefaults.set(pin.count, forKey: pinLengthKey)
        userDefaults.set(0, forKey: pinAttemptsKey)
        userDefaults.removeObject(forKey: pinLockTimeKey)
        userDefaults.removeObject(forKey: pinLastAttemptKey)

        pinStatusSubject.send(true)

        return .success(())
    }

    /// Change existing PIN
    /// - Parameters:
    ///   - currentPIN: Current PIN for verification
    ///   - newPIN: New PIN to set
    /// - Returns: Result with success or error
    public func changePIN(currentPIN: String, newPIN: String) -> Result<Void, PINError> {
        // Verify current PIN
        switch verifyPIN(currentPIN) {
        case .valid:
            return setPIN(newPIN)
        case .invalid(let error):
            return .failure(error)
        case .locked(let remainingTime):
            return .failure(.locked)
        }
    }

    /// Remove PIN
    /// - Parameter currentPIN: Current PIN for verification
    /// - Returns: Result with success or error
    public func removePIN(currentPIN: String) -> Result<Void, PINError> {
        // Verify current PIN
        switch verifyPIN(currentPIN) {
        case .valid:
            // Remove from keychain
            _ = secureStorage.delete(forKey: pinHashKey)
            _ = secureStorage.delete(forKey: pinSaltKey)

            // Clear metadata
            userDefaults.set(false, forKey: pinSetKey)
            userDefaults.removeObject(forKey: pinLengthKey)
            userDefaults.removeObject(forKey: pinAttemptsKey)
            userDefaults.removeObject(forKey: pinLockTimeKey)
            userDefaults.removeObject(forKey: pinLastAttemptKey)

            pinStatusSubject.send(false)

            return .success(())
        case .invalid(let error):
            return .failure(error)
        case .locked:
            return .failure(.locked)
        }
    }

    // MARK: - PIN Verification

    /// Verify PIN
    /// - Parameter pin: The PIN to verify
    /// - Returns: Validation result
    public func verifyPIN(_ pin: String) -> PINValidationResult {
        // Check if locked
        if isLocked {
            return .locked(remainingLockTime: remainingLockTime)
        }

        // Check if PIN is set
        guard isPINSet else {
            return .invalid(.notSet)
        }

        // Retrieve stored hash and salt
        guard let storedHashData = secureStorage.retrieve(forKey: pinHashKey),
              let storedSaltData = secureStorage.retrieve(forKey: pinSaltKey) else {
            return .invalid(.retrievalFailed)
        }

        // Convert to SymmetricKey
        let storedHash = SymmetricKey(data: storedHashData)
        let storedSalt = SymmetricKey(data: storedSaltData)

        // Hash provided PIN with stored salt
        guard let hashedPIN = hashPIN(pin, salt: storedSalt) else {
            return .invalid(.hashingFailed)
        }

        // Compare hashes using constant-time comparison
        let isValid = constantTimeCompare(storedHash, hashedPIN)

        if isValid {
            // Reset attempts on success
            userDefaults.set(0, forKey: pinAttemptsKey)
            userDefaults.removeObject(forKey: pinLockTimeKey)
            return .valid
        } else {
            // Increment failed attempts
            let attempts = failedAttempts + 1
            userDefaults.set(attempts, forKey: pinAttemptsKey)
            userDefaults.set(Date(), forKey: pinLastAttemptKey)

            if attempts >= maxAttempts {
                // Lock PIN
                let lockTime = Date().addingTimeInterval(lockDuration)
                userDefaults.set(lockTime, forKey: pinLockTimeKey)
                return .locked(remainingLockTime: lockDuration)
            }

            return .invalid(.invalid)
        }
    }

    // MARK: - PIN Validation

    /// Validate PIN strength
    /// - Parameter pin: The PIN to validate
    /// - Returns: Error if validation fails, nil if valid
    private func validatePINStrength(_ pin: String) -> PINError? {
        // Check length
        guard pin.count >= minPINLength && pin.count <= maxPINLength else {
            return .invalidLength
        }

        // Check if numeric
        guard pin.allSatisfy({ $0.isNumber }) else {
            return .invalid
        }

        // Check for common PINs
        if commonPINs.contains(pin) {
            return .commonPIN
        }

        // Check for sequential digits
        if hasSequentialDigits(pin) {
            return .sequentialDigits
        }

        // Check for repeating digits
        if hasRepeatingDigits(pin) {
            return .repeatingDigits
        }

        return nil
    }

    /// Calculate PIN strength
    /// - Parameter pin: The PIN to evaluate
    /// - Returns: PIN strength level
    public func calculatePINStrength(_ pin: String) -> PINStrength {
        guard pin.count >= minPINLength else {
            return .weak
        }

        var strength = 0

        // Length bonus
        if pin.count >= 6 {
            strength += 1
        }
        if pin.count >= 8 {
            strength += 1
        }

        // Digit variety
        let uniqueDigits = Set(pin)
        if uniqueDigits.count >= 3 {
            strength += 1
        }
        if uniqueDigits.count >= 4 {
            strength += 1
        }

        // Not sequential or repeating
        if !hasSequentialDigits(pin) {
            strength += 1
        }
        if !hasRepeatingDigits(pin) {
            strength += 1
        }

        // Not common
        if !commonPINs.contains(pin) {
            strength += 1
        }

        if strength <= 2 {
            return .weak
        } else if strength <= 4 {
            return .medium
        } else {
            return .strong
        }
    }

    // MARK: - Helper Methods

    private func hasSequentialDigits(_ pin: String) -> Bool {
        let digits = pin.compactMap { Int(String($0)) }
        guard digits.count >= 3 else { return false }

        for i in 0..<digits.count - 2 {
            let isAscending = (digits[i] + 1 == digits[i + 1]) && (digits[i + 1] + 1 == digits[i + 2])
            let isDescending = (digits[i] - 1 == digits[i + 1]) && (digits[i + 1] - 1 == digits[i + 2])

            if isAscending || isDescending {
                return true
            }
        }

        return false
    }

    private func hasRepeatingDigits(_ pin: String) -> Bool {
        let uniqueDigits = Set(pin)
        return uniqueDigits.count <= 2
    }

    private func generateSalt() -> SymmetricKey? {
        return SymmetricKey(size: .bits256)
    }

    private func hashPIN(_ pin: String, salt: SymmetricKey) -> SymmetricKey? {
        guard let pinData = pin.data(using: .utf8) else { return nil }

        // Extract salt bytes
        let saltData = salt.withUnsafeBytes { Data($0) }

        // Combine PIN and salt
        var combined = pinData
        combined.append(saltData)

        // Hash using SHA256
        let hash = SHA256.hash(data: combined)

        // Use PBKDF2 for additional security (100,000 iterations)
        let passwordData = Data(hash)
        let derived = deriveKey(from: passwordData, salt: saltData, iterations: 100_000)

        return SymmetricKey(data: derived)
    }

    private func deriveKey(from password: Data, salt: Data, iterations: Int) -> Data {
        var derivedKeyData = Data(count: 32) // 256 bits

        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
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
                        32
                    )
                }
            }
        }

        return derivationStatus == kCCSuccess ? derivedKeyData : Data()
    }

    private func constantTimeCompare(_ lhs: SymmetricKey, _ rhs: SymmetricKey) -> Bool {
        let lhsData = lhs.withUnsafeBytes { Data($0) }
        let rhsData = rhs.withUnsafeBytes { Data($0) }

        guard lhsData.count == rhsData.count else { return false }

        var result: UInt8 = 0
        for i in 0..<lhsData.count {
            result |= lhsData[i] ^ rhsData[i]
        }

        return result == 0
    }

    // MARK: - Lock Management

    /// Manually unlock PIN (for testing or admin purposes)
    public func unlock() {
        userDefaults.removeObject(forKey: pinLockTimeKey)
        userDefaults.set(0, forKey: pinAttemptsKey)
    }

    /// Reset failed attempts counter
    public func resetAttempts() {
        userDefaults.set(0, forKey: pinAttemptsKey)
        userDefaults.removeObject(forKey: pinLastAttemptKey)
    }
}

// MARK: - CommonCrypto Import

import CommonCrypto
