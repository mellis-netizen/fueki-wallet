import Foundation

/// ABI (Application Binary Interface) encoder for Ethereum smart contracts
/// Implements the Contract ABI Specification for encoding function calls and data
public struct ABIEncoder {

    // MARK: - Function Encoding

    /// Encode function call with parameters
    /// - Parameters:
    ///   - functionSignature: Function signature (e.g., "transfer(address,uint256)")
    ///   - parameters: Function parameters
    /// - Returns: Encoded function call data
    public static func encodeFunctionCall(
        functionSignature: String,
        parameters: [ABIValue]
    ) throws -> Data {
        // Calculate function selector (first 4 bytes of keccak256 hash)
        let selector = functionSelector(functionSignature)

        // Encode parameters
        let encodedParams = try encodeParameters(parameters)

        var data = Data()
        data.append(selector)
        data.append(encodedParams)

        return data
    }

    /// Calculate function selector from signature
    /// - Parameter signature: Function signature
    /// - Returns: 4-byte function selector
    public static func functionSelector(_ signature: String) -> Data {
        let hash = Keccak256.hash(signature)
        return hash.prefix(4)
    }

    // MARK: - Parameter Encoding

    /// Encode function parameters according to ABI specification
    /// - Parameter parameters: Array of parameters
    /// - Returns: Encoded parameters data
    public static func encodeParameters(_ parameters: [ABIValue]) throws -> Data {
        var headData = Data()
        var tailData = Data()

        // Calculate head size
        var headSize = parameters.count * 32

        for (index, param) in parameters.enumerated() {
            if param.isDynamic {
                // Dynamic type: encode offset in head
                let offset = headSize + tailData.count
                headData.append(try encodeUInt256(UInt64(offset)))

                // Encode actual data in tail
                tailData.append(try encodeDynamic(param))
            } else {
                // Static type: encode directly in head
                headData.append(try encodeStatic(param))
            }
        }

        var result = Data()
        result.append(headData)
        result.append(tailData)

        return result
    }

    // MARK: - Type Encoding

    static func encodeStatic(_ value: ABIValue) throws -> Data {
        switch value {
        case .uint(let val):
            return try encodeUInt256(val)
        case .int(let val):
            return try encodeInt256(val)
        case .address(let addr):
            return try encodeAddress(addr)
        case .bool(let val):
            return try encodeBool(val)
        case .bytes(let data) where data.count <= 32:
            return try encodeFixedBytes(data)
        default:
            throw ABIError.invalidType
        }
    }

    static func encodeDynamic(_ value: ABIValue) throws -> Data {
        switch value {
        case .bytes(let data):
            return try encodeDynamicBytes(data)
        case .string(let str):
            return try encodeString(str)
        case .array(let elements):
            return try encodeArray(elements)
        default:
            throw ABIError.invalidType
        }
    }

    // MARK: - Primitive Type Encoding

    static func encodeUInt256(_ value: UInt64) throws -> Data {
        var data = Data(repeating: 0, count: 32)
        var val = value.bigEndian

        withUnsafeBytes(of: &val) { bytes in
            data.replaceSubrange(24..<32, with: bytes)
        }

        return data
    }

    static func encodeInt256(_ value: Int64) throws -> Data {
        var data = Data(repeating: value < 0 ? 0xff : 0x00, count: 32)
        var val = value.bigEndian

        withUnsafeBytes(of: &val) { bytes in
            data.replaceSubrange(24..<32, with: bytes)
        }

        return data
    }

    static func encodeAddress(_ address: String) throws -> Data {
        let cleaned = address.replacingOccurrences(of: "0x", with: "")
        guard cleaned.count == 40 else {
            throw ABIError.invalidAddress
        }

        guard let addressData = Data(hex: cleaned) else {
            throw ABIError.invalidAddress
        }

        var data = Data(repeating: 0, count: 32)
        data.replaceSubrange(12..<32, with: addressData)

        return data
    }

    static func encodeBool(_ value: Bool) throws -> Data {
        return try encodeUInt256(value ? 1 : 0)
    }

    static func encodeFixedBytes(_ bytes: Data) throws -> Data {
        guard bytes.count <= 32 else {
            throw ABIError.invalidData
        }

        var data = bytes
        data.append(Data(repeating: 0, count: 32 - bytes.count))

        return data
    }

    static func encodeDynamicBytes(_ bytes: Data) throws -> Data {
        var result = Data()

        // Encode length
        result.append(try encodeUInt256(UInt64(bytes.count)))

        // Encode data (padded to multiple of 32 bytes)
        result.append(bytes)
        let padding = (32 - (bytes.count % 32)) % 32
        if padding > 0 {
            result.append(Data(repeating: 0, count: padding))
        }

        return result
    }

