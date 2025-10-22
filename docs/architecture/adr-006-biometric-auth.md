# ADR-006: Biometric Authentication Flow

## Status
**ACCEPTED** - 2025-10-21

## Context

The Fueki Mobile Wallet requires secure, user-friendly authentication to protect access to wallet operations. Biometric authentication (Face ID, Touch ID, fingerprint) provides a balance between security and usability.

### Requirements
1. **Security**: Hardware-backed biometric authentication
2. **Usability**: Fast, frictionless authentication
3. **Fallback**: PIN/password option when biometrics unavailable
4. **Graceful Degradation**: Work on devices without biometric hardware
5. **Privacy**: Biometric data never leaves device
6. **Compliance**: Follow platform security best practices

### Constraints
- iOS: Face ID, Touch ID (requires user permission)
- Android: Fingerprint, Face unlock (varies by device)
- React Native environment
- Must integrate with Secure Enclave/Keystore

## Decision

We will implement a **multi-level authentication system** using react-native-biometrics with PIN/password fallback, integrated with the Secure Enclave key management.

## Architecture

### Authentication Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    App Launch / Wallet Access                   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│           Check if Wallet Exists & Biometric Available          │
└─────────────────────────────────────────────────────────────────┘
                            │
                   ┌────────┴────────┐
                   │                 │
         ┌─────────▼────────┐  ┌────▼──────────┐
         │ Biometric        │  │ PIN/Password  │
         │ Available        │  │ Only          │
         └─────────┬────────┘  └────┬──────────┘
                   │                 │
                   ▼                 ▼
         ┌─────────────────┐  ┌──────────────────┐
         │ Biometric Prompt│  │ PIN Input Screen │
         │ (Face ID/Touch) │  │                  │
         └─────────┬────────┘  └────┬─────────────┘
                   │                 │
                   └────────┬────────┘
                            │
                    ┌───────▼───────┐
                    │  Success?     │
                    └───────┬───────┘
                            │
                   ┌────────┴────────┐
                   │                 │
         ┌─────────▼────────┐  ┌────▼──────────┐
         │ Unlock Wallet    │  │ Show Error    │
         │ (Decrypt MEK)    │  │ Retry?        │
         └─────────┬────────┘  └────┬──────────┘
                   │                 │
                   ▼                 │
         ┌──────────────────┐       │
         │ Access Granted   │       │
         │ (Wallet Unlocked)│◄──────┘
         └──────────────────┘
```

### Session Management Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Authenticated Session                        │
└─────────────────────────────────────────────────────────────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
    ┌─────────▼───────┐ ┌──▼──────┐ ┌───▼────────────┐
    │ App Background  │ │ Timeout │ │ User Logout    │
    └─────────┬───────┘ └──┬──────┘ └───┬────────────┘
              │             │             │
              └─────────────┼─────────────┘
                            ▼
              ┌─────────────────────────┐
              │ Lock Wallet             │
              │ - Clear MEK from memory │
              │ - Require re-auth       │
              └─────────────────────────┘
```

## Implementation

### 1. Biometric Service

