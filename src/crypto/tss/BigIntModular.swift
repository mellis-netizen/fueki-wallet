import Foundation

/// Production-grade BigInteger implementation for cryptographic field arithmetic
/// Supports modular arithmetic operations over large prime fields (secp256k1, ed25519, etc.)
public struct BigInt: Equatable, Comparable, CustomStringConvertible {

    // Internal representation: little-endian array of 64-bit limbs
    private var limbs: [UInt64]

    // MARK: - Constants

    /// secp256k1 curve order (n)
    public static let secp256k1Order = BigInt(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141")!

    /// secp256k1 field prime (p)
    public static let secp256k1Prime = BigInt(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F")!

    /// Ed25519 curve order (l)
    public static let ed25519Order = BigInt(hex: "1000000000000000000000000000000014DEF9DEA2F79CD65812631A5CF5D3ED")!

    /// P-256 (secp256r1) order
    public static let p256Order = BigInt(hex: "FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551")!

    public static let zero = BigInt(0)
    public static let one = BigInt(1)

    // MARK: - Initialization

    public init(_ value: UInt64 = 0) {
        if value == 0 {
            self.limbs = []
        } else {
            self.limbs = [value]
        }
    }

    public init(limbs: [UInt64]) {
        self.limbs = limbs
        self.normalize()
    }

    public init?(hex: String) {
        let cleanHex = hex.replacingOccurrences(of: "0x", with: "")
        guard !cleanHex.isEmpty else { return nil }

        var bytes: [UInt8] = []
        var index = cleanHex.startIndex

        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: min(2, cleanHex.distance(from: index, to: cleanHex.endIndex)))
            guard let byte = UInt8(cleanHex[index..<nextIndex], radix: 16) else { return nil }
            bytes.append(byte)
            index = nextIndex
        }

        self.init(data: Data(bytes))
    }

    public init(data: Data) {
        guard !data.isEmpty else {
            self.limbs = []
            return
        }

        // Convert big-endian bytes to little-endian limbs
        let bytes = Array(data)
        var tempLimbs: [UInt64] = []

        var i = bytes.count
        while i > 0 {
            var limb: UInt64 = 0
            let start = max(0, i - 8)
            let chunk = bytes[start..<i]

            for byte in chunk {
                limb = (limb << 8) | UInt64(byte)
            }

            tempLimbs.append(limb)
            i = start
        }

        self.limbs = tempLimbs
        self.normalize()
    }

    // MARK: - Normalization

    private mutating func normalize() {
        // Remove leading zero limbs
        while limbs.count > 0 && limbs.last == 0 {
            limbs.removeLast()
        }
    }

    // MARK: - Conversion

    public func toData(minLength: Int = 32) -> Data {
        guard !limbs.isEmpty else {
            return Data(repeating: 0, count: minLength)
        }

        var bytes: [UInt8] = []

        for limb in limbs.reversed() {
            var value = limb
            var limbBytes: [UInt8] = []

            for _ in 0..<8 {
                limbBytes.insert(UInt8(value & 0xFF), at: 0)
                value >>= 8
            }

            bytes.append(contentsOf: limbBytes)
        }

        // Remove leading zeros
        while bytes.count > minLength && bytes.first == 0 {
            bytes.removeFirst()
        }

        // Pad if needed
        while bytes.count < minLength {
            bytes.insert(0, at: 0)
        }

        return Data(bytes)
    }

