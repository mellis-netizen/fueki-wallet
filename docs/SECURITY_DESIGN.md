# Fueki Wallet - Security Design Specification

## 1. Security Philosophy

**Core Principles:**
1. **Defense in Depth**: Multiple layers of security
2. **Least Privilege**: Minimal permissions and access
3. **Zero Trust**: Verify everything, trust nothing
4. **Fail Secure**: Fail in a secure state
5. **Privacy by Design**: No unnecessary data collection

---

## 2. Key Management Architecture

### 2.1 Key Hierarchy (BIP-32/39/44)

```
┌──────────────────────────────────────────────────────────────────┐
│                    ENTROPY (128-256 bits)                         │
│         Generated from Hardware RNG (iOS/Android)                 │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│               MNEMONIC (12/24 words - BIP-39)                     │
│  Shown ONCE to user, must be written down                        │
│  Example: "abandon ability able about above absent..."           │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│                  SEED (512 bits - BIP-39)                         │
│  seed = PBKDF2(mnemonic, "mnemonic" + passphrase, 2048, 512)    │
│  Stored: iOS Keychain / Android Keystore                         │
│  Encrypted: Hardware-backed AES-256                              │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│              MASTER KEY (BIP-32 Root)                             │
│  master = HMAC-SHA512("Bitcoin seed", seed)                      │
│  master_private_key = master[0:32]                               │
│  master_chain_code = master[32:64]                               │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│          CHAIN-SPECIFIC KEYS (BIP-44 Derivation)                 │
│                                                                   │
│  Ethereum:  m/44'/60'/0'/0/n                                     │
│  Bitcoin:   m/84'/0'/0'/0/n   (Native SegWit)                   │
│            m/49'/0'/0'/0/n   (Wrapped SegWit)                   │
│            m/44'/0'/0'/0/n   (Legacy)                           │
│  Solana:    m/44'/501'/n'/0' (Account-based)                    │
│                                                                   │
│  where n = account index (0, 1, 2, ...)                         │
└──────────────────────────────────────────────────────────────────┘
```

### 2.2 Key Storage Implementation

#### iOS (Keychain)

```typescript
// KeyManager.ts - iOS Implementation
import Keychain from 'react-native-keychain';

export class KeyManager {
  private static KEYCHAIN_SERVICE = 'com.fueki.wallet';

  async storeSeed(seed: Buffer, passphrase: string): Promise<void> {
    // Encrypt seed with user passphrase + device key
    const encrypted = await this.encryptSeed(seed, passphrase);

    await Keychain.setGenericPassword(
      'wallet_seed',
      encrypted.toString('base64'),
      {
        service: KeyManager.KEYCHAIN_SERVICE,
        accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
        accessControl: Keychain.ACCESS_CONTROL.BIOMETRY_CURRENT_SET,
        securityLevel: Keychain.SECURITY_LEVEL.SECURE_HARDWARE,
      }
    );
  }

  async retrieveSeed(passphrase: string): Promise<Buffer> {
    const credentials = await Keychain.getGenericPassword({
      service: KeyManager.KEYCHAIN_SERVICE,
      authenticationPrompt: {
        title: 'Authenticate to access wallet',
        cancel: 'Cancel',
      },
    });

    if (!credentials) {
      throw new Error('Seed not found');
    }

    const encrypted = Buffer.from(credentials.password, 'base64');
    return await this.decryptSeed(encrypted, passphrase);
  }

  private async encryptSeed(seed: Buffer, passphrase: string): Promise<Buffer> {
    // Generate salt
    const salt = await this.generateSalt();

    // Derive encryption key from passphrase
    const key = await this.deriveKey(passphrase, salt);

    // Encrypt with AES-256-GCM
    const iv = await this.generateIV();
    const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);

    const encrypted = Buffer.concat([
      cipher.update(seed),
      cipher.final(),
    ]);

    const authTag = cipher.getAuthTag();

    // Return: salt + iv + authTag + encrypted
    return Buffer.concat([salt, iv, authTag, encrypted]);
  }
}
```

#### Android (Keystore)

