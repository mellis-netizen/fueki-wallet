import Foundation

/// Production-grade polynomial arithmetic for Shamir's Secret Sharing
/// Implements proper Lagrange interpolation over finite fields
public class PolynomialArithmetic {

    private let field: FieldArithmetic

    public enum FieldType {
        case secp256k1Order
        case secp256k1Prime
        case ed25519Order
        case p256Order

        var modulus: BigInt {
            switch self {
            case .secp256k1Order:
                return BigInt.secp256k1Order
            case .secp256k1Prime:
                return BigInt.secp256k1Prime
            case .ed25519Order:
                return BigInt.ed25519Order
            case .p256Order:
                return BigInt.p256Order
            }
        }
    }

    public init(fieldType: FieldType) {
        self.field = FieldArithmetic(modulus: fieldType.modulus)
    }

    // MARK: - Polynomial Evaluation

    /// Evaluate polynomial at given point using Horner's method
    /// P(x) = a₀ + a₁x + a₂x² + ... + aₙxⁿ
    /// Using Horner's: P(x) = a₀ + x(a₁ + x(a₂ + x(...)))
    ///
    /// - Parameters:
    ///   - coefficients: Polynomial coefficients [a₀, a₁, a₂, ..., aₙ]
    ///   - x: Point at which to evaluate
    /// - Returns: P(x) mod fieldModulus
    public func evaluate(coefficients: [BigInt], at x: BigInt) -> BigInt {
        guard !coefficients.isEmpty else {
            return .zero
        }

        // Horner's method: start from highest degree coefficient
        var result = coefficients.last!

        // Work backwards from second-highest to lowest coefficient
        for i in stride(from: coefficients.count - 2, through: 0, by: -1) {
            // result = result * x + coefficients[i]
            result = field.multiply(result, x)
            result = field.add(result, coefficients[i])
        }

        return result
    }

    // MARK: - Lagrange Interpolation

    /// Reconstruct secret using Lagrange interpolation at x=0
    /// Given points (x₁,y₁), (x₂,y₂), ..., (xₖ,yₖ), compute P(0)
    ///
    /// L(x) = Σᵢ yᵢ · lᵢ(x)
    /// where lᵢ(x) = Πⱼ≠ᵢ (x - xⱼ)/(xᵢ - xⱼ)
    ///
    /// At x=0: L(0) = Σᵢ yᵢ · Πⱼ≠ᵢ (-xⱼ)/(xᵢ - xⱼ)
    ///
    /// - Parameter shares: Array of (index, value) pairs representing polynomial points
    /// - Returns: Secret value (polynomial evaluated at x=0)
    public func lagrangeInterpolation(shares: [(x: BigInt, y: BigInt)]) -> BigInt {
        guard !shares.isEmpty else {
            return .zero
        }

        if shares.count == 1 {
            return shares[0].y
        }

        var secret = BigInt.zero

        for i in 0..<shares.count {
            let (xᵢ, yᵢ) = shares[i]

            // Compute Lagrange basis polynomial lᵢ(0)
            var numerator = BigInt.one
            var denominator = BigInt.one

            for j in 0..<shares.count where i != j {
                let xⱼ = shares[j].x

                // numerator *= (0 - xⱼ) = -xⱼ
                numerator = field.multiply(numerator, field.negate(xⱼ))

                // denominator *= (xᵢ - xⱼ)
                let diff = field.subtract(xᵢ, xⱼ)
                denominator = field.multiply(denominator, diff)
            }

            // Compute lᵢ(0) = numerator / denominator
            // In modular arithmetic: division is multiplication by modular inverse
            guard let denominatorInverse = field.inverse(denominator) else {
                fatalError("Failed to compute modular inverse for Lagrange interpolation")
            }

            let lagrangeBasis = field.multiply(numerator, denominatorInverse)

            // Add yᵢ · lᵢ(0) to secret
            let term = field.multiply(yᵢ, lagrangeBasis)
            secret = field.add(secret, term)
        }

        return secret
    }

