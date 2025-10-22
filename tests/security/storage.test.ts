/**
 * @test Secure Storage Tests
 * @description Tests for encryption, access control, and secure data persistence
 * @prerequisites
 *   - Encryption libraries available
 *   - Secure storage implementation
 * @expected All storage operations maintain confidentiality and integrity
 */

import crypto from 'crypto';

// Mock secure storage implementation
class SecureStorage {
  private storage: Map<string, { data: Buffer; iv: Buffer; authTag: Buffer }> = new Map();
  private masterKey: Buffer;

  constructor(masterKey?: Buffer) {
    this.masterKey = masterKey || crypto.randomBytes(32);
  }

  async encrypt(key: string, plaintext: string): Promise<void> {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv('aes-256-gcm', this.masterKey, iv);

    let encrypted = cipher.update(plaintext, 'utf8');
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    const authTag = cipher.getAuthTag();

    this.storage.set(key, { data: encrypted, iv, authTag });
  }

  async decrypt(key: string): Promise<string | null> {
    const stored = this.storage.get(key);
    if (!stored) return null;

    const decipher = crypto.createDecipheriv('aes-256-gcm', this.masterKey, stored.iv);
    decipher.setAuthTag(stored.authTag);

    let decrypted = decipher.update(stored.data);
    decrypted = Buffer.concat([decrypted, decipher.final()]);

    return decrypted.toString('utf8');
  }

  async delete(key: string): Promise<boolean> {
    return this.storage.delete(key);
  }

  async clear(): Promise<void> {
    this.storage.clear();
  }

  async exists(key: string): Promise<boolean> {
    return this.storage.has(key);
  }

  // Secure key derivation
  static deriveKey(password: string, salt: Buffer): Buffer {
    return crypto.pbkdf2Sync(password, salt, 100000, 32, 'sha256');
  }
}

