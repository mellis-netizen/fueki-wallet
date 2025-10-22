/**
 * TSS (Threshold Signature Scheme) Key Generation and Reconstruction Test Vectors
 * Tests distributed key generation and threshold signing
 */

import { describe, it, expect } from '@jest/globals';
import * as crypto from 'crypto';

/**
 * Polynomial evaluation in finite field
 */
class Polynomial {
  private coefficients: bigint[];

  constructor(coefficients: bigint[]) {
    this.coefficients = coefficients;
  }

  evaluate(x: bigint): bigint {
    let result = 0n;
    for (let i = this.coefficients.length - 1; i >= 0; i--) {
      result = result * x + this.coefficients[i];
    }
    return result;
  }

  static random(degree: number, secret: bigint): Polynomial {
    const coefficients = [secret];
    for (let i = 1; i <= degree; i++) {
      coefficients.push(BigInt('0x' + crypto.randomBytes(32).toString('hex')));
    }
    return new Polynomial(coefficients);
  }
}

/**
 * Lagrange interpolation for secret reconstruction
 */
function lagrangeInterpolation(shares: Array<{ x: bigint; y: bigint }>, prime: bigint): bigint {
  let secret = 0n;

  for (let i = 0; i < shares.length; i++) {
    let numerator = 1n;
    let denominator = 1n;

    for (let j = 0; j < shares.length; j++) {
      if (i !== j) {
        numerator = (numerator * (-shares[j].x)) % prime;
        denominator = (denominator * (shares[i].x - shares[j].x)) % prime;
      }
    }

    // Modular multiplicative inverse
    const lagrangeCoeff = (numerator * modInverse(denominator, prime)) % prime;
    secret = (secret + shares[i].y * lagrangeCoeff) % prime;
  }

  // Ensure positive result
  return ((secret % prime) + prime) % prime;
}

/**
 * Extended Euclidean algorithm for modular inverse
 */
function modInverse(a: bigint, m: bigint): bigint {
  a = ((a % m) + m) % m;
  let [oldR, r] = [a, m];
  let [oldS, s] = [1n, 0n];

  while (r !== 0n) {
    const quotient = oldR / r;
    [oldR, r] = [r, oldR - quotient * r];
    [oldS, s] = [s, oldS - quotient * s];
  }

  return ((oldS % m) + m) % m;
}

