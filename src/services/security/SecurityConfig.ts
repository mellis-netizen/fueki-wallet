/**
 * Security Configuration
 *
 * Centralized security policies and configurations for the Fueki wallet
 */

export const SecurityConfig = {
  // Key Management
  keyManagement: {
    // Master Encryption Key (MEK) configuration
    mek: {
      algorithm: 'AES-256-GCM',
      keySize: 256,
      ivSize: 12,
      tagSize: 16,
    },
    // HD Wallet derivation paths
    derivationPaths: {
      bitcoin: "m/84'/0'/0'",
      bitcoinTestnet: "m/84'/1'/0'",
      ethereum: "m/44'/60'/0'",
      ethereumTestnet: "m/44'/60'/0'",
    },
    // Mnemonic configuration
    mnemonic: {
      strength: 256, // 24 words
      language: 'english',
    },
  },

  // Authentication settings
  authentication: {
    biometric: {
      promptMessage: 'Authenticate to access your wallet',
      cancelButtonText: 'Cancel',
      allowDeviceCredentials: true,
      fallbackEnabled: true,
    },
    pin: {
      length: 6,
      minLength: 4,
      maxLength: 8,
      maxAttempts: 5,
      lockoutDuration: 300000, // 5 minutes in ms
      hashIterations: 100000,
      hashKeySize: 64,
      hashAlgorithm: 'sha512',
    },
    session: {
      defaultTimeout: 300, // 5 minutes in seconds
      maxTimeout: 3600, // 1 hour
      minTimeout: 60, // 1 minute
      autoLockOnBackground: true,
    },
  },

  // Secure Storage settings
  storage: {
    keychain: {
      service: 'com.fueki.wallet',
      accessLevel: 'WHEN_UNLOCKED_THIS_DEVICE_ONLY',
      securityLevel: 'SECURE_HARDWARE',
    },
    keys: {
      encryptedMnemonic: 'encrypted_mnemonic',
      encryptedPassphrase: 'encrypted_passphrase',
      pinHash: 'pin_hash',
      pinSalt: 'pin_salt',
      biometricPublicKey: 'biometric_public_key',
    },
  },

  // Transaction signing security
  signing: {
    requireBiometric: true,
    requireConfirmation: true,
    timeoutDuration: 60000, // 1 minute
    maxGasPrice: '500', // gwei
    maxTransactionAmount: '10', // ETH or BTC equivalent
  },

  // Network security
  network: {
    tlsVersion: '1.3',
    certificatePinning: {
      enabled: true,
      publicKeyHashes: [
        // Add your API certificate hashes here
      ],
    },
    timeout: 30000, // 30 seconds
    retryAttempts: 3,
  },

  // Memory protection
  memory: {
    clearSensitiveDataImmediately: true,
    disableScreenshots: true,
    disableClipboard: false,
    clipboardClearTimeout: 30000, // 30 seconds
  },

  // Security logging
  logging: {
    enabled: true,
    logLevel: 'warn', // 'debug' | 'info' | 'warn' | 'error'
    excludeSensitiveData: true,
    sensitiveFields: [
      'privateKey',
      'mnemonic',
      'seed',
      'pin',
      'password',
      'signature',
      'secret',
    ],
  },

  // Anti-tampering
  antiTampering: {
    jailbreakDetection: true,
    rootDetection: true,
    debuggerDetection: false, // Enable in production
    integrityCheck: true,
  },

  // Rate limiting
  rateLimiting: {
    maxTransactionsPerMinute: 10,
    maxSigningAttempts: 5,
    maxAPICallsPerMinute: 60,
  },

  // Encryption algorithms
  encryption: {
    symmetric: {
      algorithm: 'aes-256-gcm',
      keySize: 256,
      ivSize: 12,
      tagSize: 16,
    },
    asymmetric: {
      algorithm: 'RSA-OAEP',
      keySize: 2048,
      hash: 'SHA-256',
    },
    hashing: {
      algorithm: 'SHA-256',
      iterations: 100000,
    },
  },

  // Key rotation policy
  keyRotation: {
    mekRotationDays: 90,
    sessionKeyRotationDays: 7,
    warnBeforeDays: 7,
  },

  // Backup and recovery
  backup: {
    requireEncryption: true,
    allowCloudBackup: false, // User preference
    minBackupInterval: 86400000, // 24 hours
  },

  // Compliance
  compliance: {
    gdpr: {
      dataRetentionDays: 365,
      allowDataExport: true,
      rightToBeForgotten: true,
    },
    logging: {
      auditTrailEnabled: true,
      retentionDays: 90,
    },
  },

  // Development settings (override in production)
  development: {
    bypassBiometric: false,
    bypassPIN: false,
    mockSecureEnclave: false,
    verboseLogging: false,
  },
} as const;