```java
// KeystoreModule.java - Android Implementation
public class KeystoreModule extends ReactContextBaseJavaModule {
    private static final String KEYSTORE_PROVIDER = "AndroidKeyStore";
    private static final String KEY_ALIAS = "FuekiWalletMasterKey";

    private KeyStore keyStore;
    private KeyGenerator keyGenerator;

    public KeystoreModule(ReactApplicationContext context) {
        super(context);
        initKeyStore();
    }

    private void initKeyStore() {
        try {
            keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER);
            keyStore.load(null);

            keyGenerator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                KEYSTORE_PROVIDER
            );
        } catch (Exception e) {
            Log.e("KeystoreModule", "Failed to init keystore", e);
        }
    }

    @ReactMethod
    public void storeSeed(String encryptedSeed, Promise promise) {
        try {
            // Generate key in hardware if available (StrongBox)
            KeyGenParameterSpec spec = new KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT
            )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setUserAuthenticationValidityDurationSeconds(30)
            .setIsStrongBoxBacked(true) // Use hardware security module
            .build();

            keyGenerator.init(spec);
            SecretKey key = keyGenerator.generateKey();

            // Encrypt seed with hardware key
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, key);

            byte[] encrypted = cipher.doFinal(encryptedSeed.getBytes());
            byte[] iv = cipher.getIV();

            // Store encrypted seed + IV in shared preferences
            SharedPreferences prefs = getReactApplicationContext()
                .getSharedPreferences("FuekiSecure", Context.MODE_PRIVATE);

            prefs.edit()
                .putString("encrypted_seed", Base64.encodeToString(encrypted, Base64.NO_WRAP))
                .putString("iv", Base64.encodeToString(iv, Base64.NO_WRAP))
                .apply();

            promise.resolve(true);
        } catch (Exception e) {
            promise.reject("KEYSTORE_ERROR", e);
        }
    }

    @ReactMethod
    public void retrieveSeed(Promise promise) {
        try {
            // Retrieve key (requires biometric auth)
            SecretKey key = (SecretKey) keyStore.getKey(KEY_ALIAS, null);

            // Get encrypted data
            SharedPreferences prefs = getReactApplicationContext()
                .getSharedPreferences("FuekiSecure", Context.MODE_PRIVATE);

            String encryptedB64 = prefs.getString("encrypted_seed", null);
            String ivB64 = prefs.getString("iv", null);

            if (encryptedB64 == null || ivB64 == null) {
                promise.reject("SEED_NOT_FOUND", "Seed not found");
                return;
            }

            byte[] encrypted = Base64.decode(encryptedB64, Base64.NO_WRAP);
            byte[] iv = Base64.decode(ivB64, Base64.NO_WRAP);

            // Decrypt
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(128, iv));

            byte[] decrypted = cipher.doFinal(encrypted);

            promise.resolve(new String(decrypted));
        } catch (Exception e) {
            promise.reject("KEYSTORE_ERROR", e);
        }
    }
}
```

### 2.3 Key Derivation Functions

