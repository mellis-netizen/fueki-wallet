/**
 * Biometric Service
 *
 * Handles biometric authentication (Face ID, Touch ID, Fingerprint)
 * using react-native-biometrics library
 */

import ReactNativeBiometrics, { BiometryTypes } from 'react-native-biometrics';
import { Platform } from 'react-native';
import { SecurityConfig, SecurityError, SecurityErrorCode, SecurityEventType } from './SecurityConfig';
import { SecurityLogger } from './SecurityLogger';

/**
 * Biometric types
 */
export type BiometricType = 'face-id' | 'touch-id' | 'fingerprint' | 'none';

/**
 * Biometric availability
 */
export interface BiometricAvailability {
  available: boolean;
  type: BiometricType;
  hasCredentials: boolean;
  error?: string;
}

/**
 * Biometric authentication result
 */
export interface BiometricAuthResult {
  success: boolean;
  error?: string;
  signature?: string;
}

/**
 * Biometric Service
 */
export class BiometricService {
  private static instance: BiometricService;
  private rnBiometrics: ReactNativeBiometrics;
  private logger: SecurityLogger;

  private constructor() {
    const config = SecurityConfig.authentication.biometric;

    this.rnBiometrics = new ReactNativeBiometrics({
      allowDeviceCredentials: config.allowDeviceCredentials,
    });

    this.logger = SecurityLogger.getInstance();
  }

  /**
   * Get singleton instance
   */
  static getInstance(): BiometricService {
    if (!BiometricService.instance) {
      BiometricService.instance = new BiometricService();
    }
    return BiometricService.instance;
  }

  /**
   * Check if biometric authentication is available
   */
  async isAvailable(): Promise<BiometricAvailability> {
    try {
      const { available, biometryType, error } = await this.rnBiometrics.isSensorAvailable();

      if (!available) {
        this.logger.debug('Biometric not available', { error });
        return {
          available: false,
          type: 'none',
          hasCredentials: false,
          error,
        };
      }

      const type = this.mapBiometryType(biometryType);

      this.logger.debug('Biometric available', { type });

      return {
        available: true,
        type,
        hasCredentials: true,
      };
    } catch (error: any) {
      this.logger.error('Error checking biometric availability', { error: error.message });
      return {
        available: false,
        type: 'none',
        hasCredentials: false,
        error: error.message,
      };
    }
  }

  /**
   * Authenticate user with biometrics
   */
  async authenticate(promptMessage?: string): Promise<BiometricAuthResult> {
    try {
      // Check availability
      const availability = await this.isAvailable();

      if (!availability.available) {
        throw new SecurityError(
          SecurityErrorCode.BIOMETRIC_NOT_AVAILABLE,
          'Biometric authentication not available'
        );
      }

      // Get prompt message from config if not provided
      const config = SecurityConfig.authentication.biometric;
      const message = promptMessage || config.promptMessage;

      // Perform authentication
      const { success, error } = await this.rnBiometrics.simplePrompt({
        promptMessage: message,
        cancelButtonText: config.cancelButtonText,
      });

      if (success) {
        this.logger.logSecurityEvent(
          SecurityEventType.BIOMETRIC_AUTH,
          'Biometric authentication successful',
          { type: availability.type }
        );

        return {
          success: true,
        };
      }

      // Handle authentication failure
      this.logger.warn('Biometric authentication failed', { error });

      return {
        success: false,
        error: error || 'Authentication failed',
      };
    } catch (error: any) {
      this.logger.error('Biometric authentication error', { error: error.message });

      // Handle specific error codes
      if (error.code === SecurityErrorCode.BIOMETRIC_NOT_AVAILABLE) {
        throw error;
      }

      if (error.message?.includes('lockout')) {
        throw new SecurityError(
          SecurityErrorCode.BIOMETRIC_LOCKOUT,
          'Too many failed attempts. Biometric authentication locked.',
          { error: error.message }
        );
      }

      if (error.message?.includes('cancel')) {
        throw new SecurityError(
          SecurityErrorCode.AUTH_CANCELLED,
          'Biometric authentication cancelled by user',
          { error: error.message }
        );
      }

      throw new SecurityError(
        SecurityErrorCode.AUTH_FAILED,
        'Biometric authentication failed',
        { error: error.message }
      );
    }
  }

  /**
   * Create biometric keys for signature-based authentication
   */
  async createKeys(): Promise<{ publicKey: string }> {
    try {
      const { publicKey } = await this.rnBiometrics.createKeys();

      this.logger.info('Biometric keys created');

      return { publicKey };
    } catch (error: any) {
      this.logger.error('Failed to create biometric keys', { error: error.message });
      throw new SecurityError(
        SecurityErrorCode.KEY_GENERATION_FAILED,
        'Failed to create biometric keys',
        { error: error.message }
      );
    }
  }

  /**
   * Delete biometric keys
   */
  async deleteKeys(): Promise<void> {
    try {
      const { keysDeleted } = await this.rnBiometrics.deleteKeys();

      if (keysDeleted) {
        this.logger.info('Biometric keys deleted');
      }
    } catch (error: any) {
      this.logger.error('Failed to delete biometric keys', { error: error.message });
      throw new SecurityError(
        SecurityErrorCode.STORAGE_FAILED,
        'Failed to delete biometric keys',
        { error: error.message }
      );
    }
  }

  /**
   * Check if biometric keys exist
   */
  async hasKeys(): Promise<boolean> {
    try {
      const { keysExist } = await this.rnBiometrics.biometricKeysExist();
      return keysExist;
    } catch (error: any) {
      this.logger.error('Failed to check biometric keys', { error: error.message });
      return false;
    }
  }

  /**
   * Sign data with biometric-protected key
   */
  async signWithBiometrics(
    payload: string,
    promptMessage?: string
  ): Promise<BiometricAuthResult> {
    try {
      const config = SecurityConfig.authentication.biometric;
      const message = promptMessage || config.promptMessage;

      const { success, signature, error } = await this.rnBiometrics.createSignature({
        promptMessage: message,
        payload,
        cancelButtonText: config.cancelButtonText,
      });

      if (success && signature) {
        this.logger.info('Data signed with biometrics');

        return {
          success: true,
          signature,
        };
      }

      this.logger.warn('Biometric signing failed', { error });

      return {
        success: false,
        error: error || 'Signing failed',
      };
    } catch (error: any) {
      this.logger.error('Biometric signing error', { error: error.message });
      throw new SecurityError(
        SecurityErrorCode.SIGNING_FAILED,
        'Failed to sign with biometrics',
        { error: error.message }
      );
    }
  }

  /**
   * Get user-friendly biometric type name
   */
  async getBiometricTypeName(): Promise<string> {
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

  /**
   * Map platform biometry type to our enum
   */
  private mapBiometryType(type: BiometryTypes | undefined): BiometricType {
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
   * Check if device supports hardware biometrics
   */
  supportsHardwareBiometrics(): boolean {
    // iOS: Secure Enclave backed biometrics
    // Android: StrongBox or TEE backed biometrics
    return Platform.OS === 'ios' || Platform.OS === 'android';
  }

  /**
   * Get biometric enrollment status
   */
  async isEnrolled(): Promise<boolean> {
    const availability = await this.isAvailable();
    return availability.available && availability.hasCredentials;
  }
}

export default BiometricService;