/**
 * Security error codes
 */
export enum SecurityErrorCode {
  // Authentication errors
  AUTH_FAILED = 'AUTH_FAILED',
  AUTH_CANCELLED = 'AUTH_CANCELLED',
  AUTH_TIMEOUT = 'AUTH_TIMEOUT',
  BIOMETRIC_NOT_AVAILABLE = 'BIOMETRIC_NOT_AVAILABLE',
  BIOMETRIC_LOCKOUT = 'BIOMETRIC_LOCKOUT',
  PIN_INVALID = 'PIN_INVALID',
  PIN_LOCKOUT = 'PIN_LOCKOUT',

  // Key management errors
  KEY_GENERATION_FAILED = 'KEY_GENERATION_FAILED',
  KEY_NOT_FOUND = 'KEY_NOT_FOUND',
  KEY_DERIVATION_FAILED = 'KEY_DERIVATION_FAILED',
  MNEMONIC_INVALID = 'MNEMONIC_INVALID',

  // Encryption errors
  ENCRYPTION_FAILED = 'ENCRYPTION_FAILED',
  DECRYPTION_FAILED = 'DECRYPTION_FAILED',

  // Storage errors
  STORAGE_FAILED = 'STORAGE_FAILED',
  STORAGE_NOT_FOUND = 'STORAGE_NOT_FOUND',

  // Transaction errors
  SIGNING_FAILED = 'SIGNING_FAILED',
  TRANSACTION_TIMEOUT = 'TRANSACTION_TIMEOUT',
  INVALID_TRANSACTION = 'INVALID_TRANSACTION',

  // Security violations
  TAMPERING_DETECTED = 'TAMPERING_DETECTED',
  JAILBREAK_DETECTED = 'JAILBREAK_DETECTED',
  DEBUGGER_DETECTED = 'DEBUGGER_DETECTED',

  // General errors
  UNKNOWN_ERROR = 'UNKNOWN_ERROR',
  NOT_INITIALIZED = 'NOT_INITIALIZED',
}

/**
 * Security error class with context
 */
export class SecurityError extends Error {
  constructor(
    public code: SecurityErrorCode,
    message: string,
    public context?: Record<string, any>
  ) {
    super(message);
    this.name = 'SecurityError';

    // Sanitize context to remove sensitive data
    if (context) {
      this.context = this.sanitizeContext(context);
    }
  }

  private sanitizeContext(context: Record<string, any>): Record<string, any> {
    const sanitized: Record<string, any> = {};
    const sensitiveFields = SecurityConfig.logging.sensitiveFields;

    for (const [key, value] of Object.entries(context)) {
      if (sensitiveFields.some(field => key.toLowerCase().includes(field))) {
        sanitized[key] = '[REDACTED]';
      } else {
        sanitized[key] = value;
      }
    }

    return sanitized;
  }

  toJSON() {
    return {
      name: this.name,
      code: this.code,
      message: this.message,
      context: this.context,
    };
  }
}

/**
 * Security event types for logging
 */
