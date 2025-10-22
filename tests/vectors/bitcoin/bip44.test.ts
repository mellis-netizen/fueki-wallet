/**
 * BIP44 Multi-Account Hierarchy Test Vectors
 * Source: https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki
 *
 * BIP44 defines the following derivation path:
 * m / purpose' / coin_type' / account' / change / address_index
 *
 * Purpose: 44' (hardened)
 * Coin types: 0' for Bitcoin, 1' for Testnet, 60' for Ethereum
 */

import * as bip32 from 'bip32';
import * as bip39 from 'bip39';
import * as bitcoin from 'bitcoinjs-lib';
import { describe, it, expect } from '@jest/globals';

describe('BIP44 Multi-Account Hierarchy Test Vectors', () => {
  // Test mnemonic from BIP39
  const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  const seed = bip39.mnemonicToSeedSync(mnemonic);
  const root = bip32.fromSeed(seed);

  describe('Bitcoin Mainnet (coin_type = 0)', () => {
    it('should derive first receiving address (m/44\'/0\'/0\'/0/0)', () => {
      const path = "m/44'/0'/0'/0/0";
      const child = root.derivePath(path);
      const { address } = bitcoin.payments.p2pkh({
        pubkey: child.publicKey,
        network: bitcoin.networks.bitcoin
      });

      expect(address).toBe('1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA');
      expect(child.publicKey.toString('hex')).toBe('0330d54fd0dd420a6e5f8d3624f5f3482cae350f79d5f0753bf5beef9c2d91af3c');
    });

    it('should derive second receiving address (m/44\'/0\'/0\'/0/1)', () => {
      const path = "m/44'/0'/0'/0/1";
      const child = root.derivePath(path);
      const { address } = bitcoin.payments.p2pkh({
        pubkey: child.publicKey,
        network: bitcoin.networks.bitcoin
      });

      expect(child.publicKey.toString('hex')).toBe('03e775fd51f0dfb8cd865d9ff1cca2a158cf651fe997fdc9fee9c1d3b5e995ea77');
    });

    it('should derive first change address (m/44\'/0\'/0\'/1/0)', () => {
      const path = "m/44'/0'/0'/1/0";
      const child = root.derivePath(path);
      const { address } = bitcoin.payments.p2pkh({
        pubkey: child.publicKey,
        network: bitcoin.networks.bitcoin
      });

      expect(child.publicKey.toString('hex')).toBe('03025324888e429ab8e3dbaf1f7802648b9cd01e9b418485c5fa4c1b9b5700e1a6');
    });

    it('should derive second account first address (m/44\'/0\'/1\'/0/0)', () => {
      const path = "m/44'/0'/1'/0/0";
      const child = root.derivePath(path);
      const { address } = bitcoin.payments.p2pkh({
        pubkey: child.publicKey,
        network: bitcoin.networks.bitcoin
      });

      expect(child.publicKey).toBeDefined();
      expect(address).toBeDefined();
    });

    it('should derive multiple addresses in sequence', () => {
      const addresses = [];
      for (let i = 0; i < 5; i++) {
        const path = `m/44'/0'/0'/0/${i}`;
        const child = root.derivePath(path);
        const { address } = bitcoin.payments.p2pkh({
          pubkey: child.publicKey,
          network: bitcoin.networks.bitcoin
        });
        addresses.push(address);
      }

      expect(addresses.length).toBe(5);
      expect(new Set(addresses).size).toBe(5); // All unique
    });
  });

  describe('Bitcoin Testnet (coin_type = 1)', () => {
    it('should derive first testnet address (m/44\'/1\'/0\'/0/0)', () => {
      const path = "m/44'/1'/0'/0/0";
      const child = root.derivePath(path);
      const { address } = bitcoin.payments.p2pkh({
        pubkey: child.publicKey,
        network: bitcoin.networks.testnet
      });

      expect(address).toBeDefined();
      expect(address?.startsWith('m') || address?.startsWith('n')).toBe(true);
    });
  });

  describe('Account discovery', () => {
    it('should discover accounts according to BIP44', () => {
      // BIP44 specifies: Software should prevent a creation of an account
      // if a previous account does not have transaction history
      const accounts = [];

      for (let accountIndex = 0; accountIndex < 3; accountIndex++) {
        const path = `m/44'/0'/${accountIndex}'/0/0`;
        const child = root.derivePath(path);
        const { address } = bitcoin.payments.p2pkh({
          pubkey: child.publicKey,
          network: bitcoin.networks.bitcoin
        });

        accounts.push({
          index: accountIndex,
          path,
          address,
          publicKey: child.publicKey.toString('hex')
        });
      }

      expect(accounts.length).toBe(3);
      expect(accounts[0].address).toBe('1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA');
    });
  });

  describe('Address gap limit', () => {
    it('should generate 20 consecutive addresses (gap limit)', () => {
      // BIP44 specifies gap limit of 20
      const GAP_LIMIT = 20;
      const addresses = [];

      for (let i = 0; i < GAP_LIMIT; i++) {
        const path = `m/44'/0'/0'/0/${i}`;
        const child = root.derivePath(path);
        const { address } = bitcoin.payments.p2pkh({
          pubkey: child.publicKey,
          network: bitcoin.networks.bitcoin
        });
        addresses.push(address);
      }

      expect(addresses.length).toBe(GAP_LIMIT);
      expect(new Set(addresses).size).toBe(GAP_LIMIT); // All unique
    });
  });

  describe('SegWit addresses (BIP84 compatible)', () => {
    it('should derive P2WPKH address (m/84\'/0\'/0\'/0/0)', () => {
      const path = "m/84'/0'/0'/0/0";
      const child = root.derivePath(path);
      const { address } = bitcoin.payments.p2wpkh({
        pubkey: child.publicKey,
        network: bitcoin.networks.bitcoin
      });

      expect(address).toBeDefined();
      expect(address?.startsWith('bc1')).toBe(true);
    });

    it('should derive nested SegWit address (m/49\'/0\'/0\'/0/0)', () => {
      const path = "m/49'/0'/0'/0/0";
      const child = root.derivePath(path);
      const { address } = bitcoin.payments.p2sh({
        redeem: bitcoin.payments.p2wpkh({
          pubkey: child.publicKey,
          network: bitcoin.networks.bitcoin
        }),
        network: bitcoin.networks.bitcoin
      });

      expect(address).toBeDefined();
      expect(address?.startsWith('3')).toBe(true);
    });
  });

  describe('Cross-account derivation', () => {
    it('should derive independent keys for different accounts', () => {
      const account0 = root.derivePath("m/44'/0'/0'/0/0");
      const account1 = root.derivePath("m/44'/0'/1'/0/0");

      expect(account0.publicKey.toString('hex')).not.toBe(account1.publicKey.toString('hex'));
      expect(account0.privateKey?.toString('hex')).not.toBe(account1.privateKey?.toString('hex'));
    });

    it('should derive independent receiving and change addresses', () => {
      const receiving = root.derivePath("m/44'/0'/0'/0/0");
      const change = root.derivePath("m/44'/0'/0'/1/0");

      expect(receiving.publicKey.toString('hex')).not.toBe(change.publicKey.toString('hex'));
    });
  });

  describe('Key export and import', () => {
    it('should export and import extended public key', () => {
      const accountNode = root.derivePath("m/44'/0'/0'");
      const xpub = accountNode.neutered().toBase58();

      const imported = bip32.fromBase58(xpub);
      const child = imported.derivePath('0/0');
      const { address } = bitcoin.payments.p2pkh({
        pubkey: child.publicKey,
        network: bitcoin.networks.bitcoin
      });

      expect(address).toBe('1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA');
    });

    it('should not allow hardened derivation from xpub', () => {
      const accountNode = root.derivePath("m/44'/0'/0'");
      const xpub = accountNode.neutered().toBase58();
      const imported = bip32.fromBase58(xpub);

      expect(() => imported.deriveHardened(0)).toThrow();
    });
  });
});