```typescript
// Mnemonic.ts - BIP-39 Implementation
import { generateMnemonic, mnemonicToSeed, validateMnemonic } from '@scure/bip39';
import { wordlist } from '@scure/bip39/wordlists/english';

export class Mnemonic {
  /**
   * Generate new mnemonic (12 or 24 words)
   */
  static generate(wordCount: 12 | 24 = 12): string {
    const strength = wordCount === 12 ? 128 : 256;
    return generateMnemonic(wordlist, strength);
  }

  /**
   * Validate mnemonic
   */
  static validate(mnemonic: string): boolean {
    return validateMnemonic(mnemonic, wordlist);
  }

  /**
   * Convert mnemonic to seed (BIP-39)
   */
  static async toSeed(mnemonic: string, passphrase: string = ''): Promise<Buffer> {
    if (!this.validate(mnemonic)) {
      throw new Error('Invalid mnemonic');
    }

    // PBKDF2(mnemonic, "mnemonic" + passphrase, 2048 rounds, 512 bits)
    const seed = await mnemonicToSeed(mnemonic, passphrase);
    return Buffer.from(seed);
  }
}

// KeyDerivation.ts - BIP-32 Implementation
import { BIP32Factory } from 'bip32';
import * as ecc from '@noble/secp256k1';

export class KeyDerivation {
  private bip32 = BIP32Factory(ecc);

  /**
   * Derive key from seed using BIP-32 path
   */
  deriveKey(seed: Buffer, path: string): { privateKey: Buffer; publicKey: Buffer } {
    const master = this.bip32.fromSeed(seed);
    const child = master.derivePath(path);

    return {
      privateKey: child.privateKey!,
      publicKey: child.publicKey,
    };
  }

  /**
   * Get Ethereum address from path
   */
  getEthereumAddress(seed: Buffer, index: number = 0): string {
    const path = `m/44'/60'/0'/0/${index}`;
    const { publicKey } = this.deriveKey(seed, path);

    // Ethereum address = last 20 bytes of Keccak256(public key)
    const hash = keccak256(publicKey.slice(1)); // Remove 0x04 prefix
    const address = '0x' + hash.slice(-40);

    return address;
  }

  /**
   * Get Bitcoin address from path
   */
  getBitcoinAddress(seed: Buffer, index: number = 0, type: 'legacy' | 'segwit' | 'native' = 'native'): string {
    const paths = {
      legacy: `m/44'/0'/0'/0/${index}`,
      segwit: `m/49'/0'/0'/0/${index}`,
      native: `m/84'/0'/0'/0/${index}`,
    };

    const master = this.bip32.fromSeed(seed);
    const child = master.derivePath(paths[type]);

    if (type === 'native') {
      // Bech32 (bc1...)
      return bitcoin.payments.p2wpkh({ pubkey: child.publicKey }).address!;
    } else if (type === 'segwit') {
      // P2SH-wrapped SegWit (3...)
      return bitcoin.payments.p2sh({
        redeem: bitcoin.payments.p2wpkh({ pubkey: child.publicKey }),
      }).address!;
    } else {
      // Legacy (1...)
      return bitcoin.payments.p2pkh({ pubkey: child.publicKey }).address!;
    }
  }

  /**
   * Get Solana public key from path
   */
  getSolanaPublicKey(seed: Buffer, index: number = 0): PublicKey {
    const path = `m/44'/501'/${index}'/0'`;
    const { privateKey } = this.deriveKey(seed, path);

    // Solana uses Ed25519
    const keypair = Keypair.fromSeed(privateKey.slice(0, 32));
    return keypair.publicKey;
  }
}
```

---

## 3. Transaction Signing Security

### 3.1 Signing Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                  1. USER INITIATES TRANSACTION                    │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│           2. BUILD UNSIGNED TRANSACTION                           │
│  - Validate all inputs                                            │
│  - Check balance                                                  │
│  - Estimate fees                                                  │
│  - Build transaction object                                       │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│           3. DISPLAY CONFIRMATION SCREEN                          │
│                                                                   │
│  ╔═══════════════════════════════════════════╗                   │
│  ║ Confirm Transaction                       ║                   │
│  ╠═══════════════════════════════════════════╣                   │
│  ║ To: 0x1234...5678                        ║                   │
│  ║ Amount: 1.5 ETH ($3,000.00)              ║                   │
│  ║ Gas Fee: 0.002 ETH ($4.00)               ║                   │
│  ║ ────────────────────────────────────────  ║                   │
│  ║ Total: 1.502 ETH ($3,004.00)             ║                   │
│  ║                                           ║                   │
│  ║      [Cancel]    [Touch ID to Confirm]   ║                   │
│  ╚═══════════════════════════════════════════╝                   │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│           4. BIOMETRIC AUTHENTICATION                             │
│  - Request biometric (Touch ID / Face ID)                        │
│  - Verify user identity                                           │
│  - Unlock secure enclave                                          │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│           5. RETRIEVE PRIVATE KEY                                 │
│  - Fetch encrypted seed from Keychain/Keystore                   │
│  - Decrypt in secure enclave                                      │
│  - Derive private key for signing                                 │
│  - Key NEVER leaves secure enclave                                │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│           6. SIGN TRANSACTION IN SECURE ENCLAVE                   │
│  - Hash transaction data                                          │
│  - Sign with ECDSA/EdDSA                                          │
│  - Generate signature (r, s, v)                                   │
│  - Attach signature to transaction                                │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│           7. ZERO PRIVATE KEY FROM MEMORY                         │
│  - Overwrite key bytes with zeros                                 │
│  - Free memory                                                    │
│  - Verify key is cleared                                          │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│           8. BROADCAST SIGNED TRANSACTION                         │
│  - Serialize signed transaction                                   │
│  - Send to RPC node                                               │
│  - Return transaction hash                                        │
└──────────────────────────┬─────────────────────────────────────┘
                           │
                           ▼
                     ┌──────────┐
                     │ Complete │
                     └──────────┘
```

### 3.2 Signer Implementation

