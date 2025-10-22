import Foundation

/// Bech32 Encoding/Decoding Implementation
/// Implements BIP-173 (Bech32) and BIP-350 (Bech32m) for SegWit addresses
/// Reference: https://github.com/bitcoin/bips/blob/master/bip-0173.mediawiki
public class Bech32 {

    // MARK: - Types

    public enum Encoding {
        case bech32   // BIP-173 (original, for SegWit v0)
        case bech32m  // BIP-350 (for SegWit v1+, Taproot)

        var constant: UInt32 {
            switch self {
            case .bech32: return 1
            case .bech32m: return 0x2bc830a3
            }
        }
    }

    public enum Bech32Error: Error {
        case invalidCharacter
        case invalidChecksum
        case invalidLength
        case invalidHRP
        case invalidWitnessVersion
        case invalidWitnessProgram
        case mixedCase
    }

    // MARK: - Constants

    private static let charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
    private static let generator: [UInt32] = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]

    // MARK: - Public Methods

    /// Encode data using Bech32
    /// - Parameters:
    ///   - hrp: Human-readable part (e.g., "bc" for Bitcoin mainnet)
    ///   - values: 5-bit values to encode
    ///   - encoding: Encoding type (bech32 or bech32m)
    /// - Returns: Bech32-encoded string
    public static func encode(hrp: String, values: [UInt8], encoding: Encoding = .bech32) throws -> String {
        guard hrp.lowercased() == hrp || hrp.uppercased() == hrp else {
            throw Bech32Error.mixedCase
        }

        let checksumValues = createChecksum(hrp: hrp, values: values, encoding: encoding)
        let combined = values + checksumValues

        var result = hrp + "1"
        for value in combined {
            guard value < 32 else {
                throw Bech32Error.invalidCharacter
            }
            let index = charset.index(charset.startIndex, offsetBy: Int(value))
            result.append(charset[index])
        }

        return result
    }

    /// Decode Bech32-encoded string
    /// - Parameter string: Bech32-encoded string
    /// - Returns: Tuple of (hrp, values, encoding)
    public static func decode(_ string: String) throws -> (hrp: String, values: [UInt8], encoding: Encoding) {
        guard string.lowercased() == string || string.uppercased() == string else {
            throw Bech32Error.mixedCase
        }

        let lowercased = string.lowercased()

        guard let separatorIndex = lowercased.lastIndex(of: "1") else {
            throw Bech32Error.invalidHRP
        }

        let hrp = String(lowercased[..<separatorIndex])
        guard !hrp.isEmpty else {
            throw Bech32Error.invalidHRP
        }

        let dataString = lowercased[lowercased.index(after: separatorIndex)...]
        guard dataString.count >= 6 else {
            throw Bech32Error.invalidLength
        }

        var values = [UInt8]()
        for char in dataString {
            guard let index = charset.firstIndex(of: char) else {
                throw Bech32Error.invalidCharacter
            }
            values.append(UInt8(charset.distance(from: charset.startIndex, to: index)))
        }

        // Verify checksum
        let encoding: Encoding
        if verifyChecksum(hrp: hrp, values: values, encoding: .bech32) {
            encoding = .bech32
        } else if verifyChecksum(hrp: hrp, values: values, encoding: .bech32m) {
            encoding = .bech32m
        } else {
            throw Bech32Error.invalidChecksum
        }

        // Remove checksum
        values.removeLast(6)

        return (hrp, values, encoding)
    }

    /// Encode SegWit address
    /// - Parameters:
    ///   - hrp: Human-readable part (e.g., "bc" for mainnet, "tb" for testnet)
    ///   - witnessVersion: Witness version (0-16)
    ///   - witnessProgram: Witness program data
    /// - Returns: Bech32-encoded SegWit address
    public static func encodeSegWitAddress(hrp: String, witnessVersion: UInt8, witnessProgram: Data) throws -> String {
        guard witnessVersion <= 16 else {
            throw Bech32Error.invalidWitnessVersion
        }

        guard witnessProgram.count >= 2 && witnessProgram.count <= 40 else {
            throw Bech32Error.invalidWitnessProgram
        }

        // For version 0, program must be 20 or 32 bytes
        if witnessVersion == 0 {
            guard witnessProgram.count == 20 || witnessProgram.count == 32 else {
                throw Bech32Error.invalidWitnessProgram
            }
        }

        // Convert 8-bit data to 5-bit
        let converted = try convertBits(data: Array(witnessProgram), fromBits: 8, toBits: 5, pad: true)

        var values = [witnessVersion]
        values.append(contentsOf: converted)

        // Use bech32m for witness version 1+, bech32 for version 0
        let encoding: Encoding = witnessVersion == 0 ? .bech32 : .bech32m

        return try encode(hrp: hrp, values: values, encoding: encoding)
    }

    /// Decode SegWit address
    /// - Parameter address: Bech32-encoded SegWit address
    /// - Returns: Tuple of (hrp, witnessVersion, witnessProgram)
    public static func decodeSegWitAddress(_ address: String) throws -> (hrp: String, witnessVersion: UInt8, witnessProgram: Data) {
        let (hrp, values, encoding) = try decode(address)

        guard !values.isEmpty else {
            throw Bech32Error.invalidWitnessVersion
        }

        let witnessVersion = values[0]
        guard witnessVersion <= 16 else {
            throw Bech32Error.invalidWitnessVersion
        }

        // Verify encoding matches witness version
        if witnessVersion == 0 {
            guard encoding == .bech32 else {
                throw Bech32Error.invalidChecksum
            }
        } else {
            guard encoding == .bech32m else {
                throw Bech32Error.invalidChecksum
            }
        }

        // Convert 5-bit data to 8-bit
        let programValues = Array(values.dropFirst())
        let converted = try convertBits(data: programValues, fromBits: 5, toBits: 8, pad: false)

        let witnessProgram = Data(converted)

        // Validate program length
        guard witnessProgram.count >= 2 && witnessProgram.count <= 40 else {
            throw Bech32Error.invalidWitnessProgram
        }

        // For version 0, program must be 20 or 32 bytes
        if witnessVersion == 0 {
            guard witnessProgram.count == 20 || witnessProgram.count == 32 else {
                throw Bech32Error.invalidWitnessProgram
            }
        }

        return (hrp, witnessVersion, witnessProgram)
    }

    // MARK: - Private Helper Methods

    private static func polymod(_ values: [UInt8]) -> UInt32 {
        var chk: UInt32 = 1

        for value in values {
            let top = chk >> 25
            chk = (chk & 0x1ffffff) << 5 ^ UInt32(value)

            for i in 0..<5 {
                if (top >> i) & 1 != 0 {
                    chk ^= generator[i]
                }
            }
        }

        return chk
    }

    private static func hrpExpand(_ hrp: String) -> [UInt8] {
        var result = [UInt8]()

        for char in hrp {
            result.append(UInt8(char.unicodeScalars.first!.value) >> 5)
        }

        result.append(0)

        for char in hrp {
            result.append(UInt8(char.unicodeScalars.first!.value) & 31)
        }

        return result
    }

    private static func createChecksum(hrp: String, values: [UInt8], encoding: Encoding) -> [UInt8] {
        let expanded = hrpExpand(hrp) + values + [0, 0, 0, 0, 0, 0]
        let polymodValue = polymod(expanded) ^ encoding.constant

        var checksum = [UInt8]()
        for i in 0..<6 {
            checksum.append(UInt8((polymodValue >> (5 * (5 - i))) & 31))
        }

        return checksum
    }

    private static func verifyChecksum(hrp: String, values: [UInt8], encoding: Encoding) -> Bool {
        let expanded = hrpExpand(hrp) + values
        return polymod(expanded) == encoding.constant
    }

    private static func convertBits(data: [UInt8], fromBits: Int, toBits: Int, pad: Bool) throws -> [UInt8] {
        var acc: Int = 0
        var bits: Int = 0
        var result = [UInt8]()
        let maxv: Int = (1 << toBits) - 1

        for value in data {
            guard Int(value) >> fromBits == 0 else {
                throw Bech32Error.invalidCharacter
            }

            acc = (acc << fromBits) | Int(value)
            bits += fromBits

            while bits >= toBits {
                bits -= toBits
                result.append(UInt8((acc >> bits) & maxv))
            }
        }

        if pad {
            if bits > 0 {
                result.append(UInt8((acc << (toBits - bits)) & maxv))
            }
        } else {
            guard bits < fromBits else {
                throw Bech32Error.invalidCharacter
            }
            guard (acc << (toBits - bits)) & maxv == 0 else {
                throw Bech32Error.invalidCharacter
            }
        }

        return result
    }
}
