import Foundation
import CryptoKit

/// Keccak-256 hash implementation for Ethereum
/// NOTE: Keccak-256 is different from SHA3-256
/// Ethereum uses the original Keccak algorithm, not the final NIST SHA-3

public struct Keccak256 {

    // MARK: - Constants

    private static let KECCAK_ROUNDS = 24
    private static let KECCAK_RATE = 136 // 1088 bits = 136 bytes for Keccak-256
    private static let KECCAK_CAPACITY = 64 // 512 bits = 64 bytes
    private static let KECCAK_STATE_SIZE = 200 // 1600 bits = 200 bytes

    // Round constants for Keccak-f[1600]
    private static let RC: [UInt64] = [
        0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
        0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
        0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
        0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
        0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
        0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008
    ]

    // Rotation offsets
    private static let ROTATIONS: [[Int]] = [
        [  0, 36,  3, 41, 18 ],
        [  1, 44, 10, 45,  2 ],
        [ 62,  6, 43, 15, 61 ],
        [ 28, 55, 25, 21, 56 ],
        [ 27, 20, 39,  8, 14 ]
    ]

    // MARK: - Public Interface

    /// Compute Keccak-256 hash of data
    /// - Parameter data: Input data
    /// - Returns: 32-byte Keccak-256 hash
    public static func hash(_ data: Data) -> Data {
        var state = [UInt64](repeating: 0, count: 25) // 1600 bits / 64 = 25 lanes

        // Absorb phase
        var offset = 0
        let rateInLanes = KECCAK_RATE / 8

        while offset + KECCAK_RATE <= data.count {
            // XOR block into state
            for i in 0..<rateInLanes {
                let byte = data[offset + i * 8..<offset + (i + 1) * 8]
                state[i] ^= UInt64(littleEndian: byte.withUnsafeBytes { $0.load(as: UInt64.self) })
            }

            // Apply permutation
            keccakF1600(&state)
            offset += KECCAK_RATE
        }

        // Handle last block with padding
        var lastBlock = [UInt8](repeating: 0, count: KECCAK_RATE)
        let remaining = data.count - offset
        data[offset..<data.count].copyBytes(to: &lastBlock, count: remaining)

        // Keccak padding: append 0x01, then zeros, then 0x80 at end
        lastBlock[remaining] = 0x01
        lastBlock[KECCAK_RATE - 1] |= 0x80

        // XOR last block into state
        for i in 0..<rateInLanes {
            let start = i * 8
            let end = start + 8
            let bytes = Data(lastBlock[start..<end])
            state[i] ^= UInt64(littleEndian: bytes.withUnsafeBytes { $0.load(as: UInt64.self) })
        }

        // Final permutation
        keccakF1600(&state)

        // Squeeze phase - extract first 32 bytes (256 bits)
        var output = Data(count: 32)
        for i in 0..<4 { // 4 lanes * 8 bytes = 32 bytes
            let lane = state[i].littleEndian
            withUnsafeBytes(of: lane) { bytes in
                output.replaceSubrange(i * 8..<(i + 1) * 8, with: bytes)
            }
        }

        return output
    }

    /// Compute Keccak-256 hash of string (UTF-8 encoded)
    /// - Parameter string: Input string
    /// - Returns: 32-byte Keccak-256 hash
    public static func hash(_ string: String) -> Data {
        guard let data = string.data(using: .utf8) else {
            return Data(count: 32)
        }
        return hash(data)
    }

    /// Compute Keccak-256 and return as hex string
    /// - Parameter data: Input data
    /// - Returns: Hex string (64 characters)
    public static func hashToHex(_ data: Data) -> String {
        return hash(data).hexString
    }

    // MARK: - Keccak-f[1600] Permutation

