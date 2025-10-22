/**
 * Secure Storage Service
 *
 * Handles secure storage of sensitive data using platform-specific secure storage mechanisms
 * iOS: Keychain Services with Secure Enclave
 * Android: Keystore System with StrongBox/TEE
 */

import * as Keychain from 'react-native-keychain';
import { MMKV } from 'react-native-mmkv';
import { Platform } from 'react-native';
import { SecurityConfig, SecurityError, SecurityErrorCode } from './SecurityConfig';
import { SecurityLogger } from './SecurityLogger';

/**
 * Storage key interface
 */
export interface StorageKey {
  key: string;
  value: string;
  timestamp?: number;
  metadata?: Record<string, any>;
}

/**
 * Secure Storage Service
 */
export class SecureStorageService {
  private static instance: SecureStorageService;
  private mmkv: MMKV;
  private logger: SecurityLogger;
  private initialized: boolean = false;

  private constructor() {
    // Initialize MMKV with encryption for non-sensitive data
    this.mmkv = new MMKV({
      id: 'fueki-storage',
      encryptionKey: this.generateAppEncryptionKey(),
    });

    this.logger = SecurityLogger.getInstance();
    this.initialized = true;
  }

  /**
   * Get singleton instance
   */
  static getInstance(): SecureStorageService {
    if (!SecureStorageService.instance) {
      SecureStorageService.instance = new SecureStorageService();
    }
    return SecureStorageService.instance;
  }

  /**
   * Generate app-level encryption key (not for sensitive data)
   */
  private generateAppEncryptionKey(): string {
    // This is a static app-level key for MMKV encryption
    // NOT used for sensitive data like mnemonics
    return 'fueki-app-storage-key-v1';
  }

  /**
   * Store sensitive data in platform keychain (hardware-backed)
   */
  async storeSensitive(key: string, value: string): Promise<void> {
    if (!this.initialized) {
      throw new SecurityError(
        SecurityErrorCode.NOT_INITIALIZED,
        'Secure storage not initialized'
      );
    }

    try {
      const service = `${SecurityConfig.storage.keychain.service}.${key}`;

      await Keychain.setGenericPassword(key, value, {
        service,
        accessible: this.getAccessibleConstant(),
        securityLevel: this.getSecurityLevel(),
        storage: Keychain.STORAGE_TYPE.RSA, // Use RSA encryption
      });

      this.logger.debug('Stored sensitive data', { key });
    } catch (error) {
      this.logger.error('Failed to store sensitive data', { key, error });
      throw new SecurityError(
        SecurityErrorCode.STORAGE_FAILED,
        'Failed to store sensitive data in keychain',
        { key, error }
      );
    }
  }

  /**
   * Retrieve sensitive data from keychain
   */
  async retrieveSensitive(key: string): Promise<string | null> {
    if (!this.initialized) {
      throw new SecurityError(
        SecurityErrorCode.NOT_INITIALIZED,
        'Secure storage not initialized'
      );
    }

    try {
      const service = `${SecurityConfig.storage.keychain.service}.${key}`;

      const credentials = await Keychain.getGenericPassword({
        service,
      });

      if (credentials && typeof credentials !== 'boolean') {
        this.logger.debug('Retrieved sensitive data', { key });
        return credentials.password;
      }

      return null;
    } catch (error) {
      this.logger.error('Failed to retrieve sensitive data', { key, error });
      throw new SecurityError(
        SecurityErrorCode.STORAGE_NOT_FOUND,
        'Failed to retrieve sensitive data from keychain',
        { key, error }
      );
    }
  }

  /**
   * Delete sensitive data from keychain
   */
  async deleteSensitive(key: string): Promise<void> {
    if (!this.initialized) {
      throw new SecurityError(
        SecurityErrorCode.NOT_INITIALIZED,
        'Secure storage not initialized'
      );
    }

    try {
      const service = `${SecurityConfig.storage.keychain.service}.${key}`;

      await Keychain.resetGenericPassword({
        service,
      });

      this.logger.debug('Deleted sensitive data', { key });
    } catch (error) {
      this.logger.error('Failed to delete sensitive data', { key, error });
      throw new SecurityError(
        SecurityErrorCode.STORAGE_FAILED,
        'Failed to delete sensitive data from keychain',
        { key, error }
      );
    }
  }