    public var description: String {
        if limbs.isEmpty { return "0x0" }
        return "0x" + toData().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Comparison

    public static func == (lhs: BigInt, rhs: BigInt) -> Bool {
        return lhs.limbs == rhs.limbs
    }

    public static func < (lhs: BigInt, rhs: BigInt) -> Bool {
        if lhs.limbs.count != rhs.limbs.count {
            return lhs.limbs.count < rhs.limbs.count
        }

        for i in stride(from: lhs.limbs.count - 1, through: 0, by: -1) {
            if lhs.limbs[i] != rhs.limbs[i] {
                return lhs.limbs[i] < rhs.limbs[i]
            }
        }

        return false
    }

    public var isZero: Bool {
        return limbs.isEmpty
    }

    public var bitWidth: Int {
        guard !limbs.isEmpty else { return 0 }
        let highLimb = limbs.last!
        let limbBits = 64 - highLimb.leadingZeroBitCount
        return (limbs.count - 1) * 64 + limbBits
    }

    // MARK: - Addition

    public static func + (lhs: BigInt, rhs: BigInt) -> BigInt {
        let maxLen = max(lhs.limbs.count, rhs.limbs.count)
        var result: [UInt64] = []
        result.reserveCapacity(maxLen + 1)

        var carry: UInt64 = 0

        for i in 0..<maxLen {
            let l = i < lhs.limbs.count ? lhs.limbs[i] : 0
            let r = i < rhs.limbs.count ? rhs.limbs[i] : 0

            let (sum1, overflow1) = l.addingReportingOverflow(r)
            let (sum2, overflow2) = sum1.addingReportingOverflow(carry)

            result.append(sum2)
            carry = (overflow1 ? 1 : 0) + (overflow2 ? 1 : 0)
        }

        if carry > 0 {
            result.append(carry)
        }

        return BigInt(limbs: result)
    }

    // MARK: - Subtraction

    public static func - (lhs: BigInt, rhs: BigInt) -> BigInt {
        guard lhs >= rhs else {
            fatalError("BigInt subtraction underflow: \(lhs) - \(rhs)")
        }

        var result: [UInt64] = []
        result.reserveCapacity(lhs.limbs.count)

        var borrow: UInt64 = 0

        for i in 0..<lhs.limbs.count {
            let l = lhs.limbs[i]
            let r = i < rhs.limbs.count ? rhs.limbs[i] : 0

            let (diff1, underflow1) = l.subtractingReportingOverflow(r)
            let (diff2, underflow2) = diff1.subtractingReportingOverflow(borrow)

            result.append(diff2)
            borrow = (underflow1 ? 1 : 0) + (underflow2 ? 1 : 0)
        }

        return BigInt(limbs: result)
    }

    // MARK: - Multiplication

    public static func * (lhs: BigInt, rhs: BigInt) -> BigInt {
        if lhs.isZero || rhs.isZero {
            return .zero
        }

        var result = [UInt64](repeating: 0, count: lhs.limbs.count + rhs.limbs.count)

        for i in 0..<lhs.limbs.count {
            var carry: UInt64 = 0

            for j in 0..<rhs.limbs.count {
                let product = UInt128(lhs.limbs[i]) * UInt128(rhs.limbs[j])
                let current = UInt128(result[i + j]) + product + UInt128(carry)

                result[i + j] = UInt64(current & 0xFFFFFFFFFFFFFFFF)
                carry = UInt64(current >> 64)
            }

            result[i + rhs.limbs.count] = carry
        }

        return BigInt(limbs: result)
    }

    // MARK: - Division and Modulo

    public static func / (lhs: BigInt, rhs: BigInt) -> BigInt {
        return lhs.divMod(rhs).quotient
    }

    public static func % (lhs: BigInt, rhs: BigInt) -> BigInt {
        return lhs.divMod(rhs).remainder
    }

    private func divMod(_ divisor: BigInt) -> (quotient: BigInt, remainder: BigInt) {
        guard !divisor.isZero else {
            fatalError("Division by zero")
        }

        guard self >= divisor else {
            return (.zero, self)
        }

        if divisor == .one {
            return (self, .zero)
        }

        // Binary long division
        var quotient = BigInt.zero
        var remainder = BigInt.zero

        for i in stride(from: self.bitWidth - 1, through: 0, by: -1) {
            remainder = remainder << 1

            // Get bit i of dividend
            let limbIndex = i / 64
            let bitIndex = i % 64
            if limbIndex < self.limbs.count && (self.limbs[limbIndex] & (1 << bitIndex)) != 0 {
                remainder = remainder + .one
            }

            if remainder >= divisor {
                remainder = remainder - divisor

                // Set bit i of quotient
                let qLimbIndex = i / 64
                let qBitIndex = i % 64

                while quotient.limbs.count <= qLimbIndex {
                    quotient.limbs.append(0)
                }

                quotient.limbs[qLimbIndex] |= (1 << qBitIndex)
            }
        }

        quotient.normalize()
        return (quotient, remainder)
    }

    // MARK: - Bit Shifting

    public static func << (lhs: BigInt, rhs: Int) -> BigInt {
        guard rhs > 0 else { return lhs }
        guard !lhs.isZero else { return .zero }

        let limbShift = rhs / 64
        let bitShift = rhs % 64

        var newLimbs = [UInt64](repeating: 0, count: limbShift)
        newLimbs.append(contentsOf: lhs.limbs)

        if bitShift > 0 {
            var carry: UInt64 = 0
            for i in limbShift..<newLimbs.count {
                let newCarry = newLimbs[i] >> (64 - bitShift)
                newLimbs[i] = (newLimbs[i] << bitShift) | carry
                carry = newCarry
            }

            if carry > 0 {
                newLimbs.append(carry)
            }
        }

        return BigInt(limbs: newLimbs)
    }

    public static func >> (lhs: BigInt, rhs: Int) -> BigInt {
        guard rhs > 0 else { return lhs }
        guard !lhs.isZero else { return .zero }

        let limbShift = rhs / 64
        let bitShift = rhs % 64

        guard limbShift < lhs.limbs.count else { return .zero }

        var newLimbs = Array(lhs.limbs[limbShift...])

        if bitShift > 0 {
            var borrow: UInt64 = 0
            for i in stride(from: newLimbs.count - 1, through: 0, by: -1) {
                let newBorrow = newLimbs[i] << (64 - bitShift)
                newLimbs[i] = (newLimbs[i] >> bitShift) | borrow
                borrow = newBorrow
            }
        }

        return BigInt(limbs: newLimbs)
    }
}

// MARK: - UInt128 Helper

private struct UInt128 {
    var high: UInt64
    var low: UInt64

