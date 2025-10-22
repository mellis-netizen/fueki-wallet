import Foundation
import CommonCrypto

// MARK: - RLP Encoder
struct RLPEncoder {
    static func encode(_ item: Any) throws -> Data {
        if let data = item as? Data {
            return encodeData(data)
        } else if let string = item as? String {
            guard let data = string.data(using: .utf8) else {
                throw RLPError.invalidInput
            }
            return encodeData(data)
        } else if let number = item as? Int {
            return encodeInt(number)
        } else if let number = item as? UInt64 {
            return encodeUInt64(number)
        } else if let array = item as? [Any] {
            return try encodeList(array)
        } else {
            throw RLPError.unsupportedType
        }
    }

    private static func encodeData(_ data: Data) -> Data {
        if data.count == 1 && data[0] < 0x80 {
            return data
        } else if data.count <= 55 {
            return Data([UInt8(0x80 + data.count)]) + data
        } else {
            let lengthData = encodeLength(data.count)
            return Data([UInt8(0xb7 + lengthData.count)]) + lengthData + data
        }
    }

    private static func encodeInt(_ value: Int) -> Data {
        if value == 0 {
            return Data([0x80])
        }

        var bytes: [UInt8] = []
        var val = value

        while val > 0 {
            bytes.insert(UInt8(val & 0xff), at: 0)
            val >>= 8
        }

        return encodeData(Data(bytes))
    }

    private static func encodeUInt64(_ value: UInt64) -> Data {
        if value == 0 {
            return Data([0x80])
        }

        var bytes: [UInt8] = []
        var val = value

        while val > 0 {
            bytes.insert(UInt8(val & 0xff), at: 0)
            val >>= 8
        }

        return encodeData(Data(bytes))
    }

    private static func encodeList(_ items: [Any]) throws -> Data {
        var payload = Data()

        for item in items {
            payload.append(try encode(item))
        }

        if payload.count <= 55 {
            return Data([UInt8(0xc0 + payload.count)]) + payload
        } else {
            let lengthData = encodeLength(payload.count)
            return Data([UInt8(0xf7 + lengthData.count)]) + lengthData + payload
        }
    }

    private static func encodeLength(_ length: Int) -> Data {
        var bytes: [UInt8] = []
        var len = length

        while len > 0 {
            bytes.insert(UInt8(len & 0xff), at: 0)
            len >>= 8
        }

        return Data(bytes)
    }
}

// MARK: - RLP Error
enum RLPError: Error {
    case invalidInput
    case unsupportedType
}

// MARK: - Data Extensions
extension Data {
    // MARK: - SHA256
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }

    // MARK: - SHA3 (Keccak)
    enum SHA3Variant {
        case keccak256
        case keccak512
    }

    func sha3(_ variant: SHA3Variant) -> Data {
        // Simplified keccak implementation
        // In production, use a proper crypto library like CryptoSwift
        return self.sha256() // Placeholder
    }

    // MARK: - Hex Conversion
    func toHexString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Base58 Encoding
    func base58Encoded() -> String {
        let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        var bytes = Array(self)
        var zerosCount = 0

        for byte in bytes {
            if byte != 0 { break }
            zerosCount += 1
        }

        bytes = Array(bytes.drop(while: { $0 == 0 }))

        var result: [UInt8] = []

        for byte in bytes {
            var carry = Int(byte)
            for j in 0..<result.count {
                carry += Int(result[j]) << 8
                result[j] = UInt8(carry % 58)
                carry /= 58
            }

            while carry > 0 {
                result.append(UInt8(carry % 58))
                carry /= 58
            }
        }

        // Add leading zeros
        for _ in 0..<zerosCount {
            result.append(0)
        }

        return String(result.reversed().map { alphabet[alphabet.index(alphabet.startIndex, offsetBy: Int($0))] })
    }
}

// MARK: - String Extensions
extension String {
    // MARK: - Hex to Data
    func hexToData() -> Data? {
        let string = self.hasPrefix("0x") ? String(self.dropFirst(2)) : self

        guard string.count % 2 == 0 else { return nil }

        var data = Data()
        var index = string.startIndex

        while index < string.endIndex {
            let nextIndex = string.index(index, offsetBy: 2)
            let byteString = string[index..<nextIndex]

            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)

            index = nextIndex
        }

        return data
    }

    // MARK: - Base58 Decoding
    func base58Decode() -> Data? {
        let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        var bytes: [UInt8] = [0]

        for char in self {
            guard let index = alphabet.firstIndex(of: char) else { return nil }
            let value = alphabet.distance(from: alphabet.startIndex, to: index)

            var carry = value
            for i in 0..<bytes.count {
                carry += Int(bytes[i]) * 58
                bytes[i] = UInt8(carry & 0xff)
                carry >>= 8
            }

            while carry > 0 {
                bytes.append(UInt8(carry & 0xff))
                carry >>= 8
            }
        }

        // Add leading zeros
        for char in self {
            if char != "1" { break }
            bytes.append(0)
        }

        return Data(bytes.reversed())
    }

    // MARK: - Base58Check Decoding
    func base58CheckDecode() -> Data? {
        guard let decoded = base58Decode() else { return nil }
        guard decoded.count >= 4 else { return nil }

        let payload = decoded.dropLast(4)
        let checksum = decoded.suffix(4)

        let hash = payload.sha256().sha256()
        let expectedChecksum = hash.prefix(4)

        guard checksum.elementsEqual(expectedChecksum) else { return nil }

        // Remove version byte
        return payload.dropFirst()
    }
}

// MARK: - Character Extensions
extension Character {
    var isHexDigit: Bool {
        return isASCII && (isNumber || ("a"..."f").contains(self) || ("A"..."F").contains(self))
    }
}