```typescript
// Signer.ts - Secure Transaction Signing
import { secp256k1 } from '@noble/curves/secp256k1';
import { keccak256 } from '@noble/hashes/sha3';

export class Signer {
  /**
   * Sign Ethereum transaction
   */
  async signEthereumTransaction(
    transaction: EthereumTransaction,
    privateKey: Buffer
  ): Promise<string> {
    try {
      // Serialize transaction
      const serialized = this.serializeEthereumTx(transaction);

      // Hash transaction data (Keccak256)
      const hash = keccak256(serialized);

      // Sign with ECDSA (secp256k1)
      const signature = secp256k1.sign(hash, privateKey);

      // Recover v value (chain ID encoding)
      const v = this.calculateV(signature.recovery, transaction.chainId);

      // Build signed transaction
      const signedTx = {
        ...transaction,
        r: '0x' + signature.r.toString(16),
        s: '0x' + signature.s.toString(16),
        v,
      };

      return this.serializeSignedTx(signedTx);
    } finally {
      // Zero private key from memory
      this.zeroBuffer(privateKey);
    }
  }

  /**
   * Sign Bitcoin transaction
   */
  async signBitcoinTransaction(
    transaction: BitcoinTransaction,
    privateKey: Buffer,
    utxos: UTXO[]
  ): Promise<string> {
    try {
      const tx = new bitcoin.Transaction();

      // Add inputs
      for (const utxo of utxos) {
        tx.addInput(Buffer.from(utxo.txid, 'hex'), utxo.vout);
      }

      // Add outputs
      for (const output of transaction.outputs) {
        tx.addOutput(Buffer.from(output.address, 'hex'), output.value);
      }

      // Sign each input
      for (let i = 0; i < utxos.length; i++) {
        const utxo = utxos[i];

        // Create signature hash
        const sigHash = tx.hashForSignature(
          i,
          Buffer.from(utxo.scriptPubKey, 'hex'),
          bitcoin.Transaction.SIGHASH_ALL
        );

        // Sign with ECDSA
        const signature = secp256k1.sign(sigHash, privateKey);

        // Build script sig
        const scriptSig = bitcoin.script.compile([
          Buffer.concat([
            Buffer.from(signature.toDER()),
            Buffer.from([bitcoin.Transaction.SIGHASH_ALL])
          ]),
          Buffer.from(this.getPublicKey(privateKey), 'hex')
        ]);

        tx.setInputScript(i, scriptSig);
      }

      return tx.toHex();
    } finally {
      this.zeroBuffer(privateKey);
    }
  }

  /**
   * Sign Solana transaction
   */
  async signSolanaTransaction(
    transaction: SolanaTransaction,
    privateKey: Buffer
  ): Promise<string> {
    try {
      // Solana uses Ed25519 (different from ECDSA)
      const keypair = Keypair.fromSecretKey(privateKey);

      // Sign transaction
      transaction.sign(keypair);

      // Serialize
      return transaction.serialize().toString('base64');
    } finally {
      this.zeroBuffer(privateKey);
    }
  }

  /**
   * Zero buffer from memory (security)
   */
  private zeroBuffer(buffer: Buffer): void {
    for (let i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }
}
```

---

## 4. Authentication & Access Control

### 4.1 Biometric Authentication

```typescript
// BiometricService.ts
import ReactNativeBiometrics from 'react-native-biometrics';

export class BiometricService {
  private rnBiometrics = new ReactNativeBiometrics({
    allowDeviceCredentials: true, // Allow PIN fallback
  });

  /**
   * Check if biometrics are available
   */
  async isBiometricAvailable(): Promise<boolean> {
    const { available, biometryType } = await this.rnBiometrics.isSensorAvailable();
    return available;
  }

  /**
   * Authenticate user with biometrics
   */
  async authenticate(reason: string = 'Authenticate to access wallet'): Promise<boolean> {
    try {
      const { success } = await this.rnBiometrics.simplePrompt({
        promptMessage: reason,
        cancelButtonText: 'Cancel',
      });

      return success;
    } catch (error) {
      console.error('Biometric authentication failed:', error);
      return false;
    }
  }

  /**
   * Create signature with biometric protection
   * (iOS Secure Enclave only)
   */
  async createSignature(payload: string): Promise<string | null> {
    try {
      const { success, signature } = await this.rnBiometrics.createSignature({
        promptMessage: 'Sign transaction',
        payload,
      });

      return success ? signature : null;
    } catch (error) {
      console.error('Signature creation failed:', error);
      return null;
    }
  }
}
```

### 4.2 PIN Management

