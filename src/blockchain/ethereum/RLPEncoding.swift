import Foundation

/// RLP (Recursive Length Prefix) encoding for Ethereum
/// Implements the RLP specification used for encoding Ethereum transactions
public struct RLPEncoding {

    // MARK: - Public Interface

    /// Encode a value using RLP
    /// - Parameter value: Value to encode
    /// - Returns: RLP encoded data
    public static func encode(_ value: RLPEncodable) -> Data {
        return value.rlpEncode()
    }

    /// Encode an array of values using RLP
    /// - Parameter values: Array of values to encode
    /// - Returns: RLP encoded data
    public static func encodeList(_ values: [RLPEncodable]) -> Data {
        var concatenated = Data()
        for value in values {
            concatenated.append(value.rlpEncode())
        }
        return encodeLength(concatenated.count, offset: 0xc0) + concatenated
    }

    /// Decode RLP encoded data
    /// - Parameter data: RLP encoded data
    /// - Returns: Decoded RLP item
    public static func decode(_ data: Data) throws -> RLPItem {
        let (item, _) = try decodeItem(data, offset: 0)
        return item
    }

    // MARK: - Internal Encoding

    static func encodeData(_ data: Data) -> Data {
        if data.count == 1 && data[0] < 0x80 {
            // Single byte less than 128: encode as itself
            return data
        } else if data.count <= 55 {
            // Short string: 0x80 + length, then data
            return Data([UInt8(0x80 + data.count)]) + data
        } else {
            // Long string: 0xb7 + length of length, then length, then data
            let lengthData = encodeLength(data.count, offset: 0xb7)
            return lengthData + data
        }
    }

    static func encodeLength(_ length: Int, offset: UInt8) -> Data {
        if length <= 55 {
            return Data([offset + UInt8(length)])
        } else {
            let binaryLength = toBinary(length)
            return Data([offset + 55 + UInt8(binaryLength.count)]) + binaryLength
        }
    }

    static func toBinary(_ value: Int) -> Data {
        var val = value
        var bytes = [UInt8]()

        while val > 0 {
            bytes.insert(UInt8(val & 0xff), at: 0)
            val >>= 8
        }

        return Data(bytes.isEmpty ? [0] : bytes)
    }

    // MARK: - Decoding

    static func decodeItem(_ data: Data, offset: Int) throws -> (RLPItem, Int) {
        guard offset < data.count else {
            throw RLPError.invalidData
        }

        let prefix = data[offset]

        if prefix < 0x80 {
            // Single byte
            return (.data(Data([prefix])), offset + 1)
        } else if prefix <= 0xb7 {
            // Short string
            let length = Int(prefix - 0x80)
            let endOffset = offset + 1 + length
            guard endOffset <= data.count else {
                throw RLPError.invalidData
            }
            return (.data(data[offset + 1..<endOffset]), endOffset)
        } else if prefix <= 0xbf {
            // Long string
            let lengthOfLength = Int(prefix - 0xb7)
            let lengthEndOffset = offset + 1 + lengthOfLength
            guard lengthEndOffset <= data.count else {
                throw RLPError.invalidData
            }

            let length = try decodeLength(data[offset + 1..<lengthEndOffset])
            let endOffset = lengthEndOffset + length
            guard endOffset <= data.count else {
                throw RLPError.invalidData
            }
            return (.data(data[lengthEndOffset..<endOffset]), endOffset)
        } else if prefix <= 0xf7 {
            // Short list
            let length = Int(prefix - 0xc0)
            let endOffset = offset + 1 + length
            guard endOffset <= data.count else {
                throw RLPError.invalidData
            }

            let items = try decodeList(data[offset + 1..<endOffset])
            return (.list(items), endOffset)
        } else {
            // Long list
            let lengthOfLength = Int(prefix - 0xf7)
            let lengthEndOffset = offset + 1 + lengthOfLength
            guard lengthEndOffset <= data.count else {
                throw RLPError.invalidData
            }

            let length = try decodeLength(data[offset + 1..<lengthEndOffset])
            let endOffset = lengthEndOffset + length
            guard endOffset <= data.count else {
                throw RLPError.invalidData
            }

            let items = try decodeList(data[lengthEndOffset..<endOffset])
            return (.list(items), endOffset)
        }
    }

    static func decodeList(_ data: Data) throws -> [RLPItem] {
        var items = [RLPItem]()
        var offset = 0

        while offset < data.count {
            let (item, newOffset) = try decodeItem(data, offset: offset)
            items.append(item)
            offset = newOffset
        }

        return items
    }

    static func decodeLength(_ data: Data) throws -> Int {
        guard !data.isEmpty else {
            throw RLPError.invalidData
        }

        var length = 0
        for byte in data {
            length = (length << 8) | Int(byte)
        }

        return length
    }
}

// MARK: - RLP Types

public enum RLPItem {
    case data(Data)
    case list([RLPItem])

    public var dataValue: Data? {
        if case .data(let value) = self {
            return value
        }
        return nil
    }

    public var listValue: [RLPItem]? {
        if case .list(let items) = self {
            return items
        }
        return nil
    }
}

public enum RLPError: Error {
    case invalidData
    case encodingFailed
    case decodingFailed
}

// MARK: - RLPEncodable Protocol

public protocol RLPEncodable {
    func rlpEncode() -> Data
}

extension Data: RLPEncodable {
    public func rlpEncode() -> Data {
        return RLPEncoding.encodeData(self)
    }
}

extension String: RLPEncodable {
    public func rlpEncode() -> Data {
        guard let data = self.data(using: .utf8) else {
            return Data()
        }
        return RLPEncoding.encodeData(data)
    }
}

extension UInt64: RLPEncodable {
    public func rlpEncode() -> Data {
        if self == 0 {
            return Data([0x80]) // Empty byte array for zero
        }

        var value = self
        var bytes = [UInt8]()

        while value > 0 {
            bytes.insert(UInt8(value & 0xff), at: 0)
            value >>= 8
        }

        return RLPEncoding.encodeData(Data(bytes))
    }
}

extension Int: RLPEncodable {
    public func rlpEncode() -> Data {
        return UInt64(self).rlpEncode()
    }
}

extension Array: RLPEncodable where Element: RLPEncodable {
    public func rlpEncode() -> Data {
        return RLPEncoding.encodeList(self)
    }
}

// MARK: - Optional RLP Encoding

extension Optional: RLPEncodable where Wrapped: RLPEncodable {
    public func rlpEncode() -> Data {
        switch self {
        case .some(let value):
            return value.rlpEncode()
        case .none:
            return Data([0x80]) // Empty byte array
        }
    }
}
