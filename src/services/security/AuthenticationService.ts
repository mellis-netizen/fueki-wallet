/**
 * Authentication Service
 *
 * Handles user authentication combining biometric and PIN/password methods
 * Manages session state and auto-lock functionality
 */

import { BiometricService } from './BiometricService';
import { KeyManagementService } from './KeyManagementService';
import { SecureStorageService } from './SecureStorageService';
import { EncryptionService } from './EncryptionService';
import { SecurityConfig, SecurityError, SecurityErrorCode, SecurityEventType, SecurityValidator } from './SecurityConfig';
import { SecurityLogger } from './SecurityLogger';
import { AppState, AppStateStatus } from 'react-native';

/**
 * Authentication method types
 */
export type AuthMethod = 'biometric' | 'pin' | 'password' | 'none';

/**
 * Authentication result
 */
export interface AuthResult {
  success: boolean;
  method?: AuthMethod;
  error?: string;
  remainingAttempts?: number;
}

/**
 * PIN/Password authentication data
 */
interface PINAuthData {
  hash: string;
  salt: string;
  attempts: number;
  lockoutUntil: number;
}

/**
 * Authentication Service
 */
export class AuthenticationService {
  private static instance: AuthenticationService;
  private biometricService: BiometricService;
  private keyManagementService: KeyManagementService;
  private secureStorage: SecureStorageService;
  private logger: SecurityLogger;

  private isAuthenticated: boolean = false;
  private sessionTimeout: NodeJS.Timeout | null = null;
  private appStateSubscription: any = null;

  private constructor() {
    this.biometricService = BiometricService.getInstance();
    this.keyManagementService = KeyManagementService.getInstance();
    this.secureStorage = SecureStorageService.getInstance();
    this.logger = SecurityLogger.getInstance();

    // Set up app state listener for auto-lock
    this.setupAppStateListener();
  }

  /**
   * Get singleton instance
   */
  static getInstance(): AuthenticationService {
    if (!AuthenticationService.instance) {
      AuthenticationService.instance = new AuthenticationService();
    }
    return AuthenticationService.instance;
  }

  /**
   * Initialize authentication (check if setup is required)
   */
  async initialize(): Promise<{
    hasWallet: boolean;
    authMethod: AuthMethod;
    requiresSetup: boolean;
  }> {
    try {
      const hasWallet = await this.keyManagementService.hasWallet();

      if (!hasWallet) {
        return {
          hasWallet: false,
          authMethod: 'none',
          requiresSetup: true,
        };
      }

      const authMethod = await this.getAuthMethod();

      return {
        hasWallet: true,
        authMethod,
        requiresSetup: authMethod === 'none',
      };
    } catch (error: any) {
      this.logger.error('Failed to initialize authentication', { error: error.message });
      throw error;
    }
  }

  /**
   * Set up authentication method
   */
  async setupAuthentication(method: AuthMethod, credential?: string): Promise<void> {
    try {
      if (method === 'biometric') {
        const availability = await this.biometricService.isAvailable();

        if (!availability.available) {
          throw new SecurityError(
            SecurityErrorCode.BIOMETRIC_NOT_AVAILABLE,
            'Biometric authentication not available on this device'
          );
        }

        // Create biometric keys
        await this.biometricService.createKeys();

        // Enable biometric in storage
        this.secureStorage.storeData('auth_method', 'biometric');

        this.logger.info('Biometric authentication set up');
      } else if (method === 'pin' || method === 'password') {
        if (!credential) {
          throw new SecurityError(
            SecurityErrorCode.AUTH_FAILED,
            'PIN/password is required'
          );
        }

        // Validate credential
        if (method === 'pin') {
          const validation = SecurityValidator.validatePIN(credential);
          if (!validation.valid) {
            throw new SecurityError(
              SecurityErrorCode.PIN_INVALID,
              validation.error || 'Invalid PIN'
            );
          }
        }

        await this.setupPINOrPassword(credential);

        // Store auth method
        this.secureStorage.storeData('auth_method', method);

        this.logger.info(`${method.toUpperCase()} authentication set up`);
      } else {
        throw new SecurityError(
          SecurityErrorCode.AUTH_FAILED,
          'Invalid authentication method'
        );
      }
    } catch (error: any) {
      this.logger.error('Failed to setup authentication', { error: error.message });
      throw error;
    }
  }