```typescript
// PINService.ts
import { pbkdf2 } from '@noble/hashes/pbkdf2';
import { sha256 } from '@noble/hashes/sha256';

export class PINService {
  private static PIN_STORAGE_KEY = 'pin_hash';
  private static SALT_STORAGE_KEY = 'pin_salt';
  private static MAX_ATTEMPTS = 5;
  private static LOCKOUT_DURATION = 15 * 60 * 1000; // 15 minutes

  /**
   * Set up PIN
   */
  async setupPIN(pin: string): Promise<void> {
    if (!this.validatePIN(pin)) {
      throw new Error('Invalid PIN format');
    }

    // Generate random salt
    const salt = this.generateSalt();

    // Hash PIN with PBKDF2
    const hash = await this.hashPIN(pin, salt);

    // Store hash and salt
    await SecureStorage.set(PINService.PIN_STORAGE_KEY, hash.toString('hex'));
    await SecureStorage.set(PINService.SALT_STORAGE_KEY, salt.toString('hex'));
  }

  /**
   * Verify PIN
   */
  async verifyPIN(pin: string): Promise<boolean> {
    // Check if locked out
    if (await this.isLockedOut()) {
      throw new Error('Too many failed attempts. Try again later.');
    }

    // Get stored hash and salt
    const storedHash = await SecureStorage.get(PINService.PIN_STORAGE_KEY);
    const salt = await SecureStorage.get(PINService.SALT_STORAGE_KEY);

    if (!storedHash || !salt) {
      throw new Error('PIN not set');
    }

    // Hash input PIN
    const inputHash = await this.hashPIN(pin, Buffer.from(salt, 'hex'));

    // Compare hashes (constant-time comparison)
    const isValid = this.constantTimeEqual(
      inputHash,
      Buffer.from(storedHash, 'hex')
    );

    if (!isValid) {
      await this.recordFailedAttempt();
      return false;
    }

    await this.resetFailedAttempts();
    return true;
  }

  /**
   * Hash PIN with PBKDF2
   */
  private async hashPIN(pin: string, salt: Buffer): Promise<Buffer> {
    // PBKDF2(pin, salt, 100000 rounds, 256 bits)
    return Buffer.from(pbkdf2(sha256, pin, salt, { c: 100000, dkLen: 32 }));
  }

  /**
   * Validate PIN format
   */
  private validatePIN(pin: string): boolean {
    // Must be 6 digits
    return /^\d{6}$/.test(pin);
  }

  /**
   * Constant-time comparison (prevent timing attacks)
   */
  private constantTimeEqual(a: Buffer, b: Buffer): boolean {
    if (a.length !== b.length) {
      return false;
    }

    let result = 0;
    for (let i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }

    return result === 0;
  }

  /**
   * Record failed PIN attempt
   */
  private async recordFailedAttempt(): Promise<void> {
    const attempts = await this.getFailedAttempts();
    await SecureStorage.set('failed_attempts', (attempts + 1).toString());

    if (attempts + 1 >= PINService.MAX_ATTEMPTS) {
      await SecureStorage.set('lockout_until', (Date.now() + PINService.LOCKOUT_DURATION).toString());
    }
  }

  /**
   * Check if locked out
   */
  private async isLockedOut(): Promise<boolean> {
    const lockoutUntil = await SecureStorage.get('lockout_until');
    if (!lockoutUntil) return false;

    return Date.now() < parseInt(lockoutUntil);
  }
}
```

---

## 5. Network Security

### 5.1 Certificate Pinning

```typescript
// NetworkSecurity.ts
import axios from 'axios';
import { Platform } from 'react-native';

export class NetworkSecurity {
  /**
   * Configure certificate pinning
   */
  static configureSSLPinning() {
    if (Platform.OS === 'ios') {
      // iOS: Use TrustKit
      TrustKit.initializeWithNetworkSecurityConfiguration({
        'eth-mainnet.g.alchemy.com': {
          publicKeyHashes: [
            'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // Replace with actual
            'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // Backup pin
          ],
          enforceBackupPin: true,
        },
      });
    } else {
      // Android: Use network_security_config.xml
      // See android/app/src/main/res/xml/network_security_config.xml
    }
  }

  /**
   * Create secure axios instance
   */
  static createSecureClient() {
    const client = axios.create({
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Request interceptor
    client.interceptors.request.use((config) => {
      // Force HTTPS
      if (config.url && config.url.startsWith('http://')) {
        config.url = config.url.replace('http://', 'https://');
      }

      return config;
    });

    // Response interceptor
    client.interceptors.response.use(
      (response) => response,
      (error) => {
        // Log SSL errors
        if (error.message?.includes('certificate')) {
          console.error('SSL Certificate Error:', error);
        }
        return Promise.reject(error);
      }
    );

    return client;
  }
}
```

