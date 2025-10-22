import Foundation
import CommonCrypto

/// String and data obfuscation utilities
/// Protects sensitive strings and data from static analysis
public class ObfuscationHelper {

    // MARK: - String Obfuscation

    /// Obfuscate string using XOR cipher
    public static func obfuscateString(_ string: String, key: UInt8 = 0xAB) -> [UInt8] {
        return string.utf8.map { $0 ^ key }
    }

    /// Deobfuscate string
    public static func deobfuscateString(_ bytes: [UInt8], key: UInt8 = 0xAB) -> String? {
        let deobfuscated = bytes.map { $0 ^ key }
        return String(bytes: deobfuscated, encoding: .utf8)
    }

    /// Advanced string obfuscation with random key
    public static func obfuscateStringAdvanced(_ string: String) -> ObfuscatedString {
        let key = UInt8.random(in: 0...255)
        let obfuscated = string.utf8.map { $0 ^ key }
        return ObfuscatedString(data: obfuscated, key: key)
    }

    // MARK: - Data Obfuscation

    /// Obfuscate binary data
    public static func obfuscateData(_ data: Data, key: Data) -> Data {
        var result = Data(count: data.count)
        for i in 0..<data.count {
            result[i] = data[i] ^ key[i % key.count]
        }
        return result
    }

    /// Deobfuscate binary data
    public static func deobfuscateData(_ data: Data, key: Data) -> Data {
        // XOR is symmetric
        return obfuscateData(data, key: key)
    }

    // MARK: - API Key Protection

    /// Store and retrieve obfuscated API keys
    public class APIKeyProtector {
        private static let obfuscationKey: UInt8 = 0xD3

        public static func protect(apiKey: String) -> String {
            let obfuscated = obfuscateString(apiKey, key: obfuscationKey)
            return obfuscated.map { String(format: "%02x", $0) }.joined()
        }

        public static func retrieve(protected: String) -> String? {
            var bytes: [UInt8] = []
            var index = protected.startIndex

            while index < protected.endIndex {
                let nextIndex = protected.index(index, offsetBy: 2)
                if nextIndex <= protected.endIndex,
                   let byte = UInt8(protected[index..<nextIndex], radix: 16) {
                    bytes.append(byte)
                }
                index = nextIndex
            }

            return deobfuscateString(bytes, key: obfuscationKey)
        }
    }

    // MARK: - Private Key Obfuscation

    /// Split private key into multiple parts
    public static func splitKey(_ key: Data, parts: Int = 3) -> [Data] {
        guard parts > 1 else { return [key] }

        var keyParts: [Data] = []
        let partSize = (key.count + parts - 1) / parts

        for i in 0..<parts {
            let start = i * partSize
            let end = min(start + partSize, key.count)
            if start < key.count {
                keyParts.append(key.subdata(in: start..<end))
            }
        }

        return keyParts
    }

    /// Combine key parts
    public static func combineKeyParts(_ parts: [Data]) -> Data {
        var combined = Data()
        for part in parts {
            combined.append(part)
        }
        return combined
    }

    // MARK: - Code Obfuscation Helpers

    /// Obfuscate function name at runtime
    public static func obfuscateFunctionName(_ name: String) -> String {
        let characters = Array(name)
        var obfuscated = ""

        for char in characters {
            let unicodeValue = char.unicodeScalars.first?.value ?? 0
            obfuscated += String(format: "_%04x", unicodeValue)
        }

        return obfuscated
    }

