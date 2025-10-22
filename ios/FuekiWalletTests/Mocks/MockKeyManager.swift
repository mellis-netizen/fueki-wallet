import Foundation
@testable import FuekiWallet

final class MockKeyManager: KeyManagerProtocol {

    // MARK: - Mock Data

    var mockPrivateKey: Data?
    var mockPublicKey: Data?
    var mockAddress: String?
    var mockMnemonic: String?
    var mockSignature: Data?
    var mockSeed: Data?

    // MARK: - Behavior Flags

    var shouldFailKeyGeneration = false
    var shouldValidateMnemonic = true
    var shouldDecryptSuccessfully = true

    // MARK: - Call Tracking

    var generatePrivateKeyWasCalled = false
    var derivePublicKeyWasCalled = false
    var deriveAddressWasCalled = false
    var signWasCalled = false
    var verifyWasCalled = false
    var encryptWasCalled = false
    var decryptWasCalled = false
    var storeWasCalled = false
    var retrieveWasCalled = false
    var deleteWasCalled = false
    var clearKeysWasCalled = false

    var lastPasswordUsed: String?
    var lastSignedMessage: Data?

    // MARK: - KeyManagerProtocol Implementation

    func generatePrivateKey() throws -> Data {
        generatePrivateKeyWasCalled = true

        if shouldFailKeyGeneration {
            throw CryptoError.keyGenerationFailed
        }

        return mockPrivateKey ?? Data(repeating: 0x01, count: 32)
    }

    func derivePublicKey(from privateKey: Data) throws -> Data {
        derivePublicKeyWasCalled = true

        if privateKey.count != 32 {
            throw CryptoError.invalidKeySize
        }

        return mockPublicKey ?? Data(repeating: 0x02, count: 33)
    }

    func deriveAddress(
        from publicKey: Data,
        network: BitcoinNetwork,
        format: AddressFormat
    ) throws -> String {
        deriveAddressWasCalled = true

        if let address = mockAddress {
            return address
        }

        let prefix = network == .testnet ? "tb1q" : "bc1q"
        return "\(prefix)test123456789"
    }

    func validateAddress(_ address: String, network: BitcoinNetwork) -> Bool {
        let prefix = network == .testnet ? "tb1" : "bc1"
        return address.starts(with: prefix)
    }

    func sign(_ message: Data, with privateKey: Data) throws -> Data {
        signWasCalled = true
        lastSignedMessage = message

        if let signature = mockSignature {
            return signature
        }

        return Data(repeating: 0x03, count: 64)
    }

    func verifySignature(
        _ signature: Data,
        for message: Data,
        publicKey: Data
    ) throws -> Bool {
        verifyWasCalled = true

        // Simple mock verification
        return signature.count == 64
    }

    func encryptPrivateKey(_ privateKey: Data, password: String) throws -> Data {
        encryptWasCalled = true
        lastPasswordUsed = password

        if password.isEmpty || password.count < 8 {
            throw CryptoError.weakPassword
        }

        // Mock encryption - just combine data
        var encrypted = Data()
        encrypted.append(Data("IV".utf8)) // Mock IV
        encrypted.append(privateKey)
        encrypted.append(Data("MAC".utf8)) // Mock MAC
        return encrypted
    }

    func decryptPrivateKey(_ encryptedData: Data, password: String) throws -> Data {
        decryptWasCalled = true
        lastPasswordUsed = password

        if !shouldDecryptSuccessfully {
            throw CryptoError.decryptionFailed
        }

        // Mock decryption - extract private key from mock encrypted data
        if encryptedData.count > 40 {
            return Data(encryptedData[2..<34])
        }

        return mockPrivateKey ?? Data(repeating: 0x01, count: 32)
    }

    func storePrivateKey(_ privateKey: Data, password: String) throws {
        storeWasCalled = true
        lastPasswordUsed = password
        mockPrivateKey = privateKey
    }

    func retrievePrivateKey(password: String) throws -> Data {
        retrieveWasCalled = true
        lastPasswordUsed = password

        guard let key = mockPrivateKey else {
            throw KeyManagerError.keyNotFound
        }

        return key
    }

    func deletePrivateKey() throws {
        deleteWasCalled = true
        mockPrivateKey = nil
    }

    func deriveKey(from seed: Data, path: String) throws -> Data {
        if path.isEmpty || !path.starts(with: "m/") {
            throw CryptoError.invalidPath
        }

        return Data(repeating: 0x05, count: 32)
    }

    func clearSensitiveData(_ data: inout Data) {
        clearKeysWasCalled = true
        data = Data(repeating: 0, count: data.count)
    }

    func encrypt(_ data: Data, password: String) throws -> Data {
        encryptWasCalled = true
        return try encryptPrivateKey(data, password: password)
    }

    func decrypt(_ encryptedData: Data, password: String) throws -> Data {
        decryptWasCalled = true
        return try decryptPrivateKey(encryptedData, password: password)
    }

    // MARK: - Helper Methods

    func reset() {
        mockPrivateKey = nil
        mockPublicKey = nil
        mockAddress = nil
        mockMnemonic = nil
        mockSignature = nil
        mockSeed = nil

        shouldFailKeyGeneration = false
        shouldValidateMnemonic = true
        shouldDecryptSuccessfully = true

        generatePrivateKeyWasCalled = false
        derivePublicKeyWasCalled = false
        deriveAddressWasCalled = false
        signWasCalled = false
        verifyWasCalled = false
        encryptWasCalled = false
        decryptWasCalled = false
        storeWasCalled = false
        retrieveWasCalled = false
        deleteWasCalled = false
        clearKeysWasCalled = false

        lastPasswordUsed = nil
        lastSignedMessage = nil
    }
}
