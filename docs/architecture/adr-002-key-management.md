# ADR-002: Secure Enclave Key Management Architecture

## Status
**ACCEPTED** - 2025-10-21

## Context

The Fueki Mobile Wallet must securely manage cryptographic keys for multiple blockchain networks. Private keys are the most sensitive data in a cryptocurrency wallet - if compromised, users lose all their funds. We need a robust, secure, and user-friendly key management architecture.

### Requirements
1. **Security**: Private keys must never be exposed or stored in plaintext
2. **Hardware Backing**: Use device Secure Enclave when available
3. **Recovery**: Support mnemonic-based recovery (BIP-39)
4. **Multi-Chain**: Support HD derivation for multiple blockchains
5. **Usability**: Seamless authentication with biometrics
6. **Backup**: Secure key backup and restoration
7. **Isolation**: Keys isolated from application memory

### Constraints
- iOS Secure Enclave (Touch ID/Face ID devices)
- Android Keystore (Android 6.0+)
- React Native environment
- No server-side key storage (non-custodial)
- Must work offline

## Decision

We will implement a **multi-layered key management architecture** using Secure Enclave for encryption keys and in-memory HD derivation for blockchain keys.

## Architecture

### High-Level Key Management Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    User Authentication                          │
│          (Biometric / PIN / Password)                           │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Secure Enclave / Keystore                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Master Encryption Key (MEK)                             │  │
│  │  - Hardware-backed                                       │  │
│  │  - Never leaves Secure Enclave                           │  │
│  │  - Requires biometric/PIN to access                      │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼ (Decrypt)
┌─────────────────────────────────────────────────────────────────┐
│              Encrypted Storage (Keychain/MMKV)                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Encrypted Mnemonic Seed                                 │  │
│  │  - AES-256-GCM encrypted                                 │  │
│  │  - Encrypted with MEK                                    │  │
│  │  - Stored in secure keychain                             │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼ (In-Memory Derivation)
┌─────────────────────────────────────────────────────────────────┐
│              HD Wallet Derivation (BIP-32/44)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  Bitcoin     │  │  Ethereum    │  │  Other       │         │
│  │  m/84'/0'/0' │  │  m/44'/60'/0'│  │  Chains      │         │
│  │              │  │              │  │              │         │
│  │  Account 0   │  │  Account 0   │  │  Account 0   │         │
│  │  ├─ Change 0 │  │  ├─ Change 0 │  │  ├─ Change 0 │         │
│  │  └─ Change 1 │  │  └─ Change 1 │  │  └─ Change 1 │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Transaction Signing (In-Memory)                 │
│  - Private keys exist only in memory during signing             │
│  - Immediately cleared after use                                │
│  - Never persisted or logged                                    │
└─────────────────────────────────────────────────────────────────┘
```

### Key Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 1: Hardware Security Module (Secure Enclave/Keystore)   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Master Encryption Key (MEK)                             │  │
│  │  - 256-bit AES key                                       │  │
│  │  - Generated in Secure Enclave                           │  │
│  │  - Biometric-protected                                   │  │
│  │  - Used only for encrypting/decrypting mnemonic         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 2: Mnemonic Seed (BIP-39)                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  24-word Mnemonic (256-bit entropy)                      │  │
│  │  - User-facing backup phrase                             │  │
│  │  - Encrypted at rest with MEK                            │  │
│  │  - Converted to 512-bit seed (BIP-39)                    │  │
│  │  - Optional passphrase (25th word)                       │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 3: Master HD Key (BIP-32)                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Master Private Key (512-bit seed → BIP-32)              │  │
│  │  - Never stored, derived on-demand                       │  │
│  │  - Used to derive all account keys                       │  │
│  │  - Chain code for derivation                             │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 4: Account Keys (BIP-44)                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Purpose (44'/84'/49') → Coin Type → Account → Change    │  │
│  │                                                            │  │
│  │  Bitcoin (BIP-84 SegWit):  m/84'/0'/0'/0/0               │  │
│  │  Ethereum (BIP-44):        m/44'/60'/0'/0/0              │  │
│  │  Bitcoin Testnet:          m/84'/1'/0'/0/0               │  │
│  │                                                            │  │
│  │  - Derived on-demand                                      │  │
│  │  - Exists only during transaction signing                │  │
│  │  - Securely wiped from memory after use                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation

### 1. Secure Storage Layer

```typescript
// src/core/security/SecureStorage.ts
import * as Keychain from 'react-native-keychain';
import { MMKV } from 'react-native-mmkv';