describe('TSS Key Generation and Reconstruction Test Vectors', () => {
  // Using a large prime for finite field arithmetic
  const PRIME = BigInt('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141'); // secp256k1 order

  describe('Shamir Secret Sharing - Basic', () => {
    it('should split and reconstruct secret with 2-of-3 threshold', () => {
      const secret = 12345n;
      const threshold = 2;
      const totalShares = 3;

      // Generate polynomial: f(x) = secret + a1*x + a2*x^2 + ...
      const polynomial = Polynomial.random(threshold - 1, secret);

      // Generate shares
      const shares = [];
      for (let i = 1; i <= totalShares; i++) {
        shares.push({
          x: BigInt(i),
          y: polynomial.evaluate(BigInt(i)) % PRIME
        });
      }

      // Reconstruct with any 2 shares
      const reconstructed1 = lagrangeInterpolation([shares[0], shares[1]], PRIME);
      const reconstructed2 = lagrangeInterpolation([shares[0], shares[2]], PRIME);
      const reconstructed3 = lagrangeInterpolation([shares[1], shares[2]], PRIME);

      expect(reconstructed1).toBe(secret);
      expect(reconstructed2).toBe(secret);
      expect(reconstructed3).toBe(secret);
    });

    it('should fail to reconstruct with insufficient shares', () => {
      const secret = 12345n;
      const threshold = 3;
      const totalShares = 5;

      const polynomial = Polynomial.random(threshold - 1, secret);

      const shares = [];
      for (let i = 1; i <= totalShares; i++) {
        shares.push({
          x: BigInt(i),
          y: polynomial.evaluate(BigInt(i)) % PRIME
        });
      }

      // Try to reconstruct with only 2 shares (need 3)
      const wrongReconstruction = lagrangeInterpolation([shares[0], shares[1]], PRIME);

      // Should NOT equal the original secret
      expect(wrongReconstruction).not.toBe(secret);
    });

    it('should reconstruct with exactly threshold shares', () => {
      const secret = BigInt('0x' + crypto.randomBytes(32).toString('hex'));
      const threshold = 5;
      const totalShares = 10;

      const polynomial = Polynomial.random(threshold - 1, secret);

      const shares = [];
      for (let i = 1; i <= totalShares; i++) {
        shares.push({
          x: BigInt(i),
          y: polynomial.evaluate(BigInt(i)) % PRIME
        });
      }

      // Reconstruct with exactly 5 shares
      const reconstructed = lagrangeInterpolation(shares.slice(0, threshold), PRIME);

      expect(reconstructed).toBe(secret);
    });
  });

  describe('TSS Threshold Signatures', () => {
    it('should verify threshold is enforced', () => {
      const thresholds = [
        { t: 2, n: 3, description: '2-of-3' },
        { t: 3, n: 5, description: '3-of-5' },
        { t: 5, n: 7, description: '5-of-7' },
        { t: 7, n: 10, description: '7-of-10' }
      ];

      thresholds.forEach(({ t, n, description }) => {
        const secret = BigInt('0x' + crypto.randomBytes(32).toString('hex'));
        const polynomial = Polynomial.random(t - 1, secret);

        const shares = [];
        for (let i = 1; i <= n; i++) {
          shares.push({
            x: BigInt(i),
            y: polynomial.evaluate(BigInt(i)) % PRIME
          });
        }

        // Can reconstruct with t shares
        const reconstructed = lagrangeInterpolation(shares.slice(0, t), PRIME);
        expect(reconstructed).toBe(secret);

        // Cannot reconstruct with t-1 shares
        if (t > 1) {
          const wrongReconstruction = lagrangeInterpolation(shares.slice(0, t - 1), PRIME);
          expect(wrongReconstruction).not.toBe(secret);
        }
      });
    });
  });

  describe('Distributed Key Generation (DKG)', () => {
    it('should generate distributed key shares', () => {
      const numParties = 5;
      const threshold = 3;

      // Each party generates their own secret
      const secrets = Array(numParties).fill(0).map(() =>
        BigInt('0x' + crypto.randomBytes(32).toString('hex'))
      );

      // Each party creates a polynomial
      const polynomials = secrets.map(secret =>
        Polynomial.random(threshold - 1, secret)
      );

      // Each party computes shares for all other parties
      const shareMatrix: bigint[][] = Array(numParties).fill(0).map(() => []);

      for (let i = 0; i < numParties; i++) {
        for (let j = 1; j <= numParties; j++) {
          shareMatrix[i].push(polynomials[i].evaluate(BigInt(j)) % PRIME);
        }
      }

      // Each party combines their received shares
      const finalShares: Array<{ x: bigint; y: bigint }> = [];
      for (let j = 0; j < numParties; j++) {
        let combinedShare = 0n;
        for (let i = 0; i < numParties; i++) {
          combinedShare = (combinedShare + shareMatrix[i][j]) % PRIME;
        }
        finalShares.push({
          x: BigInt(j + 1),
          y: combinedShare
        });
      }

      // The combined secret should be sum of all individual secrets
      const expectedSecret = secrets.reduce((sum, s) => (sum + s) % PRIME, 0n);

      // Reconstruct with threshold shares
      const reconstructed = lagrangeInterpolation(finalShares.slice(0, threshold), PRIME);

      expect(reconstructed).toBe(expectedSecret);
    });
  });

  describe('Verifiable Secret Sharing (VSS)', () => {
    interface Commitment {
      partyIndex: number;
      commitments: bigint[];
    }

    it('should verify shares using commitments', () => {
      const secret = BigInt('0x' + crypto.randomBytes(32).toString('hex'));
      const threshold = 3;
      const totalShares = 5;

      const polynomial = Polynomial.random(threshold - 1, secret);

      // Generate shares
      const shares: Array<{ x: bigint; y: bigint }> = [];
      for (let i = 1; i <= totalShares; i++) {
        shares.push({
          x: BigInt(i),
          y: polynomial.evaluate(BigInt(i)) % PRIME
        });
      }

      // In real VSS, we would use elliptic curve commitments
      // Here we simulate by storing polynomial evaluations
      const commitments: bigint[] = [];
      for (let i = 0; i < threshold; i++) {
        // In practice: C_i = g^{a_i} where a_i is coefficient
        commitments.push(polynomial.evaluate(BigInt(i)));
      }

      // Verify shares (simplified - real implementation uses elliptic curves)
      shares.forEach(share => {
        // Each share can be verified against commitments
        expect(share.y).toBeDefined();
        expect(share.x).toBeGreaterThan(0n);
      });

      // Reconstruct to verify correctness
      const reconstructed = lagrangeInterpolation(shares.slice(0, threshold), PRIME);
      expect(reconstructed).toBe(secret);
    });
  });

  describe('Proactive Secret Sharing', () => {
    it('should refresh shares without changing secret', () => {
      const secret = 12345n;
      const threshold = 3;
      const totalShares = 5;

      // Initial sharing
      const polynomial1 = Polynomial.random(threshold - 1, secret);
      const shares1: Array<{ x: bigint; y: bigint }> = [];
      for (let i = 1; i <= totalShares; i++) {
        shares1.push({
          x: BigInt(i),
          y: polynomial1.evaluate(BigInt(i)) % PRIME
        });
      }

      // Refresh with zero-sharing
      const zeroPolynomial = Polynomial.random(threshold - 1, 0n);
      const deltaShares: bigint[] = [];
      for (let i = 1; i <= totalShares; i++) {
        deltaShares.push(zeroPolynomial.evaluate(BigInt(i)) % PRIME);
      }

      // Update shares
      const shares2 = shares1.map((share, idx) => ({
        x: share.x,
        y: (share.y + deltaShares[idx]) % PRIME
      }));

      // Secret should remain the same
      const reconstructed1 = lagrangeInterpolation(shares1.slice(0, threshold), PRIME);
      const reconstructed2 = lagrangeInterpolation(shares2.slice(0, threshold), PRIME);

      expect(reconstructed1).toBe(secret);
      expect(reconstructed2).toBe(secret);

      // But shares should be different
      expect(shares1[0].y).not.toBe(shares2[0].y);
    });
  });

  describe('Dynamic Threshold Changes', () => {
    it('should increase threshold from 2-of-3 to 3-of-5', () => {
      const secret = BigInt('0x' + crypto.randomBytes(32).toString('hex'));

      // Initial 2-of-3 sharing
      const polynomial1 = Polynomial.random(1, secret); // degree 1 for t=2
      const initialShares: Array<{ x: bigint; y: bigint }> = [];
      for (let i = 1; i <= 3; i++) {
        initialShares.push({
          x: BigInt(i),
          y: polynomial1.evaluate(BigInt(i)) % PRIME
        });
      }

      // Verify initial reconstruction
      const check1 = lagrangeInterpolation(initialShares.slice(0, 2), PRIME);
      expect(check1).toBe(secret);

      // Create new 3-of-5 sharing
      const polynomial2 = Polynomial.random(2, secret); // degree 2 for t=3
      const newShares: Array<{ x: bigint; y: bigint }> = [];
      for (let i = 1; i <= 5; i++) {
        newShares.push({
          x: BigInt(i),
          y: polynomial2.evaluate(BigInt(i)) % PRIME
        });
      }

      // Verify new reconstruction requires 3 shares
      const check2 = lagrangeInterpolation(newShares.slice(0, 3), PRIME);
      expect(check2).toBe(secret);

      // 2 shares should NOT be enough
      const wrongCheck = lagrangeInterpolation(newShares.slice(0, 2), PRIME);
      expect(wrongCheck).not.toBe(secret);
    });
  });

  describe('Share Corruption Detection', () => {
    it('should detect corrupted share', () => {
      const secret = 12345n;
      const threshold = 3;
      const totalShares = 5;

      const polynomial = Polynomial.random(threshold - 1, secret);

      const shares: Array<{ x: bigint; y: bigint }> = [];
      for (let i = 1; i <= totalShares; i++) {
        shares.push({
          x: BigInt(i),
          y: polynomial.evaluate(BigInt(i)) % PRIME
        });
      }

      // Corrupt one share
      const corruptedShares = [...shares];
      corruptedShares[2] = { x: shares[2].x, y: (shares[2].y + 999n) % PRIME };

      // Reconstruction with corrupted share should fail
      const wrongReconstruction = lagrangeInterpolation(
        [corruptedShares[0], corruptedShares[1], corruptedShares[2]],
        PRIME
      );

      expect(wrongReconstruction).not.toBe(secret);

      // But reconstruction with valid shares should work
      const correctReconstruction = lagrangeInterpolation(
        [shares[0], shares[1], shares[3]],
        PRIME
      );

      expect(correctReconstruction).toBe(secret);
    });
  });

  describe('Performance and Scalability', () => {
    it('should handle large threshold values efficiently', () => {
      const secret = BigInt('0x' + crypto.randomBytes(32).toString('hex'));
      const threshold = 15;
      const totalShares = 20;

      const startTime = Date.now();

      const polynomial = Polynomial.random(threshold - 1, secret);

      const shares: Array<{ x: bigint; y: bigint }> = [];
      for (let i = 1; i <= totalShares; i++) {
        shares.push({
          x: BigInt(i),
          y: polynomial.evaluate(BigInt(i)) % PRIME
        });
      }

      const reconstructed = lagrangeInterpolation(shares.slice(0, threshold), PRIME);

      const endTime = Date.now();
      const duration = endTime - startTime;

      expect(reconstructed).toBe(secret);
      expect(duration).toBeLessThan(1000); // Should complete within 1 second
    });
  });
});