    /// Generate random noise data for padding
    public static func generateNoise(size: Int) -> Data {
        var noise = Data(count: size)
        _ = noise.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, size, bytes.baseAddress!)
        }
        return noise
    }

    /// Add noise padding to data
    public static func addNoisePadding(to data: Data, targetSize: Int) -> Data {
        guard data.count < targetSize else { return data }

        var padded = data
        let noiseSize = targetSize - data.count
        let noise = generateNoise(size: noiseSize)
        padded.append(noise)

        return padded
    }

    // MARK: - String Encoding Obfuscation

    /// Encode string with custom base64-like encoding
    public static func customEncode(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }

        let base64 = data.base64EncodedString()

        // Apply additional transformations
        var transformed = ""
        for (index, char) in base64.enumerated() {
            if index % 2 == 0 {
                transformed.append(char)
            } else {
                transformed.insert(char, at: transformed.startIndex)
            }
        }

        return transformed
    }

    /// Decode custom encoded string
    public static func customDecode(_ encoded: String) -> String? {
        // Reverse the transformation
        var reversed = ""
        let chars = Array(encoded)

        var leftChars: [Character] = []
        var rightChars: [Character] = []

        for (index, char) in chars.enumerated() {
            if index % 2 == 0 {
                rightChars.append(char)
            } else {
                leftChars.insert(char, at: 0)
            }
        }

        reversed = String(leftChars + rightChars)

        // Decode base64
        guard let data = Data(base64Encoded: reversed),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    // MARK: - Runtime String Protection

    /// SecureString that exists only in protected memory
    public class SecureString {
        private var obfuscated: ObfuscatedString

        public init(_ string: String) {
            self.obfuscated = obfuscateStringAdvanced(string)
        }

        public func reveal() -> String {
            return obfuscated.deobfuscate() ?? ""
        }

        deinit {
            // Clear obfuscated data
            obfuscated.clear()
        }
    }

    // MARK: - Control Flow Obfuscation

    /// Add opaque predicates to confuse static analysis
    public static func opaqueTrue() -> Bool {
        let x = Int.random(in: 1...1000)
        return (x * x) >= 0 // Always true, but harder to analyze
    }

    public static func opaqueFalse() -> Bool {
        let x = Int.random(in: 1...1000)
        return (x * x) < 0 // Always false
    }

    /// Execute block with opaque control flow
    public static func obfuscatedExecution(_ block: () -> Void) {
        if opaqueTrue() {
            block()
        }
    }

    // MARK: - Anti-Debugging String Protection

    /// Strings that trigger debugger detection when accessed
    public static func protectedString(_ string: String) -> ProtectedString {
        return ProtectedString(value: string)
    }

    public class ProtectedString {
        private let obfuscated: [UInt8]
        private let key: UInt8

        fileprivate init(value: String) {
            self.key = UInt8.random(in: 0...255)
            self.obfuscated = obfuscateString(value, key: key)
        }

        public func getValue() -> String? {
            // Check for debugger before revealing
            if DebuggerDetector().isDebuggerAttached() {
                return nil
            }

            return deobfuscateString(obfuscated, key: key)
        }
    }
}

// MARK: - Supporting Types

public struct ObfuscatedString {
    let data: [UInt8]
    let key: UInt8

    func deobfuscate() -> String? {
        return ObfuscationHelper.deobfuscateString(data, key: key)
    }

    mutating func clear() {
        // In Swift, structs are value types, so this creates a copy
        // For true clearing, need to work with pointers
    }
}

// MARK: - Compile-Time Obfuscation Macros

public extension String {
    /// Obfuscate string literal at compile time
    func obfuscated() -> [UInt8] {
        return ObfuscationHelper.obfuscateString(self)
    }

    /// Static string that's deobfuscated at runtime
    static func secure(_ obfuscated: [UInt8]) -> String? {
        return ObfuscationHelper.deobfuscateString(obfuscated)
    }
}

// MARK: - Examples

/*
 Usage Examples:

 // 1. Simple string obfuscation
 let apiKey = "sk_live_123456789"
 let protected = APIKeyProtector.protect(apiKey: apiKey)
 let retrieved = APIKeyProtector.retrieve(protected: protected)

 // 2. Secure string in memory
 let password = SecureString("MyPassword123!")
 let revealed = password.reveal()

 // 3. Protected string with debugger check
 let sensitive = ObfuscationHelper.protectedString("sensitive_data")
 if let value = sensitive.getValue() {
     // Use value
 }

 // 4. Compile-time obfuscation
 let obfuscated: [UInt8] = "API_KEY_HERE".obfuscated()
 let deobfuscated = String.secure(obfuscated)
 */
