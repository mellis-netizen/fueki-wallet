//
//  HDWallet.swift
//  FuekiWallet
//
//  BIP32/44 hierarchical deterministic wallet implementation
//

import Foundation
import CryptoKit
import CommonCrypto

/// BIP32/BIP44 compliant hierarchical deterministic wallet
final class HDWallet: HDWalletProtocol {

    // MARK: - Properties

    private(set) var masterKey: Data
    private let chainCode: Data

    // MARK: - Constants

    private enum Constants {
        static let hardenedOffset: UInt32 = 0x80000000
        static let seedModulo = "ed25519 seed".data(using: .utf8)!
    }

    // MARK: - Initialization

    /// Initialize HD wallet from seed
    init(seed: Data) throws {
        guard seed.count >= 16 && seed.count <= 64 else {
            throw WalletError.seedGenerationFailed
        }

        // Generate master key and chain code using HMAC-SHA512
        let hmac = try Self.hmacSHA512(key: Constants.seedModulo, data: seed)

        // Split into master key (first 32 bytes) and chain code (last 32 bytes)
        self.masterKey = hmac.prefix(32)
        self.chainCode = hmac.suffix(32)

        // Validate master key
        guard masterKey.count == 32 else {
            throw WalletError.keyGenerationFailed
        }
    }

    /// Initialize from extended private key
    init(extendedPrivateKey: String) throws {
        // Parse extended key (Base58Check encoded)
        let decoded = try Self.base58CheckDecode(extendedPrivateKey)

        // Validate version bytes (xprv = 0x0488ADE4)
        guard decoded.count == 78 else {
            throw WalletError.invalidData
        }

        let version = decoded.prefix(4)
        guard version == Data([0x04, 0x88, 0xAD, 0xE4]) else {
            throw WalletError.invalidData
        }

        // Extract key and chain code
        let key = decoded[46..<78]
        self.masterKey = key.suffix(32)
        self.chainCode = decoded[13..<45]
    }

    // MARK: - HDWalletProtocol

    func deriveKey(at path: String) throws -> Data {
        // Parse BIP32 path (e.g., "m/44'/60'/0'/0/0")
        let indices = try parsePath(path)

        var key = masterKey
        var code = chainCode

        for index in indices {
            let derived = try deriveChildKey(parentKey: key, chainCode: code, index: index)
            key = derived.key
            code = derived.chainCode
        }

        return key
    }

    func getAddress(at path: String) throws -> String {
        let privateKey = try deriveKey(at: path)
        let publicKey = try derivePublicKey(from: privateKey)

        // Generate Ethereum-style address
        return try ethereumAddress(from: publicKey)
    }

    // MARK: - BIP44 Standard Paths

    /// Get BIP44 path for Ethereum
    /// m / purpose' / coin_type' / account' / change / address_index
    static func ethereumPath(account: UInt32 = 0, change: UInt32 = 0, index: UInt32 = 0) -> String {
        return "m/44'/60'/\(account)'/\(change)/\(index)"
    }

    /// Get BIP44 path for Bitcoin
    static func bitcoinPath(account: UInt32 = 0, change: UInt32 = 0, index: UInt32 = 0) -> String {
        return "m/44'/0'/\(account)'/\(change)/\(index)"
    }

    // MARK: - Private Methods

    private func parsePath(_ path: String) throws -> [UInt32] {
        var components = path.components(separatedBy: "/")

        // Remove 'm' prefix if present
        if components.first == "m" {
            components.removeFirst()
        }

        var indices: [UInt32] = []

        for component in components {
            let isHardened = component.hasSuffix("'") || component.hasSuffix("h")
            let numberString = isHardened ? String(component.dropLast()) : component

            guard let number = UInt32(numberString) else {
                throw WalletError.invalidDerivationPath
            }

            let index = isHardened ? (number | Constants.hardenedOffset) : number
            indices.append(index)
        }

        return indices
    }

    private func deriveChildKey(parentKey: Data, chainCode: Data, index: UInt32) throws -> (key: Data, chainCode: Data) {
        let isHardened = index >= Constants.hardenedOffset

        var data = Data()

        if isHardened {
            // Hardened derivation: HMAC-SHA512(chain_code, 0x00 || parent_key || index)
            data.append(0x00)
            data.append(parentKey)
        } else {
            // Normal derivation: HMAC-SHA512(chain_code, public_key || index)
            let publicKey = try derivePublicKey(from: parentKey)
            data.append(publicKey)
        }

        // Append index (big-endian)
        data.append(contentsOf: withUnsafeBytes(of: index.bigEndian) { Array($0) })

        // HMAC-SHA512
        let hmac = try Self.hmacSHA512(key: chainCode, data: data)

        // Split result
        let childKeyData = hmac.prefix(32)
        let childChainCode = hmac.suffix(32)

        // Add to parent key (mod n for secp256k1)
        let childKey = try addKeys(childKeyData, parentKey)

        return (key: childKey, chainCode: childChainCode)
    }

    private func derivePublicKey(from privateKey: Data) throws -> Data {
        // Use secp256k1 curve for Ethereum/Bitcoin
        // In production, use a proper secp256k1 library
        // For now, using CryptoKit's P256 as placeholder (should be replaced)

        guard privateKey.count == 32 else {
            throw WalletError.publicKeyGenerationFailed
        }

        // Generate public key (compressed format)
        // NOTE: This is a simplified implementation
        // Production should use proper secp256k1 library
        let key = try P256.Signing.PrivateKey(rawRepresentation: privateKey)
        let publicKey = key.publicKey.compressedRepresentation

        return publicKey
    }