    /// Convenience method for Lagrange interpolation with UInt32 indices
    public func lagrangeInterpolation(shares: [(index: UInt32, value: Data)]) -> Data {
        let bigIntShares = shares.map { share in
            (x: BigInt(UInt64(share.index)), y: BigInt(data: share.value))
        }

        let secret = lagrangeInterpolation(shares: bigIntShares)
        return secret.toData(minLength: 32)
    }

    // MARK: - Share Generation

    /// Generate shares using polynomial evaluation
    /// Creates a random polynomial P(x) where P(0) = secret
    /// Then evaluates P(1), P(2), ..., P(n) to create n shares
    ///
    /// - Parameters:
    ///   - secret: The secret value (becomes a₀)
    ///   - threshold: Number of shares needed to reconstruct (degree + 1)
    ///   - totalShares: Total number of shares to generate
    ///   - randomCoefficients: Random coefficients a₁, a₂, ..., aₜ₋₁
    /// - Returns: Array of (index, value) pairs
    public func generateShares(
        secret: BigInt,
        threshold: Int,
        totalShares: Int,
        randomCoefficients: [BigInt]
    ) -> [(index: UInt32, value: BigInt)] {
        precondition(threshold > 0 && threshold <= totalShares, "Invalid threshold")
        precondition(randomCoefficients.count == threshold - 1, "Need exactly threshold-1 random coefficients")

        // Polynomial coefficients: [secret, random₁, random₂, ..., randomₜ₋₁]
        var coefficients = [secret]
        coefficients.append(contentsOf: randomCoefficients)

        // Generate shares by evaluating polynomial at x = 1, 2, 3, ..., n
        var shares: [(UInt32, BigInt)] = []

        for i in 1...totalShares {
            let x = BigInt(UInt64(i))
            let y = evaluate(coefficients: coefficients, at: x)
            shares.append((UInt32(i), y))
        }

        return shares
    }

    // MARK: - Verification

    /// Verify that shares lie on the same polynomial
    /// Useful for detecting corrupted shares
    ///
    /// - Parameters:
    ///   - shares: Shares to verify
    ///   - threshold: Expected threshold
    /// - Returns: True if shares are consistent
    public func verifyShares(shares: [(x: BigInt, y: BigInt)], threshold: Int) -> Bool {
        guard shares.count >= threshold else {
            return false
        }

        // Take exactly threshold shares and reconstruct
        let subset1 = Array(shares.prefix(threshold))
        let secret1 = lagrangeInterpolation(shares: subset1)

        // Try another combination if we have enough shares
        if shares.count > threshold {
            let subset2 = Array(shares.suffix(threshold))
            let secret2 = lagrangeInterpolation(shares: subset2)

            // Both combinations should yield same secret
            return secret1 == secret2
        }

        return true
    }
}

// MARK: - Polynomial Extension for Data

extension PolynomialArithmetic {

    /// Evaluate polynomial with Data coefficients
    public func evaluate(coefficients: [Data], at x: Data) -> Data {
        let bigIntCoeffs = coefficients.map { BigInt(data: $0) }
        let bigIntX = BigInt(data: x)
        let result = evaluate(coefficients: bigIntCoeffs, at: bigIntX)
        return result.toData(minLength: 32)
    }

    /// Generate shares with Data inputs
    public func generateShares(
        secret: Data,
        threshold: Int,
        totalShares: Int,
        randomCoefficients: [Data]
    ) -> [(index: UInt32, value: Data)] {
        let bigIntSecret = BigInt(data: secret)
        let bigIntCoeffs = randomCoefficients.map { BigInt(data: $0) }

        let shares = generateShares(
            secret: bigIntSecret,
            threshold: threshold,
            totalShares: totalShares,
            randomCoefficients: bigIntCoeffs
        )

        return shares.map { (index: $0.index, value: $0.value.toData(minLength: 32)) }
    }
}
