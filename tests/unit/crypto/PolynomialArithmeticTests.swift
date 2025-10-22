import XCTest
@testable import FuekiWallet

/// Comprehensive tests for polynomial arithmetic and Shamir's Secret Sharing
/// Tests polynomial evaluation, Lagrange interpolation, and share generation
class PolynomialArithmeticTests: XCTestCase {

    var polynomial: PolynomialArithmetic!

    override func setUp() {
        super.setUp()
        polynomial = PolynomialArithmetic(fieldType: .secp256k1Order)
    }

    override func tearDown() {
        polynomial = nil
        super.tearDown()
    }

    // MARK: - Polynomial Evaluation Tests

    func testPolynomialEvaluationConstant() {
        // P(x) = 5
        let coefficients = [BigInt(5)]
        let x = BigInt(100)

        let result = polynomial.evaluate(coefficients: coefficients, at: x)

        // Constant polynomial always returns same value
        XCTAssertEqual(result, BigInt(5))
    }

    func testPolynomialEvaluationLinear() {
        // P(x) = 3 + 2x
        let coefficients = [BigInt(3), BigInt(2)]
        let x = BigInt(5)

        let result = polynomial.evaluate(coefficients: coefficients, at: x)

        // P(5) = 3 + 2*5 = 13
        XCTAssertEqual(result, BigInt(13))
    }

    func testPolynomialEvaluationQuadratic() {
        // P(x) = 1 + 2x + 3x²
        let coefficients = [BigInt(1), BigInt(2), BigInt(3)]
        let x = BigInt(4)

        let result = polynomial.evaluate(coefficients: coefficients, at: x)

        // P(4) = 1 + 2*4 + 3*16 = 1 + 8 + 48 = 57
        XCTAssertEqual(result, BigInt(57))
    }

    func testPolynomialEvaluationAtZero() {
        // P(x) = 42 + 10x + 5x²
        let coefficients = [BigInt(42), BigInt(10), BigInt(5)]
        let x = BigInt.zero

        let result = polynomial.evaluate(coefficients: coefficients, at: x)

        // P(0) should equal the constant term
        XCTAssertEqual(result, BigInt(42))
    }

    // MARK: - Lagrange Interpolation Tests

    func testLagrangeInterpolationTwoPoints() {
        // Two points uniquely define a line: (1, 3) and (2, 5)
        // Line equation: y = 1 + 2x
        // Therefore P(0) = 1

        let shares = [
            (x: BigInt(1), y: BigInt(3)),
            (x: BigInt(2), y: BigInt(5))
        ]

        let secret = polynomial.lagrangeInterpolation(shares: shares)

        XCTAssertEqual(secret, BigInt(1))
    }

    func testLagrangeInterpolationThreePoints() {
        // Three points define a quadratic: (1, 6), (2, 11), (3, 18)
        // Polynomial: y = 3 + 2x + x²
        // Therefore P(0) = 3

        let shares = [
            (x: BigInt(1), y: BigInt(6)),
            (x: BigInt(2), y: BigInt(11)),
            (x: BigInt(3), y: BigInt(18))
        ]

        let secret = polynomial.lagrangeInterpolation(shares: shares)

        XCTAssertEqual(secret, BigInt(3))
    }

    func testLagrangeInterpolationFourPoints() {
        // Four points from cubic: P(x) = 5 + x + 2x² + 3x³
        let coefficients = [BigInt(5), BigInt(1), BigInt(2), BigInt(3)]

        var shares: [(BigInt, BigInt)] = []
        for i in 1...4 {
            let x = BigInt(UInt64(i))
            let y = polynomial.evaluate(coefficients: coefficients, at: x)
            shares.append((x, y))
        }

        let reconstructed = polynomial.lagrangeInterpolation(shares: shares)

        // Should recover the secret (constant term)
        XCTAssertEqual(reconstructed, BigInt(5))
    }

    func testLagrangeInterpolationWithExtraShares() {
        // Generate 5 points from a polynomial with threshold 3
        // Any 3+ points should reconstruct the same secret

        let secret = BigInt(42)
        let coefficients = [secret, BigInt(7), BigInt(13)]

        var shares: [(BigInt, BigInt)] = []
        for i in 1...5 {
            let x = BigInt(UInt64(i))
            let y = polynomial.evaluate(coefficients: coefficients, at: x)
            shares.append((x, y))
        }

        // Test with exactly 3 shares
        let reconstructed3 = polynomial.lagrangeInterpolation(shares: Array(shares[0..<3]))
        XCTAssertEqual(reconstructed3, secret)

        // Test with 4 shares
        let reconstructed4 = polynomial.lagrangeInterpolation(shares: Array(shares[0..<4]))
        XCTAssertEqual(reconstructed4, secret)

        // Test with all 5 shares
        let reconstructed5 = polynomial.lagrangeInterpolation(shares: shares)
        XCTAssertEqual(reconstructed5, secret)
    }

