/**
 * Key Management Service
 *
 * Manages cryptographic keys for the wallet:
 * - Mnemonic generation and storage
 * - HD key derivation (BIP-32/44/84)
 * - Key encryption with Secure Enclave
 * - Wallet unlock/lock operations
 */

import { HDKey } from '@scure/bip32';
import * as bip39 from '@scure/bip39';
import { wordlist } from '@scure/bip39/wordlists/english';
import { SecureStorageService } from './SecureStorageService';
import { EncryptionService } from './EncryptionService';
import { SecurityConfig, SecurityError, SecurityErrorCode, SecurityEventType } from './SecurityConfig';
import { SecurityLogger } from './SecurityLogger';

/**
 * Chain types supported
 */
export enum ChainType {
  BITCOIN = 'bitcoin',
  BITCOIN_TESTNET = 'bitcoin_testnet',
  ETHEREUM = 'ethereum',
  ETHEREUM_TESTNET = 'ethereum_testnet',
}

/**
 * Wallet metadata
 */
export interface WalletMetadata {
  createdAt: number;
  hasPassphrase: boolean;
  version: string;
  lastUnlocked?: number;
}

/**
 * Key Management Service
 */
export class KeyManagementService {
  private static instance: KeyManagementService;
  private secureStorage: SecureStorageService;
  private logger: SecurityLogger;
  private masterKey: HDKey | null = null;
  private isUnlocked: boolean = false;
  private lockTimer: NodeJS.Timeout | null = null;

  private constructor() {
    this.secureStorage = SecureStorageService.getInstance();
    this.logger = SecurityLogger.getInstance();
  }

  /**
   * Get singleton instance
   */
  static getInstance(): KeyManagementService {
    if (!KeyManagementService.instance) {
      KeyManagementService.instance = new KeyManagementService();
    }
    return KeyManagementService.instance;
  }

  /**
   * Generate new wallet with mnemonic
   */
  async generateWallet(passphrase?: string): Promise<string> {
    try {
      const config = SecurityConfig.keyManagement.mnemonic;

      // Generate mnemonic (24 words for 256-bit entropy)
      const mnemonic = bip39.generateMnemonic(wordlist, config.strength);

      // Validate generated mnemonic
      if (!bip39.validateMnemonic(mnemonic, wordlist)) {
        throw new SecurityError(
          SecurityErrorCode.KEY_GENERATION_FAILED,
          'Generated invalid mnemonic'
        );
      }

      // Store encrypted mnemonic
      await this.storeMnemonic(mnemonic, passphrase);

      this.logger.logSecurityEvent(
        SecurityEventType.WALLET_CREATED,
        'New wallet created',
        { hasPassphrase: !!passphrase }
      );

      return mnemonic;
    } catch (error: any) {
      this.logger.error('Failed to generate wallet', { error: error.message });
      throw error;
    }
  }

  /**
   * Import existing wallet from mnemonic
   */
  async importWallet(mnemonic: string, passphrase?: string): Promise<void> {
    try {
      // Validate mnemonic
      if (!bip39.validateMnemonic(mnemonic.trim(), wordlist)) {
        throw new SecurityError(
          SecurityErrorCode.MNEMONIC_INVALID,
          'Invalid mnemonic phrase'
        );
      }

      // Store encrypted mnemonic
      await this.storeMnemonic(mnemonic.trim(), passphrase);

      this.logger.logSecurityEvent(
        SecurityEventType.WALLET_IMPORTED,
        'Wallet imported from mnemonic',
        { hasPassphrase: !!passphrase }
      );
    } catch (error: any) {
      this.logger.error('Failed to import wallet', { error: error.message });
      throw error;
    }
  }

  /**
   * Store mnemonic encrypted with Secure Enclave
   */
  private async storeMnemonic(mnemonic: string, passphrase?: string): Promise<void> {
    try {
      // Encrypt mnemonic with Secure Enclave
      const encryptedMnemonic = await EncryptionService.encryptWithSecureEnclave(mnemonic);

      // Store encrypted mnemonic in keychain
      await this.secureStorage.storeSensitive(
        SecurityConfig.storage.keys.encryptedMnemonic,
        encryptedMnemonic
      );

      // Store optional passphrase
      if (passphrase) {
        const encryptedPassphrase = await EncryptionService.encryptWithSecureEnclave(passphrase);
        await this.secureStorage.storeSensitive(
          SecurityConfig.storage.keys.encryptedPassphrase,
          encryptedPassphrase
        );
      }

      // Store wallet metadata
      const metadata: WalletMetadata = {
        createdAt: Date.now(),
        hasPassphrase: !!passphrase,
        version: '1.0.0',
      };

      this.secureStorage.storeData('wallet_metadata', metadata);

      this.logger.info('Mnemonic stored securely');
    } catch (error: any) {
      this.logger.error('Failed to store mnemonic', { error: error.message });
      throw new SecurityError(
        SecurityErrorCode.STORAGE_FAILED,
        'Failed to store wallet mnemonic',
        { error: error.message }
      );
    }
  }