```typescript
// src/services/BiometricAuth.ts

import ReactNativeBiometrics, { BiometryTypes } from 'react-native-biometrics';

export class BiometricAuth {
  private static rnBiometrics = new ReactNativeBiometrics({
    allowDeviceCredentials: true, // Allow PIN/password fallback
  });

  /**
   * Check if biometrics are available on device
   */
  static async isAvailable(): Promise<BiometricAvailability> {
    try {
      const { available, biometryType } = await this.rnBiometrics.isSensorAvailable();

      return {
        available,
        type: this.mapBiometryType(biometryType),
        hasCredentials: available,
      };
    } catch (error) {
      console.error('Error checking biometric availability:', error);
      return {
        available: false,
        type: 'none',
        hasCredentials: false,
      };
    }
  }

  /**
   * Authenticate user with biometrics
   */
  static async authenticate(promptMessage: string): Promise<boolean> {
    try {
      const { available } = await this.isAvailable();

      if (!available) {
        throw new Error('Biometric authentication not available');
      }

      const { success } = await this.rnBiometrics.simplePrompt({
        promptMessage,
        cancelButtonText: 'Cancel',
      });

      return success;
    } catch (error: any) {
      // Handle specific errors
      if (error.code === 'USER_CANCELLATION') {
        console.log('User cancelled authentication');
        return false;
      }

      if (error.code === 'BIOMETRIC_ERROR_LOCKOUT') {
        throw new Error('Too many failed attempts. Please try again later.');
      }

      if (error.code === 'BIOMETRIC_ERROR_LOCKOUT_PERMANENT') {
        throw new Error('Biometric authentication locked. Use PIN instead.');
      }

      throw error;
    }
  }

  /**
   * Create biometric keys (for advanced signature-based auth)
   */
  static async createKeys(): Promise<{ publicKey: string }> {
    try {
      const { publicKey } = await this.rnBiometrics.createKeys();
      return { publicKey };
    } catch (error) {
      console.error('Error creating biometric keys:', error);
      throw error;
    }
  }

  /**
   * Delete biometric keys
   */
  static async deleteKeys(): Promise<void> {
    try {
      await this.rnBiometrics.deleteKeys();
    } catch (error) {
      console.error('Error deleting biometric keys:', error);
      throw error;
    }
  }

  /**
   * Sign data with biometric-protected key
   */
  static async signWithBiometrics(payload: string, promptMessage: string): Promise<string> {
    try {
      const { success, signature } = await this.rnBiometrics.createSignature({
        promptMessage,
        payload,
        cancelButtonText: 'Cancel',
      });

      if (!success || !signature) {
        throw new Error('Biometric signature failed');
      }

      return signature;
    } catch (error) {
      console.error('Error signing with biometrics:', error);
      throw error;
    }
  }

  /**
   * Map platform biometry type to our enum
   */
  private static mapBiometryType(type: BiometryTypes | undefined): BiometricType {
    switch (type) {
      case BiometryTypes.FaceID:
        return 'face-id';
      case BiometryTypes.TouchID:
        return 'touch-id';
      case BiometryTypes.Biometrics:
        return 'fingerprint';
      default:
        return 'none';
    }
  }

  /**
   * Get user-friendly biometric type name
   */
  static async getBiometricTypeName(): Promise<string> {
    const { type } = await this.isAvailable();

    switch (type) {
      case 'face-id':
        return 'Face ID';
      case 'touch-id':
        return 'Touch ID';
      case 'fingerprint':
        return 'Fingerprint';
      default:
        return 'Biometric';
    }
  }
}

export interface BiometricAvailability {
  available: boolean;
  type: BiometricType;
  hasCredentials: boolean;
}

export type BiometricType = 'face-id' | 'touch-id' | 'fingerprint' | 'none';
```

### 2. PIN/Password Service