export class SecureStorage {
  private mmkv: MMKV;

  constructor() {
    // MMKV with encryption for non-sensitive data
    this.mmkv = new MMKV({
      id: 'fueki-storage',
      encryptionKey: 'app-level-encryption-key', // Static app key
    });
  }

  /**
   * Store sensitive data in platform keychain (Secure Enclave backed)
   * iOS: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
   * Android: StrongBox/TEE backed
   */
  async storeSensitive(key: string, value: string): Promise<void> {
    await Keychain.setGenericPassword(key, value, {
      service: `fueki.${key}`,
      accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
      securityLevel: Keychain.SECURITY_LEVEL.SECURE_HARDWARE,
    });
  }

  async retrieveSensitive(key: string): Promise<string | null> {
    const credentials = await Keychain.getGenericPassword({
      service: `fueki.${key}`,
    });

    if (credentials) {
      return credentials.password;
    }
    return null;
  }

  async deleteSensitive(key: string): Promise<void> {
    await Keychain.resetGenericPassword({
      service: `fueki.${key}`,
    });
  }

  /**
   * Store non-sensitive data in encrypted MMKV
   */
  storeData(key: string, value: any): void {
    this.mmkv.set(key, JSON.stringify(value));
  }

  retrieveData<T>(key: string): T | null {
    const value = this.mmkv.getString(key);
    return value ? JSON.parse(value) : null;
  }

  deleteData(key: string): void {
    this.mmkv.delete(key);
  }

  clearAll(): void {
    this.mmkv.clearAll();
  }
}
```

### 2. Encryption Service

```typescript
// src/core/security/EncryptionService.ts
import { NativeModules, Platform } from 'react-native';
import crypto from 'crypto'; // react-native-crypto polyfill
import { Buffer } from 'buffer';

export class EncryptionService {
  /**
   * Encrypt data using AES-256-GCM
   * On iOS/Android, this can be delegated to Secure Enclave for MEK operations
   */
  static async encrypt(data: string, key: Uint8Array): Promise<EncryptedData> {
    // Generate random IV (12 bytes for GCM)
    const iv = crypto.randomBytes(12);

    // Create cipher
    const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);

    // Encrypt
    const encrypted = Buffer.concat([
      cipher.update(data, 'utf8'),
      cipher.final(),
    ]);

    // Get auth tag
    const authTag = cipher.getAuthTag();

    return {
      ciphertext: encrypted.toString('base64'),
      iv: iv.toString('base64'),
      authTag: authTag.toString('base64'),
    };
  }

  static async decrypt(encryptedData: EncryptedData, key: Uint8Array): Promise<string> {
    const decipher = crypto.createDecipheriv(
      'aes-256-gcm',
      key,
      Buffer.from(encryptedData.iv, 'base64')
    );

    decipher.setAuthTag(Buffer.from(encryptedData.authTag, 'base64'));

    const decrypted = Buffer.concat([
      decipher.update(Buffer.from(encryptedData.ciphertext, 'base64')),
      decipher.final(),
    ]);

    return decrypted.toString('utf8');
  }

  /**
   * Use Secure Enclave for encryption (iOS/Android native)
   * This is the preferred method for MEK operations
   */
  static async encryptWithSecureEnclave(data: string): Promise<string> {
    if (Platform.OS === 'ios') {
      // Use iOS Keychain with kSecAttrAccessControl
      return await NativeModules.SecureEnclaveModule.encrypt(data);
    } else if (Platform.OS === 'android') {
      // Use Android Keystore
      return await NativeModules.KeystoreModule.encrypt(data);
    }
    throw new Error('Secure Enclave not available');
  }

  static async decryptWithSecureEnclave(encryptedData: string): Promise<string> {
    if (Platform.OS === 'ios') {
      return await NativeModules.SecureEnclaveModule.decrypt(encryptedData);
    } else if (Platform.OS === 'android') {
      return await NativeModules.KeystoreModule.decrypt(encryptedData);
    }
    throw new Error('Secure Enclave not available');
  }
}