  /**
   * Unlock wallet (decrypt mnemonic and derive master key)
   */
  async unlock(biometricAuth: boolean = true): Promise<void> {
    if (this.isUnlocked) {
      this.logger.debug('Wallet already unlocked');
      return;
    }

    try {
      // Retrieve encrypted mnemonic
      const encryptedMnemonic = await this.secureStorage.retrieveSensitive(
        SecurityConfig.storage.keys.encryptedMnemonic
      );

      if (!encryptedMnemonic) {
        throw new SecurityError(
          SecurityErrorCode.KEY_NOT_FOUND,
          'No wallet found'
        );
      }

      // Decrypt with Secure Enclave (triggers biometric prompt if enabled)
      const mnemonic = await EncryptionService.decryptWithSecureEnclave(encryptedMnemonic);

      // Get optional passphrase
      let passphrase: string | undefined;
      const encryptedPassphrase = await this.secureStorage.retrieveSensitive(
        SecurityConfig.storage.keys.encryptedPassphrase
      );

      if (encryptedPassphrase) {
        passphrase = await EncryptionService.decryptWithSecureEnclave(encryptedPassphrase);
      }

      // Convert mnemonic to seed
      const seed = await bip39.mnemonicToSeed(mnemonic, passphrase);

      // Derive master key
      this.masterKey = HDKey.fromMasterSeed(seed);
      this.isUnlocked = true;

      // Update metadata
      const metadata = this.secureStorage.retrieveData<WalletMetadata>('wallet_metadata');
      if (metadata) {
        metadata.lastUnlocked = Date.now();
        this.secureStorage.storeData('wallet_metadata', metadata);
      }

      this.logger.logSecurityEvent(
        SecurityEventType.WALLET_UNLOCKED,
        'Wallet unlocked successfully'
      );

      // Start auto-lock timer
      this.startAutoLockTimer();
    } catch (error: any) {
      this.logger.error('Failed to unlock wallet', { error: error.message });
      throw new SecurityError(
        SecurityErrorCode.DECRYPTION_FAILED,
        'Failed to unlock wallet',
        { error: error.message }
      );
    }
  }

  /**
   * Lock wallet (clear master key from memory)
   */
  lock(): void {
    if (this.masterKey) {
      // Securely wipe master key
      this.masterKey = null;
    }

    this.isUnlocked = false;
    this.clearAutoLockTimer();

    this.logger.logSecurityEvent(
      SecurityEventType.WALLET_LOCKED,
      'Wallet locked'
    );
  }

  /**
   * Start auto-lock timer
   */
  private startAutoLockTimer(): void {
    this.clearAutoLockTimer();

    const timeout = SecurityConfig.authentication.session.defaultTimeout * 1000;

    this.lockTimer = setTimeout(() => {
      this.logger.logSecurityEvent(
        SecurityEventType.SESSION_TIMEOUT,
        'Session timeout - locking wallet'
      );
      this.lock();
    }, timeout);
  }

  /**
   * Clear auto-lock timer
   */
  private clearAutoLockTimer(): void {
    if (this.lockTimer) {
      clearTimeout(this.lockTimer);
      this.lockTimer = null;
    }
  }

  /**
   * Reset auto-lock timer (on user activity)
   */
  resetAutoLockTimer(): void {
    if (this.isUnlocked) {
      this.startAutoLockTimer();
    }
  }

  /**
   * Derive account key for specific chain
   */
  deriveAccountKey(
    chainType: ChainType,
    accountIndex: number = 0
  ): HDKey {
    if (!this.isUnlocked || !this.masterKey) {
      throw new SecurityError(
        SecurityErrorCode.KEY_NOT_FOUND,
        'Wallet is locked'
      );
    }

    const path = this.getDerivationPath(chainType, accountIndex);
    const derivedKey = this.masterKey.derive(path);

    this.logger.logSecurityEvent(
      SecurityEventType.KEY_DERIVED,
      'Account key derived',
      { chainType, accountIndex, path }
    );

    return derivedKey;
  }