    func testLagrangeInterpolationDifferentCombinations() {
        // Generate 5 shares with threshold 3
        let secret = BigInt(123)
        let coefficients = [secret, BigInt(456), BigInt(789)]

        var allShares: [(BigInt, BigInt)] = []
        for i in 1...5 {
            let x = BigInt(UInt64(i))
            let y = polynomial.evaluate(coefficients: coefficients, at: x)
            allShares.append((x, y))
        }

        // Test different combinations of 3 shares
        let combo1 = [allShares[0], allShares[1], allShares[2]]
        let combo2 = [allShares[0], allShares[2], allShares[4]]
        let combo3 = [allShares[1], allShares[3], allShares[4]]

        let result1 = polynomial.lagrangeInterpolation(shares: combo1)
        let result2 = polynomial.lagrangeInterpolation(shares: combo2)
        let result3 = polynomial.lagrangeInterpolation(shares: combo3)

        XCTAssertEqual(result1, secret)
        XCTAssertEqual(result2, secret)
        XCTAssertEqual(result3, secret)
    }

    // MARK: - Share Generation Tests

    func testShareGeneration2of3() {
        let secret = BigInt(999)
        let randomCoeff = BigInt(111)

        let shares = polynomial.generateShares(
            secret: secret,
            threshold: 2,
            totalShares: 3,
            randomCoefficients: [randomCoeff]
        )

        XCTAssertEqual(shares.count, 3)

        // All shares should be unique
        let values = shares.map { $0.value }
        XCTAssertEqual(Set(values).count, 3)

        // Any 2 shares should reconstruct the secret
        let reconstructed = polynomial.lagrangeInterpolation(shares: [
            (x: BigInt(UInt64(shares[0].index)), y: shares[0].value),
            (x: BigInt(UInt64(shares[1].index)), y: shares[1].value)
        ])

        XCTAssertEqual(reconstructed, secret)
    }

    func testShareGeneration3of5() {
        let secret = BigInt(12345)
        let randomCoeffs = [BigInt(111), BigInt(222)]

        let shares = polynomial.generateShares(
            secret: secret,
            threshold: 3,
            totalShares: 5,
            randomCoefficients: randomCoeffs
        )

        XCTAssertEqual(shares.count, 5)

        // Test reconstruction with exactly threshold shares
        let subset = shares[0..<3]
        let reconstructed = polynomial.lagrangeInterpolation(shares: subset.map {
            (x: BigInt(UInt64($0.index)), y: $0.value)
        })

        XCTAssertEqual(reconstructed, secret)
    }

    // MARK: - Shamir's Secret Sharing Integration Tests

    func testShamirSecretSharingRoundTrip() {
        // Complete workflow: generate shares and reconstruct
        let originalSecret = BigInt(hex: "DEADBEEFCAFEBABE1234567890ABCDEF")!

        // Generate random coefficients for threshold-1
        let threshold = 3
        let totalShares = 5
        let randomCoeffs = [
            BigInt(hex: "1111111111111111111111111111111111111111111111111111111111111111")!,
            BigInt(hex: "2222222222222222222222222222222222222222222222222222222222222222")!
        ]

        // Generate shares
        let shares = polynomial.generateShares(
            secret: originalSecret,
            threshold: threshold,
            totalShares: totalShares,
            randomCoefficients: randomCoeffs
        )

        // Reconstruct from threshold shares
        let selectedShares = shares[0..<threshold]
        let reconstructed = polynomial.lagrangeInterpolation(shares: selectedShares.map {
            (x: BigInt(UInt64($0.index)), y: $0.value)
        })

        XCTAssertEqual(reconstructed, originalSecret)
    }

    func testShamirSecretSharingWithSecp256k1Secret() {
        // Test with a typical secp256k1 private key
        let privateKey = BigInt(hex: "E9873D79C6D87DC0FB6A5778633389F4453213303DA61F20BD67FC233AA33262")!

        let threshold = 2
        let totalShares = 3
        let randomCoeffs = [
            BigInt(hex: "3333333333333333333333333333333333333333333333333333333333333333")!
        ]

        let shares = polynomial.generateShares(
            secret: privateKey,
            threshold: threshold,
            totalShares: totalShares,
            randomCoefficients: randomCoeffs
        )

        // Test different share combinations
        for i in 0..<totalShares {
            for j in (i+1)..<totalShares {
                let twoShares = [shares[i], shares[j]]
                let reconstructed = polynomial.lagrangeInterpolation(shares: twoShares.map {
                    (x: BigInt(UInt64($0.index)), y: $0.value)
                })

                XCTAssertEqual(reconstructed, privateKey)
            }
        }
    }

    // MARK: - Data Conversion Tests

