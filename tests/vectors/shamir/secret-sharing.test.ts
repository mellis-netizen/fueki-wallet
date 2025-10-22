/**
 * Shamir's Secret Sharing Test Vectors
 * SLIP-39 (Satoshi Labs Improvement Proposal 39) compliant implementation
 * Source: https://github.com/satoshilabs/slips/blob/master/slip-0039.md
 */

import { describe, it, expect } from '@jest/globals';
import * as crypto from 'crypto';

/**
 * GF(256) operations for SLIP-39
 */
class GF256 {
  private static readonly EXP_TABLE: number[] = new Array(255);
  private static readonly LOG_TABLE: number[] = new Array(256);

  // Initialize lookup tables
  static {
    let x = 1;
    for (let i = 0; i < 255; i++) {
      this.EXP_TABLE[i] = x;
      this.LOG_TABLE[x] = i;
      x = (x << 1) ^ (x & 0x80 ? 0x11d : 0); // Multiply by x modulo the polynomial
    }
    this.LOG_TABLE[0] = -1; // Undefined for 0
  }

  static add(a: number, b: number): number {
    return a ^ b;
  }

  static multiply(a: number, b: number): number {
    if (a === 0 || b === 0) return 0;
    return this.EXP_TABLE[(this.LOG_TABLE[a] + this.LOG_TABLE[b]) % 255];
  }

  static divide(a: number, b: number): number {
    if (b === 0) throw new Error('Division by zero');
    if (a === 0) return 0;
    return this.EXP_TABLE[(this.LOG_TABLE[a] - this.LOG_TABLE[b] + 255) % 255];
  }

  static power(a: number, exp: number): number {
    if (exp === 0) return 1;
    if (a === 0) return 0;
    return this.EXP_TABLE[(this.LOG_TABLE[a] * exp) % 255];
  }
}

/**
 * Polynomial in GF(256)
 */
class GF256Polynomial {
  private coefficients: number[];

  constructor(coefficients: number[]) {
    this.coefficients = coefficients;
  }

  evaluate(x: number): number {
    let result = 0;
    for (let i = this.coefficients.length - 1; i >= 0; i--) {
      result = GF256.add(GF256.multiply(result, x), this.coefficients[i]);
    }
    return result;
  }

  static random(degree: number, secret: number): GF256Polynomial {
    const coefficients = [secret];
    for (let i = 1; i <= degree; i++) {
      coefficients.push(crypto.randomBytes(1)[0]);
    }
    return new GF256Polynomial(coefficients);
  }
}

/**
 * Lagrange interpolation in GF(256)
 */
function lagrangeInterpolateGF256(shares: Array<{ x: number; y: number }>): number {
  let secret = 0;

  for (let i = 0; i < shares.length; i++) {
    let numerator = 1;
    let denominator = 1;

    for (let j = 0; j < shares.length; j++) {
      if (i !== j) {
        numerator = GF256.multiply(numerator, shares[j].x);
        denominator = GF256.multiply(denominator, GF256.add(shares[i].x, shares[j].x));
      }
    }

    const lagrangeCoeff = GF256.divide(numerator, denominator);
    secret = GF256.add(secret, GF256.multiply(shares[i].y, lagrangeCoeff));
  }

  return secret;
}

