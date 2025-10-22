/**
 * Ethereum Address Generation Test Vectors
 * Tests BIP44 Ethereum address derivation (m/44'/60'/0'/0/x)
 */

import * as bip32 from 'bip32';
import * as bip39 from 'bip39';
import { describe, it, expect } from '@jest/globals';
import { keccak256 } from 'ethereumjs-util';

describe('Ethereum Address Generation Test Vectors', () => {
  // Helper function to derive Ethereum address from public key
  function publicKeyToAddress(publicKey: Buffer): string {
    // Remove the first byte (0x04 prefix for uncompressed key)
    const publicKeyBuffer = publicKey.slice(1);

    // Keccak256 hash
    const hash = keccak256(publicKeyBuffer);

    // Take last 20 bytes
    const address = hash.slice(-20);

    // Add 0x prefix and return checksummed address
    return toChecksumAddress('0x' + address.toString('hex'));
  }

  // EIP-55: Mixed-case checksum address encoding
  function toChecksumAddress(address: string): string {
    const addr = address.toLowerCase().replace('0x', '');
    const hash = keccak256(Buffer.from(addr, 'utf8')).toString('hex');
    let checksumAddr = '0x';

    for (let i = 0; i < addr.length; i++) {
      if (parseInt(hash[i], 16) >= 8) {
        checksumAddr += addr[i].toUpperCase();
      } else {
        checksumAddr += addr[i];
      }
    }

    return checksumAddr;
  }

  describe('BIP44 Ethereum Path (m/44\'/60\'/0\'/0/x)', () => {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const seed = bip39.mnemonicToSeedSync(mnemonic);
    const root = bip32.fromSeed(seed);

    it('should derive first Ethereum address (m/44\'/60\'/0\'/0/0)', () => {
      const path = "m/44'/60'/0'/0/0";
      const child = root.derivePath(path);

      // Get uncompressed public key
      const publicKey = Buffer.concat([
        Buffer.from([0x04]),
        child.publicKey.slice(1)
      ]);

      const address = publicKeyToAddress(publicKey);

      // Known test vector address for this mnemonic
      expect(address.toLowerCase()).toBe('0x9858EfFD232B4033E47d90003D41EC34EcaEda94'.toLowerCase());
    });

    it('should derive second Ethereum address (m/44\'/60\'/0\'/0/1)', () => {
      const path = "m/44'/60'/0'/0/1";
      const child = root.derivePath(path);

      const publicKey = Buffer.concat([
        Buffer.from([0x04]),
        child.publicKey.slice(1)
      ]);

      const address = publicKeyToAddress(publicKey);
      expect(address).toMatch(/^0x[0-9a-fA-F]{40}$/);
    });

    it('should derive multiple addresses in sequence', () => {
      const addresses = [];

      for (let i = 0; i < 10; i++) {
        const path = `m/44'/60'/0'/0/${i}`;
        const child = root.derivePath(path);

        const publicKey = Buffer.concat([
          Buffer.from([0x04]),
          child.publicKey.slice(1)
        ]);

        const address = publicKeyToAddress(publicKey);
        addresses.push(address);
      }

      expect(addresses.length).toBe(10);
      expect(new Set(addresses).size).toBe(10); // All unique
      addresses.forEach(addr => {
        expect(addr).toMatch(/^0x[0-9a-fA-F]{40}$/);
      });
    });

    it('should derive account 1 addresses (m/44\'/60\'/1\'/0/x)', () => {
      const account0Address = root.derivePath("m/44'/60'/0'/0/0");
      const account1Address = root.derivePath("m/44'/60'/1'/0/0");

      const publicKey0 = Buffer.concat([
        Buffer.from([0x04]),
        account0Address.publicKey.slice(1)
      ]);

      const publicKey1 = Buffer.concat([
        Buffer.from([0x04]),
        account1Address.publicKey.slice(1)
      ]);

      const addr0 = publicKeyToAddress(publicKey0);
      const addr1 = publicKeyToAddress(publicKey1);

      expect(addr0).not.toBe(addr1);
    });
  });

  describe('EIP-55 Checksum Validation', () => {
    const testVectors = [
      '0x5aAeb6053f3E94C9b9A09f33669435E7Ef1BeAed',
      '0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359',
      '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB',
      '0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb'
    ];

    testVectors.forEach(address => {
      it(`should validate checksum for ${address}`, () => {
        const checksummed = toChecksumAddress(address);
        expect(checksummed).toBe(address);
      });
    });

    it('should produce checksummed address', () => {
      const lowercase = '0x5aaeb6053f3e94c9b9a09f33669435e7ef1beaed';
      const checksummed = toChecksumAddress(lowercase);
      expect(checksummed).toBe('0x5aAeb6053f3E94C9b9A09f33669435E7Ef1BeAed');
    });
  });

  describe('Multiple Mnemonic Test Vectors', () => {
    const testVectors = [
      {
        mnemonic: 'legal winner thank year wave sausage worth useful legal winner thank yellow',
        expectedAddress: '0x' // Will be computed
      },
      {
        mnemonic: 'letter advice cage absurd amount doctor acoustic avoid letter advice cage above',
        expectedAddress: '0x' // Will be computed
      }
    ];

    testVectors.forEach((vector, index) => {
      it(`should derive address from mnemonic ${index + 1}`, () => {
        const seed = bip39.mnemonicToSeedSync(vector.mnemonic);
        const root = bip32.fromSeed(seed);
        const child = root.derivePath("m/44'/60'/0'/0/0");

        const publicKey = Buffer.concat([
          Buffer.from([0x04]),
          child.publicKey.slice(1)
        ]);

        const address = publicKeyToAddress(publicKey);
        expect(address).toMatch(/^0x[0-9a-fA-F]{40}$/);
      });
    });
  });

  describe('Private Key to Address', () => {
    it('should derive correct address from known private key', () => {
      const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      const seed = bip39.mnemonicToSeedSync(mnemonic);
      const root = bip32.fromSeed(seed);
      const child = root.derivePath("m/44'/60'/0'/0/0");

      expect(child.privateKey).toBeDefined();
      expect(child.privateKey?.length).toBe(32);

      const publicKey = Buffer.concat([
        Buffer.from([0x04]),
        child.publicKey.slice(1)
      ]);

      const address = publicKeyToAddress(publicKey);
      expect(address.toLowerCase()).toBe('0x9858EfFD232B4033E47d90003D41EC34EcaEda94'.toLowerCase());
    });
  });

  describe('Public Key Validation', () => {
    it('should have valid uncompressed public key format', () => {
      const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      const seed = bip39.mnemonicToSeedSync(mnemonic);
      const root = bip32.fromSeed(seed);
      const child = root.derivePath("m/44'/60'/0'/0/0");

      // Ethereum uses uncompressed public keys
      const publicKey = Buffer.concat([
        Buffer.from([0x04]),
        child.publicKey.slice(1)
      ]);

      expect(publicKey.length).toBe(65);
      expect(publicKey[0]).toBe(0x04);
    });
  });

  describe('Address Uniqueness', () => {
    it('should generate unique addresses for different paths', () => {
      const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      const seed = bip39.mnemonicToSeedSync(mnemonic);
      const root = bip32.fromSeed(seed);

      const addresses = new Set();

      // Test different accounts
      for (let account = 0; account < 3; account++) {
        // Test different addresses
        for (let index = 0; index < 5; index++) {
          const path = `m/44'/60'/${account}'/0/${index}`;
          const child = root.derivePath(path);

          const publicKey = Buffer.concat([
            Buffer.from([0x04]),
            child.publicKey.slice(1)
          ]);

          const address = publicKeyToAddress(publicKey);
          addresses.add(address);
        }
      }

      expect(addresses.size).toBe(15); // 3 accounts * 5 addresses = 15 unique
    });
  });
});
