/**
 * Encryption Service
 *
 * Handles all cryptographic operations including:
 * - AES-256-GCM encryption/decryption
 * - Secure random generation
 * - Key derivation (PBKDF2)
 * - Hashing
 */

import { NativeModules, Platform } from 'react-native';
import crypto from 'react-native-quick-crypto';
import { SecurityConfig, SecurityError, SecurityErrorCode } from './SecurityConfig';
import { SecurityLogger } from './SecurityLogger';

/**
 * Encrypted data structure
 */
export interface EncryptedData {
  ciphertext: string; // Base64 encoded
  iv: string; // Base64 encoded
  authTag: string; // Base64 encoded
  algorithm: string;
}

/**
 * Encryption Service
 */
export class EncryptionService {
  private static logger = SecurityLogger.getInstance();

  /**
   * Encrypt data using AES-256-GCM
   */
  static async encrypt(data: string, key: Buffer): Promise<EncryptedData> {
    try {
      const config = SecurityConfig.encryption.symmetric;

      // Validate key size
      if (key.length !== config.keySize / 8) {
        throw new SecurityError(
          SecurityErrorCode.ENCRYPTION_FAILED,
          `Invalid key size: expected ${config.keySize / 8} bytes`
        );
      }

      // Generate random IV
      const iv = crypto.randomBytes(config.ivSize);

      // Create cipher
      const cipher = crypto.createCipheriv(config.algorithm, key, iv);

      // Encrypt data
      let encrypted = cipher.update(data, 'utf8');
      encrypted = Buffer.concat([encrypted, cipher.final()]);

      // Get authentication tag
      const authTag = cipher.getAuthTag();

      this.logger.debug('Data encrypted successfully');

      return {
        ciphertext: encrypted.toString('base64'),
        iv: iv.toString('base64'),
        authTag: authTag.toString('base64'),
        algorithm: config.algorithm,
      };
    } catch (error: any) {
      this.logger.error('Encryption failed', { error: error.message });
      throw new SecurityError(
        SecurityErrorCode.ENCRYPTION_FAILED,
        'Failed to encrypt data',
        { error: error.message }
      );
    }
  }

  /**
   * Decrypt data using AES-256-GCM
   */
  static async decrypt(encryptedData: EncryptedData, key: Buffer): Promise<string> {
    try {
      const config = SecurityConfig.encryption.symmetric;

      // Validate key size
      if (key.length !== config.keySize / 8) {
        throw new SecurityError(
          SecurityErrorCode.DECRYPTION_FAILED,
          `Invalid key size: expected ${config.keySize / 8} bytes`
        );
      }

      // Decode Base64 data
      const ciphertext = Buffer.from(encryptedData.ciphertext, 'base64');
      const iv = Buffer.from(encryptedData.iv, 'base64');
      const authTag = Buffer.from(encryptedData.authTag, 'base64');

      // Create decipher
      const decipher = crypto.createDecipheriv(config.algorithm, key, iv);
      decipher.setAuthTag(authTag);

      // Decrypt data
      let decrypted = decipher.update(ciphertext);
      decrypted = Buffer.concat([decrypted, decipher.final()]);

      this.logger.debug('Data decrypted successfully');

      return decrypted.toString('utf8');
    } catch (error: any) {
      this.logger.error('Decryption failed', { error: error.message });
      throw new SecurityError(
        SecurityErrorCode.DECRYPTION_FAILED,
        'Failed to decrypt data',
        { error: error.message }
      );
    }
  }

  /**
   * Use Secure Enclave/Keystore for encryption (platform-specific)
   */
  static async encryptWithSecureEnclave(data: string): Promise<string> {
    try {
      if (Platform.OS === 'ios') {
        const { SecureEnclaveModule } = NativeModules;
        if (!SecureEnclaveModule) {
          throw new Error('Secure Enclave module not available');
        }
        return await SecureEnclaveModule.encrypt(data);
      } else if (Platform.OS === 'android') {
        const { KeystoreModule } = NativeModules;
        if (!KeystoreModule) {
          throw new Error('Keystore module not available');
        }
        return await KeystoreModule.encrypt(data);
      }

      throw new Error('Platform not supported');
    } catch (error: any) {
      this.logger.error('Secure Enclave encryption failed', { error: error.message });
      throw new SecurityError(
        SecurityErrorCode.ENCRYPTION_FAILED,
        'Failed to encrypt with Secure Enclave',
        { error: error.message }
      );
    }
  }

  /**
   * Use Secure Enclave/Keystore for decryption (platform-specific)
   */
  static async decryptWithSecureEnclave(encryptedData: string): Promise<string> {
    try {
      if (Platform.OS === 'ios') {
        const { SecureEnclaveModule } = NativeModules;
        if (!SecureEnclaveModule) {
          throw new Error('Secure Enclave module not available');
        }
        return await SecureEnclaveModule.decrypt(encryptedData);
      } else if (Platform.OS === 'android') {
        const { KeystoreModule } = NativeModules;
        if (!KeystoreModule) {
          throw new Error('Keystore module not available');
        }
        return await KeystoreModule.decrypt(encryptedData);
      }

      throw new Error('Platform not supported');
    } catch (error: any) {
      this.logger.error('Secure Enclave decryption failed', { error: error.message });
      throw new SecurityError(
        SecurityErrorCode.DECRYPTION_FAILED,
        'Failed to decrypt with Secure Enclave',
        { error: error.message }
      );
    }
  }

  /**
   * Generate secure random bytes
   */
  static generateRandomBytes(size: number): Buffer {
    try {
      return crypto.randomBytes(size);
    } catch (error: any) {
      this.logger.error('Failed to generate random bytes', { error: error.message });
      throw new SecurityError(
        SecurityErrorCode.KEY_GENERATION_FAILED,
        'Failed to generate random bytes',
        { error: error.message }
      );
    }
  }