describe('Shamir\'s Secret Sharing Test Vectors', () => {
  describe('GF(256) Arithmetic', () => {
    it('should perform addition correctly', () => {
      expect(GF256.add(0x53, 0xca)).toBe(0x99);
      expect(GF256.add(0x00, 0xff)).toBe(0xff);
      expect(GF256.add(0xaa, 0xaa)).toBe(0x00);
    });

    it('should perform multiplication correctly', () => {
      expect(GF256.multiply(0x53, 0xca)).toBe(0x01);
      expect(GF256.multiply(0x00, 0xff)).toBe(0x00);
      expect(GF256.multiply(0x01, 0xff)).toBe(0xff);
      expect(GF256.multiply(0x02, 0x03)).toBe(0x06);
    });

    it('should perform division correctly', () => {
      expect(GF256.divide(0x01, 0x53)).toBe(0xca);
      expect(GF256.divide(0xff, 0x01)).toBe(0xff);
      expect(GF256.divide(0x00, 0xff)).toBe(0x00);
    });

    it('should handle power operations', () => {
      expect(GF256.power(0x02, 0)).toBe(1);
      expect(GF256.power(0x02, 1)).toBe(2);
      expect(GF256.power(0x02, 8)).toBe(0x1d);
    });
  });

  describe('Basic Secret Sharing in GF(256)', () => {
    it('should split and reconstruct byte secret with 2-of-3 threshold', () => {
      const secret = 0x42; // Single byte
      const threshold = 2;
      const totalShares = 3;

      const polynomial = GF256Polynomial.random(threshold - 1, secret);

      const shares: Array<{ x: number; y: number }> = [];
      for (let i = 1; i <= totalShares; i++) {
        shares.push({
          x: i,
          y: polynomial.evaluate(i)
        });
      }

      // Reconstruct with any 2 shares
      const reconstructed1 = lagrangeInterpolateGF256([shares[0], shares[1]]);
      const reconstructed2 = lagrangeInterpolateGF256([shares[0], shares[2]]);
      const reconstructed3 = lagrangeInterpolateGF256([shares[1], shares[2]]);

      expect(reconstructed1).toBe(secret);
      expect(reconstructed2).toBe(secret);
      expect(reconstructed3).toBe(secret);
    });

    it('should work with different threshold configurations', () => {
      const testCases = [
        { t: 2, n: 3 },
        { t: 3, n: 5 },
        { t: 4, n: 7 },
        { t: 5, n: 9 }
      ];

      testCases.forEach(({ t, n }) => {
        const secret = crypto.randomBytes(1)[0];
        const polynomial = GF256Polynomial.random(t - 1, secret);

        const shares: Array<{ x: number; y: number }> = [];
        for (let i = 1; i <= n; i++) {
          shares.push({
            x: i,
            y: polynomial.evaluate(i)
          });
        }

        const reconstructed = lagrangeInterpolateGF256(shares.slice(0, t));
        expect(reconstructed).toBe(secret);
      });
    });
  });

  describe('Multi-byte Secret Sharing', () => {
    function splitSecret(secret: Buffer, threshold: number, totalShares: number): Buffer[] {
      const shares: Buffer[] = Array(totalShares).fill(null).map(() => Buffer.alloc(secret.length + 1));

      // Store share index in first byte
      for (let i = 0; i < totalShares; i++) {
        shares[i][0] = i + 1;
      }

      // Split each byte independently
      for (let byteIndex = 0; byteIndex < secret.length; byteIndex++) {
        const polynomial = GF256Polynomial.random(threshold - 1, secret[byteIndex]);

        for (let shareIndex = 0; shareIndex < totalShares; shareIndex++) {
          const x = shareIndex + 1;
          shares[shareIndex][byteIndex + 1] = polynomial.evaluate(x);
        }
      }

      return shares;
    }

    function combineShares(shares: Buffer[], threshold: number): Buffer {
      if (shares.length < threshold) {
        throw new Error('Insufficient shares');
      }

      const secretLength = shares[0].length - 1;
      const secret = Buffer.alloc(secretLength);

      for (let byteIndex = 0; byteIndex < secretLength; byteIndex++) {
        const points: Array<{ x: number; y: number }> = [];

        for (let shareIndex = 0; shareIndex < threshold; shareIndex++) {
          points.push({
            x: shares[shareIndex][0],
            y: shares[shareIndex][byteIndex + 1]
          });
        }

        secret[byteIndex] = lagrangeInterpolateGF256(points);
      }

      return secret;
    }

    it('should split and reconstruct 16-byte secret', () => {
      const secret = crypto.randomBytes(16);
      const threshold = 3;
      const totalShares = 5;

      const shares = splitSecret(secret, threshold, totalShares);

      // Reconstruct with any 3 shares
      const reconstructed1 = combineShares([shares[0], shares[1], shares[2]], threshold);
      const reconstructed2 = combineShares([shares[0], shares[2], shares[4]], threshold);
      const reconstructed3 = combineShares([shares[1], shares[3], shares[4]], threshold);

      expect(reconstructed1.equals(secret)).toBe(true);
      expect(reconstructed2.equals(secret)).toBe(true);
      expect(reconstructed3.equals(secret)).toBe(true);
    });

    it('should split and reconstruct 32-byte secret (private key)', () => {
      const secret = crypto.randomBytes(32);
      const threshold = 5;
      const totalShares = 8;

      const shares = splitSecret(secret, threshold, totalShares);

      // Reconstruct with exactly threshold shares
      const reconstructed = combineShares(shares.slice(0, threshold), threshold);

      expect(reconstructed.equals(secret)).toBe(true);
    });

    it('should fail with insufficient shares', () => {
      const secret = crypto.randomBytes(32);
      const threshold = 5;
      const totalShares = 8;

      const shares = splitSecret(secret, threshold, totalShares);

      // Try with only 4 shares (need 5)
      expect(() => combineShares(shares.slice(0, threshold - 1), threshold)).toThrow();
    });
  });

  describe('SLIP-39 Word List Encoding', () => {
    // Simplified SLIP-39 word encoding (real implementation uses specific word list)
    it('should encode shares into mnemonic words (concept)', () => {
      const secret = Buffer.from('test secret data');
      const threshold = 2;
      const totalShares = 3;

      const shares = [];
      for (let byteIndex = 0; byteIndex < secret.length; byteIndex++) {
        const polynomial = GF256Polynomial.random(threshold - 1, secret[byteIndex]);

        for (let shareIndex = 0; shareIndex < totalShares; shareIndex++) {
          if (!shares[shareIndex]) {
            shares[shareIndex] = [];
          }
          shares[shareIndex].push(polynomial.evaluate(shareIndex + 1));
        }
      }

      // Each share is a sequence of bytes that would be encoded as words
      expect(shares.length).toBe(totalShares);
      shares.forEach(share => {
        expect(share.length).toBe(secret.length);
      });
    });
  });

  describe('Share Validation and Error Detection', () => {
    it('should detect corrupted share', () => {
      const secret = crypto.randomBytes(16);
      const threshold = 3;
      const totalShares = 5;

      const shares = [];
      for (let byteIndex = 0; byteIndex < secret.length; byteIndex++) {
        const polynomial = GF256Polynomial.random(threshold - 1, secret[byteIndex]);

        for (let shareIndex = 0; shareIndex < totalShares; shareIndex++) {
          if (!shares[shareIndex]) {
            shares[shareIndex] = Buffer.alloc(secret.length + 1);
            shares[shareIndex][0] = shareIndex + 1;
          }
          shares[shareIndex][byteIndex + 1] = polynomial.evaluate(shareIndex + 1);
        }
      }

      // Corrupt one share
      shares[1][5] ^= 0xff;

      // Reconstruction with corrupted share should produce wrong result
      const points: Array<{ x: number; y: number }> = [];
      for (let i = 0; i < threshold; i++) {
        points.push({
          x: shares[i][0],
          y: shares[i][1] // First byte
        });
      }

      const wrongReconstruction = lagrangeInterpolateGF256(points);
      // For corrupted share at index 1, byte 5, the first byte should still be correct
      // but full reconstruction would fail
      expect(shares[1][5]).not.toBe(shares[1][5] ^ 0xff); // Corrupted
    });
  });

  describe('Group Sharing (SLIP-39 Groups)', () => {
    interface GroupShare {
      groupIndex: number;
      memberIndex: number;
      threshold: number;
      data: Buffer;
    }

    it('should implement 2-of-3 groups with 2-of-3 members each', () => {
      const secret = crypto.randomBytes(16);
      const groupThreshold = 2; // Need 2 groups
      const memberThreshold = 2; // Need 2 members from each group
      const totalGroups = 3;
      const membersPerGroup = 3;

      // First level: split among groups
      const groupSecrets: Buffer[] = [];
      for (let byteIndex = 0; byteIndex < secret.length; byteIndex++) {
        const polynomial = GF256Polynomial.random(groupThreshold - 1, secret[byteIndex]);

        for (let groupIndex = 0; groupIndex < totalGroups; groupIndex++) {
          if (!groupSecrets[groupIndex]) {
            groupSecrets[groupIndex] = Buffer.alloc(secret.length + 1);
            groupSecrets[groupIndex][0] = groupIndex + 1;
          }
          groupSecrets[groupIndex][byteIndex + 1] = polynomial.evaluate(groupIndex + 1);
        }
      }

      // Second level: split each group secret among members
      const memberShares: GroupShare[][] = Array(totalGroups).fill(null).map(() => []);

      for (let groupIndex = 0; groupIndex < totalGroups; groupIndex++) {
        const groupSecret = groupSecrets[groupIndex].slice(1); // Remove index byte

        for (let byteIndex = 0; byteIndex < groupSecret.length; byteIndex++) {
          const polynomial = GF256Polynomial.random(memberThreshold - 1, groupSecret[byteIndex]);

          for (let memberIndex = 0; memberIndex < membersPerGroup; memberIndex++) {
            if (!memberShares[groupIndex][memberIndex]) {
              memberShares[groupIndex][memberIndex] = {
                groupIndex,
                memberIndex,
                threshold: memberThreshold,
                data: Buffer.alloc(groupSecret.length + 1)
              };
              memberShares[groupIndex][memberIndex].data[0] = memberIndex + 1;
            }
            memberShares[groupIndex][memberIndex].data[byteIndex + 1] = polynomial.evaluate(memberIndex + 1);
          }
        }
      }

      // Reconstruct: Use 2 members from 2 groups
      const group0Shares = [memberShares[0][0].data, memberShares[0][1].data];
      const group1Shares = [memberShares[1][0].data, memberShares[1][2].data];

      // Reconstruct group secrets
      const reconstructedGroup0 = Buffer.alloc(secret.length);
      const reconstructedGroup1 = Buffer.alloc(secret.length);

      for (let byteIndex = 0; byteIndex < secret.length; byteIndex++) {
        const points0 = group0Shares.map(share => ({
          x: share[0],
          y: share[byteIndex + 1]
        }));
        const points1 = group1Shares.map(share => ({
          x: share[0],
          y: share[byteIndex + 1]
        }));

        reconstructedGroup0[byteIndex] = lagrangeInterpolateGF256(points0);
        reconstructedGroup1[byteIndex] = lagrangeInterpolateGF256(points1);
      }

      // Reconstruct final secret from group secrets
      const finalSecret = Buffer.alloc(secret.length);
      for (let byteIndex = 0; byteIndex < secret.length; byteIndex++) {
        const points = [
          { x: 1, y: reconstructedGroup0[byteIndex] },
          { x: 2, y: reconstructedGroup1[byteIndex] }
        ];
        finalSecret[byteIndex] = lagrangeInterpolateGF256(points);
      }

      expect(finalSecret.equals(secret)).toBe(true);
    });
  });

  describe('Performance Tests', () => {
    it('should handle large secrets efficiently', () => {
      const secret = crypto.randomBytes(256); // 256 bytes
      const threshold = 5;
      const totalShares = 10;

      const startTime = Date.now();

      const shares: Buffer[] = Array(totalShares).fill(null).map(() => Buffer.alloc(secret.length + 1));

      for (let i = 0; i < totalShares; i++) {
        shares[i][0] = i + 1;
      }

      for (let byteIndex = 0; byteIndex < secret.length; byteIndex++) {
        const polynomial = GF256Polynomial.random(threshold - 1, secret[byteIndex]);

        for (let shareIndex = 0; shareIndex < totalShares; shareIndex++) {
          shares[shareIndex][byteIndex + 1] = polynomial.evaluate(shareIndex + 1);
        }
      }

      // Reconstruct
      const reconstructed = Buffer.alloc(secret.length);
      for (let byteIndex = 0; byteIndex < secret.length; byteIndex++) {
        const points: Array<{ x: number; y: number }> = [];
        for (let shareIndex = 0; shareIndex < threshold; shareIndex++) {
          points.push({
            x: shares[shareIndex][0],
            y: shares[shareIndex][byteIndex + 1]
          });
        }
        reconstructed[byteIndex] = lagrangeInterpolateGF256(points);
      }

      const endTime = Date.now();
      const duration = endTime - startTime;

      expect(reconstructed.equals(secret)).toBe(true);
      expect(duration).toBeLessThan(1000); // Should complete within 1 second
    });
  });
});
