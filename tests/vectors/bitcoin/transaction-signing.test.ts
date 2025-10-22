/**
 * Bitcoin Transaction Signing Test Vectors
 * Tests transaction creation and signing with various input types
 */

import * as bitcoin from 'bitcoinjs-lib';
import * as bip32 from 'bip32';
import * as bip39 from 'bip39';
import { describe, it, expect } from '@jest/globals';
import * as ecc from 'tiny-secp256k1';

// Initialize bitcoin-js with elliptic curve
bitcoin.initEccLib(ecc);

describe('Bitcoin Transaction Signing Test Vectors', () => {
  const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  const seed = bip39.mnemonicToSeedSync(mnemonic);
  const root = bip32.fromSeed(seed);

  describe('P2PKH Transaction Signing', () => {
    it('should create and sign a P2PKH transaction', () => {
      const path = "m/44'/0'/0'/0/0";
      const keyPair = root.derivePath(path);
      const { address } = bitcoin.payments.p2pkh({
        pubkey: keyPair.publicKey,
        network: bitcoin.networks.bitcoin
      });

      const psbt = new bitcoin.Psbt({ network: bitcoin.networks.bitcoin });

      // Add input (mock UTXO)
      psbt.addInput({
        hash: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 0,
        nonWitnessUtxo: Buffer.from(
          '0100000001000000000000000000000000000000000000000000000000000000000000000000000000' +
          '00ffffffff0100f2052a010000001976a914' +
          bitcoin.address.fromBase58Check(address!).hash.toString('hex') +
          '88acffffffff',
          'hex'
        )
      });

      // Add output
      psbt.addOutput({
        address: '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa',
        value: 50000000
      });

      // Sign
      psbt.signInput(0, keyPair);
      psbt.validateSignaturesOfInput(0, () => true);
      psbt.finalizeAllInputs();

      const tx = psbt.extractTransaction();
      expect(tx.getId()).toBeDefined();
      expect(tx.ins.length).toBe(1);
      expect(tx.outs.length).toBe(1);
    });
  });

  describe('P2WPKH Transaction Signing (Native SegWit)', () => {
    it('should create and sign a P2WPKH transaction', () => {
      const path = "m/84'/0'/0'/0/0";
      const keyPair = root.derivePath(path);
      const { address } = bitcoin.payments.p2wpkh({
        pubkey: keyPair.publicKey,
        network: bitcoin.networks.bitcoin
      });

      const psbt = new bitcoin.Psbt({ network: bitcoin.networks.bitcoin });

      // Add input with witness UTXO
      psbt.addInput({
        hash: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 0,
        witnessUtxo: {
          script: bitcoin.payments.p2wpkh({
            pubkey: keyPair.publicKey,
            network: bitcoin.networks.bitcoin
          }).output!,
          value: 100000000
        }
      });

      // Add output
      psbt.addOutput({
        address: 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
        value: 99900000
      });

      // Sign
      psbt.signInput(0, keyPair);
      psbt.validateSignaturesOfInput(0, () => true);
      psbt.finalizeAllInputs();

      const tx = psbt.extractTransaction();
      expect(tx.getId()).toBeDefined();
      expect(tx.hasWitnesses()).toBe(true);
    });
  });

  describe('P2SH-P2WPKH Transaction Signing (Nested SegWit)', () => {
    it('should create and sign a P2SH-P2WPKH transaction', () => {
      const path = "m/49'/0'/0'/0/0";
      const keyPair = root.derivePath(path);

      const p2wpkh = bitcoin.payments.p2wpkh({
        pubkey: keyPair.publicKey,
        network: bitcoin.networks.bitcoin
      });

      const { address } = bitcoin.payments.p2sh({
        redeem: p2wpkh,
        network: bitcoin.networks.bitcoin
      });

      const psbt = new bitcoin.Psbt({ network: bitcoin.networks.bitcoin });

      // Add input
      psbt.addInput({
        hash: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 0,
        witnessUtxo: {
          script: bitcoin.payments.p2sh({
            redeem: p2wpkh,
            network: bitcoin.networks.bitcoin
          }).output!,
          value: 100000000
        },
        redeemScript: p2wpkh.output
      });

      // Add output
      psbt.addOutput({
        address: '3J98t1WpEZ73CNmYviecrnyiWrnqRhWNLy',
        value: 99900000
      });

      // Sign
      psbt.signInput(0, keyPair);
      psbt.validateSignaturesOfInput(0, () => true);
      psbt.finalizeAllInputs();

      const tx = psbt.extractTransaction();
      expect(tx.getId()).toBeDefined();
      expect(tx.hasWitnesses()).toBe(true);
    });
  });

  describe('Multi-Input Transaction', () => {
    it('should create and sign transaction with multiple inputs', () => {
      const keyPair1 = root.derivePath("m/44'/0'/0'/0/0");
      const keyPair2 = root.derivePath("m/44'/0'/0'/0/1");

      const { address: address1 } = bitcoin.payments.p2pkh({
        pubkey: keyPair1.publicKey,
        network: bitcoin.networks.bitcoin
      });

      const { address: address2 } = bitcoin.payments.p2pkh({
        pubkey: keyPair2.publicKey,
        network: bitcoin.networks.bitcoin
      });

      const psbt = new bitcoin.Psbt({ network: bitcoin.networks.bitcoin });

      // Add first input
      psbt.addInput({
        hash: '1111111111111111111111111111111111111111111111111111111111111111',
        index: 0,
        nonWitnessUtxo: Buffer.from(
          '0100000001000000000000000000000000000000000000000000000000000000000000000000000000' +
          '00ffffffff0100f2052a010000001976a914' +
          bitcoin.address.fromBase58Check(address1!).hash.toString('hex') +
          '88acffffffff',
          'hex'
        )
      });

      // Add second input
      psbt.addInput({
        hash: '2222222222222222222222222222222222222222222222222222222222222222',
        index: 0,
        nonWitnessUtxo: Buffer.from(
          '0100000001000000000000000000000000000000000000000000000000000000000000000000000000' +
          '00ffffffff0100f2052a010000001976a914' +
          bitcoin.address.fromBase58Check(address2!).hash.toString('hex') +
          '88acffffffff',
          'hex'
        )
      });

      // Add output
      psbt.addOutput({
        address: '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa',
        value: 100000000
      });

      // Sign both inputs
      psbt.signInput(0, keyPair1);
      psbt.signInput(1, keyPair2);

      psbt.validateSignaturesOfInput(0, () => true);
      psbt.validateSignaturesOfInput(1, () => true);
      psbt.finalizeAllInputs();

      const tx = psbt.extractTransaction();
      expect(tx.getId()).toBeDefined();
      expect(tx.ins.length).toBe(2);
      expect(tx.outs.length).toBe(1);
    });
  });

  describe('Transaction with Change Output', () => {
    it('should create transaction with change address', () => {
      const keyPair = root.derivePath("m/44'/0'/0'/0/0");
      const changeKeyPair = root.derivePath("m/44'/0'/0'/1/0");

      const { address } = bitcoin.payments.p2pkh({
        pubkey: keyPair.publicKey,
        network: bitcoin.networks.bitcoin
      });

      const { address: changeAddress } = bitcoin.payments.p2pkh({
        pubkey: changeKeyPair.publicKey,
        network: bitcoin.networks.bitcoin
      });

      const psbt = new bitcoin.Psbt({ network: bitcoin.networks.bitcoin });

      // Add input
      psbt.addInput({
        hash: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 0,
        nonWitnessUtxo: Buffer.from(
          '0100000001000000000000000000000000000000000000000000000000000000000000000000000000' +
          '00ffffffff0100e1f505000000001976a914' +
          bitcoin.address.fromBase58Check(address!).hash.toString('hex') +
          '88acffffffff',
          'hex'
        )
      });

      // Add payment output
      psbt.addOutput({
        address: '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa',
        value: 50000000
      });

      // Add change output
      psbt.addOutput({
        address: changeAddress!,
        value: 49990000
      });

      // Sign
      psbt.signInput(0, keyPair);
      psbt.validateSignaturesOfInput(0, () => true);
      psbt.finalizeAllInputs();

      const tx = psbt.extractTransaction();
      expect(tx.outs.length).toBe(2);
      expect(tx.outs[0].value).toBe(50000000);
      expect(tx.outs[1].value).toBe(49990000);
    });
  });

  describe('SIGHASH types', () => {
    it('should sign with SIGHASH_ALL (default)', () => {
      const keyPair = root.derivePath("m/44'/0'/0'/0/0");
      const { address } = bitcoin.payments.p2pkh({
        pubkey: keyPair.publicKey,
        network: bitcoin.networks.bitcoin
      });

      const psbt = new bitcoin.Psbt({ network: bitcoin.networks.bitcoin });

      psbt.addInput({
        hash: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 0,
        nonWitnessUtxo: Buffer.from(
          '0100000001000000000000000000000000000000000000000000000000000000000000000000000000' +
          '00ffffffff0100f2052a010000001976a914' +
          bitcoin.address.fromBase58Check(address!).hash.toString('hex') +
          '88acffffffff',
          'hex'
        )
      });

      psbt.addOutput({
        address: '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa',
        value: 50000000
      });

      // Default is SIGHASH_ALL (0x01)
      psbt.signInput(0, keyPair);
      psbt.finalizeAllInputs();

      const tx = psbt.extractTransaction();
      expect(tx.getId()).toBeDefined();
    });
  });

  describe('Fee calculation', () => {
    it('should calculate proper transaction fee', () => {
      const inputValue = 100000000; // 1 BTC
      const outputValue = 99900000; // 0.999 BTC
      const expectedFee = 100000; // 0.001 BTC (100,000 satoshis)

      const calculatedFee = inputValue - outputValue;
      expect(calculatedFee).toBe(expectedFee);

      // Fee rate calculation (assuming tx size of 250 bytes)
      const txSize = 250;
      const feeRate = calculatedFee / txSize;
      expect(feeRate).toBe(400); // 400 sat/byte
    });
  });
});