  /**
   * Derive address key
   */
  deriveAddressKey(
    chainType: ChainType,
    accountIndex: number = 0,
    change: number = 0,
    addressIndex: number = 0
  ): HDKey {
    if (!this.isUnlocked || !this.masterKey) {
      throw new SecurityError(
        SecurityErrorCode.KEY_NOT_FOUND,
        'Wallet is locked'
      );
    }

    const path = this.getDerivationPath(chainType, accountIndex, change, addressIndex);
    const derivedKey = this.masterKey.derive(path);

    this.logger.debug('Address key derived', {
      chainType,
      accountIndex,
      change,
      addressIndex,
    });

    return derivedKey;
  }

  /**
   * Get derivation path for chain (BIP-44/84)
   */
  private getDerivationPath(
    chainType: ChainType,
    accountIndex: number = 0,
    change?: number,
    addressIndex?: number
  ): string {
    const paths = SecurityConfig.keyManagement.derivationPaths;

    let path: string;

    switch (chainType) {
      case ChainType.BITCOIN:
        path = paths.bitcoin;
        break;
      case ChainType.BITCOIN_TESTNET:
        path = paths.bitcoinTestnet;
        break;
      case ChainType.ETHEREUM:
        path = paths.ethereum;
        break;
      case ChainType.ETHEREUM_TESTNET:
        path = paths.ethereumTestnet;
        break;
      default:
        throw new SecurityError(
          SecurityErrorCode.KEY_DERIVATION_FAILED,
          `Unsupported chain type: ${chainType}`
        );
    }

    // Replace account index
    path = path.replace(/0'$/, `${accountIndex}'`);

    // Append change and address index if provided
    if (change !== undefined) {
      path += `/${change}`;
    }

    if (addressIndex !== undefined) {
      path += `/${addressIndex}`;
    }

    return path;
  }

  /**
   * Export mnemonic (requires re-authentication)
   */
  async exportMnemonic(): Promise<string> {
    try {
      const encryptedMnemonic = await this.secureStorage.retrieveSensitive(
        SecurityConfig.storage.keys.encryptedMnemonic
      );

      if (!encryptedMnemonic) {
        throw new SecurityError(
          SecurityErrorCode.KEY_NOT_FOUND,
          'No wallet found'
        );
      }

      // Requires biometric re-authentication
      const mnemonic = await EncryptionService.decryptWithSecureEnclave(encryptedMnemonic);

      this.logger.warn('Mnemonic exported');

      return mnemonic;
    } catch (error: any) {
      this.logger.error('Failed to export mnemonic', { error: error.message });
      throw error;
    }
  }

  /**
   * Delete wallet (WARNING: Cannot be undone)
   */
  async deleteWallet(): Promise<void> {
    try {
      // Lock wallet first
      this.lock();

      // Delete all sensitive data
      await this.secureStorage.deleteSensitive(
        SecurityConfig.storage.keys.encryptedMnemonic
      );
      await this.secureStorage.deleteSensitive(
        SecurityConfig.storage.keys.encryptedPassphrase
      );

      // Delete metadata
      this.secureStorage.deleteData('wallet_metadata');

      // Clear all other data
      this.secureStorage.clearAll();

      this.logger.warn('Wallet deleted permanently');
    } catch (error: any) {
      this.logger.error('Failed to delete wallet', { error: error.message });
      throw error;
    }
  }

  /**
   * Check if wallet exists
   */
  async hasWallet(): Promise<boolean> {
    return await this.secureStorage.hasSensitive(
      SecurityConfig.storage.keys.encryptedMnemonic
    );
  }

  /**
   * Check if wallet is unlocked
   */
  isWalletUnlocked(): boolean {
    return this.isUnlocked;
  }

  /**
   * Get wallet metadata
   */
  getWalletMetadata(): WalletMetadata | null {
    return this.secureStorage.retrieveData<WalletMetadata>('wallet_metadata');
  }

  /**
   * Validate mnemonic without importing
   */
  validateMnemonic(mnemonic: string): boolean {
    return bip39.validateMnemonic(mnemonic.trim(), wordlist);
  }

  /**
   * Get mnemonic word list
   */
  getMnemonicWordList(): string[] {
    return wordlist;
  }
}

export default KeyManagementService;
