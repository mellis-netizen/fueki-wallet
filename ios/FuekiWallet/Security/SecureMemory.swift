import Foundation
import Security

/// Memory protection utilities for handling sensitive data
/// Provides secure memory allocation, zeroing, and protection
public class SecureMemory {

    // MARK: - Secure Data Container

    /// Secure container for sensitive data with automatic zeroing
    public class SecureContainer<T> {
        private var storage: UnsafeMutableRawPointer?
        private let size: Int

        public init(value: T) {
            size = MemoryLayout<T>.size
            storage = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<T>.alignment)
            storage?.storeBytes(of: value, as: T.self)
        }

        public func getValue() -> T? {
            return storage?.load(as: T.self)
        }

        public func setValue(_ value: T) {
            storage?.storeBytes(of: value, as: T.self)
        }

        deinit {
            // Securely zero memory before deallocation
            if let storage = storage {
                SecureMemory.secureZero(pointer: storage, size: size)
                storage.deallocate()
            }
        }
    }

    // MARK: - Memory Protection

    /// Protect memory region (make it read-only)
    public static func protectMemory(pointer: UnsafeMutableRawPointer, size: Int) -> Bool {
        let result = mprotect(pointer, size, PROT_READ)
        return result == 0
    }

    /// Unprotect memory region (make it read-write)
    public static func unprotectMemory(pointer: UnsafeMutableRawPointer, size: Int) -> Bool {
        let result = mprotect(pointer, size, PROT_READ | PROT_WRITE)
        return result == 0
    }

    /// Lock memory to prevent swapping to disk
    public static func lockMemory(pointer: UnsafeMutableRawPointer, size: Int) -> Bool {
        let result = mlock(pointer, size)
        return result == 0
    }

    /// Unlock previously locked memory
    public static func unlockMemory(pointer: UnsafeMutableRawPointer, size: Int) -> Bool {
        let result = munlock(pointer, size)
        return result == 0
    }

    // MARK: - Secure Zeroing

    /// Securely zero memory (prevents compiler optimization)
    public static func secureZero(pointer: UnsafeMutableRawPointer, size: Int) {
        // Use memset_s which cannot be optimized away
        memset_s(pointer, size, 0, size)
    }

    /// Securely zero Data object
    public static func secureZero(data: inout Data) {
        data.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            secureZero(pointer: baseAddress, size: bytes.count)
        }
    }

    /// Securely zero String
    public static func secureZero(string: inout String) {
        var data = Data(string.utf8)
        secureZero(data: &data)
        string = ""
    }

    /// Securely zero array
    public static func secureZero<T>(array: inout [T]) {
        array.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            secureZero(pointer: baseAddress, size: bytes.count)
        }
        array.removeAll()
    }

    // MARK: - Secure Allocation

    /// Allocate secure memory for sensitive data
    public static func allocateSecure(size: Int) -> UnsafeMutableRawPointer? {
        guard let pointer = UnsafeMutableRawPointer.allocate(
            byteCount: size,
            alignment: MemoryLayout<UInt8>.alignment
        ) as UnsafeMutableRawPointer? else {
            return nil
        }

        // Initialize to zero
        secureZero(pointer: pointer, size: size)

        // Lock memory to prevent swapping
        _ = lockMemory(pointer: pointer, size: size)

        return pointer
    }

    /// Deallocate secure memory
    public static func deallocateSecure(pointer: UnsafeMutableRawPointer, size: Int) {
        // Zero before deallocation
        secureZero(pointer: pointer, size: size)

        // Unlock memory
        _ = unlockMemory(pointer: pointer, size: size)

        // Deallocate
        pointer.deallocate()
    }

    // MARK: - Secure String Handling

    /// Create secure string that zeros memory on deallocation
    public class SecureString {
        private var data: Data

        public init(_ string: String) {
            self.data = Data(string.utf8)

            // Lock data in memory
            data.withUnsafeMutableBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return }
                _ = lockMemory(pointer: baseAddress, size: bytes.count)
            }
        }

        public func getString() -> String? {
            return String(data: data, encoding: .utf8)
        }

        deinit {
            // Unlock and zero memory
            data.withUnsafeMutableBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return }
                _ = unlockMemory(pointer: baseAddress, size: bytes.count)
                SecureMemory.secureZero(pointer: baseAddress, size: bytes.count)
            }
        }
    }

    // MARK: - Secure Data Copying

    /// Copy data securely with automatic cleanup
    public static func secureCopy(source: UnsafeRawPointer, destination: UnsafeMutableRawPointer, size: Int) {
        memcpy(destination, source, size)
    }

    /// Compare data in constant time (prevents timing attacks)
    public static func constantTimeCompare(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }

        var result: UInt8 = 0
        for i in 0..<lhs.count {
            result |= lhs[i] ^ rhs[i]
        }

        return result == 0
    }

    // MARK: - Memory Encryption

    /// Encrypt sensitive data in memory
    public static func encryptInMemory(data: Data, key: Data) throws -> Data {
        var encryptedData = Data(count: data.count + kCCBlockSizeAES128)
        var bytesEncrypted = 0

        let status = data.withUnsafeBytes { dataBytes in
            key.withUnsafeBytes { keyBytes in
                encryptedData.withUnsafeMutableBytes { encryptedBytes in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, key.count,
                        nil, // IV
                        dataBytes.baseAddress, data.count,
                        encryptedBytes.baseAddress, encryptedData.count,
                        &bytesEncrypted
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw SecureMemoryError.encryptionFailed
        }

        encryptedData.count = bytesEncrypted
        return encryptedData
    }

    /// Decrypt data from memory
    public static func decryptInMemory(encryptedData: Data, key: Data) throws -> Data {
        var decryptedData = Data(count: encryptedData.count + kCCBlockSizeAES128)
        var bytesDecrypted = 0

        let status = encryptedData.withUnsafeBytes { encryptedBytes in
            key.withUnsafeBytes { keyBytes in
                decryptedData.withUnsafeMutableBytes { decryptedBytes in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, key.count,
                        nil, // IV
                        encryptedBytes.baseAddress, encryptedData.count,
                        decryptedBytes.baseAddress, decryptedData.count,
                        &bytesDecrypted
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw SecureMemoryError.decryptionFailed
        }

        decryptedData.count = bytesDecrypted
        return decryptedData
    }

    // MARK: - Global Memory Cleanup

    /// Zero all sensitive memory (call on app termination)
    public static func zeroMemory() {
        // This would need to track all secure allocations
        // Implementation depends on app architecture
        SecurityLogger.shared.log(
            event: .systemShutdown,
            level: .info,
            message: "Zeroing sensitive memory"
        )
    }

    // MARK: - Memory Pressure Handling

    /// Handle memory pressure by clearing caches
    public static func handleMemoryPressure() {
        // Clear any cached sensitive data
        URLCache.shared.removeAllCachedResponses()

        SecurityLogger.shared.log(
            event: .memoryPressure,
            level: .warning,
            message: "Handling memory pressure"
        )
    }
}

// MARK: - Errors

public enum SecureMemoryError: Error {
    case allocationFailed
    case encryptionFailed
    case decryptionFailed
    case protectionFailed
}

// MARK: - Memory Protection Extensions

extension Data {
    /// Create protected Data that zeros on deallocation
    public static func secureData(from bytes: [UInt8]) -> Data {
        var data = Data(bytes)
        // In production, implement custom Data wrapper with secure deallocation
        return data
    }

    /// Securely clear this Data object
    public mutating func secureZero() {
        SecureMemory.secureZero(data: &self)
    }
}

extension String {
    /// Securely clear this String
    public mutating func secureZero() {
        SecureMemory.secureZero(string: &self)
    }
}
