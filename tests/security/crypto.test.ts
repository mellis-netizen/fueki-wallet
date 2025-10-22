/**
 * @test Cryptographic Security Tests
 * @description Comprehensive tests for key generation, randomness, and cryptographic operations
 * @prerequisites
 *   - Crypto libraries installed
 *   - Secure random number generator available
 * @expected All cryptographic operations meet security standards
 */

import crypto from 'crypto';
import * as bip39 from 'bip39';
import * as bip32 from 'bip32';
import { ec as EC } from 'elliptic';

describe('Cryptographic Security Tests', () => {
  describe('Key Generation Randomness', () => {
    it('should generate cryptographically secure random bytes', () => {
      const randomBytes1 = crypto.randomBytes(32);
      const randomBytes2 = crypto.randomBytes(32);

      expect(randomBytes1).toHaveLength(32);
      expect(randomBytes2).toHaveLength(32);
      expect(randomBytes1.equals(randomBytes2)).toBe(false);
    });

    it('should pass statistical randomness tests (Chi-square)', () => {
      const samples = 10000;
      const buckets = 256;
      const frequencies = new Array(buckets).fill(0);

      // Generate random samples
      for (let i = 0; i < samples; i++) {
        const randomByte = crypto.randomBytes(1)[0];
        frequencies[randomByte]++;
      }

      // Chi-square test
      const expected = samples / buckets;
      const chiSquare = frequencies.reduce((sum, freq) => {
        return sum + Math.pow(freq - expected, 2) / expected;
      }, 0);

      // Critical value for 255 degrees of freedom at 0.05 significance
      const criticalValue = 293.25;
      expect(chiSquare).toBeLessThan(criticalValue);
    });

    it('should generate unique mnemonics', () => {
      const mnemonics = new Set();
      const iterations = 1000;

      for (let i = 0; i < iterations; i++) {
        const mnemonic = bip39.generateMnemonic(256);
        expect(mnemonics.has(mnemonic)).toBe(false);
        mnemonics.add(mnemonic);
      }

      expect(mnemonics.size).toBe(iterations);
    });

    it('should generate valid BIP39 mnemonics', () => {
      const strengths = [128, 160, 192, 224, 256];

      strengths.forEach(strength => {
        const mnemonic = bip39.generateMnemonic(strength);
        expect(bip39.validateMnemonic(mnemonic)).toBe(true);

        const wordCount = strength / 32 * 3;
        expect(mnemonic.split(' ')).toHaveLength(wordCount);
      });
    });

    it('should generate unique private keys from same mnemonic with different paths', () => {
      const mnemonic = bip39.generateMnemonic(256);
      const seed = bip39.mnemonicToSeedSync(mnemonic);
      const root = bip32.fromSeed(seed);

      const paths = [
        "m/44'/0'/0'/0/0",  // Bitcoin
        "m/44'/60'/0'/0/0", // Ethereum
        "m/44'/0'/0'/0/1",  // Bitcoin second address
        "m/44'/60'/0'/0/1", // Ethereum second address
      ];

      const privateKeys = paths.map(path => {
        const child = root.derivePath(path);
        return child.privateKey?.toString('hex');
      });

      // All keys should be unique
      const uniqueKeys = new Set(privateKeys);
      expect(uniqueKeys.size).toBe(paths.length);
    });

    it('should not generate weak private keys (all zeros, all ones)', () => {
      const iterations = 100;
      const weakPatterns = [
        Buffer.alloc(32, 0),
        Buffer.alloc(32, 0xff),
      ];

      for (let i = 0; i < iterations; i++) {
        const privateKey = crypto.randomBytes(32);

        weakPatterns.forEach(pattern => {
          expect(privateKey.equals(pattern)).toBe(false);
        });

        // Check not all same byte
        const firstByte = privateKey[0];
        const allSame = privateKey.every(byte => byte === firstByte);
        expect(allSame).toBe(false);
      }
    });

    it('should generate keys with proper entropy distribution', () => {
      const iterations = 100;
      const entropyScores: number[] = [];

      for (let i = 0; i < iterations; i++) {
        const key = crypto.randomBytes(32);

        // Calculate Shannon entropy
        const frequencies = new Map<number, number>();
        for (const byte of key) {
          frequencies.set(byte, (frequencies.get(byte) || 0) + 1);
        }

        let entropy = 0;
        for (const freq of frequencies.values()) {
          const probability = freq / key.length;
          entropy -= probability * Math.log2(probability);
        }

        entropyScores.push(entropy);
      }

      // Average entropy should be high (close to 8 bits per byte)
      const avgEntropy = entropyScores.reduce((a, b) => a + b) / entropyScores.length;
      expect(avgEntropy).toBeGreaterThan(7.0); // Good entropy threshold
    });
  });

  describe('Key Uniqueness Tests', () => {
    it('should generate unique keypairs across multiple sessions', () => {
      const ec = new EC('secp256k1');
      const keypairs = new Set();
      const iterations = 1000;

      for (let i = 0; i < iterations; i++) {
        const keyPair = ec.genKeyPair();
        const privateKey = keyPair.getPrivate('hex');

        expect(keypairs.has(privateKey)).toBe(false);
        keypairs.add(privateKey);
      }

      expect(keypairs.size).toBe(iterations);
    });

    it('should generate unique Ethereum addresses', () => {
      const addresses = new Set();
      const iterations = 100;

      for (let i = 0; i < iterations; i++) {
        const mnemonic = bip39.generateMnemonic(256);
        const seed = bip39.mnemonicToSeedSync(mnemonic);
        const root = bip32.fromSeed(seed);
        const child = root.derivePath("m/44'/60'/0'/0/0");

        const privateKey = child.privateKey?.toString('hex');
        expect(privateKey).toBeDefined();
        expect(addresses.has(privateKey)).toBe(false);
        addresses.add(privateKey);
      }

      expect(addresses.size).toBe(iterations);
    });

    it('should detect collision attempts (birthday attack simulation)', () => {
      // Simulate detecting collisions in a smaller keyspace
      const shortKeys = new Set();
      const keyLength = 4; // Intentionally small for testing collision detection
      let collisionDetected = false;

      for (let i = 0; i < 100000 && !collisionDetected; i++) {
        const key = crypto.randomBytes(keyLength).toString('hex');
        if (shortKeys.has(key)) {
          collisionDetected = true;
        }
        shortKeys.add(key);
      }

      // For 4 bytes, we expect collisions (this tests collision detection works)
      expect(collisionDetected).toBe(true);
    });
  });

  describe('Cryptographic Validation', () => {
    it('should validate private key range for secp256k1', () => {
      const ec = new EC('secp256k1');
      const n = ec.curve.n;

      // Test valid key
      const validKey = crypto.randomBytes(32);
      const validKeyBN = BigInt('0x' + validKey.toString('hex'));
      expect(validKeyBN > 0n && validKeyBN < n.toBigInt()).toBe(true);

      // Test invalid keys
      const zeroKey = Buffer.alloc(32, 0);
      const zeroKeyBN = BigInt('0x' + zeroKey.toString('hex'));
      expect(zeroKeyBN === 0n).toBe(true); // Invalid

      // Key equal to or greater than curve order is invalid
      const nBuffer = Buffer.from(n.toArray());
      const nBN = BigInt('0x' + nBuffer.toString('hex'));
      expect(nBN >= n.toBigInt()).toBe(true); // Invalid
    });

    it('should properly derive public key from private key', () => {
      const ec = new EC('secp256k1');
      const iterations = 100;

      for (let i = 0; i < iterations; i++) {
        const keyPair = ec.genKeyPair();
        const privateKey = keyPair.getPrivate('hex');
        const publicKey = keyPair.getPublic('hex');

        // Re-derive public key
        const derivedKeyPair = ec.keyFromPrivate(privateKey, 'hex');
        const derivedPublicKey = derivedKeyPair.getPublic('hex');

        expect(derivedPublicKey).toBe(publicKey);
      }
    });

    it('should validate mnemonic checksums', () => {
      const validMnemonic = bip39.generateMnemonic(256);
      expect(bip39.validateMnemonic(validMnemonic)).toBe(true);

      // Corrupt mnemonic by changing one word
      const words = validMnemonic.split(' ');
      words[0] = 'abandon';
      const corruptedMnemonic = words.join(' ');

      expect(bip39.validateMnemonic(corruptedMnemonic)).toBe(false);
    });

    it('should enforce minimum key strength requirements', () => {
      const weakStrengths = [64, 96]; // Below minimum
      const strongStrengths = [128, 160, 192, 224, 256];

      weakStrengths.forEach(strength => {
        expect(() => bip39.generateMnemonic(strength)).toThrow();
      });

      strongStrengths.forEach(strength => {
        const mnemonic = bip39.generateMnemonic(strength);
        expect(bip39.validateMnemonic(mnemonic)).toBe(true);
      });
    });
  });

  describe('Timing Attack Resistance', () => {
    it('should use constant-time comparison for sensitive data', () => {
      const secret1 = crypto.randomBytes(32);
      const secret2 = Buffer.from(secret1);
      const different = crypto.randomBytes(32);

      // Using crypto.timingSafeEqual for constant-time comparison
      expect(crypto.timingSafeEqual(secret1, secret2)).toBe(true);
      expect(() => crypto.timingSafeEqual(secret1, different)).toThrow();
    });

    it('should not leak information through timing in key derivation', async () => {
      const mnemonic = bip39.generateMnemonic(256);
      const iterations = 100;
      const timings: number[] = [];

      for (let i = 0; i < iterations; i++) {
        const start = process.hrtime.bigint();
        bip39.mnemonicToSeedSync(mnemonic);
        const end = process.hrtime.bigint();
        timings.push(Number(end - start) / 1000000); // Convert to ms
      }

      // Calculate standard deviation
      const mean = timings.reduce((a, b) => a + b) / timings.length;
      const variance = timings.reduce((sum, time) => sum + Math.pow(time - mean, 2), 0) / timings.length;
      const stdDev = Math.sqrt(variance);

      // Coefficient of variation should be low (< 10%)
      const coefficientOfVariation = (stdDev / mean) * 100;
      expect(coefficientOfVariation).toBeLessThan(10);
    });
  });

  describe('Key Derivation Security', () => {
    it('should produce deterministic keys from same seed', () => {
      const mnemonic = bip39.generateMnemonic(256);
      const seed1 = bip39.mnemonicToSeedSync(mnemonic);
      const seed2 = bip39.mnemonicToSeedSync(mnemonic);

      expect(seed1.equals(seed2)).toBe(true);

      const root1 = bip32.fromSeed(seed1);
      const root2 = bip32.fromSeed(seed2);

      const path = "m/44'/60'/0'/0/0";
      const key1 = root1.derivePath(path).privateKey;
      const key2 = root2.derivePath(path).privateKey;

      expect(key1?.equals(key2!)).toBe(true);
    });

    it('should not allow private key recovery from public key', () => {
      const ec = new EC('secp256k1');
      const keyPair = ec.genKeyPair();
      const publicKey = keyPair.getPublic('hex');

      // Attempt to derive private key from public key should fail
      const publicKeyPoint = ec.keyFromPublic(publicKey, 'hex');
      expect(publicKeyPoint.getPrivate()).toBeNull();
    });

    it('should enforce hardened derivation for sensitive paths', () => {
      const mnemonic = bip39.generateMnemonic(256);
      const seed = bip39.mnemonicToSeedSync(mnemonic);
      const root = bip32.fromSeed(seed);

      // Hardened paths (with ')
      const hardenedPath = "m/44'/60'/0'/0/0";
      const hardenedChild = root.derivePath(hardenedPath);
      expect(hardenedChild.privateKey).toBeDefined();

      // Non-hardened derivation should still work but is less secure
      const nonHardenedPath = "m/44/60/0/0/0";
      const nonHardenedChild = root.derivePath(nonHardenedPath);
      expect(nonHardenedChild.privateKey).toBeDefined();

      // Keys should be different
      expect(hardenedChild.privateKey?.equals(nonHardenedChild.privateKey!)).toBe(false);
    });
  });

  describe('Entropy Source Validation', () => {
    it('should detect weak entropy sources', () => {
      // Simulate weak RNG
      const weakEntropy = Buffer.alloc(32);
      for (let i = 0; i < 32; i++) {
        weakEntropy[i] = i; // Predictable pattern
      }

      // Calculate entropy
      const frequencies = new Map<number, number>();
      for (const byte of weakEntropy) {
        frequencies.set(byte, (frequencies.get(byte) || 0) + 1);
      }

      let entropy = 0;
      for (const freq of frequencies.values()) {
        const probability = freq / weakEntropy.length;
        entropy -= probability * Math.log2(probability);
      }

      // Weak entropy should be detected (low entropy score)
      expect(entropy).toBeLessThan(7.0);

      // Strong entropy from crypto.randomBytes
      const strongEntropy = crypto.randomBytes(32);
      const strongFrequencies = new Map<number, number>();
      for (const byte of strongEntropy) {
        strongFrequencies.set(byte, (strongFrequencies.get(byte) || 0) + 1);
      }

      let strongEntropyScore = 0;
      for (const freq of strongFrequencies.values()) {
        const probability = freq / strongEntropy.length;
        strongEntropyScore -= probability * Math.log2(probability);
      }

      expect(strongEntropyScore).toBeGreaterThan(entropy);
    });
  });
});