  /**
   * Check if sensitive data exists
   */
  async hasSensitive(key: string): Promise<boolean> {
    try {
      const value = await this.retrieveSensitive(key);
      return value !== null;
    } catch {
      return false;
    }
  }

  /**
   * Store non-sensitive data in encrypted MMKV
   */
  storeData(key: string, value: any): void {
    if (!this.initialized) {
      throw new SecurityError(
        SecurityErrorCode.NOT_INITIALIZED,
        'Secure storage not initialized'
      );
    }

    try {
      const data: StorageKey = {
        key,
        value: JSON.stringify(value),
        timestamp: Date.now(),
      };

      this.mmkv.set(key, JSON.stringify(data));
      this.logger.debug('Stored data', { key });
    } catch (error) {
      this.logger.error('Failed to store data', { key, error });
      throw new SecurityError(
        SecurityErrorCode.STORAGE_FAILED,
        'Failed to store data in MMKV',
        { key, error }
      );
    }
  }

  /**
   * Retrieve non-sensitive data from MMKV
   */
  retrieveData<T>(key: string): T | null {
    if (!this.initialized) {
      throw new SecurityError(
        SecurityErrorCode.NOT_INITIALIZED,
        'Secure storage not initialized'
      );
    }

    try {
      const stored = this.mmkv.getString(key);

      if (!stored) {
        return null;
      }

      const data: StorageKey = JSON.parse(stored);
      this.logger.debug('Retrieved data', { key });

      return JSON.parse(data.value) as T;
    } catch (error) {
      this.logger.error('Failed to retrieve data', { key, error });
      return null;
    }
  }

  /**
   * Delete non-sensitive data from MMKV
   */
  deleteData(key: string): void {
    if (!this.initialized) {
      throw new SecurityError(
        SecurityErrorCode.NOT_INITIALIZED,
        'Secure storage not initialized'
      );
    }

    try {
      this.mmkv.delete(key);
      this.logger.debug('Deleted data', { key });
    } catch (error) {
      this.logger.error('Failed to delete data', { key, error });
      throw new SecurityError(
        SecurityErrorCode.STORAGE_FAILED,
        'Failed to delete data from MMKV',
        { key, error }
      );
    }
  }

  /**
   * Check if non-sensitive data exists
   */
  hasData(key: string): boolean {
    return this.mmkv.contains(key);
  }

  /**
   * Get all keys from MMKV
   */
  getAllKeys(): string[] {
    return this.mmkv.getAllKeys();
  }

  /**
   * Clear all non-sensitive data
   */
  clearAll(): void {
    if (!this.initialized) {
      throw new SecurityError(
        SecurityErrorCode.NOT_INITIALIZED,
        'Secure storage not initialized'
      );
    }

    try {
      this.mmkv.clearAll();
      this.logger.info('Cleared all non-sensitive data');
    } catch (error) {
      this.logger.error('Failed to clear data', { error });
      throw new SecurityError(
        SecurityErrorCode.STORAGE_FAILED,
        'Failed to clear MMKV storage',
        { error }
      );
    }
  }

  /**
   * Clear all sensitive data from keychain
   */
  async clearAllSensitive(): Promise<void> {
    if (!this.initialized) {
      throw new SecurityError(
        SecurityErrorCode.NOT_INITIALIZED,
        'Secure storage not initialized'
      );
    }

    try {
      // Delete all known sensitive keys
      const sensitiveKeys = Object.values(SecurityConfig.storage.keys);

      for (const key of sensitiveKeys) {
        try {
          await this.deleteSensitive(key);
        } catch {
          // Continue deleting other keys even if one fails
        }
      }

      this.logger.info('Cleared all sensitive data');
    } catch (error) {
      this.logger.error('Failed to clear sensitive data', { error });
      throw new SecurityError(
        SecurityErrorCode.STORAGE_FAILED,
        'Failed to clear sensitive data',
        { error }
      );
    }
  }

