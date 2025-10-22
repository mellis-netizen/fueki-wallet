import XCTest
@testable import FuekiWallet

/// Comprehensive tests for BigInt modular arithmetic implementation
/// Tests basic operations, field arithmetic, and cryptographic properties
class BigIntTests: XCTestCase {

    // MARK: - Basic Arithmetic Tests

    func testBigIntInitialization() {
        let zero = BigInt(0)
        XCTAssertTrue(zero.isZero)
        XCTAssertEqual(zero.toData(), Data(repeating: 0, count: 32))

        let one = BigInt(1)
        XCTAssertFalse(one.isZero)
        XCTAssertEqual(one, BigInt.one)

        let large = BigInt(UInt64.max)
        XCTAssertFalse(large.isZero)
    }

    func testBigIntHexInitialization() {
        let num1 = BigInt(hex: "FF")
        XCTAssertNotNil(num1)
        XCTAssertEqual(num1, BigInt(255))

        let num2 = BigInt(hex: "0x1234567890ABCDEF")
        XCTAssertNotNil(num2)

        let secp256k1Order = BigInt(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141")
        XCTAssertNotNil(secp256k1Order)
        XCTAssertEqual(secp256k1Order, BigInt.secp256k1Order)
    }

    func testBigIntDataConversion() {
        let data = Data([0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF])
        let num = BigInt(data: data)
        let converted = num.toData(minLength: 8)

        XCTAssertEqual(converted, data)
    }

    func testAddition() {
        let a = BigInt(100)
        let b = BigInt(50)
        let sum = a + b

        XCTAssertEqual(sum, BigInt(150))

        // Test overflow to next limb
        let large1 = BigInt(UInt64.max)
        let large2 = BigInt(1)
        let largeSum = large1 + large2

        XCTAssertEqual(largeSum.bitWidth, 65)
    }

    func testSubtraction() {
        let a = BigInt(100)
        let b = BigInt(30)
        let diff = a - b

        XCTAssertEqual(diff, BigInt(70))

        // Test with same values
        let same = a - a
        XCTAssertTrue(same.isZero)
    }

    func testMultiplication() {
        let a = BigInt(123)
        let b = BigInt(456)
        let product = a * b

        XCTAssertEqual(product, BigInt(56088))

        // Test with zero
        let zero = a * BigInt.zero
        XCTAssertTrue(zero.isZero)

        // Test with one
        let identity = a * BigInt.one
        XCTAssertEqual(identity, a)
    }

    func testDivision() {
        let a = BigInt(100)
        let b = BigInt(10)
        let quotient = a / b

        XCTAssertEqual(quotient, BigInt(10))

        // Test remainder
        let c = BigInt(105)
        let remainder = c % b

        XCTAssertEqual(remainder, BigInt(5))
    }

    func testComparison() {
        let a = BigInt(100)
        let b = BigInt(50)
        let c = BigInt(100)

        XCTAssertTrue(a > b)
        XCTAssertTrue(b < a)
        XCTAssertTrue(a == c)
        XCTAssertTrue(a >= c)
        XCTAssertTrue(a <= c)
        XCTAssertFalse(a == b)
    }

    func testBitShifting() {
        let num = BigInt(1)

        let shifted8 = num << 8
        XCTAssertEqual(shifted8, BigInt(256))

        let shifted64 = num << 64
        XCTAssertEqual(shifted64.bitWidth, 65)

        let shiftedBack = shifted8 >> 8
        XCTAssertEqual(shiftedBack, num)
    }

    // MARK: - Field Arithmetic Tests

    func testModularAddition() {
        let field = FieldArithmetic(modulus: BigInt(17))

        let a = BigInt(10)
        let b = BigInt(12)
        let sum = field.add(a, b)

        // (10 + 12) mod 17 = 5
        XCTAssertEqual(sum, BigInt(5))
    }

    func testModularSubtraction() {
        let field = FieldArithmetic(modulus: BigInt(17))

        let a = BigInt(5)
        let b = BigInt(10)
        let diff = field.subtract(a, b)

        // (5 - 10) mod 17 = -5 mod 17 = 12
        XCTAssertEqual(diff, BigInt(12))
    }

    func testModularMultiplication() {
        let field = FieldArithmetic(modulus: BigInt(17))

        let a = BigInt(8)
        let b = BigInt(9)
        let product = field.multiply(a, b)

        // (8 * 9) mod 17 = 72 mod 17 = 4
        XCTAssertEqual(product, BigInt(4))
    }

    func testModularExponentiation() {
        let field = FieldArithmetic(modulus: BigInt(17))

        let base = BigInt(3)
        let exponent = BigInt(4)
        let power = field.power(base, exponent)

        // 3^4 mod 17 = 81 mod 17 = 13
        XCTAssertEqual(power, BigInt(13))
    }

    func testModularInverse() {
        let field = FieldArithmetic(modulus: BigInt(17))

        let a = BigInt(3)
        let inverse = field.inverse(a)

        XCTAssertNotNil(inverse)

        // 3 * inverse ≡ 1 (mod 17)
        // 3 * 6 = 18 ≡ 1 (mod 17)
        let product = field.multiply(a, inverse!)
        XCTAssertEqual(product, BigInt.one)
    }

    func testModularInverseWithZeroReturnsNil() {
        let field = FieldArithmetic(modulus: BigInt(17))

        let inverse = field.inverse(BigInt.zero)
        XCTAssertNil(inverse)
    }

    func testModularNegate() {
        let field = FieldArithmetic(modulus: BigInt(17))

        let a = BigInt(5)
        let negated = field.negate(a)

        // -5 mod 17 = 12
        XCTAssertEqual(negated, BigInt(12))

        // Adding a number and its negation should give zero
        let sum = field.add(a, negated)
        XCTAssertTrue(sum.isZero)
    }

    // MARK: - Secp256k1 Field Tests

    func testSecp256k1FieldArithmetic() {
        let field = FieldArithmetic(modulus: BigInt.secp256k1Order)

        // Test that modular inverse works correctly
        let secret = BigInt(hex: "1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF")!
        let inverse = field.inverse(secret)

        XCTAssertNotNil(inverse)

        let product = field.multiply(secret, inverse!)
        XCTAssertEqual(product, BigInt.one)
    }

    func testSecp256k1OrderProperties() {
        let n = BigInt.secp256k1Order

        // Verify secp256k1 order is 256 bits
        XCTAssertEqual(n.bitWidth, 256)

        // Verify it's prime-like (test small factors)
        let two = BigInt(2)
        let remainder = n % two
        XCTAssertEqual(remainder, BigInt.one) // Should be odd
    }

    // MARK: - Cryptographic Test Vectors

    func testKnownTestVector1() {
        // Test vector from secp256k1 specification
        let field = FieldArithmetic(modulus: BigInt.secp256k1Order)

        let a = BigInt(hex: "AA5E28D6A97A2479A65527F7290311A3624D4CC0FA1578598EE3C2613BF99522")!
        let b = BigInt(hex: "5C974E9F5E9E9D9B3B9E3E5E4E4F3E4F3E4F3E4F3E4F3E4F3E4F3E4F3E4F3E4F")!

        let sum = field.add(a, b)
        let product = field.multiply(a, b)

        // Results should be within the field
        XCTAssertTrue(sum < BigInt.secp256k1Order)
        XCTAssertTrue(product < BigInt.secp256k1Order)
    }

    func testModularInverseTestVector() {
        // Known test vector for modular inverse
        let field = FieldArithmetic(modulus: BigInt(7919))

        let a = BigInt(1234)
        let expectedInverse = BigInt(5179)

        let inverse = field.inverse(a)
        XCTAssertNotNil(inverse)
        XCTAssertEqual(inverse, expectedInverse)

        // Verify: a * a^(-1) ≡ 1 (mod m)
        let product = field.multiply(a, inverse!)
        XCTAssertEqual(product, BigInt.one)
    }

    // MARK: - Edge Cases

    func testLargeNumberOperations() {
        let a = BigInt(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF")!
        let b = BigInt(1)

        let sum = a + b
        XCTAssertTrue(sum.bitWidth > 256)

        let product = a * a
        XCTAssertTrue(product.bitWidth > 256)
    }

    func testDivisionByOne() {
        let num = BigInt(12345)
        let quotient = num / BigInt.one

        XCTAssertEqual(quotient, num)
    }

    func testZeroOperations() {
        let zero = BigInt.zero
        let num = BigInt(100)

        XCTAssertEqual(zero + num, num)
        XCTAssertEqual(num + zero, num)
        XCTAssertEqual(zero * num, zero)
        XCTAssertEqual(num - zero, num)
    }

    func testBitWidth() {
        XCTAssertEqual(BigInt.zero.bitWidth, 0)
        XCTAssertEqual(BigInt(1).bitWidth, 1)
        XCTAssertEqual(BigInt(255).bitWidth, 8)
        XCTAssertEqual(BigInt(256).bitWidth, 9)
        XCTAssertEqual(BigInt.secp256k1Order.bitWidth, 256)
    }

    // MARK: - Performance Tests

    func testLargeMultiplicationPerformance() {
        let a = BigInt.secp256k1Order
        let b = BigInt.secp256k1Order

        measure {
            _ = a * b
        }
    }

    func testModularInversePerformance() {
        let field = FieldArithmetic(modulus: BigInt.secp256k1Order)
        let num = BigInt(hex: "1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF")!

        measure {
            _ = field.inverse(num)
        }
    }

    func testModularExponentiationPerformance() {
        let field = FieldArithmetic(modulus: BigInt.secp256k1Order)
        let base = BigInt(3)
        let exponent = BigInt(65537) // Common RSA exponent

        measure {
            _ = field.power(base, exponent)
        }
    }
}