```typescript
// src/services/PINAuth.ts

import { SecureStorage } from '../core/security/SecureStorage';
import { EncryptionService } from '../core/security/EncryptionService';
import crypto from 'crypto';

export class PINAuth {
  private static PIN_HASH_KEY = 'pin_hash';
  private static PIN_SALT_KEY = 'pin_salt';
  private static MAX_ATTEMPTS = 5;
  private static LOCKOUT_DURATION = 300000; // 5 minutes

  private static secureStorage = new SecureStorage();

  /**
   * Set up PIN for the first time
   */
  static async setupPIN(pin: string): Promise<void> {
    if (!this.validatePIN(pin)) {
      throw new Error('PIN must be 6 digits');
    }

    // Generate salt
    const salt = crypto.randomBytes(32).toString('hex');

    // Hash PIN with salt
    const hash = await this.hashPIN(pin, salt);

    // Store hash and salt in secure storage
    await this.secureStorage.storeSensitive(this.PIN_HASH_KEY, hash);
    await this.secureStorage.storeSensitive(this.PIN_SALT_KEY, salt);

    // Reset attempts
    this.secureStorage.storeData('pin_attempts', 0);
    this.secureStorage.storeData('pin_lockout_until', 0);
  }

  /**
   * Verify PIN
   */
  static async verifyPIN(pin: string): Promise<boolean> {
    // Check if locked out
    const lockoutUntil = this.secureStorage.retrieveData<number>('pin_lockout_until') || 0;
    if (Date.now() < lockoutUntil) {
      const remainingSeconds = Math.ceil((lockoutUntil - Date.now()) / 1000);
      throw new Error(`Too many failed attempts. Try again in ${remainingSeconds} seconds.`);
    }

    // Get stored hash and salt
    const storedHash = await this.secureStorage.retrieveSensitive(this.PIN_HASH_KEY);
    const salt = await this.secureStorage.retrieveSensitive(this.PIN_SALT_KEY);

    if (!storedHash || !salt) {
      throw new Error('PIN not set up');
    }

    // Hash provided PIN
    const hash = await this.hashPIN(pin, salt);

    // Compare hashes
    const isValid = hash === storedHash;

    if (isValid) {
      // Reset attempts on success
      this.secureStorage.storeData('pin_attempts', 0);
      return true;
    } else {
      // Increment failed attempts
      const attempts = (this.secureStorage.retrieveData<number>('pin_attempts') || 0) + 1;
      this.secureStorage.storeData('pin_attempts', attempts);

      if (attempts >= this.MAX_ATTEMPTS) {
        // Lock out user
        const lockoutUntil = Date.now() + this.LOCKOUT_DURATION;
        this.secureStorage.storeData('pin_lockout_until', lockoutUntil);
        throw new Error('Too many failed attempts. Account locked for 5 minutes.');
      }

      return false;
    }
  }

  /**
   * Change PIN
   */
  static async changePIN(oldPIN: string, newPIN: string): Promise<void> {
    // Verify old PIN
    const isValid = await this.verifyPIN(oldPIN);
    if (!isValid) {
      throw new Error('Invalid current PIN');
    }

    // Set new PIN
    await this.setupPIN(newPIN);
  }

  /**
   * Check if PIN is set up
   */
  static async hasPIN(): Promise<boolean> {
    const hash = await this.secureStorage.retrieveSensitive(this.PIN_HASH_KEY);
    return hash !== null;
  }

  /**
   * Remove PIN (requires verification)
   */
  static async removePIN(pin: string): Promise<void> {
    const isValid = await this.verifyPIN(pin);
    if (!isValid) {
      throw new Error('Invalid PIN');
    }

    await this.secureStorage.deleteSensitive(this.PIN_HASH_KEY);
    await this.secureStorage.deleteSensitive(this.PIN_SALT_KEY);
    this.secureStorage.deleteData('pin_attempts');
    this.secureStorage.deleteData('pin_lockout_until');
  }

  /**
   * Hash PIN with PBKDF2
   */
  private static async hashPIN(pin: string, salt: string): Promise<string> {
    return new Promise((resolve, reject) => {
      crypto.pbkdf2(pin, salt, 100000, 64, 'sha512', (err, derivedKey) => {
        if (err) reject(err);
        resolve(derivedKey.toString('hex'));
      });
    });
  }

  /**
   * Validate PIN format
   */
  private static validatePIN(pin: string): boolean {
    return /^\d{6}$/.test(pin);
  }

  /**
   * Get remaining attempts
   */
  static getRemainingAttempts(): number {
    const attempts = this.secureStorage.retrieveData<number>('pin_attempts') || 0;
    return Math.max(0, this.MAX_ATTEMPTS - attempts);
  }
}
```

### 3. Authentication Manager