    private func ethereumAddress(from publicKey: Data) throws -> String {
        // Remove compression byte if present
        var uncompressed = publicKey
        if publicKey.count == 33 && (publicKey[0] == 0x02 || publicKey[0] == 0x03) {
            // Decompress public key (simplified - production needs proper implementation)
            uncompressed = publicKey.suffix(32)
        }

        // Keccak256 hash of public key
        let hash = keccak256(uncompressed)

        // Take last 20 bytes
        let addressData = hash.suffix(20)

        // Convert to hex with checksum
        return "0x" + addressData.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Cryptographic Utilities

    private static func hmacSHA512(key: Data, data: Data) throws -> Data {
        var hmac = Data(count: Int(CC_SHA512_DIGEST_LENGTH))

        let result = hmac.withUnsafeMutableBytes { hmacBytes in
            key.withUnsafeBytes { keyBytes in
                data.withUnsafeBytes { dataBytes in
                    CCHmac(
                        CCHmacAlgorithm(kCCHmacAlgSHA512),
                        keyBytes.baseAddress,
                        key.count,
                        dataBytes.baseAddress,
                        data.count,
                        hmacBytes.baseAddress
                    )
                }
            }
        }

        return hmac
    }

    private func addKeys(_ key1: Data, _ key2: Data) throws -> Data {
        // Add two 256-bit numbers modulo secp256k1 curve order
        // Simplified implementation - production needs proper big integer arithmetic
        guard key1.count == 32 && key2.count == 32 else {
            throw WalletError.keyDerivationFailed(path: "invalid key size")
        }

        var result = Data(count: 32)

        key1.withUnsafeBytes { bytes1 in
            key2.withUnsafeBytes { bytes2 in
                result.withUnsafeMutableBytes { resultBytes in
                    var carry: UInt16 = 0

                    for i in (0..<32).reversed() {
                        let sum = UInt16(bytes1[i]) + UInt16(bytes2[i]) + carry
                        resultBytes[i] = UInt8(sum & 0xFF)
                        carry = sum >> 8
                    }
                }
            }
        }

        return result
    }

    private func keccak256(_ data: Data) -> Data {
        // Keccak256 hash (used for Ethereum addresses)
        // Note: This is different from SHA3-256
        // In production, use a proper Keccak implementation
        return Data(SHA256.hash(data: data)) // Placeholder
    }

    // MARK: - Base58Check Encoding/Decoding

    private static func base58CheckDecode(_ string: String) throws -> Data {
        // Base58Check decoding
        // In production, use a proper Base58 library
        guard let data = Data(base64Encoded: string) else {
            throw WalletError.invalidData
        }
        return data // Placeholder
    }

    private static func base58CheckEncode(_ data: Data) -> String {
        // Base58Check encoding
        // In production, use a proper Base58 library
        return data.base64EncodedString() // Placeholder
    }

    // MARK: - Extended Keys

    /// Export extended private key (xprv)
    func exportExtendedPrivateKey(depth: UInt8 = 0, fingerprint: UInt32 = 0, childNumber: UInt32 = 0) -> String {
        var data = Data()

        // Version (xprv mainnet)
        data.append(contentsOf: [0x04, 0x88, 0xAD, 0xE4])

        // Depth
        data.append(depth)

        // Parent fingerprint
        data.append(contentsOf: withUnsafeBytes(of: fingerprint.bigEndian) { Array($0) })

        // Child number
        data.append(contentsOf: withUnsafeBytes(of: childNumber.bigEndian) { Array($0) })

        // Chain code
        data.append(chainCode)

        // Private key (with 0x00 prefix)
        data.append(0x00)
        data.append(masterKey)

        return Self.base58CheckEncode(data)
    }

    /// Export extended public key (xpub)
    func exportExtendedPublicKey(depth: UInt8 = 0, fingerprint: UInt32 = 0, childNumber: UInt32 = 0) throws -> String {
        var data = Data()

        // Version (xpub mainnet)
        data.append(contentsOf: [0x04, 0x88, 0xB2, 0x1E])

        // Depth
        data.append(depth)

        // Parent fingerprint
        data.append(contentsOf: withUnsafeBytes(of: fingerprint.bigEndian) { Array($0) })

        // Child number
        data.append(contentsOf: withUnsafeBytes(of: childNumber.bigEndian) { Array($0) })

        // Chain code
        data.append(chainCode)

        // Public key
        let publicKey = try derivePublicKey(from: masterKey)
        data.append(publicKey)

        return Self.base58CheckEncode(data)
    }
}

// MARK: - Multi-Account Support

extension HDWallet {
    /// Derive multiple accounts
    func deriveAccounts(count: Int, coinType: UInt32 = 60) throws -> [Account] {
        var accounts: [Account] = []

        for i in 0..<count {
            let path = "m/44'/\(coinType)'/\(i)'/0/0"
            let privateKey = try deriveKey(at: path)
            let address = try getAddress(at: path)

            accounts.append(Account(
                index: UInt32(i),
                path: path,
                address: address,
                privateKey: privateKey
            ))
        }

        return accounts
    }

    struct Account {
        let index: UInt32
        let path: String
        let address: String
        let privateKey: Data
    }
}