  /**
   * Wipe all data (nuclear option)
   */
  async wipeAll(): Promise<void> {
    await this.clearAllSensitive();
    this.clearAll();
    this.logger.warn('Wiped all storage data');
  }

  /**
   * Get accessible constant for keychain
   */
  private getAccessibleConstant(): Keychain.ACCESSIBLE {
    const level = SecurityConfig.storage.keychain.accessLevel;

    switch (level) {
      case 'WHEN_UNLOCKED':
        return Keychain.ACCESSIBLE.WHEN_UNLOCKED;
      case 'WHEN_UNLOCKED_THIS_DEVICE_ONLY':
        return Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY;
      case 'AFTER_FIRST_UNLOCK':
        return Keychain.ACCESSIBLE.AFTER_FIRST_UNLOCK;
      case 'AFTER_FIRST_UNLOCK_THIS_DEVICE_ONLY':
        return Keychain.ACCESSIBLE.AFTER_FIRST_UNLOCK_THIS_DEVICE_ONLY;
      case 'WHEN_PASSCODE_SET_THIS_DEVICE_ONLY':
        return Keychain.ACCESSIBLE.WHEN_PASSCODE_SET_THIS_DEVICE_ONLY;
      default:
        return Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY;
    }
  }

  /**
   * Get security level for keychain
   */
  private getSecurityLevel(): Keychain.SECURITY_LEVEL {
    const level = SecurityConfig.storage.keychain.securityLevel;

    switch (level) {
      case 'SECURE_HARDWARE':
        return Keychain.SECURITY_LEVEL.SECURE_HARDWARE;
      case 'SECURE_SOFTWARE':
        return Keychain.SECURITY_LEVEL.SECURE_SOFTWARE;
      case 'ANY':
        return Keychain.SECURITY_LEVEL.ANY;
      default:
        return Keychain.SECURITY_LEVEL.SECURE_HARDWARE;
    }
  }

  /**
   * Get storage size
   */
  getStorageSize(): { mmkvSize: number; keychainKeys: number } {
    const allKeys = this.getAllKeys();
    let totalSize = 0;

    for (const key of allKeys) {
      const value = this.mmkv.getString(key);
      if (value) {
        totalSize += value.length;
      }
    }

    return {
      mmkvSize: totalSize,
      keychainKeys: Object.keys(SecurityConfig.storage.keys).length,
    };
  }

  /**
   * Export non-sensitive data
   */
  exportData(): Record<string, any> {
    const allKeys = this.getAllKeys();
    const exported: Record<string, any> = {};

    for (const key of allKeys) {
      const value = this.retrieveData(key);
      if (value !== null) {
        exported[key] = value;
      }
    }

    return exported;
  }

  /**
   * Import non-sensitive data
   */
  importData(data: Record<string, any>): void {
    for (const [key, value] of Object.entries(data)) {
      this.storeData(key, value);
    }

    this.logger.info('Imported data', { keyCount: Object.keys(data).length });
  }

  /**
   * Check storage health
   */
  async checkHealth(): Promise<{
    healthy: boolean;
    issues: string[];
  }> {
    const issues: string[] = [];

    try {
      // Test MMKV
      const testKey = '__health_check__';
      this.storeData(testKey, { test: true });
      const retrieved = this.retrieveData(testKey);
      this.deleteData(testKey);

      if (!retrieved) {
        issues.push('MMKV read/write test failed');
      }

      // Test Keychain
      const testSensitiveKey = '__health_check_sensitive__';
      await this.storeSensitive(testSensitiveKey, 'test');
      const sensitiveRetrieved = await this.retrieveSensitive(testSensitiveKey);
      await this.deleteSensitive(testSensitiveKey);

      if (!sensitiveRetrieved) {
        issues.push('Keychain read/write test failed');
      }
    } catch (error: any) {
      issues.push(`Health check failed: ${error.message}`);
    }

    return {
      healthy: issues.length === 0,
      issues,
    };
  }
}

export default SecureStorageService;