```typescript
// src/services/AuthManager.ts

import { BiometricAuth } from './BiometricAuth';
import { PINAuth } from './PINAuth';
import { KeyManagementService } from '../core/wallet/KeyManagementService';
import { useSettingsStore } from '../stores/settingsStore';

export class AuthManager {
  private keyManager: KeyManagementService;
  private sessionTimeout: NodeJS.Timeout | null = null;

  constructor() {
    this.keyManager = new KeyManagementService();
  }

  /**
   * Initial setup: Choose authentication method
   */
  async setupAuthentication(method: 'biometric' | 'pin', pin?: string): Promise<void> {
    if (method === 'biometric') {
      const { available } = await BiometricAuth.isAvailable();
      if (!available) {
        throw new Error('Biometric authentication not available on this device');
      }

      // Create biometric keys
      await BiometricAuth.createKeys();

      // Enable biometric in settings
      useSettingsStore.getState().setBiometricEnabled(true);
    } else if (method === 'pin' && pin) {
      await PINAuth.setupPIN(pin);
    } else {
      throw new Error('Invalid authentication method');
    }
  }

  /**
   * Authenticate and unlock wallet
   */
  async authenticate(): Promise<boolean> {
    const biometricEnabled = useSettingsStore.getState().biometricEnabled;

    try {
      let authenticated = false;

      if (biometricEnabled) {
        // Try biometric first
        try {
          const typeName = await BiometricAuth.getBiometricTypeName();
          authenticated = await BiometricAuth.authenticate(`Unlock your wallet with ${typeName}`);
        } catch (error: any) {
          console.error('Biometric auth failed:', error);

          // Fall back to PIN if biometric fails
          if (await PINAuth.hasPIN()) {
            // Show PIN input UI (handled by component)
            return false;
          }

          throw error;
        }
      } else {
        // Use PIN
        if (!(await PINAuth.hasPIN())) {
          throw new Error('No authentication method set up');
        }

        // PIN verification handled by UI component
        return false;
      }

      if (authenticated) {
        await this.unlockWallet();
        this.startSessionTimeout();
        return true;
      }

      return false;
    } catch (error) {
      console.error('Authentication failed:', error);
      throw error;
    }
  }

  /**
   * Verify PIN and unlock (called from PIN input UI)
   */
  async authenticateWithPIN(pin: string): Promise<boolean> {
    const isValid = await PINAuth.verifyPIN(pin);

    if (isValid) {
      await this.unlockWallet();
      this.startSessionTimeout();
    }

    return isValid;
  }

  /**
   * Unlock wallet (decrypt mnemonic)
   */
  private async unlockWallet(): Promise<void> {
    await this.keyManager.unlock();
  }

  /**
   * Lock wallet (clear sensitive data)
   */
  lockWallet(): void {
    this.keyManager.lock();
    this.clearSessionTimeout();
  }

  /**
   * Start auto-lock timeout
   */
  private startSessionTimeout(): void {
    this.clearSessionTimeout();

    const timeout = useSettingsStore.getState().autoLockTimeout;

    if (timeout > 0) {
      this.sessionTimeout = setTimeout(() => {
        console.log('Session timeout - locking wallet');
        this.lockWallet();
      }, timeout * 1000);
    }
  }

  /**
   * Clear auto-lock timeout
   */
  private clearSessionTimeout(): void {
    if (this.sessionTimeout) {
      clearTimeout(this.sessionTimeout);
      this.sessionTimeout = null;
    }
  }

  /**
   * Reset session timeout (on user activity)
   */
  resetSessionTimeout(): void {
    if (this.keyManager.isWalletUnlocked()) {
      this.startSessionTimeout();
    }
  }

  /**
   * Check if wallet is unlocked
   */
  isUnlocked(): boolean {
    return this.keyManager.isWalletUnlocked();
  }

  /**
   * Get authentication method
   */
  async getAuthMethod(): Promise<'biometric' | 'pin' | 'none'> {
    const biometricEnabled = useSettingsStore.getState().biometricEnabled;

    if (biometricEnabled) {
      return 'biometric';
    } else if (await PINAuth.hasPIN()) {
      return 'pin';
    }

    return 'none';
  }
}
```

### 4. Authentication Screen Component

```typescript
// src/screens/AuthScreen.tsx

import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { BiometricAuth } from '../services/BiometricAuth';
import { AuthManager } from '../services/AuthManager';
import { PINInput } from '../components/PINInput';

export const AuthScreen: React.FC = () => {
  const [authMethod, setAuthMethod] = useState<'biometric' | 'pin' | 'none'>('none');
  const [showPIN, setShowPIN] = useState(false);
  const [error, setError] = useState<string>('');
  const [biometricType, setBiometricType] = useState<string>('');

  const authManager = new AuthManager();

  useEffect(() => {
    initAuth();
  }, []);

  const initAuth = async () => {
    const method = await authManager.getAuthMethod();
    setAuthMethod(method);

    if (method === 'biometric') {
      const typeName = await BiometricAuth.getBiometricTypeName();
      setBiometricType(typeName);
      // Auto-trigger biometric prompt
      handleBiometricAuth();
    } else if (method === 'pin') {
      setShowPIN(true);
    }
  };

  const handleBiometricAuth = async () => {
    try {
      const success = await authManager.authenticate();

      if (success) {
        // Navigate to main app
        console.log('Authentication successful');
      } else {
        // Show PIN fallback
        setShowPIN(true);
      }
    } catch (error: any) {
      setError(error.message);
      setShowPIN(true);
    }
  };

  const handlePINSubmit = async (pin: string) => {
    try {
      const success = await authManager.authenticateWithPIN(pin);

      if (success) {
        // Navigate to main app
        console.log('PIN authentication successful');
      } else {
        setError('Invalid PIN');
      }
    } catch (error: any) {
      setError(error.message);
    }
  };

  if (authMethod === 'none') {
    return (
      <View style={styles.container}>
        <Text>Setting up authentication...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Unlock Fueki Wallet</Text>

      {error ? <Text style={styles.error}>{error}</Text> : null}

      {!showPIN && authMethod === 'biometric' ? (
        <View style={styles.biometricContainer}>
          <Text style={styles.subtitle}>Use {biometricType} to unlock</Text>
          <TouchableOpacity style={styles.button} onPress={handleBiometricAuth}>
            <Text style={styles.buttonText}>Authenticate</Text>
          </TouchableOpacity>
          <TouchableOpacity onPress={() => setShowPIN(true)}>
            <Text style={styles.linkText}>Use PIN instead</Text>
          </TouchableOpacity>
        </View>
      ) : null}

      {showPIN ? (
        <View style={styles.pinContainer}>
          <Text style={styles.subtitle}>Enter your PIN</Text>
          <PINInput onSubmit={handlePINSubmit} />
          {authMethod === 'biometric' ? (
            <TouchableOpacity onPress={() => setShowPIN(false)}>
              <Text style={styles.linkText}>Use {biometricType} instead</Text>
            </TouchableOpacity>
          ) : null}
        </View>
      ) : null}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
  },
  subtitle: {
    fontSize: 16,
    marginBottom: 20,
  },
  error: {
    color: 'red',
    marginBottom: 10,
  },
  biometricContainer: {
    alignItems: 'center',
  },
  pinContainer: {
    alignItems: 'center',
  },
  button: {
    backgroundColor: '#007AFF',
    padding: 15,
    borderRadius: 10,
    marginBottom: 20,
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
  linkText: {
    color: '#007AFF',
    fontSize: 14,
  },
});
```