    private static func keccakF1600(_ state: inout [UInt64]) {
        for round in 0..<KECCAK_ROUNDS {
            // θ (theta) step
            var c = [UInt64](repeating: 0, count: 5)
            for x in 0..<5 {
                c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20]
            }

            var d = [UInt64](repeating: 0, count: 5)
            for x in 0..<5 {
                d[x] = c[(x + 4) % 5] ^ rotateLeft(c[(x + 1) % 5], by: 1)
            }

            for x in 0..<5 {
                for y in 0..<5 {
                    state[x + 5 * y] ^= d[x]
                }
            }

            // ρ (rho) and π (pi) steps
            var b = [UInt64](repeating: 0, count: 25)
            for x in 0..<5 {
                for y in 0..<5 {
                    let rotation = ROTATIONS[x][y]
                    let newX = y
                    let newY = (2 * x + 3 * y) % 5
                    b[newX + 5 * newY] = rotateLeft(state[x + 5 * y], by: rotation)
                }
            }

            // χ (chi) step
            for y in 0..<5 {
                var t = [UInt64](repeating: 0, count: 5)
                for x in 0..<5 {
                    t[x] = b[x + 5 * y]
                }
                for x in 0..<5 {
                    state[x + 5 * y] = t[x] ^ ((~t[(x + 1) % 5]) & t[(x + 2) % 5])
                }
            }

            // ι (iota) step
            state[0] ^= RC[round]
        }
    }

    private static func rotateLeft(_ value: UInt64, by amount: Int) -> UInt64 {
        return (value << amount) | (value >> (64 - amount))
    }
}

// MARK: - Data Extension

extension Data {
    /// Compute Keccak-256 hash
    public func keccak256() -> Data {
        return Keccak256.hash(self)
    }

    /// Compute Keccak-256 and return as hex string
    public func keccak256Hex() -> String {
        return Keccak256.hashToHex(self)
    }

    /// Convert to hex string
    public var hexString: String {
        return self.map { String(format: "%02x", $0) }.joined()
    }

    /// Create Data from hex string
    public init?(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "0x", with: "")
        guard cleaned.count % 2 == 0 else { return nil }

        var data = Data(capacity: cleaned.count / 2)
        var index = cleaned.startIndex

        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            let byteString = cleaned[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }

        self = data
    }
}

// MARK: - Ethereum Address Utilities

extension Keccak256 {

    /// Derive Ethereum address from public key
    /// - Parameter publicKey: 64-byte uncompressed public key (without 0x04 prefix)
    /// - Returns: 20-byte Ethereum address
    public static func ethereumAddress(from publicKey: Data) -> Data {
        var pubKey = publicKey

        // Remove 0x04 prefix if present
        if pubKey.count == 65 && pubKey[0] == 0x04 {
            pubKey = pubKey.dropFirst()
        }

        guard pubKey.count == 64 else {
            return Data(count: 20)
        }

        // Keccak-256 hash of public key
        let hash = Keccak256.hash(pubKey)

        // Take last 20 bytes
        return hash.suffix(20)
    }

    /// Derive checksummed Ethereum address (EIP-55)
    /// - Parameter address: 20-byte Ethereum address
    /// - Returns: Checksummed address string (0x prefixed)
    public static func checksumAddress(_ address: Data) -> String {
        guard address.count == 20 else {
            return "0x" + address.hexString
        }

        let hex = address.hexString.lowercased()
        let hash = Keccak256.hash(hex).hexString

        var checksummed = "0x"
        for (i, char) in hex.enumerated() {
            let hashChar = hash[hash.index(hash.startIndex, offsetBy: i)]
            if let hashValue = Int(String(hashChar), radix: 16), hashValue >= 8 {
                checksummed.append(char.uppercased())
            } else {
                checksummed.append(char)
            }
        }

        return checksummed
    }

    /// Validate EIP-55 checksummed address
    /// - Parameter address: Address string to validate
    /// - Returns: True if checksum is valid
    public static func isValidChecksumAddress(_ address: String) -> Bool {
        let cleaned = address.replacingOccurrences(of: "0x", with: "")
        guard cleaned.count == 40 else { return false }

        // If all lowercase or all uppercase, skip checksum validation
        if cleaned == cleaned.lowercased() || cleaned == cleaned.uppercased() {
            return true
        }

        // Validate checksum
        guard let addressData = Data(hex: cleaned) else { return false }
        let expected = checksumAddress(addressData)

        return "0x" + cleaned == expected
    }
}
