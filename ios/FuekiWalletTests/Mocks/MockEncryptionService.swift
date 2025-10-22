//
//  MockEncryptionService.swift
//  FuekiWalletTests
//
//  Mock encryption service for cryptography testing
//

import Foundation
@testable import FuekiWallet

final class MockEncryptionService {

    // MARK: - Mock Data

    var mockSalt: Data = Data(repeating: 0x01, count: 32)
    var mockEncryptionKey: Data = Data(repeating: 0x02, count: 32)
    var mockEncryptedData: Data = Data(repeating: 0x03, count: 64)
    var mockDecryptedData: Data = Data(repeating: 0x04, count: 32)

    // MARK: - Call Tracking

    var generateSaltCalled = false
    var deriveKeyCalled = false
    var encryptCalled = false
    var decryptCalled = false

    // MARK: - Failure Flags

    var shouldFailGenerateSalt = false
    var shouldFailDeriveKey = false
    var shouldFailEncryption = false
    var shouldFailDecryption = false

    // MARK: - Methods

    func generateSalt() throws -> Data {
        generateSaltCalled = true

        if shouldFailGenerateSalt {
            throw EncryptionError.saltGenerationFailed
        }

        return mockSalt
    }

    func deriveKey(from password: String, salt: Data) throws -> Data {
        deriveKeyCalled = true

        if shouldFailDeriveKey {
            throw EncryptionError.keyDerivationFailed
        }

        return mockEncryptionKey
    }

    func encrypt(_ data: Data, withKey key: Data) throws -> Data {
        encryptCalled = true

        if shouldFailEncryption {
            throw EncryptionError.encryptionFailed
        }

        return mockEncryptedData
    }

    func decrypt(_ data: Data, withKey key: Data) throws -> Data {
        decryptCalled = true

        if shouldFailDecryption {
            throw EncryptionError.decryptionFailed
        }

        return mockDecryptedData
    }

    // MARK: - Helper Methods

    func reset() {
        mockSalt = Data(repeating: 0x01, count: 32)
        mockEncryptionKey = Data(repeating: 0x02, count: 32)
        mockEncryptedData = Data(repeating: 0x03, count: 64)
        mockDecryptedData = Data(repeating: 0x04, count: 32)

        generateSaltCalled = false
        deriveKeyCalled = false
        encryptCalled = false
        decryptCalled = false

        shouldFailGenerateSalt = false
        shouldFailDeriveKey = false
        shouldFailEncryption = false
        shouldFailDecryption = false
    }
}

enum EncryptionError: Error {
    case saltGenerationFailed
    case keyDerivationFailed
    case encryptionFailed
    case decryptionFailed
}
