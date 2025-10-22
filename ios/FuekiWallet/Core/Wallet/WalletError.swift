//
//  WalletError.swift
//  FuekiWallet
//
//  Comprehensive error handling for wallet operations
//

import Foundation

/// Comprehensive error types for wallet operations
enum WalletError: LocalizedError {
    // MARK: - Initialization Errors
    case initializationFailed(String)
    case walletAlreadyExists
    case walletNotFound

    // MARK: - Mnemonic Errors
    case invalidMnemonic
    case invalidMnemonicWordCount
    case invalidMnemonicChecksum
    case mnemonicGenerationFailed
    case invalidMnemonicLanguage

    // MARK: - Key Management Errors
    case keyGenerationFailed
    case keyDerivationFailed(path: String)
    case invalidDerivationPath
    case privateKeyNotFound
    case publicKeyGenerationFailed
    case seedGenerationFailed

    // MARK: - Secure Enclave Errors
    case secureEnclaveNotAvailable
    case secureEnclaveOperationFailed(String)
    case secureEnclaveKeyGenerationFailed

    // MARK: - Keychain Errors
    case keychainSaveFailed(OSStatus)
    case keychainLoadFailed(OSStatus)
    case keychainDeleteFailed(OSStatus)
    case keychainAccessDenied
    case keychainItemNotFound

    // MARK: - Encryption Errors
    case encryptionFailed
    case decryptionFailed
    case invalidEncryptionKey
    case invalidCiphertext
    case invalidNonce
    case invalidTag

    // MARK: - Biometric Errors
    case biometricNotAvailable
    case biometricNotEnrolled
    case biometricAuthenticationFailed
    case biometricLockout
    case biometricCancelled

    // MARK: - Backup/Restore Errors
    case backupFailed(String)
    case restoreFailed(String)
    case invalidBackupData
    case backupDecryptionFailed

    // MARK: - Security Errors
    case jailbreakDetected
    case securityCheckFailed(String)
    case rateLimitExceeded
    case passwordTooWeak
    case invalidPassword
    case authenticationAttemptsExceeded

    // MARK: - Data Errors
    case invalidData
    case corruptedData
    case serializationFailed
    case deserializationFailed

    // MARK: - Network Errors
    case networkUnavailable
    case serverError(Int)
    case requestFailed(String)

    // MARK: - LocalizedError Implementation
    var errorDescription: String? {
        switch self {
        // Initialization
        case .initializationFailed(let reason):
            return "Wallet initialization failed: \(reason)"
        case .walletAlreadyExists:
            return "A wallet already exists. Please delete the existing wallet before creating a new one."
        case .walletNotFound:
            return "No wallet found. Please create a new wallet."

        // Mnemonic
        case .invalidMnemonic:
            return "Invalid mnemonic phrase. Please check your recovery phrase."
        case .invalidMnemonicWordCount:
            return "Invalid mnemonic word count. Expected 12, 15, 18, 21, or 24 words."
        case .invalidMnemonicChecksum:
            return "Invalid mnemonic checksum. The recovery phrase is corrupted."
        case .mnemonicGenerationFailed:
            return "Failed to generate mnemonic phrase. Please try again."
        case .invalidMnemonicLanguage:
            return "Invalid mnemonic language. Only English is currently supported."

        // Key Management
        case .keyGenerationFailed:
            return "Failed to generate cryptographic keys."
        case .keyDerivationFailed(let path):
            return "Failed to derive key at path: \(path)"
        case .invalidDerivationPath:
            return "Invalid BIP32 derivation path format."
        case .privateKeyNotFound:
            return "Private key not found in secure storage."
        case .publicKeyGenerationFailed:
            return "Failed to generate public key from private key."
        case .seedGenerationFailed:
            return "Failed to generate seed from mnemonic."

        // Secure Enclave
        case .secureEnclaveNotAvailable:
            return "Secure Enclave is not available on this device."
        case .secureEnclaveOperationFailed(let reason):
            return "Secure Enclave operation failed: \(reason)"
        case .secureEnclaveKeyGenerationFailed:
            return "Failed to generate key in Secure Enclave."

        // Keychain
        case .keychainSaveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        case .keychainLoadFailed(let status):
            return "Failed to load from Keychain (status: \(status))"
        case .keychainDeleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        case .keychainAccessDenied:
            return "Keychain access denied. Please check app permissions."
        case .keychainItemNotFound:
            return "Requested item not found in Keychain."

        // Encryption
        case .encryptionFailed:
            return "Failed to encrypt data."
        case .decryptionFailed:
            return "Failed to decrypt data. The password may be incorrect."
        case .invalidEncryptionKey:
            return "Invalid encryption key."
        case .invalidCiphertext:
            return "Invalid encrypted data."
        case .invalidNonce:
            return "Invalid encryption nonce."
        case .invalidTag:
            return "Invalid authentication tag."

        // Biometric
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device."
        case .biometricNotEnrolled:
            return "No biometric credentials enrolled. Please set up Face ID or Touch ID."
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed. Please try again."
        case .biometricLockout:
            return "Too many failed attempts. Biometric authentication is locked."
        case .biometricCancelled:
            return "Biometric authentication was cancelled."

        // Backup/Restore
        case .backupFailed(let reason):
            return "Backup failed: \(reason)"
        case .restoreFailed(let reason):
            return "Restore failed: \(reason)"
        case .invalidBackupData:
            return "Invalid backup data format."
        case .backupDecryptionFailed:
            return "Failed to decrypt backup. The password may be incorrect."

        // Security
        case .jailbreakDetected:
            return "Security risk detected. This app cannot run on jailbroken devices."
        case .securityCheckFailed(let reason):
            return "Security check failed: \(reason)"
        case .rateLimitExceeded:
            return "Too many requests. Please wait before trying again."
        case .passwordTooWeak:
            return "Password does not meet security requirements."
        case .invalidPassword:
            return "Invalid password."
        case .authenticationAttemptsExceeded:
            return "Too many failed authentication attempts. Please try again later."

        // Data
        case .invalidData:
            return "Invalid data format."
        case .corruptedData:
            return "Data is corrupted and cannot be read."
        case .serializationFailed:
            return "Failed to serialize data."
        case .deserializationFailed:
            return "Failed to deserialize data."

        // Network
        case .networkUnavailable:
            return "Network is unavailable. Please check your connection."
        case .serverError(let code):
            return "Server error (code: \(code))"
        case .requestFailed(let reason):
            return "Request failed: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .walletAlreadyExists:
            return "Use the existing wallet or delete it to create a new one."
        case .walletNotFound:
            return "Create a new wallet or restore from a backup."
        case .invalidMnemonic, .invalidMnemonicChecksum:
            return "Verify your recovery phrase and try again."
        case .biometricNotEnrolled:
            return "Enable Face ID or Touch ID in device settings."
        case .biometricLockout:
            return "Wait a few minutes or authenticate with your passcode."
        case .jailbreakDetected:
            return "For your security, restore your device to factory settings."
        case .authenticationAttemptsExceeded:
            return "Wait 5 minutes before attempting to authenticate again."
        case .passwordTooWeak:
            return "Use at least 8 characters with numbers and special characters."
        default:
            return nil
        }
    }
}

// MARK: - Result Type Extension
extension Result where Failure == WalletError {
    var errorDescription: String? {
        switch self {
        case .failure(let error):
            return error.errorDescription
        case .success:
            return nil
        }
    }
}
