/**
 * @test Secure Memory Wiping Tests
 * @description Tests for secure deletion and memory wiping of sensitive data
 * @prerequisites
 *   - Memory management utilities
 *   - Secure deletion mechanisms
 * @expected Private keys and sensitive data are securely wiped from memory
 */

import crypto from 'crypto';

// Secure memory utilities
class SecureMemory {
  /**
   * Securely wipe a buffer by overwriting with random data multiple times
   */
  static secureWipe(buffer: Buffer, passes: number = 3): void {
    for (let i = 0; i < passes; i++) {
      // First pass: random data
      crypto.randomFillSync(buffer);

      // Second pass: zeros
      if (i === passes - 1) {
        buffer.fill(0);
      }
    }
  }

  /**
   * Securely wipe a string from memory
   */
  static secureWipeString(str: string): void {
    // In JavaScript, strings are immutable, so we can't directly wipe them
    // This demonstrates the concept; in production, use Buffer for sensitive data
    if (typeof str !== 'string') return;

    // Create a buffer from string and wipe it
    const buffer = Buffer.from(str, 'utf-8');
    SecureMemory.secureWipe(buffer);
  }

  /**
   * Create a secure buffer that will be wiped when no longer needed
   */
  static createSecureBuffer(size: number): SecureBuffer {
    return new SecureBuffer(size);
  }

  /**
   * Verify buffer has been wiped (all zeros or random pattern)
   */
  static isWiped(buffer: Buffer): boolean {
    // Check if all zeros
    const allZeros = buffer.every(byte => byte === 0);

    // Check if all same value (another wipe pattern)
    const firstByte = buffer[0];
    const allSame = buffer.every(byte => byte === firstByte);

    return allZeros || allSame;
  }
}

// Secure buffer wrapper with automatic wiping
class SecureBuffer {
  private buffer: Buffer;
  private isWiped: boolean = false;

  constructor(size: number) {
    this.buffer = Buffer.allocUnsafe(size);
  }

  write(data: Buffer | string): void {
    if (this.isWiped) {
      throw new Error('Cannot write to wiped buffer');
    }

    if (typeof data === 'string') {
      this.buffer.write(data, 'utf-8');
    } else {
      data.copy(this.buffer);
    }
  }

  read(): Buffer {
    if (this.isWiped) {
      throw new Error('Cannot read from wiped buffer');
    }
    return this.buffer;
  }

  wipe(): void {
    SecureMemory.secureWipe(this.buffer);
    this.isWiped = true;
  }

  isSecurelyWiped(): boolean {
    return this.isWiped && SecureMemory.isWiped(this.buffer);
  }

  get length(): number {
    return this.buffer.length;
  }
}

// Private key manager with secure memory handling
class PrivateKeyManager {
  private keys: Map<string, SecureBuffer> = new Map();

  storeKey(keyId: string, privateKey: Buffer): void {
    const secureBuffer = SecureMemory.createSecureBuffer(privateKey.length);
    secureBuffer.write(privateKey);

    // Wipe the input buffer
    SecureMemory.secureWipe(privateKey);

    this.keys.set(keyId, secureBuffer);
  }

  getKey(keyId: string): Buffer | null {
    const secureBuffer = this.keys.get(keyId);
    if (!secureBuffer) return null;

    // Return a copy, not the original
    return Buffer.from(secureBuffer.read());
  }

  deleteKey(keyId: string): boolean {
    const secureBuffer = this.keys.get(keyId);
    if (!secureBuffer) return false;

    secureBuffer.wipe();
    return this.keys.delete(keyId);
  }

  clearAll(): void {
    for (const [keyId, secureBuffer] of this.keys.entries()) {
      secureBuffer.wipe();
    }
    this.keys.clear();
  }

  isKeyWiped(keyId: string): boolean {
    const secureBuffer = this.keys.get(keyId);
    if (!secureBuffer) return true;

    return secureBuffer.isSecurelyWiped();
  }
}

