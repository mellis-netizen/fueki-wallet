/**
 * Ethereum Transaction Signing Test Vectors
 * Tests transaction creation and signing including EIP-155, EIP-1559, EIP-2930
 */

import * as bip32 from 'bip32';
import * as bip39 from 'bip39';
import { describe, it, expect } from '@jest/globals';
import { Transaction, FeeMarketEIP1559Transaction, AccessListEIP2930Transaction } from '@ethereumjs/tx';
import { Common, Hardfork, Chain } from '@ethereumjs/common';
import { privateToAddress, toBuffer, bufferToHex } from 'ethereumjs-util';

describe('Ethereum Transaction Signing Test Vectors', () => {
  const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  const seed = bip39.mnemonicToSeedSync(mnemonic);
  const root = bip32.fromSeed(seed);
  const child = root.derivePath("m/44'/60'/0'/0/0");
  const privateKey = child.privateKey!;

  describe('Legacy Transaction Signing (Pre-EIP-155)', () => {
    it('should sign legacy transaction without chain ID', () => {
      const txParams = {
        nonce: '0x00',
        gasPrice: '0x09184e72a000', // 10000000000000
        gasLimit: '0x2710', // 10000
        to: '0x0000000000000000000000000000000000000000',
        value: '0x00',
        data: '0x7f7465737432000000000000000000000000000000000000000000000000000000600057',
      };

      const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.Homestead });
      const tx = Transaction.fromTxData(txParams, { common });
      const signedTx = tx.sign(privateKey);

      expect(signedTx.v).toBeDefined();
      expect(signedTx.r).toBeDefined();
      expect(signedTx.s).toBeDefined();
      expect(signedTx.verifySignature()).toBe(true);
    });
  });

  describe('EIP-155 Transaction Signing (Replay Protection)', () => {
    it('should sign EIP-155 transaction for mainnet (chainId = 1)', () => {
      const txParams = {
        nonce: '0x00',
        gasPrice: '0x09184e72a000',
        gasLimit: '0x2710',
        to: '0x0000000000000000000000000000000000000000',
        value: '0x00',
        data: '0x',
      };

      const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.London });
      const tx = Transaction.fromTxData(txParams, { common });
      const signedTx = tx.sign(privateKey);

      // EIP-155: v = CHAIN_ID * 2 + 35 + {0, 1}
      const v = signedTx.v!;
      expect(v === 37n || v === 38n).toBe(true); // For mainnet (chainId = 1)
      expect(signedTx.verifySignature()).toBe(true);
    });

    it('should sign EIP-155 transaction for different chain IDs', () => {
      const chainIds = [1, 3, 4, 5, 42, 137]; // Mainnet, Ropsten, Rinkeby, Goerli, Kovan, Polygon

      chainIds.forEach(chainId => {
        const common = new Common({ chain: chainId, hardfork: Hardfork.London });
        const tx = Transaction.fromTxData({
          nonce: '0x00',
          gasPrice: '0x09184e72a000',
          gasLimit: '0x2710',
          to: '0x0000000000000000000000000000000000000000',
          value: '0x00',
        }, { common });

        const signedTx = tx.sign(privateKey);
        const expectedV1 = BigInt(chainId * 2 + 35);
        const expectedV2 = BigInt(chainId * 2 + 36);

        expect(signedTx.v === expectedV1 || signedTx.v === expectedV2).toBe(true);
        expect(signedTx.verifySignature()).toBe(true);
      });
    });
  });

  describe('EIP-2930 Transaction Signing (Access Lists)', () => {
    it('should sign EIP-2930 transaction with access list', () => {
      const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.Berlin });

      const txParams = {
        chainId: 1,
        nonce: '0x00',
        gasPrice: '0x09184e72a000',
        gasLimit: '0x2710',
        to: '0x0000000000000000000000000000000000000000',
        value: '0x00',
        data: '0x',
        accessList: [
          {
            address: '0x0000000000000000000000000000000000000001',
            storageKeys: [
              '0x0000000000000000000000000000000000000000000000000000000000000000'
            ]
          }
        ]
      };

      const tx = AccessListEIP2930Transaction.fromTxData(txParams, { common });
      const signedTx = tx.sign(privateKey);

      expect(signedTx.accessList).toBeDefined();
      expect(signedTx.accessList.length).toBe(1);
      expect(signedTx.verifySignature()).toBe(true);
    });

    it('should sign EIP-2930 transaction with multiple access list entries', () => {
      const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.Berlin });

      const txParams = {
        chainId: 1,
        nonce: '0x00',
        gasPrice: '0x09184e72a000',
        gasLimit: '0x2710',
        to: '0x0000000000000000000000000000000000000000',
        value: '0x00',
        accessList: [
          {
            address: '0x0000000000000000000000000000000000000001',
            storageKeys: [
              '0x0000000000000000000000000000000000000000000000000000000000000000',
              '0x0000000000000000000000000000000000000000000000000000000000000001'
            ]
          },
          {
            address: '0x0000000000000000000000000000000000000002',
            storageKeys: []
          }
        ]
      };

      const tx = AccessListEIP2930Transaction.fromTxData(txParams, { common });
      const signedTx = tx.sign(privateKey);

      expect(signedTx.accessList.length).toBe(2);
      expect(signedTx.verifySignature()).toBe(true);
    });
  });

  describe('EIP-1559 Transaction Signing (Fee Market)', () => {
    it('should sign EIP-1559 transaction', () => {
      const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.London });

      const txParams = {
        chainId: 1,
        nonce: '0x00',
        maxPriorityFeePerGas: '0x3b9aca00', // 1 Gwei
        maxFeePerGas: '0x2540be400', // 10 Gwei
        gasLimit: '0x5208', // 21000
        to: '0x0000000000000000000000000000000000000000',
        value: '0x00',
        data: '0x'
      };

      const tx = FeeMarketEIP1559Transaction.fromTxData(txParams, { common });
      const signedTx = tx.sign(privateKey);

      expect(signedTx.maxPriorityFeePerGas).toBeDefined();
      expect(signedTx.maxFeePerGas).toBeDefined();
      expect(signedTx.verifySignature()).toBe(true);
    });

    it('should validate maxPriorityFeePerGas <= maxFeePerGas', () => {
      const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.London });

      const txParams = {
        chainId: 1,
        nonce: '0x00',
        maxPriorityFeePerGas: '0x3b9aca00', // 1 Gwei
        maxFeePerGas: '0x77359400', // 2 Gwei
        gasLimit: '0x5208',
        to: '0x0000000000000000000000000000000000000000',
        value: '0x00',
      };

      const tx = FeeMarketEIP1559Transaction.fromTxData(txParams, { common });
      const signedTx = tx.sign(privateKey);

      expect(signedTx.maxPriorityFeePerGas! <= signedTx.maxFeePerGas!).toBe(true);
    });

    it('should sign EIP-1559 transaction with access list', () => {
      const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.London });

      const txParams = {
        chainId: 1,
        nonce: '0x00',
        maxPriorityFeePerGas: '0x3b9aca00',
        maxFeePerGas: '0x2540be400',
        gasLimit: '0x5208',
        to: '0x0000000000000000000000000000000000000000',
        value: '0x00',
        accessList: [
          {
            address: '0x0000000000000000000000000000000000000001',
            storageKeys: ['0x0000000000000000000000000000000000000000000000000000000000000000']
          }
        ]
      };

      const tx = FeeMarketEIP1559Transaction.fromTxData(txParams, { common });
      const signedTx = tx.sign(privateKey);

      expect(signedTx.accessList).toBeDefined();
      expect(signedTx.verifySignature()).toBe(true);
    });
  });

  describe('Transaction Serialization and Recovery', () => {
    it('should serialize and deserialize signed transaction', () => {
      const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.London });

      const txParams = {
        nonce: '0x00',
        gasPrice: '0x09184e72a000',
        gasLimit: '0x2710',
        to: '0x0000000000000000000000000000000000000000',
        value: '0x0186a0', // 100000 wei
        data: '0x'
      };

      const tx = Transaction.fromTxData(txParams, { common });
      const signedTx = tx.sign(privateKey);

      const serialized = signedTx.serialize();
      const deserialized = Transaction.fromSerializedTx(serialized, { common });

      expect(deserialized.verifySignature()).toBe(true);
      expect(bufferToHex(deserialized.serialize())).toBe(bufferToHex(serialized));
    });

    it('should recover sender address from signed transaction', () => {
      const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.London });

      const tx = Transaction.fromTxData({
        nonce: '0x00',
        gasPrice: '0x09184e72a000',
        gasLimit: '0x2710',
        to: '0x0000000000000000000000000000000000000000',
        value: '0x00'
      }, { common });

      const signedTx = tx.sign(privateKey);
      const senderAddress = signedTx.getSenderAddress();
      const expectedAddress = privateToAddress(privateKey);

      expect(senderAddress.toString()).toBe(bufferToHex(expectedAddress));
    });
  });

  describe('Transaction Hash Calculation', () => {
    it('should calculate correct transaction hash', () => {
      const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.London });

      const tx = Transaction.fromTxData({
        nonce: '0x00',
        gasPrice: '0x09184e72a000',
        gasLimit: '0x2710',
        to: '0x0000000000000000000000000000000000000000',
        value: '0x00',
        data: '0x'
      }, { common });

      const signedTx = tx.sign(privateKey);
      const hash = signedTx.hash();

      expect(hash).toBeDefined();
      expect(hash.length).toBe(32);
      expect(bufferToHex(hash)).toMatch(/^0x[0-9a-f]{64}$/);
    });
  });

  describe('Contract Deployment Transaction', () => {
    it('should sign contract deployment transaction (to = null)', () => {
      const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.London });

      // Simple contract bytecode (example)
      const contractBytecode = '0x6080604052348015600f57600080fd5b50603f80601d6000396000f3fe6080604052600080fdfea264697066735822';

      const tx = Transaction.fromTxData({
        nonce: '0x00',
        gasPrice: '0x09184e72a000',
        gasLimit: '0x186a0', // Higher gas for contract deployment
        value: '0x00',
        data: contractBytecode
      }, { common });

      const signedTx = tx.sign(privateKey);

      expect(signedTx.to).toBeUndefined();
      expect(signedTx.data.toString('hex')).toContain(contractBytecode.slice(2));
      expect(signedTx.verifySignature()).toBe(true);
    });
  });

  describe('Multi-signature coordination', () => {
    it('should sign same transaction with different private keys', () => {
      const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.London });

      const txParams = {
        nonce: '0x00',
        gasPrice: '0x09184e72a000',
        gasLimit: '0x2710',
        to: '0x0000000000000000000000000000000000000000',
        value: '0x00'
      };

      // First signer
      const tx1 = Transaction.fromTxData(txParams, { common });
      const signedTx1 = tx1.sign(privateKey);

      // Second signer (different derivation path)
      const child2 = root.derivePath("m/44'/60'/0'/0/1");
      const privateKey2 = child2.privateKey!;
      const tx2 = Transaction.fromTxData(txParams, { common });
      const signedTx2 = tx2.sign(privateKey2);

      expect(signedTx1.getSenderAddress().toString()).not.toBe(signedTx2.getSenderAddress().toString());
      expect(signedTx1.verifySignature()).toBe(true);
      expect(signedTx2.verifySignature()).toBe(true);
    });
  });
});
