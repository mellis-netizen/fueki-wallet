import Foundation

/// RIPEMD-160 Hashing Implementation
/// Based on the official RIPEMD-160 specification
/// Reference: https://homes.esat.kuleuven.be/~bosselae/ripemd160.html
public class RIPEMD160 {

    // MARK: - Constants

    private static let K_LEFT: [UInt32] = [
        0x00000000, 0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xA953FD4E
    ]

    private static let K_RIGHT: [UInt32] = [
        0x50A28BE6, 0x5C4DD124, 0x6D703EF3, 0x7A6D76E9, 0x00000000
    ]

    private static let R_LEFT: [Int] = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
        7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8,
        3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
        1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2,
        4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13
    ]

    private static let R_RIGHT: [Int] = [
        5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12,
        6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2,
        15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
        8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14,
        12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11
    ]

    private static let S_LEFT: [Int] = [
        11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8,
        7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12,
        11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5,
        11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12,
        9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6
    ]

    private static let S_RIGHT: [Int] = [
        8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6,
        9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11,
        9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5,
        15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8,
        8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11
    ]

    // MARK: - Public Methods

    /// Compute RIPEMD-160 hash of data
    /// - Parameter data: Input data to hash
    /// - Returns: 20-byte hash
    public static func hash(_ data: Data) -> Data {
        var message = data
        let messageLength = UInt64(data.count)

        // Padding
        message.append(0x80)

        while (message.count % 64) != 56 {
            message.append(0x00)
        }

        // Append message length in bits (little-endian)
        var lengthInBits = messageLength * 8
        withUnsafeBytes(of: &lengthInBits) { bytes in
            message.append(contentsOf: bytes)
        }

        // Initialize hash values
        var h0: UInt32 = 0x67452301
        var h1: UInt32 = 0xEFCDAB89
        var h2: UInt32 = 0x98BADCFE
        var h3: UInt32 = 0x10325476
        var h4: UInt32 = 0xC3D2E1F0

        // Process message in 512-bit chunks
        for chunkStart in stride(from: 0, to: message.count, by: 64) {
            var x = [UInt32](repeating: 0, count: 16)

            for i in 0..<16 {
                let offset = chunkStart + i * 4
                x[i] = UInt32(message[offset])
                    | (UInt32(message[offset + 1]) << 8)
                    | (UInt32(message[offset + 2]) << 16)
                    | (UInt32(message[offset + 3]) << 24)
            }

            // Initialize working variables
            var aL = h0, bL = h1, cL = h2, dL = h3, eL = h4
            var aR = h0, bR = h1, cR = h2, dR = h3, eR = h4

            // Main loop - left line
            for j in 0..<80 {
                var t = aL &+ f(j, bL, cL, dL) &+ x[R_LEFT[j]] &+ K_LEFT[j / 16]
                t = rotateLeft(t, by: S_LEFT[j]) &+ eL
                aL = eL
                eL = dL
                dL = rotateLeft(cL, by: 10)
                cL = bL
                bL = t
            }

            // Main loop - right line
            for j in 0..<80 {
                var t = aR &+ f(79 - j, bR, cR, dR) &+ x[R_RIGHT[j]] &+ K_RIGHT[j / 16]
                t = rotateLeft(t, by: S_RIGHT[j]) &+ eR
                aR = eR
                eR = dR
                dR = rotateLeft(cR, by: 10)
                cR = bR
                bR = t
            }

            // Update hash values
            let t = h1 &+ cL &+ dR
            h1 = h2 &+ dL &+ eR
            h2 = h3 &+ eL &+ aR
            h3 = h4 &+ aL &+ bR
            h4 = h0 &+ bL &+ cR
            h0 = t
        }

        // Produce final hash value (little-endian)
        var result = Data()
        for value in [h0, h1, h2, h3, h4] {
            withUnsafeBytes(of: value.littleEndian) { bytes in
                result.append(contentsOf: bytes)
            }
        }

        return result
    }

    // MARK: - Private Helper Methods

    private static func f(_ j: Int, _ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        switch j {
        case 0..<16:
            return x ^ y ^ z
        case 16..<32:
            return (x & y) | (~x & z)
        case 32..<48:
            return (x | ~y) ^ z
        case 48..<64:
            return (x & z) | (y & ~z)
        case 64..<80:
            return x ^ (y | ~z)
        default:
            return 0
        }
    }

    private static func rotateLeft(_ value: UInt32, by count: Int) -> UInt32 {
        return (value << count) | (value >> (32 - count))
    }
}