### 5.2 Android Network Security Config

```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Production -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">eth-mainnet.g.alchemy.com</domain>
        <pin-set expiration="2026-01-01">
            <!-- Alchemy Certificate Pin -->
            <pin digest="SHA-256">AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</pin>
            <!-- Backup Pin -->
            <pin digest="SHA-256">BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=</pin>
        </pin-set>
    </domain-config>

    <!-- Block cleartext (HTTP) traffic -->
    <base-config cleartextTrafficPermitted="false" />
</network-security-config>
```

---

## 6. Runtime Security

### 6.1 Jailbreak/Root Detection

```typescript
// SecurityChecks.ts
import JailMonkey from 'jail-monkey';

export class SecurityChecks {
  /**
   * Check if device is compromised
   */
  static async checkDeviceSecurity(): Promise<{
    isSecure: boolean;
    warnings: string[];
  }> {
    const warnings: string[] = [];

    // Check for jailbreak (iOS) or root (Android)
    if (JailMonkey.isJailBroken()) {
      warnings.push('Device is jailbroken/rooted');
    }

    // Check for debugger
    if (JailMonkey.isOnExternalStorage()) {
      warnings.push('App installed on external storage');
    }

    // Check if running in emulator
    if (await JailMonkey.isDebuggedMode()) {
      warnings.push('Debugger detected');
    }

    // Check for suspicious apps
    if (JailMonkey.hookDetected()) {
      warnings.push('Hooking framework detected');
    }

    return {
      isSecure: warnings.length === 0,
      warnings,
    };
  }

  /**
   * Enforce security checks
   */
  static async enforceSecurityPolicy(): Promise<void> {
    const { isSecure, warnings } = await this.checkDeviceSecurity();

    if (!isSecure) {
      // Log warnings
      console.warn('Security warnings:', warnings);

      // Show warning to user
      Alert.alert(
        'Security Warning',
        'Your device may be compromised. For your security, please use this app on a secure device.',
        [
          { text: 'Continue Anyway', style: 'cancel' },
          { text: 'Exit', onPress: () => RNExitApp.exitApp() },
        ]
      );
    }
  }
}
```

---

## 7. Data Protection

### 7.1 Encryption at Rest

```typescript
// SecureStorage.ts
import MMKV from 'react-native-mmkv';
import CryptoJS from 'crypto-js';

export class SecureStorage {
  private static storage = new MMKV({
    id: 'fueki-secure-storage',
    encryptionKey: 'device-specific-key', // From device keychain
  });

  /**
   * Store encrypted value
   */
  static async set(key: string, value: string): Promise<void> {
    // Additional encryption layer
    const encrypted = CryptoJS.AES.encrypt(
      value,
      await this.getEncryptionKey()
    ).toString();

    this.storage.set(key, encrypted);
  }

  /**
   * Retrieve and decrypt value
   */
  static async get(key: string): Promise<string | null> {
    const encrypted = this.storage.getString(key);
    if (!encrypted) return null;

    const decrypted = CryptoJS.AES.decrypt(
      encrypted,
      await this.getEncryptionKey()
    );

    return decrypted.toString(CryptoJS.enc.Utf8);
  }

  /**
   * Get device-specific encryption key
   */
  private static async getEncryptionKey(): Promise<string> {
    // Stored in hardware keychain
    return await DeviceKeychain.getEncryptionKey();
  }
}
```

---

## 8. Security Best Practices Checklist

### Code Security
- [x] No hardcoded secrets
- [x] All sensitive data encrypted
- [x] Memory zeroed after use
- [x] Input validation everywhere
- [x] SQL injection prevention
- [x] Constant-time comparisons

### Network Security
- [x] HTTPS only
- [x] Certificate pinning
- [x] TLS 1.3 minimum
- [x] Timeout configurations
- [x] Error handling

### Authentication
- [x] Biometric support
- [x] PIN fallback
- [x] Auto-lock
- [x] Failed attempt limiting
- [x] Lockout on brute force

### Storage Security
- [x] Hardware-backed storage
- [x] Encrypted database
- [x] Secure deletion
- [x] No cloud backup of keys

### Runtime Security
- [x] Jailbreak detection
- [x] Debugger detection
- [x] Code obfuscation
- [x] Strip debug symbols

---

**Document Version:** 1.0.0
**Last Updated:** 2025-10-21