    static func encodeString(_ string: String) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw ABIError.invalidData
        }

        return try encodeDynamicBytes(data)
    }

    static func encodeArray(_ elements: [ABIValue]) throws -> Data {
        var result = Data()

        // Encode length
        result.append(try encodeUInt256(UInt64(elements.count)))

        // Encode elements
        result.append(try encodeParameters(elements))

        return result
    }
}

// MARK: - ABI Types

public enum ABIValue {
    case uint(UInt64)
    case int(Int64)
    case address(String)
    case bool(Bool)
    case bytes(Data)
    case string(String)
    case array([ABIValue])

    var isDynamic: Bool {
        switch self {
        case .bytes, .string, .array:
            return true
        default:
            return false
        }
    }
}

public enum ABIError: Error {
    case invalidType
    case invalidAddress
    case invalidData
    case encodingFailed
    case decodingFailed
}

// MARK: - Common Function Encoders

extension ABIEncoder {

    /// Encode ERC-20 transfer function call
    /// - Parameters:
    ///   - to: Recipient address
    ///   - amount: Transfer amount
    /// - Returns: Encoded function call
    public static func encodeERC20Transfer(to: String, amount: UInt64) throws -> Data {
        return try encodeFunctionCall(
            functionSignature: "transfer(address,uint256)",
            parameters: [
                .address(to),
                .uint(amount)
            ]
        )
    }

    /// Encode ERC-20 approve function call
    /// - Parameters:
    ///   - spender: Spender address
    ///   - amount: Approval amount
    /// - Returns: Encoded function call
    public static func encodeERC20Approve(spender: String, amount: UInt64) throws -> Data {
        return try encodeFunctionCall(
            functionSignature: "approve(address,uint256)",
            parameters: [
                .address(spender),
                .uint(amount)
            ]
        )
    }

    /// Encode ERC-20 balanceOf function call
    /// - Parameter account: Account address
    /// - Returns: Encoded function call
    public static func encodeERC20BalanceOf(account: String) throws -> Data {
        return try encodeFunctionCall(
            functionSignature: "balanceOf(address)",
            parameters: [
                .address(account)
            ]
        )
    }

    /// Encode ERC-20 transferFrom function call
    /// - Parameters:
    ///   - from: Sender address
    ///   - to: Recipient address
    ///   - amount: Transfer amount
    /// - Returns: Encoded function call
    public static func encodeERC20TransferFrom(from: String, to: String, amount: UInt64) throws -> Data {
        return try encodeFunctionCall(
            functionSignature: "transferFrom(address,address,uint256)",
            parameters: [
                .address(from),
                .address(to),
                .uint(amount)
            ]
        )
    }
}

// MARK: - ABI Decoder

public struct ABIDecoder {

    /// Decode uint256 from ABI encoded data
    /// - Parameter data: ABI encoded data (32 bytes)
    /// - Returns: Decoded uint256 value
    public static func decodeUInt256(_ data: Data) throws -> UInt64 {
        guard data.count >= 32 else {
            throw ABIError.decodingFailed
        }

        let value = data.suffix(32).prefix(8)
        return value.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
    }

    /// Decode address from ABI encoded data
    /// - Parameter data: ABI encoded data (32 bytes)
    /// - Returns: Decoded address (0x prefixed)
    public static func decodeAddress(_ data: Data) throws -> String {
        guard data.count >= 32 else {
            throw ABIError.decodingFailed
        }

        let addressBytes = data.suffix(32).suffix(20)
        return "0x" + addressBytes.hexString
    }

    /// Decode bool from ABI encoded data
    /// - Parameter data: ABI encoded data (32 bytes)
    /// - Returns: Decoded boolean value
    public static func decodeBool(_ data: Data) throws -> Bool {
        let value = try decodeUInt256(data)
        return value != 0
    }

    /// Decode bytes from ABI encoded data
    /// - Parameter data: ABI encoded data
    /// - Returns: Decoded bytes
    public static func decodeBytes(_ data: Data) throws -> Data {
        guard data.count >= 32 else {
            throw ABIError.decodingFailed
        }

        // First 32 bytes contain length
        let length = try decodeUInt256(data.prefix(32))

        guard data.count >= 32 + Int(length) else {
            throw ABIError.decodingFailed
        }

        return data.dropFirst(32).prefix(Int(length))
    }

    /// Decode string from ABI encoded data
    /// - Parameter data: ABI encoded data
    /// - Returns: Decoded string
    public static func decodeString(_ data: Data) throws -> String {
        let bytes = try decodeBytes(data)

        guard let string = String(data: bytes, encoding: .utf8) else {
            throw ABIError.decodingFailed
        }

        return string
    }
}