interface EncryptedData {
  ciphertext: string;
  iv: string;
  authTag: string;
}
```

### 3. Key Management Service

```typescript
// src/core/wallet/KeyManagementService.ts
import { HDKey } from '@scure/bip32';
import * as bip39 from '@scure/bip39';
import { wordlist } from '@scure/bip39/wordlists/english';
import { SecureStorage } from '../security/SecureStorage';
import { EncryptionService } from '../security/EncryptionService';
import { CryptoService } from '../crypto/CryptoService';

export class KeyManagementService {
  private secureStorage: SecureStorage;
  private masterKey: HDKey | null = null;
  private isUnlocked: boolean = false;

  constructor() {
    this.secureStorage = new SecureStorage();
  }

  /**
   * Generate new wallet with mnemonic
   */
  async generateWallet(passphrase?: string): Promise<string> {
    // Generate 24-word mnemonic (256-bit entropy)
    const mnemonic = bip39.generateMnemonic(wordlist, 256);

    // Validate mnemonic
    if (!bip39.validateMnemonic(mnemonic, wordlist)) {
      throw new Error('Generated invalid mnemonic');
    }

    // Store encrypted mnemonic
    await this.storeMnemonic(mnemonic, passphrase);

    return mnemonic;
  }

  /**
   * Import existing wallet from mnemonic
   */
  async importWallet(mnemonic: string, passphrase?: string): Promise<void> {
    // Validate mnemonic
    if (!bip39.validateMnemonic(mnemonic, wordlist)) {
      throw new Error('Invalid mnemonic phrase');
    }

    // Store encrypted mnemonic
    await this.storeMnemonic(mnemonic, passphrase);
  }

  /**
   * Store mnemonic encrypted with Secure Enclave
   */
  private async storeMnemonic(mnemonic: string, passphrase?: string): Promise<void> {
    // Encrypt mnemonic with Secure Enclave
    const encrypted = await EncryptionService.encryptWithSecureEnclave(mnemonic);

    // Store encrypted mnemonic in keychain
    await this.secureStorage.storeSensitive('encrypted_mnemonic', encrypted);

    // Store optional passphrase flag
    if (passphrase) {
      const encryptedPassphrase = await EncryptionService.encryptWithSecureEnclave(passphrase);
      await this.secureStorage.storeSensitive('encrypted_passphrase', encryptedPassphrase);
    }

    // Store wallet metadata
    this.secureStorage.storeData('wallet_metadata', {
      createdAt: Date.now(),
      hasPassphrase: !!passphrase,
      version: '1.0.0',
    });
  }

  /**
   * Unlock wallet (decrypt mnemonic and derive master key)
   * Requires biometric authentication
   */
  async unlock(biometricAuth: boolean = true): Promise<void> {
    if (this.isUnlocked) {
      return;
    }

    // Retrieve encrypted mnemonic
    const encrypted = await this.secureStorage.retrieveSensitive('encrypted_mnemonic');
    if (!encrypted) {
      throw new Error('No wallet found');
    }

    // Decrypt with Secure Enclave (triggers biometric prompt)
    const mnemonic = await EncryptionService.decryptWithSecureEnclave(encrypted);

    // Get optional passphrase
    let passphrase: string | undefined;
    const encryptedPassphrase = await this.secureStorage.retrieveSensitive('encrypted_passphrase');
    if (encryptedPassphrase) {
      passphrase = await EncryptionService.decryptWithSecureEnclave(encryptedPassphrase);
    }

    // Convert mnemonic to seed
    const seed = await bip39.mnemonicToSeed(mnemonic, passphrase);

    // Derive master key
    this.masterKey = HDKey.fromMasterSeed(seed);
    this.isUnlocked = true;

    // Clear sensitive data from memory
    // (mnemonic, passphrase, seed will be garbage collected)
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
  }