export enum SecurityEventType {
  // Authentication events
  AUTH_SUCCESS = 'AUTH_SUCCESS',
  AUTH_FAILURE = 'AUTH_FAILURE',
  BIOMETRIC_AUTH = 'BIOMETRIC_AUTH',
  PIN_AUTH = 'PIN_AUTH',
  SESSION_START = 'SESSION_START',
  SESSION_END = 'SESSION_END',
  SESSION_TIMEOUT = 'SESSION_TIMEOUT',

  // Key management events
  WALLET_CREATED = 'WALLET_CREATED',
  WALLET_IMPORTED = 'WALLET_IMPORTED',
  WALLET_LOCKED = 'WALLET_LOCKED',
  WALLET_UNLOCKED = 'WALLET_UNLOCKED',
  KEY_DERIVED = 'KEY_DERIVED',

  // Transaction events
  TRANSACTION_SIGNED = 'TRANSACTION_SIGNED',
  TRANSACTION_CANCELLED = 'TRANSACTION_CANCELLED',

  // Security events
  TAMPERING_ATTEMPT = 'TAMPERING_ATTEMPT',
  SUSPICIOUS_ACTIVITY = 'SUSPICIOUS_ACTIVITY',
  SECURITY_ALERT = 'SECURITY_ALERT',

  // System events
  APP_BACKGROUND = 'APP_BACKGROUND',
  APP_FOREGROUND = 'APP_FOREGROUND',
}

/**
 * Validation utilities
 */
export class SecurityValidator {
  /**
   * Validate PIN format
   */
  static validatePIN(pin: string): { valid: boolean; error?: string } {
    const config = SecurityConfig.authentication.pin;

    if (!pin) {
      return { valid: false, error: 'PIN is required' };
    }

    if (pin.length < config.minLength) {
      return { valid: false, error: `PIN must be at least ${config.minLength} digits` };
    }

    if (pin.length > config.maxLength) {
      return { valid: false, error: `PIN must be at most ${config.maxLength} digits` };
    }

    if (!/^\d+$/.test(pin)) {
      return { valid: false, error: 'PIN must contain only digits' };
    }

    return { valid: true };
  }

  /**
   * Validate mnemonic phrase
   */
  static validateMnemonic(mnemonic: string): { valid: boolean; error?: string } {
    if (!mnemonic) {
      return { valid: false, error: 'Mnemonic is required' };
    }

    const words = mnemonic.trim().split(/\s+/);

    if (![12, 15, 18, 21, 24].includes(words.length)) {
      return { valid: false, error: 'Invalid mnemonic length' };
    }

    return { valid: true };
  }

  /**
   * Validate transaction amount
   */
  static validateTransactionAmount(amount: string): { valid: boolean; error?: string } {
    if (!amount) {
      return { valid: false, error: 'Amount is required' };
    }

    const numAmount = parseFloat(amount);

    if (isNaN(numAmount) || numAmount <= 0) {
      return { valid: false, error: 'Invalid amount' };
    }

    const maxAmount = parseFloat(SecurityConfig.signing.maxTransactionAmount);
    if (numAmount > maxAmount) {
      return { valid: false, error: `Amount exceeds maximum (${maxAmount})` };
    }

    return { valid: true };
  }

  /**
   * Validate Ethereum address
   */
  static validateEthereumAddress(address: string): { valid: boolean; error?: string } {
    if (!address) {
      return { valid: false, error: 'Address is required' };
    }

    if (!/^0x[a-fA-F0-9]{40}$/.test(address)) {
      return { valid: false, error: 'Invalid Ethereum address format' };
    }

    return { valid: true };
  }

  /**
   * Validate Bitcoin address
   */
  static validateBitcoinAddress(address: string): { valid: boolean; error?: string } {
    if (!address) {
      return { valid: false, error: 'Address is required' };
    }

    // Basic validation (can be enhanced with proper library)
    if (address.length < 26 || address.length > 62) {
      return { valid: false, error: 'Invalid Bitcoin address length' };
    }

    return { valid: true };
  }
}

export default SecurityConfig;
