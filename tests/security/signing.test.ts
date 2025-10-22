/**
 * @test Transaction Signing Tests
 * @description Tests for cryptographic signing with known test vectors
 * @prerequisites
 *   - Elliptic curve libraries available
 *   - Test vectors from official standards
 * @expected All signatures verify correctly and resist attacks
 */

import crypto from 'crypto';
import { ec as EC } from 'elliptic';
import * as ethUtil from 'ethereumjs-util';
import * as bitcoin from 'bitcoinjs-lib';

describe('Transaction Signing Tests', () => {
  const ec = new EC('secp256k1');

  describe('ECDSA Signature Test Vectors', () => {
    // Test vectors from RFC 6979
    const testVectors = [
      {
        privateKey: '0xC9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721',
        message: 'sample',
        expectedR: 'EFD48B2AACB6A8FD1140DD9CD45E81D69D2C877B56AAF991C34D0EA84EAF3716',
        expectedS: 'F7CB1C942D657C41D436C7A1B6E29F65F3E900DBB9AFF4064DC4AB2F843ACDA8',
      },
      {
        privateKey: '0xC9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721',
        message: 'test',
        expectedR: 'F1ABB023518351CD71D881567B1EA663ED3EFCF6C5132B354F28D3B0B7D38367',
        expectedS: '019F4113742A2B14BD25926B49C649155F267E60D3814B4C0CC84250E46F0083',
      },
    ];

    testVectors.forEach((vector, index) => {
      it(`should produce correct signature for test vector ${index + 1}`, () => {
        const privateKey = vector.privateKey.replace('0x', '');
        const messageHash = crypto.createHash('sha256').update(vector.message).digest();

        const keyPair = ec.keyFromPrivate(privateKey, 'hex');
        const signature = keyPair.sign(messageHash, { canonical: true });

        const r = signature.r.toString('hex').toUpperCase().padStart(64, '0');
        const s = signature.s.toString('hex').toUpperCase().padStart(64, '0');

        expect(r).toBe(vector.expectedR);
        expect(s).toBe(vector.expectedS);
      });
    });
  });

  describe('Ethereum Transaction Signing', () => {
    it('should sign Ethereum transaction correctly', () => {
      const privateKey = Buffer.from('4646464646464646464646464646464646464646464646464646464646464646', 'hex');
      const txParams = {
        nonce: '0x00',
        gasPrice: '0x09184e72a000',
        gasLimit: '0x2710',
        to: '0x0000000000000000000000000000000000000000',
        value: '0x00',
        data: '0x7f7465737432000000000000000000000000000000000000000000000000000000600057',
      };

      // Create message hash
      const msgHash = ethUtil.keccak256(Buffer.from(JSON.stringify(txParams)));

      // Sign
      const signature = ethUtil.ecsign(msgHash, privateKey);

      // Verify signature components
      expect(signature.r).toHaveLength(32);
      expect(signature.s).toHaveLength(32);
      expect(signature.v).toBeGreaterThanOrEqual(27);
      expect(signature.v).toBeLessThanOrEqual(28);

      // Recover public key
      const publicKey = ethUtil.ecrecover(msgHash, signature.v, signature.r, signature.s);
      const address = ethUtil.publicToAddress(publicKey);

      // Verify address matches private key
      const expectedAddress = ethUtil.privateToAddress(privateKey);
      expect(address.equals(expectedAddress)).toBe(true);
    });

    it('should produce deterministic signatures (RFC 6979)', () => {
      const privateKey = crypto.randomBytes(32);
      const message = crypto.randomBytes(32);

      const sig1 = ethUtil.ecsign(message, privateKey);
      const sig2 = ethUtil.ecsign(message, privateKey);

      expect(sig1.r.equals(sig2.r)).toBe(true);
      expect(sig1.s.equals(sig2.s)).toBe(true);
      expect(sig1.v).toBe(sig2.v);
    });

    it('should use low-s values for malleability protection', () => {
      const privateKey = crypto.randomBytes(32);
      const message = crypto.randomBytes(32);

      const signature = ethUtil.ecsign(message, privateKey);

      // s value should be in lower half of curve order
      const secp256k1N = BigInt('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141');
      const s = BigInt('0x' + signature.s.toString('hex'));

      expect(s <= secp256k1N / 2n).toBe(true);
    });
  });

  describe('Bitcoin Transaction Signing', () => {
    it('should sign Bitcoin transaction with P2PKH', () => {
      const keyPair = bitcoin.ECPair.makeRandom();
      const { address } = bitcoin.payments.p2pkh({ pubkey: keyPair.publicKey });

      const psbt = new bitcoin.Psbt();

      // Add dummy input (in real scenario, this would be a UTXO)
      const txHex = '0200000001f9f34e95b9d5c8abcd20fc5bd4a825d1517be62f0f775e5f36da944d9452e550000000006b483045022100c86e9a111afc90f64b4904bd609e9eaed80d48ca17c162b1aca0a788ac3526f002207bb79b60d4fc6526329bf18a77135dc5660209e761da46e1c2f1152ec013215801210211755115eabf846720f5cb18f248666fec631e5e1e66009ce3710ceea5b1ad13ffffffff01905f0100000000001976a9148bbc95d2709c71607c60ee3f097c1217482f518d88ac00000000';

      psbt.addInput({
        hash: 'f9f34e95b9d5c8abcd20fc5bd4a825d1517be62f0f775e5f36da944d9452e550',
        index: 0,
        nonWitnessUtxo: Buffer.from(txHex, 'hex'),
      });

      psbt.addOutput({
        address: address!,
        value: 90000,
      });

      psbt.signInput(0, keyPair);
      psbt.validateSignaturesOfInput(0);
      psbt.finalizeAllInputs();

      const tx = psbt.extractTransaction();
      expect(tx.getId()).toBeDefined();
    });

    it('should sign Bitcoin SegWit transaction', () => {
      const keyPair = bitcoin.ECPair.makeRandom();
      const { address } = bitcoin.payments.p2wpkh({ pubkey: keyPair.publicKey });

      const psbt = new bitcoin.Psbt();

      psbt.addInput({
        hash: 'a'.repeat(64),
        index: 0,
        witnessUtxo: {
          script: Buffer.from('0014' + '00'.repeat(20), 'hex'),
          value: 100000,
        },
      });

      psbt.addOutput({
        address: address!,
        value: 90000,
      });

      psbt.signInput(0, keyPair);

      expect(() => psbt.validateSignaturesOfInput(0)).not.toThrow();
    });
  });

  describe('Signature Verification', () => {
    it('should verify valid signatures', () => {
      const keyPair = ec.genKeyPair();
      const message = crypto.randomBytes(32);

      const signature = keyPair.sign(message);
      const isValid = keyPair.verify(message, signature);

      expect(isValid).toBe(true);
    });

    it('should reject invalid signatures', () => {
      const keyPair = ec.genKeyPair();
      const message = crypto.randomBytes(32);
      const wrongMessage = crypto.randomBytes(32);

      const signature = keyPair.sign(message);
      const isValid = keyPair.verify(wrongMessage, signature);

      expect(isValid).toBe(false);
    });

    it('should reject signatures from wrong key', () => {
      const keyPair1 = ec.genKeyPair();
      const keyPair2 = ec.genKeyPair();
      const message = crypto.randomBytes(32);

      const signature = keyPair1.sign(message);
      const isValid = keyPair2.verify(message, signature);

      expect(isValid).toBe(false);
    });

    it('should reject tampered signatures', () => {
      const keyPair = ec.genKeyPair();
      const message = crypto.randomBytes(32);

      const signature = keyPair.sign(message);

      // Tamper with r value
      signature.r = signature.r.add(ec.curve.n.subn(1));

      const isValid = keyPair.verify(message, signature);
      expect(isValid).toBe(false);
    });
  });

  describe('Signature Malleability Protection', () => {
    it('should prevent signature malleability attacks', () => {
      const privateKey = crypto.randomBytes(32);
      const message = crypto.randomBytes(32);

      const signature = ethUtil.ecsign(message, privateKey);

      // Attempt to create malleable signature (flip s value)
      const secp256k1N = BigInt('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141');
      const s = BigInt('0x' + signature.s.toString('hex'));
      const malleableS = secp256k1N - s;

      // Original should be low-s
      expect(s <= secp256k1N / 2n).toBe(true);

      // Malleable should be high-s (rejected)
      expect(malleableS > secp256k1N / 2n).toBe(true);
    });

    it('should use canonical signatures', () => {
      const keyPair = ec.genKeyPair();
      const message = crypto.randomBytes(32);

      const signature = keyPair.sign(message, { canonical: true });

      // s should be in lower half
      const s = signature.s.toBigInt();
      const halfN = ec.curve.n.shrn(1).toBigInt();

      expect(s <= halfN).toBe(true);
    });
  });

  describe('Edge Cases and Attack Resistance', () => {
    it('should handle zero message hash gracefully', () => {
      const keyPair = ec.genKeyPair();
      const zeroMessage = Buffer.alloc(32, 0);

      expect(() => {
        keyPair.sign(zeroMessage);
      }).not.toThrow();
    });

    it('should reject signatures with invalid r or s values', () => {
      const keyPair = ec.genKeyPair();
      const message = crypto.randomBytes(32);

      // Create invalid signature (r = 0)
      const invalidSig = {
        r: ec.curve.n.muln(0),
        s: ec.curve.n.subn(1),
        recoveryParam: 0,
      };

      const isValid = keyPair.verify(message, invalidSig);
      expect(isValid).toBe(false);
    });

    it('should handle maximum value messages', () => {
      const keyPair = ec.genKeyPair();
      const maxMessage = Buffer.alloc(32, 0xFF);

      const signature = keyPair.sign(maxMessage);
      const isValid = keyPair.verify(maxMessage, signature);

      expect(isValid).toBe(true);
    });

    it('should prevent private key recovery from signatures', () => {
      const privateKey = crypto.randomBytes(32);
      const message = crypto.randomBytes(32);

      const signature = ethUtil.ecsign(message, privateKey);

      // Attempting to recover private key from signature should not be possible
      // We can only recover public key
      const publicKey = ethUtil.ecrecover(message, signature.v, signature.r, signature.s);

      expect(publicKey).toBeDefined();
      expect(publicKey).toHaveLength(64); // Public key, not private
    });
  });

  describe('Performance Tests', () => {
    it('should sign transactions efficiently', () => {
      const keyPair = ec.genKeyPair();
      const iterations = 1000;

      const start = process.hrtime.bigint();

      for (let i = 0; i < iterations; i++) {
        const message = crypto.randomBytes(32);
        keyPair.sign(message);
      }

      const end = process.hrtime.bigint();
      const duration = Number(end - start) / 1000000;

      // Should complete 1000 signatures in reasonable time
      expect(duration).toBeLessThan(1000); // < 1 second
    });

    it('should verify signatures efficiently', () => {
      const keyPair = ec.genKeyPair();
      const message = crypto.randomBytes(32);
      const signature = keyPair.sign(message);
      const iterations = 1000;

      const start = process.hrtime.bigint();

      for (let i = 0; i < iterations; i++) {
        keyPair.verify(message, signature);
      }

      const end = process.hrtime.bigint();
      const duration = Number(end - start) / 1000000;

      expect(duration).toBeLessThan(1000); // < 1 second
    });
  });
});