    func testDataConversionRoundTrip() {
        let secretData = Data(hex: "DEADBEEFCAFEBABE1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF")!

        let threshold = 2
        let totalShares = 3
        let randomCoeffsData = [
            Data(hex: "1111111111111111111111111111111111111111111111111111111111111111")!
        ]

        // Generate shares using Data interface
        let shares = polynomial.generateShares(
            secret: secretData,
            threshold: threshold,
            totalShares: totalShares,
            randomCoefficients: randomCoeffsData
        )

        // Reconstruct using Data interface
        let reconstructed = polynomial.lagrangeInterpolation(shares: shares)

        XCTAssertEqual(reconstructed, secretData)
    }

    // MARK: - Share Verification Tests

    func testShareVerificationValid() {
        let secret = BigInt(777)
        let randomCoeffs = [BigInt(888), BigInt(999)]

        let shares = polynomial.generateShares(
            secret: secret,
            threshold: 3,
            totalShares: 5,
            randomCoefficients: randomCoeffs
        )

        let bigIntShares = shares.map { (x: BigInt(UInt64($0.index)), y: $0.value) }

        let isValid = polynomial.verifyShares(shares: bigIntShares, threshold: 3)
        XCTAssertTrue(isValid)
    }

    func testShareVerificationInvalid() {
        let secret = BigInt(777)
        let randomCoeffs = [BigInt(888), BigInt(999)]

        var shares = polynomial.generateShares(
            secret: secret,
            threshold: 3,
            totalShares: 5,
            randomCoefficients: randomCoeffs
        )

        // Corrupt one share
        shares[2].value = shares[2].value + BigInt(1)

        let bigIntShares = shares.map { (x: BigInt(UInt64($0.index)), y: $0.value) }

        // With corrupted share, different combinations will give different results
        // This test verifies the verification would catch inconsistency
        if shares.count > 3 {
            let subset1 = [bigIntShares[0], bigIntShares[1], bigIntShares[2]]
            let subset2 = [bigIntShares[0], bigIntShares[1], bigIntShares[3]]

            let result1 = polynomial.lagrangeInterpolation(shares: subset1)
            let result2 = polynomial.lagrangeInterpolation(shares: subset2)

            // Different subsets should give different results when shares are corrupted
            XCTAssertNotEqual(result1, result2)
        }
    }

    // MARK: - Edge Cases

    func testSingleShareThreshold1of1() {
        // Degenerate case: threshold 1 of 1
        let secret = BigInt(42)

        let shares = polynomial.generateShares(
            secret: secret,
            threshold: 1,
            totalShares: 1,
            randomCoefficients: []
        )

        XCTAssertEqual(shares.count, 1)

        let reconstructed = polynomial.lagrangeInterpolation(shares: [
            (x: BigInt(UInt64(shares[0].index)), y: shares[0].value)
        ])

        XCTAssertEqual(reconstructed, secret)
    }

    func testLargeThreshold() {
        // Test with threshold 10 of 15
        let secret = BigInt(99999)
        var randomCoeffs: [BigInt] = []
        for i in 1...9 {
            randomCoeffs.append(BigInt(UInt64(i * 1111)))
        }

        let shares = polynomial.generateShares(
            secret: secret,
            threshold: 10,
            totalShares: 15,
            randomCoefficients: randomCoeffs
        )

        XCTAssertEqual(shares.count, 15)

        // Reconstruct with exactly 10 shares
        let subset = shares[0..<10]
        let reconstructed = polynomial.lagrangeInterpolation(shares: subset.map {
            (x: BigInt(UInt64($0.index)), y: $0.value)
        })

        XCTAssertEqual(reconstructed, secret)
    }

    // MARK: - Performance Tests

    func testShareGenerationPerformance() {
        let secret = BigInt.secp256k1Order
        let randomCoeffs = [BigInt(1), BigInt(2)]

        measure {
            _ = polynomial.generateShares(
                secret: secret,
                threshold: 3,
                totalShares: 5,
                randomCoefficients: randomCoeffs
            )
        }
    }

    func testLagrangeInterpolationPerformance() {
        let secret = BigInt.secp256k1Order
        let randomCoeffs = [BigInt(1), BigInt(2)]

        let shares = polynomial.generateShares(
            secret: secret,
            threshold: 3,
            totalShares: 5,
            randomCoefficients: randomCoeffs
        )

        let bigIntShares = shares.map { (x: BigInt(UInt64($0.index)), y: $0.value) }

        measure {
            _ = polynomial.lagrangeInterpolation(shares: Array(bigIntShares[0..<3]))
        }
    }
}

// MARK: - Data Extension Helper

extension Data {
    init?(hex: String) {
        let cleanHex = hex.replacingOccurrences(of: "0x", with: "")
        guard cleanHex.count % 2 == 0 else { return nil }

        var data = Data(capacity: cleanHex.count / 2)
        var index = cleanHex.startIndex

        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            guard let byte = UInt8(cleanHex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }

        self = data
    }
}