  /**
   * Derive account key for specific chain
   */
  deriveAccountKey(chainType: ChainType, accountIndex: number = 0): HDKey {
    if (!this.isUnlocked || !this.masterKey) {
      throw new Error('Wallet is locked');
    }

    const path = this.getDerivationPath(chainType, accountIndex);
    return this.masterKey.derive(path);
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
      throw new Error('Wallet is locked');
    }

    const path = this.getDerivationPath(chainType, accountIndex, change, addressIndex);
    return this.masterKey.derive(path);
  }

  /**
   * Get derivation path for chain
   */
  private getDerivationPath(
    chainType: ChainType,
    accountIndex: number = 0,
    change?: number,
    addressIndex?: number
  ): string {
    const paths: Record<ChainType, string> = {
      [ChainType.BITCOIN]: `m/84'/0'/${accountIndex}'`,
      [ChainType.BITCOIN_TESTNET]: `m/84'/1'/${accountIndex}'`,
      [ChainType.ETHEREUM]: `m/44'/60'/${accountIndex}'`,
      [ChainType.ETHEREUM_TESTNET]: `m/44'/60'/${accountIndex}'`,
    };

    let path = paths[chainType];

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
    const encrypted = await this.secureStorage.retrieveSensitive('encrypted_mnemonic');
    if (!encrypted) {
      throw new Error('No wallet found');
    }

    // Requires biometric re-authentication
    return await EncryptionService.decryptWithSecureEnclave(encrypted);
  }

  /**
   * Delete wallet (WARNING: Cannot be undone)
   */
  async deleteWallet(): Promise<void> {
    // Lock wallet first
    this.lock();

    // Delete all sensitive data
    await this.secureStorage.deleteSensitive('encrypted_mnemonic');
    await this.secureStorage.deleteSensitive('encrypted_passphrase');

    // Delete metadata
    this.secureStorage.deleteData('wallet_metadata');

    // Clear all other data
    this.secureStorage.clearAll();
  }

  /**
   * Check if wallet exists
   */
  async hasWallet(): Promise<boolean> {
    const encrypted = await this.secureStorage.retrieveSensitive('encrypted_mnemonic');
    return encrypted !== null;
  }

  /**
   * Check if wallet is unlocked
   */
  isWalletUnlocked(): boolean {
    return this.isUnlocked;
  }
}

export enum ChainType {
  BITCOIN = 'bitcoin',
  BITCOIN_TESTNET = 'bitcoin_testnet',
  ETHEREUM = 'ethereum',
  ETHEREUM_TESTNET = 'ethereum_testnet',
}
```

### 4. Native Secure Enclave Modules

#### iOS (Swift)
```swift
// ios/SecureEnclaveModule.swift
import Foundation
import Security
import LocalAuthentication

@objc(SecureEnclaveModule)
class SecureEnclaveModule: NSObject {

  @objc
  func encrypt(_ plaintext: String,
               resolver: @escaping RCTPromiseResolveBlock,
               rejecter: @escaping RCTPromiseRejectBlock) {

    // Create encryption key in Secure Enclave
    guard let key = createSecureEnclaveKey() else {
      rejecter("ENCRYPTION_ERROR", "Failed to create encryption key", nil)
      return
    }

    // Encrypt data
    guard let data = plaintext.data(using: .utf8),
          let encrypted = SecKeyCreateEncryptedData(key,
                                                      .eciesEncryptionStandardX963SHA256AESGCM,
                                                      data as CFData,
                                                      nil) else {
      rejecter("ENCRYPTION_ERROR", "Failed to encrypt data", nil)
      return
    }

    resolver((encrypted as Data).base64EncodedString())
  }