  /**
   * Authenticate user
   */
  async authenticate(credential?: string): Promise<AuthResult> {
    try {
      const authMethod = await this.getAuthMethod();

      if (authMethod === 'none') {
        throw new SecurityError(
          SecurityErrorCode.NOT_INITIALIZED,
          'No authentication method set up'
        );
      }

      let result: AuthResult;

      if (authMethod === 'biometric') {
        result = await this.authenticateWithBiometric();
      } else if (authMethod === 'pin' || authMethod === 'password') {
        if (!credential) {
          throw new SecurityError(
            SecurityErrorCode.AUTH_FAILED,
            `${authMethod.toUpperCase()} is required`
          );
        }
        result = await this.authenticateWithPIN(credential);
      } else {
        throw new SecurityError(
          SecurityErrorCode.AUTH_FAILED,
          'Unknown authentication method'
        );
      }

      if (result.success) {
        // Unlock wallet
        await this.keyManagementService.unlock();

        // Start session
        this.startSession();

        this.logger.logSecurityEvent(
          SecurityEventType.AUTH_SUCCESS,
          'User authenticated successfully',
          { method: authMethod }
        );
      } else {
        this.logger.logSecurityEvent(
          SecurityEventType.AUTH_FAILURE,
          'Authentication failed',
          { method: authMethod, error: result.error }
        );
      }

      return result;
    } catch (error: any) {
      this.logger.error('Authentication error', { error: error.message });
      throw error;
    }
  }

  /**
   * Authenticate with biometrics
   */
  private async authenticateWithBiometric(): Promise<AuthResult> {
    try {
      const typeName = await this.biometricService.getBiometricTypeName();
      const result = await this.biometricService.authenticate(
        `Unlock your wallet with ${typeName}`
      );

      return {
        success: result.success,
        method: 'biometric',
        error: result.error,
      };
    } catch (error: any) {
      return {
        success: false,
        method: 'biometric',
        error: error.message,
      };
    }
  }

  /**
   * Authenticate with PIN/password
   */
  private async authenticateWithPIN(credential: string): Promise<AuthResult> {
    try {
      const pinData = await this.getPINData();

      if (!pinData) {
        throw new SecurityError(
          SecurityErrorCode.KEY_NOT_FOUND,
          'PIN not set up'
        );
      }

      // Check lockout
      if (Date.now() < pinData.lockoutUntil) {
        const remainingSeconds = Math.ceil((pinData.lockoutUntil - Date.now()) / 1000);
        throw new SecurityError(
          SecurityErrorCode.PIN_LOCKOUT,
          `Too many failed attempts. Try again in ${remainingSeconds} seconds.`
        );
      }

      // Hash provided credential
      const salt = Buffer.from(pinData.salt, 'hex');
      const hash = await this.hashCredential(credential, salt);

      // Compare hashes
      const isValid = hash === pinData.hash;

      if (isValid) {
        // Reset attempts
        pinData.attempts = 0;
        await this.savePINData(pinData);

        return {
          success: true,
          method: 'pin',
        };
      } else {
        // Increment failed attempts
        pinData.attempts += 1;

        const config = SecurityConfig.authentication.pin;
        const remainingAttempts = config.maxAttempts - pinData.attempts;

        if (pinData.attempts >= config.maxAttempts) {
          // Lock out user
          pinData.lockoutUntil = Date.now() + config.lockoutDuration;
          await this.savePINData(pinData);

          throw new SecurityError(
            SecurityErrorCode.PIN_LOCKOUT,
            `Too many failed attempts. Account locked for ${config.lockoutDuration / 60000} minutes.`
          );
        }

        await this.savePINData(pinData);

        return {
          success: false,
          method: 'pin',
          error: 'Invalid PIN',
          remainingAttempts,
        };
      }
    } catch (error: any) {
      if (error instanceof SecurityError) {
        throw error;
      }

      return {
        success: false,
        method: 'pin',
        error: error.message,
      };
    }
  }

  /**
   * Set up PIN or password
   */
  private async setupPINOrPassword(credential: string): Promise<void> {
    try {
      // Generate salt
      const salt = EncryptionService.generateRandomBytes(32);

      // Hash credential
      const hash = await this.hashCredential(credential, salt);

      // Save data
      const pinData: PINAuthData = {
        hash,
        salt: salt.toString('hex'),
        attempts: 0,
        lockoutUntil: 0,
      };

      await this.savePINData(pinData);
    } catch (error: any) {
      this.logger.error('Failed to setup PIN/password', { error: error.message });
      throw error;
    }
  }

  /**
   * Hash credential with PBKDF2
   */
  private async hashCredential(credential: string, salt: Buffer): Promise<string> {
    const config = SecurityConfig.authentication.pin;
    const derived = await EncryptionService.deriveKeyFromPassword(
      credential,
      salt,
      config.hashIterations,
      config.hashKeySize
    );
    return derived.toString('hex');
  }