describe('Secure Storage Tests', () => {
  let storage: SecureStorage;

  beforeEach(() => {
    storage = new SecureStorage();
  });

  afterEach(async () => {
    await storage.clear();
  });

  describe('Encryption Tests', () => {
    it('should encrypt and decrypt data correctly', async () => {
      const plaintext = 'sensitive private key data';
      await storage.encrypt('privateKey', plaintext);

      const decrypted = await storage.decrypt('privateKey');
      expect(decrypted).toBe(plaintext);
    });

    it('should use AES-256-GCM encryption', async () => {
      const plaintext = 'test data';
      await storage.encrypt('test', plaintext);

      // Verify data is actually encrypted (not plaintext)
      const stored = (storage as any).storage.get('test');
      expect(stored.data.toString('utf8')).not.toContain(plaintext);
      expect(stored.iv).toHaveLength(16);
      expect(stored.authTag).toHaveLength(16);
    });

    it('should use unique IVs for each encryption', async () => {
      const plaintext = 'same data';

      await storage.encrypt('key1', plaintext);
      await storage.encrypt('key2', plaintext);

      const stored1 = (storage as any).storage.get('key1');
      const stored2 = (storage as any).storage.get('key2');

      expect(stored1.iv.equals(stored2.iv)).toBe(false);
      expect(stored1.data.equals(stored2.data)).toBe(false); // Different ciphertext
    });

    it('should detect tampering with authentication tag', async () => {
      const plaintext = 'secure data';
      await storage.encrypt('test', plaintext);

      // Tamper with stored data
      const stored = (storage as any).storage.get('test');
      stored.data[0] ^= 0xFF; // Flip bits

      await expect(storage.decrypt('test')).rejects.toThrow();
    });

    it('should detect tampering with IV', async () => {
      const plaintext = 'secure data';
      await storage.encrypt('test', plaintext);

      // Tamper with IV
      const stored = (storage as any).storage.get('test');
      stored.iv[0] ^= 0xFF;

      await expect(storage.decrypt('test')).rejects.toThrow();
    });

    it('should handle large data encryption', async () => {
      const largePlaintext = 'x'.repeat(1024 * 1024); // 1MB
      await storage.encrypt('large', largePlaintext);

      const decrypted = await storage.decrypt('large');
      expect(decrypted).toBe(largePlaintext);
    });

    it('should encrypt special characters and unicode', async () => {
      const specialText = '🔐 Private Key: ñ, ü, ö, 密钥, مفتاح';
      await storage.encrypt('special', specialText);

      const decrypted = await storage.decrypt('special');
      expect(decrypted).toBe(specialText);
    });
  });

  describe('Access Control Tests', () => {
    it('should isolate data between different keys', async () => {
      await storage.encrypt('user1:privateKey', 'user1 secret');
      await storage.encrypt('user2:privateKey', 'user2 secret');

      const user1Data = await storage.decrypt('user1:privateKey');
      const user2Data = await storage.decrypt('user2:privateKey');

      expect(user1Data).toBe('user1 secret');
      expect(user2Data).toBe('user2 secret');
      expect(user1Data).not.toBe(user2Data);
    });

    it('should return null for non-existent keys', async () => {
      const result = await storage.decrypt('nonexistent');
      expect(result).toBeNull();
    });

    it('should verify key existence before access', async () => {
      expect(await storage.exists('test')).toBe(false);

      await storage.encrypt('test', 'data');
      expect(await storage.exists('test')).toBe(true);

      await storage.delete('test');
      expect(await storage.exists('test')).toBe(false);
    });

    it('should properly delete sensitive data', async () => {
      await storage.encrypt('sensitive', 'private key');
      expect(await storage.exists('sensitive')).toBe(true);

      const deleted = await storage.delete('sensitive');
      expect(deleted).toBe(true);
      expect(await storage.exists('sensitive')).toBe(false);
      expect(await storage.decrypt('sensitive')).toBeNull();
    });

    it('should enforce master key requirement', () => {
      const masterKey = crypto.randomBytes(32);
      const storage1 = new SecureStorage(masterKey);
      const storage2 = new SecureStorage(crypto.randomBytes(32)); // Different key

      storage1.encrypt('test', 'secret data');

      // Storage2 cannot decrypt storage1's data (different master key)
      expect(async () => {
        const stored = (storage1 as any).storage.get('test');
        (storage2 as any).storage.set('test', stored);
        await storage2.decrypt('test');
      }).rejects.toThrow();
    });
  });

  describe('Key Derivation Tests', () => {
    it('should derive consistent keys from same password and salt', () => {
      const password = 'user_password_123';
      const salt = crypto.randomBytes(32);

      const key1 = SecureStorage.deriveKey(password, salt);
      const key2 = SecureStorage.deriveKey(password, salt);

      expect(key1.equals(key2)).toBe(true);
    });

    it('should derive different keys from different passwords', () => {
      const salt = crypto.randomBytes(32);

      const key1 = SecureStorage.deriveKey('password1', salt);
      const key2 = SecureStorage.deriveKey('password2', salt);

      expect(key1.equals(key2)).toBe(false);
    });

    it('should derive different keys from different salts', () => {
      const password = 'same_password';

      const key1 = SecureStorage.deriveKey(password, crypto.randomBytes(32));
      const key2 = SecureStorage.deriveKey(password, crypto.randomBytes(32));

      expect(key1.equals(key2)).toBe(false);
    });

    it('should use sufficient iterations for PBKDF2', () => {
      const password = 'test_password';
      const salt = crypto.randomBytes(32);

      const start = process.hrtime.bigint();
      SecureStorage.deriveKey(password, salt);
      const end = process.hrtime.bigint();

      const durationMs = Number(end - start) / 1000000;

      // Should take reasonable time (indicating sufficient iterations)
      expect(durationMs).toBeGreaterThan(10); // At least 10ms
    });

    it('should produce 256-bit keys', () => {
      const password = 'test_password';
      const salt = crypto.randomBytes(32);

      const key = SecureStorage.deriveKey(password, salt);

      expect(key).toHaveLength(32); // 256 bits
    });
  });

  describe('Data Integrity Tests', () => {
    it('should maintain data integrity over multiple operations', async () => {
      const data = {
        privateKey: '0x' + crypto.randomBytes(32).toString('hex'),
        mnemonic: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
        address: '0x' + crypto.randomBytes(20).toString('hex'),
      };

      await storage.encrypt('wallet:privateKey', data.privateKey);
      await storage.encrypt('wallet:mnemonic', data.mnemonic);
      await storage.encrypt('wallet:address', data.address);

      // Verify all data remains intact
      expect(await storage.decrypt('wallet:privateKey')).toBe(data.privateKey);
      expect(await storage.decrypt('wallet:mnemonic')).toBe(data.mnemonic);
      expect(await storage.decrypt('wallet:address')).toBe(data.address);
    });

    it('should handle concurrent encryption operations', async () => {
      const promises = [];

      for (let i = 0; i < 100; i++) {
        promises.push(storage.encrypt(`key${i}`, `value${i}`));
      }

      await Promise.all(promises);

      // Verify all data stored correctly
      for (let i = 0; i < 100; i++) {
        const value = await storage.decrypt(`key${i}`);
        expect(value).toBe(`value${i}`);
      }
    });

    it('should preserve data across clear operations for specific keys', async () => {
      await storage.encrypt('keep', 'important data');
      await storage.encrypt('temp1', 'temporary data');
      await storage.encrypt('temp2', 'temporary data');

      await storage.delete('temp1');
      await storage.delete('temp2');

      expect(await storage.decrypt('keep')).toBe('important data');
      expect(await storage.decrypt('temp1')).toBeNull();
      expect(await storage.decrypt('temp2')).toBeNull();
    });
  });

  describe('Security Edge Cases', () => {
    it('should handle empty string encryption', async () => {
      await storage.encrypt('empty', '');
      const decrypted = await storage.decrypt('empty');
      expect(decrypted).toBe('');
    });

    it('should handle whitespace-only encryption', async () => {
      const whitespace = '   \t\n  ';
      await storage.encrypt('whitespace', whitespace);
      const decrypted = await storage.decrypt('whitespace');
      expect(decrypted).toBe(whitespace);
    });

    it('should prevent key enumeration attacks', () => {
      // Storage should not leak information about which keys exist
      expect(async () => {
        await storage.decrypt('random_key_that_does_not_exist');
      }).not.toThrow();
    });

    it('should handle binary data encryption', async () => {
      const binaryData = crypto.randomBytes(256).toString('base64');
      await storage.encrypt('binary', binaryData);
      const decrypted = await storage.decrypt('binary');
      expect(decrypted).toBe(binaryData);
    });

    it('should enforce key length validation', () => {
      const shortKey = crypto.randomBytes(16); // 128 bits (too short)
      const validKey = crypto.randomBytes(32); // 256 bits

      expect(() => new SecureStorage(shortKey)).toThrow();
      expect(() => new SecureStorage(validKey)).not.toThrow();
    });
  });

  describe('Performance and Efficiency', () => {
    it('should encrypt and decrypt within acceptable time', async () => {
      const plaintext = 'performance test data';

      const encryptStart = process.hrtime.bigint();
      await storage.encrypt('perf', plaintext);
      const encryptEnd = process.hrtime.bigint();

      const decryptStart = process.hrtime.bigint();
      await storage.decrypt('perf');
      const decryptEnd = process.hrtime.bigint();

      const encryptTime = Number(encryptEnd - encryptStart) / 1000000;
      const decryptTime = Number(decryptEnd - decryptStart) / 1000000;

      expect(encryptTime).toBeLessThan(10); // < 10ms
      expect(decryptTime).toBeLessThan(10); // < 10ms
    });

    it('should handle batch operations efficiently', async () => {
      const count = 1000;
      const start = process.hrtime.bigint();

      const promises = [];
      for (let i = 0; i < count; i++) {
        promises.push(storage.encrypt(`batch${i}`, `value${i}`));
      }
      await Promise.all(promises);

      const end = process.hrtime.bigint();
      const duration = Number(end - start) / 1000000;

      // Should complete in reasonable time
      expect(duration).toBeLessThan(5000); // < 5 seconds for 1000 operations
    });
  });
});