    init(_ value: UInt64) {
        self.high = 0
        self.low = value
    }

    init(high: UInt64, low: UInt64) {
        self.high = high
        self.low = low
    }

    static func * (lhs: UInt128, rhs: UInt128) -> UInt128 {
        // Multiply two UInt128 values (we only need lower 128 bits)
        let a = lhs.low
        let b = rhs.low

        let low = a.multipliedFullWidth(by: b)

        return UInt128(high: low.high, low: low.low)
    }

    static func + (lhs: UInt128, rhs: UInt128) -> UInt128 {
        let (low, overflow) = lhs.low.addingReportingOverflow(rhs.low)
        let high = lhs.high + rhs.high + (overflow ? 1 : 0)
        return UInt128(high: high, low: low)
    }

    static func >> (lhs: UInt128, rhs: Int) -> UInt64 {
        if rhs >= 64 {
            return lhs.high >> (rhs - 64)
        } else {
            return (lhs.low >> rhs) | (lhs.high << (64 - rhs))
        }
    }

    static func & (lhs: UInt128, rhs: UInt64) -> UInt64 {
        return lhs.low & rhs
    }
}

// MARK: - Modular Arithmetic

public struct FieldArithmetic {
    let modulus: BigInt

    public init(modulus: BigInt) {
        self.modulus = modulus
    }

    /// Modular addition: (a + b) mod m
    public func add(_ a: BigInt, _ b: BigInt) -> BigInt {
        let sum = a + b
        if sum < modulus {
            return sum
        }
        return sum % modulus
    }

    /// Modular subtraction: (a - b) mod m
    public func subtract(_ a: BigInt, _ b: BigInt) -> BigInt {
        if a >= b {
            return a - b
        }
        // a < b: compute (a + m) - b
        return (a + modulus) - b
    }

    /// Modular multiplication: (a * b) mod m
    public func multiply(_ a: BigInt, _ b: BigInt) -> BigInt {
        let product = a * b
        return product % modulus
    }

    /// Modular exponentiation: (base^exp) mod m using binary exponentiation
    public func power(_ base: BigInt, _ exponent: BigInt) -> BigInt {
        if exponent.isZero {
            return .one
        }

        var result = BigInt.one
        var base = base % modulus
        var exp = exponent

        while !exp.isZero {
            // If exp is odd, multiply result by base
            if exp.limbs.first?.isMultiple(of: 2) == false {
                result = multiply(result, base)
            }

            // Square the base and halve the exponent
            base = multiply(base, base)
            exp = exp >> 1
        }

        return result
    }

    /// Modular inverse: a^(-1) mod m using Extended Euclidean Algorithm
    public func inverse(_ a: BigInt) -> BigInt? {
        guard !a.isZero else { return nil }

        var t = BigInt.zero
        var newT = BigInt.one
        var r = modulus
        var newR = a % modulus

        while !newR.isZero {
            let quotient = r / newR

            // Update t
            let tempT = t
            if quotient * newT <= t {
                t = t - (quotient * newT)
            } else {
                // Handle negative: t - q*newT = -(q*newT - t)
                // In modular arithmetic: -x ≡ m - x (mod m)
                let diff = (quotient * newT) - t
                t = modulus - (diff % modulus)
            }
            newT = tempT

            // Update r
            let tempR = r
            r = newR
            newR = tempR - (quotient * newR)

            // Swap
            (t, newT) = (newT, t)
            (r, newR) = (newR, r)
        }

        // r should be 1 (gcd(a, modulus) = 1)
        guard r == .one else {
            return nil // No inverse exists
        }

        // Ensure t is positive
        if t < .zero || t >= modulus {
            t = t % modulus
        }

        return t
    }

    /// Negate: -a mod m
    public func negate(_ a: BigInt) -> BigInt {
        if a.isZero {
            return .zero
        }
        return modulus - (a % modulus)
    }
}