  /**
   * Get PIN data from storage
   */
  private async getPINData(): Promise<PINAuthData | null> {
    const data = await this.secureStorage.retrieveSensitive(SecurityConfig.storage.keys.pinHash);
    return data ? JSON.parse(data) : null;
  }

  /**
   * Save PIN data to storage
   */
  private async savePINData(data: PINAuthData): Promise<void> {
    await this.secureStorage.storeSensitive(
      SecurityConfig.storage.keys.pinHash,
      JSON.stringify(data)
    );
  }

  /**
   * Change authentication credential
   */
  async changeCredential(oldCredential: string, newCredential: string): Promise<void> {
    try {
      // Verify old credential
      const result = await this.authenticate(oldCredential);

      if (!result.success) {
        throw new SecurityError(
          SecurityErrorCode.AUTH_FAILED,
          'Invalid current credential'
        );
      }

      // Set new credential
      const authMethod = await this.getAuthMethod();

      if (authMethod === 'pin' || authMethod === 'password') {
        await this.setupPINOrPassword(newCredential);
        this.logger.info('Credential changed successfully');
      } else {
        throw new SecurityError(
          SecurityErrorCode.AUTH_FAILED,
          'Cannot change biometric credential'
        );
      }
    } catch (error: any) {
      this.logger.error('Failed to change credential', { error: error.message });
      throw error;
    }
  }

  /**
   * Get current authentication method
   */
  async getAuthMethod(): Promise<AuthMethod> {
    const method = this.secureStorage.retrieveData<AuthMethod>('auth_method');
    return method || 'none';
  }

  /**
   * Check if user is authenticated
   */
  isAuthenticated(): boolean {
    return this.isAuthenticated && this.keyManagementService.isWalletUnlocked();
  }

  /**
   * Start authenticated session
   */
  private startSession(): void {
    this.isAuthenticated = true;
    this.startSessionTimeout();

    this.logger.logSecurityEvent(
      SecurityEventType.SESSION_START,
      'Authentication session started'
    );
  }

  /**
   * End authenticated session
   */
  endSession(): void {
    this.isAuthenticated = false;
    this.keyManagementService.lock();
    this.clearSessionTimeout();

    this.logger.logSecurityEvent(
      SecurityEventType.SESSION_END,
      'Authentication session ended'
    );
  }

  /**
   * Start session timeout
   */
  private startSessionTimeout(): void {
    this.clearSessionTimeout();

    const timeout = SecurityConfig.authentication.session.defaultTimeout * 1000;

    this.sessionTimeout = setTimeout(() => {
      this.logger.logSecurityEvent(
        SecurityEventType.SESSION_TIMEOUT,
        'Session timeout - ending session'
      );
      this.endSession();
    }, timeout);
  }

  /**
   * Clear session timeout
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
    if (this.isAuthenticated) {
      this.startSessionTimeout();
      this.keyManagementService.resetAutoLockTimer();
    }
  }

  /**
   * Set up app state listener for auto-lock
   */
  private setupAppStateListener(): void {
    this.appStateSubscription = AppState.addEventListener(
      'change',
      this.handleAppStateChange.bind(this)
    );
  }

  /**
   * Handle app state changes
   */
  private handleAppStateChange(nextAppState: AppStateStatus): void {
    if (nextAppState === 'background' || nextAppState === 'inactive') {
      // App going to background
      if (SecurityConfig.authentication.session.autoLockOnBackground) {
        this.logger.logSecurityEvent(
          SecurityEventType.APP_BACKGROUND,
          'App backgrounded - locking wallet'
        );
        this.endSession();
      }
    }

    if (nextAppState === 'active') {
      this.logger.logSecurityEvent(
        SecurityEventType.APP_FOREGROUND,
        'App foregrounded'
      );
    }
  }

  /**
   * Clean up
   */
  destroy(): void {
    this.endSession();

    if (this.appStateSubscription) {
      this.appStateSubscription.remove();
    }
  }

  /**
   * Get remaining PIN attempts
   */
  async getRemainingAttempts(): Promise<number> {
    const pinData = await this.getPINData();

    if (!pinData) {
      return 0;
    }

    const config = SecurityConfig.authentication.pin;
    return Math.max(0, config.maxAttempts - pinData.attempts);
  }

  /**
   * Check if locked out
   */
  async isLockedOut(): Promise<{ locked: boolean; remainingSeconds?: number }> {
    const pinData = await this.getPINData();

    if (!pinData || pinData.lockoutUntil === 0) {
      return { locked: false };
    }

    if (Date.now() < pinData.lockoutUntil) {
      const remainingSeconds = Math.ceil((pinData.lockoutUntil - Date.now()) / 1000);
      return {
        locked: true,
        remainingSeconds,
      };
    }

    return { locked: false };
  }
}

export default AuthenticationService;