  /**
   * Generate symmetric encryption key
   */
  static generateEncryptionKey(): Buffer {
    const keySize = SecurityConfig.encryption.symmetric.keySize / 8;
    return this.generateRandomBytes(keySize);
  }

  /**
   * Derive key from password using PBKDF2
   */
  static async deriveKeyFromPassword(
    password: string,
    salt: Buffer,
    iterations?: number,
    keySize?: number
  ): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const config = SecurityConfig.encryption.hashing;
      const actualIterations = iterations || config.iterations;
      const actualKeySize = keySize || SecurityConfig.encryption.symmetric.keySize / 8;

      crypto.pbkdf2(
        password,
        salt,
        actualIterations,
        actualKeySize,
        'sha512',
        (err, derivedKey) => {
          if (err) {
            this.logger.error('Key derivation failed', { error: err.message });
            reject(
              new SecurityError(
                SecurityErrorCode.KEY_DERIVATION_FAILED,
                'Failed to derive key from password',
                { error: err.message }
              )
            );
          } else {
            this.logger.debug('Key derived successfully');
            resolve(derivedKey);
          }
        }
      );
    });
  }

  /**
   * Hash data using SHA-256
   */
  static hash(data: string | Buffer, algorithm: string = 'sha256'): Buffer {
    try {
      const hash = crypto.createHash(algorithm);
      hash.update(data);
      return hash.digest();
    } catch (error: any) {
      this.logger.error('Hashing failed', { error: error.message });
      throw new SecurityError(
        SecurityErrorCode.ENCRYPTION_FAILED,
        'Failed to hash data',
        { error: error.message }
      );
    }
  }

  /**
   * Create HMAC
   */
  static createHMAC(data: string | Buffer, key: Buffer, algorithm: string = 'sha256'): Buffer {
    try {
      const hmac = crypto.createHmac(algorithm, key);
      hmac.update(data);
      return hmac.digest();
    } catch (error: any) {
      this.logger.error('HMAC creation failed', { error: error.message });
      throw new SecurityError(
        SecurityErrorCode.ENCRYPTION_FAILED,
        'Failed to create HMAC',
        { error: error.message }
      );
    }
  }

  /**
   * Verify HMAC
   */
  static verifyHMAC(
    data: string | Buffer,
    key: Buffer,
    expectedHMAC: Buffer,
    algorithm: string = 'sha256'
  ): boolean {
    try {
      const computedHMAC = this.createHMAC(data, key, algorithm);
      return crypto.timingSafeEqual(computedHMAC, expectedHMAC);
    } catch (error: any) {
      this.logger.error('HMAC verification failed', { error: error.message });
      return false;
    }
  }

  /**
   * Securely compare two buffers (timing-safe)
   */
  static secureCompare(a: Buffer, b: Buffer): boolean {
    try {
      if (a.length !== b.length) {
        return false;
      }
      return crypto.timingSafeEqual(a, b);
    } catch {
      return false;
    }
  }

  /**
   * Securely wipe buffer from memory
   */
  static secureWipe(buffer: Buffer): void {
    if (buffer && buffer.length > 0) {
      buffer.fill(0);
      this.logger.debug('Buffer wiped from memory');
    }
  }

  /**
   * Encrypt with password (derives key from password)
   */
  static async encryptWithPassword(
    data: string,
    password: string
  ): Promise<EncryptedData & { salt: string }> {
    try {
      // Generate salt
      const salt = this.generateRandomBytes(32);

      // Derive key from password
      const key = await this.deriveKeyFromPassword(password, salt);

      // Encrypt data
      const encrypted = await this.encrypt(data, key);

      // Securely wipe key
      this.secureWipe(key);

      return {
        ...encrypted,
        salt: salt.toString('base64'),
      };
    } catch (error: any) {
      this.logger.error('Password encryption failed', { error: error.message });
      throw new SecurityError(
        SecurityErrorCode.ENCRYPTION_FAILED,
        'Failed to encrypt with password',
        { error: error.message }
      );
    }
  }

  /**
   * Decrypt with password
   */
  static async decryptWithPassword(
    encryptedData: EncryptedData & { salt: string },
    password: string
  ): Promise<string> {
    try {
      // Decode salt
      const salt = Buffer.from(encryptedData.salt, 'base64');

      // Derive key from password
      const key = await this.deriveKeyFromPassword(password, salt);

      // Decrypt data
      const decrypted = await this.decrypt(encryptedData, key);

      // Securely wipe key
      this.secureWipe(key);

      return decrypted;
    } catch (error: any) {
      this.logger.error('Password decryption failed', { error: error.message });
      throw new SecurityError(
        SecurityErrorCode.DECRYPTION_FAILED,
        'Failed to decrypt with password',
        { error: error.message }
      );
    }
  }

  /**
   * Generate entropy for mnemonics
   */
  static generateMnemonicEntropy(strength: number = 256): Buffer {
    if (![128, 160, 192, 224, 256].includes(strength)) {
      throw new SecurityError(
        SecurityErrorCode.KEY_GENERATION_FAILED,
        'Invalid mnemonic strength'
      );
    }

    return this.generateRandomBytes(strength / 8);
  }

  /**
   * Test encryption/decryption round-trip
   */
  static async testRoundTrip(): Promise<boolean> {
    try {
      const testData = 'Test encryption data';
      const key = this.generateEncryptionKey();

      const encrypted = await this.encrypt(testData, key);
      const decrypted = await this.decrypt(encrypted, key);

      this.secureWipe(key);

      return decrypted === testData;
    } catch {
      return false;
    }
  }
}

export default EncryptionService;