### 5. App State Listener (Auto-Lock)

```typescript
// src/hooks/useAppState.ts

import { useEffect, useRef } from 'react';
import { AppState, AppStateStatus } from 'react-native';
import { AuthManager } from '../services/AuthManager';

export const useAppStateLock = () => {
  const appState = useRef(AppState.currentState);
  const authManager = useRef(new AuthManager());

  useEffect(() => {
    const subscription = AppState.addEventListener('change', handleAppStateChange);

    return () => {
      subscription.remove();
    };
  }, []);

  const handleAppStateChange = (nextAppState: AppStateStatus) => {
    if (appState.current === 'active' && nextAppState.match(/inactive|background/)) {
      // App going to background - lock wallet
      console.log('App backgrounded - locking wallet');
      authManager.current.lockWallet();
    }

    appState.current = nextAppState;
  };
};
```

## Security Considerations

### 1. **Biometric Data Privacy**
- Biometric data never leaves the device
- Authentication handled by iOS/Android secure hardware
- No biometric templates stored by app

### 2. **Brute Force Protection**
- PIN attempts limited (5 attempts)
- Lockout period after max attempts
- Exponential backoff on failures

### 3. **Session Management**
- Auto-lock on app background
- Configurable timeout
- Clear sensitive data on lock

### 4. **Secure Key Storage**
- MEK protected by biometric/PIN
- Keys encrypted at rest
- Memory cleared on lock

## Platform-Specific Considerations

### iOS
- Request Face ID/Touch ID permission in Info.plist
- Handle biometric authentication errors gracefully
- Respect user privacy settings

### Android
- Handle different biometric implementations
- Support fingerprint sensors
- Handle device credential fallback

## Testing

```typescript
describe('AuthManager', () => {
  it('should authenticate with biometrics', async () => {
    const authManager = new AuthManager();
    // Mock biometric success
    const result = await authManager.authenticate();
    expect(result).toBe(true);
  });

  it('should fallback to PIN on biometric failure', async () => {
    // Test PIN fallback
  });

  it('should lock wallet after timeout', async () => {
    // Test auto-lock
  });
});
```

## User Experience

### First Time Setup
1. Create wallet (generate mnemonic)
2. Choose authentication method (biometric or PIN)
3. Set up chosen method
4. Confirm authentication works

### Daily Use
1. Open app → Biometric prompt
2. Authenticate → Wallet unlocked
3. Use app normally
4. App backgrounds → Wallet locks
5. Reopen → Authenticate again

### Error Scenarios
- Biometric fails → Fall back to PIN
- Too many PIN attempts → Temporary lockout
- No biometric hardware → PIN only
- Biometric disabled → PIN required

## References

- [react-native-biometrics](https://github.com/SelfLender/react-native-biometrics)
- [iOS Biometric Authentication](https://developer.apple.com/documentation/localauthentication)
- [Android BiometricPrompt](https://developer.android.com/training/sign-in/biometric-auth)

---

**Related ADRs:**
- [ADR-002: Key Management](./adr-002-key-management.md)
- [ADR-005: State Management](./adr-005-state-management.md)
- [ADR-008: Error Handling](./adr-008-error-handling.md)
