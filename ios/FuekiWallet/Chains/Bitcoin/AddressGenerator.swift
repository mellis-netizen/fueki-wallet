//
//  AddressGenerator.swift
//  FuekiWallet
//
//  Production-grade Bitcoin address generation and validation
//

import Foundation
import BitcoinKit
import CryptoSwift

/// Generates and validates Bitcoin addresses
public final class AddressGenerator {

    // MARK: - Properties

    private let network: Network

    // Address prefixes
    private var p2pkhPrefix: UInt8 {
        return network == .mainnet ? 0x00 : 0x6f
    }

    private var p2shPrefix: UInt8 {
        return network == .mainnet ? 0x05 : 0xc4
    }

    private var bech32HRP: String {
        return network == .mainnet ? "bc" : "tb"
    }

    // MARK: - Initialization

    public init(network: Network) {
        self.network = network
    }

    // MARK: - Address Generation

    /// Generate address from private key
    public func generate(privateKey: PrivateKey, type: AddressType) throws -> String {
        let publicKey = privateKey.publicKey()
        return try generate(publicKey: publicKey, type: type)
    }

    /// Generate address from public key
    public func generate(publicKey: PublicKey, type: AddressType) throws -> String {
        switch type {
        case .P2PKH:
            return try generateP2PKH(publicKey: publicKey)
        case .P2WPKH:
            return try generateP2WPKH(publicKey: publicKey)
        case .P2SH_P2WPKH:
            return try generateP2SH_P2WPKH(publicKey: publicKey)
        }
    }

    // MARK: - Address Types

    /// Generate Legacy P2PKH address (1...)
    private func generateP2PKH(publicKey: PublicKey) throws -> String {
        let pubKeyHash = publicKey.pubkeyHash

        var payload = Data([p2pkhPrefix])
        payload.append(pubKeyHash)

        let checksum = calculateChecksum(payload)
        payload.append(checksum)

        return Base58.encode(payload)
    }

    /// Generate Native SegWit P2WPKH address (bc1...)
    private func generateP2WPKH(publicKey: PublicKey) throws -> String {
        let pubKeyHash = publicKey.pubkeyHash

        // Bech32 encoding with witness version 0
        let witnessProgram = [UInt8](pubKeyHash)
        return try Bech32.encode(hrp: bech32HRP, version: 0, program: witnessProgram)
    }

    /// Generate Nested SegWit P2SH-P2WPKH address (3...)
    private func generateP2SH_P2WPKH(publicKey: PublicKey) throws -> String {
        let pubKeyHash = publicKey.pubkeyHash

        // Create witness script
        var witnessScript = Data([0x00, 0x14]) // OP_0 + 20 bytes
        witnessScript.append(pubKeyHash)

        // Hash the witness script
        let scriptHash = witnessScript.sha256().ripemd160()

        var payload = Data([p2shPrefix])
        payload.append(scriptHash)

        let checksum = calculateChecksum(payload)
        payload.append(checksum)

        return Base58.encode(payload)
    }

    // MARK: - Address Validation

    /// Validate Bitcoin address
    public func validate(address: String) -> Bool {
        if address.starts(with: "1") || address.starts(with: "3") {
            return validateLegacyAddress(address)
        } else if address.starts(with: bech32HRP) {
            return validateBech32Address(address)
        }
        return false
    }

    /// Validate legacy address (Base58)
    private func validateLegacyAddress(_ address: String) -> Bool {
        guard let decoded = Base58.decode(address) else {
            return false
        }

        guard decoded.count == 25 else {
            return false
        }

        let payload = decoded.prefix(21)
        let checksum = decoded.suffix(4)

        let calculatedChecksum = calculateChecksum(payload)

        return checksum == calculatedChecksum
    }

    /// Validate Bech32 address
    private func validateBech32Address(_ address: String) -> Bool {
        do {
            let decoded = try Bech32.decode(address)
            return decoded.hrp == bech32HRP && (decoded.version == 0 || decoded.version == 1)
        } catch {
            return false
        }
    }

    /// Determine address type
    public func getAddressType(_ address: String) -> AddressType? {
        if address.starts(with: "1") {
            return .P2PKH
        } else if address.starts(with: "3") {
            return .P2SH_P2WPKH
        } else if address.starts(with: bech32HRP) {
            return .P2WPKH
        }
        return nil
    }

    // MARK: - Script Generation

    /// Get scriptPubKey for address
    public func getScriptPubKey(address: String) throws -> Script {
        guard let type = getAddressType(address) else {
            throw AddressGeneratorError.invalidAddress
        }

        switch type {
        case .P2PKH:
            return try getP2PKHScript(address: address)
        case .P2WPKH:
            return try getP2WPKHScript(address: address)
        case .P2SH_P2WPKH:
            return try getP2SHScript(address: address)
        }
    }

    private func getP2PKHScript(address: String) throws -> Script {
        guard let decoded = Base58.decode(address) else {
            throw AddressGeneratorError.invalidAddress
        }

        let pubKeyHash = decoded.dropFirst().dropLast(4)

        return try Script()
            .append(.OP_DUP)
            .append(.OP_HASH160)
            .appendData(Data(pubKeyHash))
            .append(.OP_EQUALVERIFY)
            .append(.OP_CHECKSIG)
    }

    private func getP2WPKHScript(address: String) throws -> Script {
        let decoded = try Bech32.decode(address)

        return try Script()
            .append(.OP_0)
            .appendData(Data(decoded.program))
    }