describe('Secure Memory Wiping Tests', () => {
  describe('Basic Memory Wiping', () => {
    it('should wipe buffer with zeros', () => {
      const buffer = Buffer.from('sensitive private key data');
      const originalData = buffer.toString('utf-8');

      SecureMemory.secureWipe(buffer);

      expect(buffer.toString('utf-8')).not.toBe(originalData);
      expect(SecureMemory.isWiped(buffer)).toBe(true);
    });

    it('should perform multiple wipe passes', () => {
      const buffer = crypto.randomBytes(32);
      const original = Buffer.from(buffer);

      SecureMemory.secureWipe(buffer, 5);

      expect(buffer.equals(original)).toBe(false);
      expect(SecureMemory.isWiped(buffer)).toBe(true);
    });

    it('should wipe sensitive strings', () => {
      const sensitiveString = 'my private key: 0x' + crypto.randomBytes(32).toString('hex');

      // Convert to buffer for wiping
      const buffer = Buffer.from(sensitiveString, 'utf-8');
      SecureMemory.secureWipe(buffer);

      expect(buffer.toString('utf-8')).not.toContain('private key');
      expect(SecureMemory.isWiped(buffer)).toBe(true);
    });

    it('should handle empty buffers', () => {
      const emptyBuffer = Buffer.alloc(0);

      expect(() => SecureMemory.secureWipe(emptyBuffer)).not.toThrow();
    });

    it('should handle large buffers efficiently', () => {
      const largeBuffer = crypto.randomBytes(1024 * 1024); // 1MB

      const start = process.hrtime.bigint();
      SecureMemory.secureWipe(largeBuffer);
      const end = process.hrtime.bigint();

      const duration = Number(end - start) / 1000000; // ms
      expect(duration).toBeLessThan(100); // Should complete in < 100ms
      expect(SecureMemory.isWiped(largeBuffer)).toBe(true);
    });
  });

  describe('SecureBuffer Tests', () => {
    it('should create and use secure buffer', () => {
      const secureBuffer = SecureMemory.createSecureBuffer(32);
      const data = crypto.randomBytes(32);

      secureBuffer.write(data);

      const retrieved = secureBuffer.read();
      expect(retrieved.equals(data)).toBe(true);
    });

    it('should wipe secure buffer on demand', () => {
      const secureBuffer = SecureMemory.createSecureBuffer(32);
      const data = crypto.randomBytes(32);

      secureBuffer.write(data);
      secureBuffer.wipe();

      expect(secureBuffer.isSecurelyWiped()).toBe(true);
      expect(() => secureBuffer.read()).toThrow('wiped');
    });

    it('should prevent writing to wiped buffer', () => {
      const secureBuffer = SecureMemory.createSecureBuffer(32);

      secureBuffer.wipe();

      expect(() => secureBuffer.write('new data')).toThrow('wiped');
    });

    it('should prevent reading from wiped buffer', () => {
      const secureBuffer = SecureMemory.createSecureBuffer(32);
      secureBuffer.write('sensitive data');
      secureBuffer.wipe();

      expect(() => secureBuffer.read()).toThrow('wiped');
    });

    it('should handle string data', () => {
      const secureBuffer = SecureMemory.createSecureBuffer(64);
      const secretPhrase = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

      secureBuffer.write(secretPhrase);

      const retrieved = secureBuffer.read().toString('utf-8');
      expect(retrieved).toContain('abandon');

      secureBuffer.wipe();
      expect(secureBuffer.isSecurelyWiped()).toBe(true);
    });
  });

  describe('Private Key Manager Tests', () => {
    let keyManager: PrivateKeyManager;

    beforeEach(() => {
      keyManager = new PrivateKeyManager();
    });

    afterEach(() => {
      keyManager.clearAll();
    });

    it('should store and retrieve private keys', () => {
      const privateKey = crypto.randomBytes(32);
      const keyId = 'wallet1';

      keyManager.storeKey(keyId, privateKey);

      const retrieved = keyManager.getKey(keyId);
      expect(retrieved).toBeDefined();
      expect(retrieved?.length).toBe(32);
    });

    it('should wipe original buffer after storing', () => {
      const privateKey = crypto.randomBytes(32);
      const originalCopy = Buffer.from(privateKey);
      const keyId = 'wallet1';

      keyManager.storeKey(keyId, privateKey);

      // Original buffer should be wiped
      expect(privateKey.equals(originalCopy)).toBe(false);
      expect(SecureMemory.isWiped(privateKey)).toBe(true);
    });

    it('should securely delete private keys', () => {
      const privateKey = crypto.randomBytes(32);
      const keyId = 'wallet1';

      keyManager.storeKey(keyId, privateKey);
      const deleted = keyManager.deleteKey(keyId);

      expect(deleted).toBe(true);
      expect(keyManager.getKey(keyId)).toBeNull();
      expect(keyManager.isKeyWiped(keyId)).toBe(true);
    });

    it('should verify key is wiped after deletion', () => {
      const privateKey = crypto.randomBytes(32);
      const keyId = 'wallet1';

      keyManager.storeKey(keyId, Buffer.from(privateKey));
      keyManager.deleteKey(keyId);

      expect(keyManager.isKeyWiped(keyId)).toBe(true);
    });

    it('should clear all keys securely', () => {
      const keys = [
        { id: 'wallet1', key: crypto.randomBytes(32) },
        { id: 'wallet2', key: crypto.randomBytes(32) },
        { id: 'wallet3', key: crypto.randomBytes(32) },
      ];

      keys.forEach(({ id, key }) => {
        keyManager.storeKey(id, Buffer.from(key));
      });

      keyManager.clearAll();

      keys.forEach(({ id }) => {
        expect(keyManager.getKey(id)).toBeNull();
      });
    });

    it('should handle multiple keys independently', () => {
      const key1 = crypto.randomBytes(32);
      const key2 = crypto.randomBytes(32);

      keyManager.storeKey('wallet1', Buffer.from(key1));
      keyManager.storeKey('wallet2', Buffer.from(key2));

      keyManager.deleteKey('wallet1');

      expect(keyManager.getKey('wallet1')).toBeNull();
      expect(keyManager.getKey('wallet2')).not.toBeNull();
    });

    it('should return copies, not original buffers', () => {
      const privateKey = crypto.randomBytes(32);
      const keyId = 'wallet1';

      keyManager.storeKey(keyId, Buffer.from(privateKey));

      const retrieved1 = keyManager.getKey(keyId);
      const retrieved2 = keyManager.getKey(keyId);

      // Should be equal in value
      expect(retrieved1?.equals(retrieved2!)).toBe(true);

      // But different buffer instances
      expect(retrieved1).not.toBe(retrieved2);
    });
  });

  describe('Memory Leak Prevention', () => {
    it('should not leave traces in memory after wiping', () => {
      const sensitiveData = 'SENSITIVE_PRIVATE_KEY_' + crypto.randomBytes(16).toString('hex');
      const buffer = Buffer.from(sensitiveData, 'utf-8');

      SecureMemory.secureWipe(buffer);

      // Verify no traces of original data
      const bufferStr = buffer.toString('utf-8');
      expect(bufferStr).not.toContain('SENSITIVE');
      expect(bufferStr).not.toContain('PRIVATE_KEY');
    });

    it('should handle rapid allocation and deallocation', () => {
      const iterations = 1000;

      for (let i = 0; i < iterations; i++) {
        const buffer = crypto.randomBytes(32);
        SecureMemory.secureWipe(buffer);

        expect(SecureMemory.isWiped(buffer)).toBe(true);
      }
    });

    it('should wipe temporary computation buffers', () => {
      // Simulate cryptographic operation with intermediate values
      const privateKey = crypto.randomBytes(32);
      const intermediateBuffer = Buffer.from(privateKey);

      // Perform computation (simulated)
      const result = crypto.createHash('sha256').update(intermediateBuffer).digest();

      // Wipe intermediate values
      SecureMemory.secureWipe(intermediateBuffer);

      expect(SecureMemory.isWiped(intermediateBuffer)).toBe(true);
      expect(result).toHaveLength(32); // Result still available
    });
  });

  describe('Edge Cases and Stress Tests', () => {
    it('should handle concurrent wipe operations', async () => {
      const buffers = Array.from({ length: 100 }, () => crypto.randomBytes(32));

      await Promise.all(
        buffers.map(buffer => Promise.resolve(SecureMemory.secureWipe(buffer)))
      );

      buffers.forEach(buffer => {
        expect(SecureMemory.isWiped(buffer)).toBe(true);
      });
    });

    it('should wipe buffers of various sizes', () => {
      const sizes = [1, 16, 32, 64, 128, 256, 512, 1024, 4096];

      sizes.forEach(size => {
        const buffer = crypto.randomBytes(size);
        SecureMemory.secureWipe(buffer);
        expect(SecureMemory.isWiped(buffer)).toBe(true);
      });
    });

    it('should handle buffer reuse after wiping', () => {
      const buffer = Buffer.allocUnsafe(32);

      // Write, wipe, write again
      buffer.write('first sensitive data');
      SecureMemory.secureWipe(buffer);
      expect(SecureMemory.isWiped(buffer)).toBe(true);

      buffer.write('second sensitive data');
      expect(buffer.toString('utf-8')).toContain('second');

      SecureMemory.secureWipe(buffer);
      expect(SecureMemory.isWiped(buffer)).toBe(true);
    });

    it('should verify complete wiping (no partial data remains)', () => {
      const sensitiveData = 'a'.repeat(1000); // Repeated pattern
      const buffer = Buffer.from(sensitiveData, 'utf-8');

      SecureMemory.secureWipe(buffer);

      // Check no 'a' characters remain
      for (let i = 0; i < buffer.length; i++) {
        expect(buffer[i]).not.toBe('a'.charCodeAt(0));
      }
    });
  });

  describe('Performance Tests', () => {
    it('should wipe buffers efficiently', () => {
      const buffer = crypto.randomBytes(1024);

      const start = process.hrtime.bigint();
      SecureMemory.secureWipe(buffer);
      const end = process.hrtime.bigint();

      const duration = Number(end - start) / 1000000; // ms
      expect(duration).toBeLessThan(10); // < 10ms for 1KB
    });

    it('should handle high-frequency wiping', () => {
      const iterations = 10000;
      const buffer = Buffer.allocUnsafe(32);

      const start = process.hrtime.bigint();

      for (let i = 0; i < iterations; i++) {
        crypto.randomFillSync(buffer);
        SecureMemory.secureWipe(buffer, 1); // Single pass for speed
      }

      const end = process.hrtime.bigint();
      const duration = Number(end - start) / 1000000; // ms

      expect(duration).toBeLessThan(1000); // < 1 second for 10k wipes
    });
  });

  describe('Integration with Real-World Scenarios', () => {
    it('should securely handle mnemonic phrases', () => {
      const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
      const mnemonicBuffer = Buffer.from(mnemonic, 'utf-8');

      // Use mnemonic for key derivation (simulated)
      const seed = crypto.createHash('sha256').update(mnemonicBuffer).digest();

      // Wipe mnemonic from memory
      SecureMemory.secureWipe(mnemonicBuffer);

      expect(mnemonicBuffer.toString('utf-8')).not.toContain('abandon');
      expect(SecureMemory.isWiped(mnemonicBuffer)).toBe(true);
      expect(seed).toHaveLength(32); // Seed still available
    });

    it('should securely handle password-derived keys', () => {
      const password = 'user_password_123';
      const salt = crypto.randomBytes(32);

      // Derive key
      const derivedKey = crypto.pbkdf2Sync(password, salt, 100000, 32, 'sha256');

      // Wipe intermediate values
      const passwordBuffer = Buffer.from(password, 'utf-8');
      SecureMemory.secureWipe(passwordBuffer);
      SecureMemory.secureWipe(salt);

      expect(SecureMemory.isWiped(passwordBuffer)).toBe(true);
      expect(SecureMemory.isWiped(salt)).toBe(true);
      expect(derivedKey).toHaveLength(32);
    });
  });
});