  @objc
  func decrypt(_ ciphertext: String,
               resolver: @escaping RCTPromiseResolveBlock,
               rejecter: @escaping RCTPromiseRejectBlock) {

    // Retrieve key (triggers biometric prompt)
    guard let key = retrieveSecureEnclaveKey() else {
      rejecter("DECRYPTION_ERROR", "Failed to retrieve decryption key", nil)
      return
    }

    // Decrypt data
    guard let data = Data(base64Encoded: ciphertext),
          let decrypted = SecKeyCreateDecryptedData(key,
                                                      .eciesEncryptionStandardX963SHA256AESGCM,
                                                      data as CFData,
                                                      nil) else {
      rejecter("DECRYPTION_ERROR", "Failed to decrypt data", nil)
      return
    }

    resolver(String(data: decrypted as Data, encoding: .utf8))
  }

  private func createSecureEnclaveKey() -> SecKey? {
    let access = SecAccessControlCreateWithFlags(
      kCFAllocatorDefault,
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      [.privateKeyUsage, .biometryCurrentSet],
      nil
    )!

    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: "com.fueki.wallet.key",
        kSecAttrAccessControl as String: access
      ]
    ]

    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      return nil
    }

    return privateKey
  }

  private func retrieveSecureEnclaveKey() -> SecKey? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: "com.fueki.wallet.key",
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecReturnRef as String: true,
      kSecUseOperationPrompt as String: "Authenticate to access your wallet"
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    guard status == errSecSuccess else {
      return nil
    }

    return (item as! SecKey)
  }
}
```

#### Android (Kotlin)
```kotlin
// android/app/src/main/java/com/fueki/KeystoreModule.kt
package com.fueki

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricPrompt
import com.facebook.react.bridge.*
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import android.util.Base64

class KeystoreModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private val keyAlias = "fueki_master_key"

    override fun getName() = "KeystoreModule"

    @ReactMethod
    fun encrypt(plaintext: String, promise: Promise) {
        try {
            val key = getOrCreateKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, key)

            val iv = cipher.iv
            val encrypted = cipher.doFinal(plaintext.toByteArray())

            // Combine IV and ciphertext
            val combined = iv + encrypted
            val encoded = Base64.encodeToString(combined, Base64.NO_WRAP)

            promise.resolve(encoded)
        } catch (e: Exception) {
            promise.reject("ENCRYPTION_ERROR", e.message)
        }
    }

    @ReactMethod
    fun decrypt(ciphertext: String, promise: Promise) {
        try {
            val combined = Base64.decode(ciphertext, Base64.NO_WRAP)

            // Extract IV and ciphertext
            val iv = combined.sliceArray(0 until 12)
            val encrypted = combined.sliceArray(12 until combined.size)

            val key = getOrCreateKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv))

            val decrypted = cipher.doFinal(encrypted)
            promise.resolve(String(decrypted))
        } catch (e: Exception) {
            promise.reject("DECRYPTION_ERROR", e.message)
        }
    }

    private fun getOrCreateKey(): SecretKey {
        if (!keyStore.containsAlias(keyAlias)) {
            val keyGenerator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                "AndroidKeyStore"
            )

            val spec = KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setUserAuthenticationRequired(true)
                .setUserAuthenticationValidityDurationSeconds(30)
                .build()

            keyGenerator.init(spec)
            keyGenerator.generateKey()
        }

        return keyStore.getKey(keyAlias, null) as SecretKey
    }
}
```

## Security Considerations

### 1. **Never Store Private Keys**
- Private keys are NEVER stored on disk
- Derived on-demand from mnemonic
- Exist only in memory during transaction signing
- Cleared immediately after use

### 2. **Defense in Depth**
- **Layer 1**: Device unlock (PIN/Biometric)
- **Layer 2**: App authentication (Biometric)
- **Layer 3**: Secure Enclave encryption
- **Layer 4**: In-memory key derivation
- **Layer 5**: Transaction confirmation

### 3. **Secure Memory Handling**
```typescript
// Always clear sensitive data
function signTransaction(privateKey: Uint8Array, txData: Uint8Array): Uint8Array {
  try {
    const signature = secp256k1.sign(txData, privateKey);
    return signature;
  } finally {
    // Securely wipe private key
    privateKey.fill(0);
  }
}
```

### 4. **Backup & Recovery**
- **Mnemonic Backup**: User responsibility to secure 24 words
- **No Cloud Backup**: Never upload mnemonic to cloud
- **Paper Backup**: Recommend physical backup
- **Recovery Testing**: Guide users through recovery process

### 5. **Attack Mitigations**

| Attack Vector | Mitigation |
|--------------|------------|
| Memory Dump | Keys exist briefly, cleared after use |
| Screen Recording | Disable screenshots for sensitive screens |
| Clipboard Snooping | Auto-clear clipboard after paste |
| Keyloggers | Use native secure input fields |
| Reverse Engineering | Code obfuscation, anti-tampering |
| Physical Access | Biometric + device encryption |
| Malware | Sandboxing, permission restrictions |

## Performance Considerations

### Benchmarks (Target Devices)
- Mnemonic Generation: < 100ms
- Wallet Unlock: < 500ms (includes biometric)
- Key Derivation: < 50ms per key
- Transaction Signing: < 200ms

### Optimization Strategies
- Cache derived public keys (not private keys)
- Batch key derivations when possible
- Use native crypto modules for heavy operations
- Lazy load chains and accounts

## Testing Strategy

### Unit Tests
```typescript
describe('KeyManagementService', () => {
  it('should generate valid 24-word mnemonic', async () => {
    const mnemonic = await keyManager.generateWallet();
    const words = mnemonic.split(' ');
    expect(words).toHaveLength(24);
    expect(bip39.validateMnemonic(mnemonic, wordlist)).toBe(true);
  });

  it('should derive correct Bitcoin address', async () => {
    const mnemonic = 'abandon abandon ... art'; // Test vector
    await keyManager.importWallet(mnemonic);
    await keyManager.unlock();

    const key = keyManager.deriveAddressKey(ChainType.BITCOIN, 0, 0, 0);
    const address = CryptoService.toBitcoinAddress(key.publicKey!);

    expect(address).toBe('bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu');
  });
});
```

### Integration Tests
- Test biometric authentication flow
- Test wallet recovery process
- Test multi-chain derivation
- Test secure storage persistence

### Security Tests
- Verify keys never logged
- Verify keys cleared from memory
- Test Secure Enclave integration
- Penetration testing with security tools

## Migration Strategy

### Version Compatibility
- Support importing from other wallets (MetaMask, Trust Wallet)
- Migrate from older key storage schemes
- Backward compatible derivation paths

## References

### Standards
- [BIP-32: HD Wallets](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki)
- [BIP-39: Mnemonic Code](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki)
- [BIP-44: Multi-Account](https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki)
- [BIP-84: Native SegWit](https://github.com/bitcoin/bips/blob/master/bip-0084.mediawiki)

### Security
- [OWASP Mobile Top 10](https://owasp.org/www-project-mobile-top-10/)
- [iOS Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Android Keystore](https://developer.android.com/training/articles/keystore)

---

**Related ADRs:**
- [ADR-001: Cryptographic Libraries](./adr-001-cryptographic-libraries.md)
- [ADR-006: Biometric Authentication](./adr-006-biometric-auth.md)
- [ADR-007: Transaction Architecture](./adr-007-transaction-architecture.md)