    private func getP2SHScript(address: String) throws -> Script {
        guard let decoded = Base58.decode(address) else {
            throw AddressGeneratorError.invalidAddress
        }

        let scriptHash = decoded.dropFirst().dropLast(4)

        return try Script()
            .append(.OP_HASH160)
            .appendData(Data(scriptHash))
            .append(.OP_EQUAL)
    }

    // MARK: - BIP32 Derivation

    /// Derive address from HD path
    public func deriveAddress(
        seed: Data,
        path: String,
        type: AddressType = .P2WPKH
    ) throws -> String {

        let privateKey = try HDPrivateKey(seed: seed, network: network)
        let derivedKey = try privateKey.derived(at: path)

        return try generate(privateKey: derivedKey.key, type: type)
    }

    /// Generate multiple addresses from extended public key
    public func generateAddresses(
        extendedPublicKey: HDPublicKey,
        startIndex: UInt32,
        count: Int,
        change: Bool = false,
        type: AddressType = .P2WPKH
    ) throws -> [String] {

        var addresses: [String] = []
        let changeIndex: UInt32 = change ? 1 : 0

        for i in 0..<count {
            let index = startIndex + UInt32(i)
            let derivedKey = try extendedPublicKey
                .derived(at: changeIndex)
                .derived(at: index)

            let address = try generate(publicKey: derivedKey.key, type: type)
            addresses.append(address)
        }

        return addresses
    }

    // MARK: - Helper Methods

    private func calculateChecksum(_ data: Data) -> Data {
        let hash = data.sha256().sha256()
        return hash.prefix(4)
    }
}

// MARK: - Bech32 Implementation

private struct Bech32 {

    static let charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

    struct DecodedBech32 {
        let hrp: String
        let version: UInt8
        let program: [UInt8]
    }

    static func encode(hrp: String, version: UInt8, program: [UInt8]) throws -> String {
        var data = [version] + convertBits(data: program, fromBits: 8, toBits: 5, pad: true)
        let checksum = createChecksum(hrp: hrp, data: data)
        data.append(contentsOf: checksum)

        var result = hrp + "1"
        for value in data {
            result.append(charset[charset.index(charset.startIndex, offsetBy: Int(value))])
        }

        return result
    }

    static func decode(_ bech32: String) throws -> DecodedBech32 {
        guard let separatorIndex = bech32.lastIndex(of: "1") else {
            throw AddressGeneratorError.invalidBech32
        }

        let hrp = String(bech32[..<separatorIndex])
        let data = String(bech32[bech32.index(after: separatorIndex)...])

        var decoded: [UInt8] = []
        for char in data {
            guard let index = charset.firstIndex(of: char) else {
                throw AddressGeneratorError.invalidBech32
            }
            decoded.append(UInt8(charset.distance(from: charset.startIndex, to: index)))
        }

        guard verifyChecksum(hrp: hrp, data: decoded) else {
            throw AddressGeneratorError.invalidChecksum
        }

        let version = decoded[0]
        let program = convertBits(data: Array(decoded.dropFirst().dropLast(6)), fromBits: 5, toBits: 8, pad: false)

        return DecodedBech32(hrp: hrp, version: version, program: program)
    }

    private static func createChecksum(hrp: String, data: [UInt8]) -> [UInt8] {
        let values = expandHRP(hrp) + data + [0, 0, 0, 0, 0, 0]
        let polymod = calculatePolymod(values) ^ 1

        var checksum: [UInt8] = []
        for i in 0..<6 {
            checksum.append(UInt8((polymod >> (5 * (5 - i))) & 31))
        }
        return checksum
    }

    private static func verifyChecksum(hrp: String, data: [UInt8]) -> Bool {
        let values = expandHRP(hrp) + data
        return calculatePolymod(values) == 1
    }

    private static func expandHRP(_ hrp: String) -> [UInt8] {
        var result: [UInt8] = []
        for char in hrp {
            result.append(UInt8(char.asciiValue! >> 5))
        }
        result.append(0)
        for char in hrp {
            result.append(UInt8(char.asciiValue! & 31))
        }
        return result
    }

    private static func calculatePolymod(_ values: [UInt8]) -> UInt32 {
        var chk: UInt32 = 1
        for value in values {
            let top = chk >> 25
            chk = (chk & 0x1ffffff) << 5 ^ UInt32(value)

            if top & 1 != 0 { chk ^= 0x3b6a57b2 }
            if top & 2 != 0 { chk ^= 0x26508e6d }
            if top & 4 != 0 { chk ^= 0x1ea119fa }
            if top & 8 != 0 { chk ^= 0x3d4233dd }
            if top & 16 != 0 { chk ^= 0x2a1462b3 }
        }
        return chk
    }

    private static func convertBits(data: [UInt8], fromBits: Int, toBits: Int, pad: Bool) -> [UInt8] {
        var acc = 0
        var bits = 0
        var result: [UInt8] = []
        let maxv = (1 << toBits) - 1

        for value in data {
            acc = (acc << fromBits) | Int(value)
            bits += fromBits

            while bits >= toBits {
                bits -= toBits
                result.append(UInt8((acc >> bits) & maxv))
            }
        }

        if pad && bits > 0 {
            result.append(UInt8((acc << (toBits - bits)) & maxv))
        }

        return result
    }
}

// MARK: - Errors

public enum AddressGeneratorError: LocalizedError {
    case invalidAddress
    case invalidBech32
    case invalidChecksum
    case derivationFailed

    public var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid Bitcoin address"
        case .invalidBech32:
            return "Invalid Bech32 encoding"
        case .invalidChecksum:
            return "Invalid address checksum"
        case .derivationFailed:
            return "Failed to derive address"
        }
    }
}
