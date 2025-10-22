/**
 * Security Services - Barrel Export
 *
 * Centralized export for all security services in the Fueki wallet
 */

// Core Security Configuration
export {
  SecurityConfig,
  SecurityError,
  SecurityErrorCode,
  SecurityEventType,
  SecurityValidator
} from './SecurityConfig';

// Security Logger
export { SecurityLogger, type LogLevel, type LogEntry } from './SecurityLogger';

// Secure Storage
export { SecureStorageService, type StorageKey } from './SecureStorageService';

// Encryption Service
export {
  EncryptionService,
  type EncryptedData
} from './EncryptionService';

// Key Management
export {
  KeyManagementService,
  ChainType,
  type WalletMetadata
} from './KeyManagementService';

// Biometric Authentication
export {
  BiometricService,
  type BiometricType,
  type BiometricAvailability,
  type BiometricAuthResult
} from './BiometricService';

// Authentication Service
export {
  AuthenticationService,
  type AuthMethod,
  type AuthResult
} from './AuthenticationService';

// Transaction Signing
export {
  SigningService,
  type UnsignedTransaction,
  type SignedTransaction,
  type SignedMessage
} from './SigningService';

/**
 * Initialize all security services
 */
export function initializeSecurityServices() {
  // Initialize singleton instances
  const logger = SecurityLogger.getInstance();
  const storage = SecureStorageService.getInstance();
  const encryption = EncryptionService;
  const keyManager = KeyManagementService.getInstance();
  const biometric = BiometricService.getInstance();
  const auth = AuthenticationService.getInstance();
  const signing = SigningService.getInstance();

  logger.info('Security services initialized');

  return {
    logger,
    storage,
    encryption,
    keyManager,
    biometric,
    auth,
    signing,
  };
}

/**
 * Health check for all security services
 */
export async function checkSecurityHealth(): Promise<{
  healthy: boolean;
  services: Record<string, { status: string; error?: string }>;
}> {
  const services: Record<string, { status: string; error?: string }> = {};

  try {
    // Check storage
    const storageHealth = await SecureStorageService.getInstance().checkHealth();
    services.storage = {
      status: storageHealth.healthy ? 'healthy' : 'unhealthy',
      error: storageHealth.issues.join(', ') || undefined,
    };

    // Check encryption
    const encryptionTest = await EncryptionService.testRoundTrip();
    services.encryption = {
      status: encryptionTest ? 'healthy' : 'unhealthy',
    };

    // Check biometric availability
    const biometricAvailability = await BiometricService.getInstance().isAvailable();
    services.biometric = {
      status: biometricAvailability.available ? 'available' : 'unavailable',
      error: biometricAvailability.error,
    };

    // Check key manager
    const hasWallet = await KeyManagementService.getInstance().hasWallet();
    services.keyManager = {
      status: hasWallet ? 'wallet-exists' : 'no-wallet',
    };

    // Overall health
    const healthy = Object.values(services).every(
      s => s.status === 'healthy' || s.status === 'available' || s.status === 'wallet-exists'
    );

    return {
      healthy,
      services,
    };
  } catch (error: any) {
    return {
      healthy: false,
      services: {
        error: {
          status: 'error',
          error: error.message,
        },
      },
    };
  }
}

/**
 * Security service version
 */
export const SECURITY_VERSION = '1.0.0';

export default {
  initializeSecurityServices,
  checkSecurityHealth,
  SECURITY_VERSION,
};
