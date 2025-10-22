# ADR-008: Error Handling and Recovery Mechanisms

## Status
**ACCEPTED** - 2025-10-21

## Context

A production mobile wallet must handle errors gracefully to ensure:
- User funds are never at risk
- Users receive clear, actionable error messages
- The app recovers from errors automatically when possible
- Developers can diagnose issues quickly
- Critical errors are logged for analysis

### Requirements
1. **Safety**: Never lose user data or funds
2. **User Experience**: Clear, non-technical error messages
3. **Recovery**: Automatic recovery when possible
4. **Logging**: Comprehensive error tracking
5. **Monitoring**: Real-time error alerts for critical issues
6. **Offline Support**: Handle network failures gracefully

### Error Categories
1. **Network Errors**: Connectivity, timeout, server errors
2. **Validation Errors**: Invalid input, insufficient balance
3. **Authentication Errors**: Biometric failure, wrong PIN
4. **Blockchain Errors**: Transaction rejection, gas estimation failure
5. **Storage Errors**: Disk full, encryption failure
6. **System Errors**: Out of memory, permissions denied
7. **Programming Errors**: Unexpected exceptions, null references

## Decision

We will implement a **comprehensive error handling strategy** with custom error classes, error boundaries, retry mechanisms, and user-friendly error presentation.

## Architecture

### Error Handling Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Error Occurs                                 │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Categorize Error Type                              │
│  (Network, Validation, Auth, Blockchain, Storage, System)       │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Determine Recovery Strategy                        │
│  - Auto-retry (network, transient errors)                       │
│  - User action required (validation, auth)                      │
│  - Graceful degradation (features unavailable)                  │
│  - Fatal error (app restart required)                           │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Log Error                                          │
│  - Local logging (sensitive data redacted)                      │
│  - Remote logging (opt-in, critical errors only)                │
│  - Analytics (error patterns)                                   │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Present to User                                    │
│  - User-friendly message                                        │
│  - Suggested actions                                            │
│  - Recovery options                                             │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation

### 1. Custom Error Classes

```typescript
// src/core/errors/WalletError.ts

export class WalletError extends Error {
  public readonly code: string;
  public readonly category: ErrorCategory;
  public readonly severity: ErrorSeverity;
  public readonly recoverable: boolean;
  public readonly userMessage: string;
  public readonly technicalDetails?: any;
  public readonly timestamp: number;

  constructor(
    code: string,
    message: string,
    category: ErrorCategory,
    severity: ErrorSeverity,
    options?: ErrorOptions
  ) {
    super(message);
    this.name = 'WalletError';
    this.code = code;
    this.category = category;
    this.severity = severity;
    this.recoverable = options?.recoverable ?? false;
    this.userMessage = options?.userMessage || this.getDefaultUserMessage();
    this.technicalDetails = options?.technicalDetails;
    this.timestamp = Date.now();

    // Maintain proper stack trace
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, WalletError);
    }
  }

  private getDefaultUserMessage(): string {
    switch (this.category) {
      case ErrorCategory.NETWORK:
        return 'Network connection issue. Please check your internet connection.';
      case ErrorCategory.VALIDATION:
        return 'Invalid input. Please check and try again.';
      case ErrorCategory.AUTHENTICATION:
        return 'Authentication failed. Please try again.';
      case ErrorCategory.BLOCKCHAIN:
        return 'Blockchain operation failed. Please try again later.';
      case ErrorCategory.STORAGE:
        return 'Storage error occurred. Please ensure sufficient space available.';
      case ErrorCategory.SYSTEM:
        return 'System error occurred. Please restart the app.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  toJSON() {
    return {
      name: this.name,
      code: this.code,
      message: this.message,
      category: this.category,
      severity: this.severity,
      recoverable: this.recoverable,
      userMessage: this.userMessage,
      timestamp: this.timestamp,
      stack: this.stack,
    };
  }
}

export enum ErrorCategory {
  NETWORK = 'network',
  VALIDATION = 'validation',
  AUTHENTICATION = 'authentication',
  BLOCKCHAIN = 'blockchain',
  STORAGE = 'storage',
  SYSTEM = 'system',
  UNKNOWN = 'unknown',
}

export enum ErrorSeverity {
  LOW = 'low',       // Informational, no user action needed
  MEDIUM = 'medium', // User should be notified
  HIGH = 'high',     // Requires user action
  CRITICAL = 'critical', // App cannot continue
}

interface ErrorOptions {
  recoverable?: boolean;
  userMessage?: string;
  technicalDetails?: any;
}

// Specific error classes

export class NetworkError extends WalletError {
  constructor(message: string, options?: ErrorOptions) {
    super('NETWORK_ERROR', message, ErrorCategory.NETWORK, ErrorSeverity.MEDIUM, {
      recoverable: true,
      ...options,
    });
  }
}

export class ValidationError extends WalletError {
  constructor(message: string, field?: string, options?: ErrorOptions) {
    super('VALIDATION_ERROR', message, ErrorCategory.VALIDATION, ErrorSeverity.MEDIUM, {
      recoverable: true,
      technicalDetails: { field },
      ...options,
    });
  }
}

export class AuthenticationError extends WalletError {
  constructor(message: string, options?: ErrorOptions) {
    super('AUTH_ERROR', message, ErrorCategory.AUTHENTICATION, ErrorSeverity.HIGH, {
      recoverable: true,
      ...options,
    });
  }
}

export class BlockchainError extends WalletError {
  constructor(message: string, txHash?: string, options?: ErrorOptions) {
    super('BLOCKCHAIN_ERROR', message, ErrorCategory.BLOCKCHAIN, ErrorSeverity.HIGH, {
      recoverable: true,
      technicalDetails: { txHash },
      ...options,
    });
  }
}

export class InsufficientBalanceError extends WalletError {
  constructor(required: BigInt, available: BigInt) {
    super(
      'INSUFFICIENT_BALANCE',
      `Insufficient balance. Required: ${required}, Available: ${available}`,
      ErrorCategory.VALIDATION,
      ErrorSeverity.MEDIUM,
      {
        recoverable: true,
        userMessage: 'Insufficient balance for this transaction.',
        technicalDetails: { required, available },
      }
    );
  }
}

export class StorageError extends WalletError {
  constructor(message: string, options?: ErrorOptions) {
    super('STORAGE_ERROR', message, ErrorCategory.STORAGE, ErrorSeverity.HIGH, {
      recoverable: false,
      ...options,
    });
  }
}

export class CriticalError extends WalletError {
  constructor(message: string, options?: ErrorOptions) {
    super('CRITICAL_ERROR', message, ErrorCategory.SYSTEM, ErrorSeverity.CRITICAL, {
      recoverable: false,
      ...options,
    });
  }
}
```

### 2. Error Handler Service

```typescript
// src/services/ErrorHandler.ts

import { WalletError, ErrorSeverity } from '../core/errors/WalletError';
import { useUIStore } from '../stores/uiStore';
import { Logger } from './Logger';
import * as Sentry from '@sentry/react-native';

export class ErrorHandler {
  private static logger = new Logger('ErrorHandler');

  /**
   * Handle error globally
   */
  static handle(error: Error | WalletError, context?: string): void {
    // Convert to WalletError if needed
    const walletError = error instanceof WalletError
      ? error
      : this.toWalletError(error);

    // Log error
    this.logError(walletError, context);

    // Show user notification
    this.notifyUser(walletError);

    // Report to analytics/monitoring
    this.reportError(walletError, context);

    // Attempt recovery
    this.attemptRecovery(walletError);
  }

  /**
   * Convert generic Error to WalletError
   */
  private static toWalletError(error: Error): WalletError {
    // Try to categorize based on error message
    if (error.message.includes('network') || error.message.includes('fetch')) {
      return new WalletError(
        'UNKNOWN_NETWORK_ERROR',
        error.message,
        ErrorCategory.NETWORK,
        ErrorSeverity.MEDIUM,
        { recoverable: true }
      );
    }

    // Default to unknown system error
    return new WalletError(
      'UNKNOWN_ERROR',
      error.message,
      ErrorCategory.SYSTEM,
      ErrorSeverity.HIGH,
      { recoverable: false }
    );
  }

  /**
   * Log error details
   */
  private static logError(error: WalletError, context?: string): void {
    const logData = {
      code: error.code,
      message: error.message,
      category: error.category,
      severity: error.severity,
      context,
      timestamp: error.timestamp,
      stack: error.stack,
    };

    switch (error.severity) {
      case ErrorSeverity.LOW:
        this.logger.info('Error occurred', logData);
        break;
      case ErrorSeverity.MEDIUM:
        this.logger.warn('Error occurred', logData);
        break;
      case ErrorSeverity.HIGH:
      case ErrorSeverity.CRITICAL:
        this.logger.error('Error occurred', logData);
        break;
    }
  }

  /**
   * Show error to user
   */
  private static notifyUser(error: WalletError): void {
    const showToast = useUIStore.getState().showToast;

    const toastType = this.getToastType(error.severity);
    const duration = error.severity === ErrorSeverity.CRITICAL ? undefined : 5000;

    showToast({
      type: toastType,
      message: error.userMessage,
      duration,
    });
  }

  /**
   * Report error to monitoring service
   */
  private static reportError(error: WalletError, context?: string): void {
    // Only report medium, high, and critical errors
    if (error.severity === ErrorSeverity.LOW) {
      return;
    }

    // Check if user opted into analytics
    const analyticsEnabled = useSettingsStore.getState().analyticsEnabled;
    if (!analyticsEnabled) {
      return;
    }

    try {
      Sentry.captureException(error, {
        level: this.getSentryLevel(error.severity),
        contexts: {
          wallet: {
            code: error.code,
            category: error.category,
            context,
          },
        },
        tags: {
          error_category: error.category,
          error_severity: error.severity,
        },
      });
    } catch (reportError) {
      this.logger.error('Failed to report error', reportError);
    }
  }

  /**
   * Attempt automatic recovery
   */
  private static attemptRecovery(error: WalletError): void {
    if (!error.recoverable) {
      return;
    }

    switch (error.category) {
      case ErrorCategory.NETWORK:
        this.handleNetworkRecovery(error);
        break;
      case ErrorCategory.STORAGE:
        this.handleStorageRecovery(error);
        break;
      // Add more recovery strategies
    }
  }

  /**
   * Handle network error recovery
   */
  private static handleNetworkRecovery(error: WalletError): void {
    // Network errors are typically handled by retry mechanisms
    // in the network layer
    this.logger.info('Network error will be retried automatically');
  }

  /**
   * Handle storage error recovery
   */
  private static handleStorageRecovery(error: WalletError): void {
    // Try to clear cache and retry
    this.logger.info('Attempting storage recovery');
    // Implementation specific to storage error type
  }

  /**
   * Get toast type from error severity
   */
  private static getToastType(severity: ErrorSeverity): 'error' | 'warning' | 'info' {
    switch (severity) {
      case ErrorSeverity.CRITICAL:
      case ErrorSeverity.HIGH:
        return 'error';
      case ErrorSeverity.MEDIUM:
        return 'warning';
      case ErrorSeverity.LOW:
      default:
        return 'info';
    }
  }

  /**
   * Get Sentry log level from error severity
   */
  private static getSentryLevel(severity: ErrorSeverity): Sentry.SeverityLevel {
    switch (severity) {
      case ErrorSeverity.CRITICAL:
        return 'fatal';
      case ErrorSeverity.HIGH:
        return 'error';
      case ErrorSeverity.MEDIUM:
        return 'warning';
      case ErrorSeverity.LOW:
      default:
        return 'info';
    }
  }
}
```

### 3. Error Boundary Component

```typescript
// src/components/ErrorBoundary.tsx

import React, { Component, ReactNode } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { ErrorHandler } from '../services/ErrorHandler';
import { CriticalError } from '../core/errors/WalletError';

interface Props {
  children: ReactNode;
  fallback?: (error: Error, resetError: () => void) => ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    // Log error to error handler
    const criticalError = new CriticalError(error.message, {
      technicalDetails: {
        componentStack: errorInfo.componentStack,
      },
    });

    ErrorHandler.handle(criticalError, 'React Error Boundary');
  }

  resetError = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback(this.state.error!, this.resetError);
      }

      return (
        <View style={styles.container}>
          <Text style={styles.title}>Oops! Something went wrong</Text>
          <Text style={styles.message}>
            The app encountered an unexpected error. Please try restarting.
          </Text>
          <TouchableOpacity style={styles.button} onPress={this.resetError}>
            <Text style={styles.buttonText}>Try Again</Text>
          </TouchableOpacity>
        </View>
      );
    }

    return this.props.children;
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#fff',
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 12,
  },
  message: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
    marginBottom: 24,
  },
  button: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
});
```

### 4. Retry Mechanism

```typescript
// src/utils/retry.ts

import { NetworkError } from '../core/errors/WalletError';

export interface RetryOptions {
  maxAttempts?: number;
  initialDelay?: number;
  maxDelay?: number;
  backoffMultiplier?: number;
  shouldRetry?: (error: Error) => boolean;
}

export async function retry<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {}
): Promise<T> {
  const {
    maxAttempts = 3,
    initialDelay = 1000,
    maxDelay = 10000,
    backoffMultiplier = 2,
    shouldRetry = (error) => error instanceof NetworkError,
  } = options;

  let lastError: Error;
  let delay = initialDelay;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error: any) {
      lastError = error;

      // Don't retry if we've exhausted attempts
      if (attempt === maxAttempts) {
        break;
      }

      // Check if we should retry this error
      if (!shouldRetry(error)) {
        throw error;
      }

      // Wait before retrying
      await new Promise(resolve => setTimeout(resolve, delay));

      // Increase delay for next attempt
      delay = Math.min(delay * backoffMultiplier, maxDelay);
    }
  }

  throw lastError!;
}

// Usage example
export async function fetchWithRetry<T>(url: string): Promise<T> {
  return retry(
    async () => {
      const response = await fetch(url);
      if (!response.ok) {
        throw new NetworkError(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.json();
    },
    {
      maxAttempts: 3,
      initialDelay: 1000,
      shouldRetry: (error) => error instanceof NetworkError,
    }
  );
}
```

### 5. Logger Service

```typescript
// src/services/Logger.ts

export class Logger {
  private context: string;
  private static logLevel: LogLevel = __DEV__ ? LogLevel.DEBUG : LogLevel.INFO;

  constructor(context: string) {
    this.context = context;
  }

  debug(message: string, data?: any): void {
    if (Logger.logLevel <= LogLevel.DEBUG) {
      this.log('DEBUG', message, data);
    }
  }

  info(message: string, data?: any): void {
    if (Logger.logLevel <= LogLevel.INFO) {
      this.log('INFO', message, data);
    }
  }

  warn(message: string, data?: any): void {
    if (Logger.logLevel <= LogLevel.WARN) {
      this.log('WARN', message, data);
    }
  }

  error(message: string, data?: any): void {
    if (Logger.logLevel <= LogLevel.ERROR) {
      this.log('ERROR', message, data);
    }
  }

  private log(level: string, message: string, data?: any): void {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] [${level}] [${this.context}] ${message}`;

    // Sanitize data (remove sensitive information)
    const sanitizedData = this.sanitize(data);

    switch (level) {
      case 'DEBUG':
        console.debug(logMessage, sanitizedData);
        break;
      case 'INFO':
        console.log(logMessage, sanitizedData);
        break;
      case 'WARN':
        console.warn(logMessage, sanitizedData);
        break;
      case 'ERROR':
        console.error(logMessage, sanitizedData);
        break;
    }

    // Persist critical logs
    if (level === 'ERROR') {
      this.persistLog(level, message, sanitizedData);
    }
  }

  private sanitize(data: any): any {
    if (!data) return data;

    const sensitiveKeys = ['privateKey', 'mnemonic', 'password', 'pin', 'secret'];

    if (typeof data === 'object') {
      const sanitized = Array.isArray(data) ? [] : {};

      for (const key in data) {
        if (sensitiveKeys.some(k => key.toLowerCase().includes(k))) {
          sanitized[key] = '[REDACTED]';
        } else if (typeof data[key] === 'object') {
          sanitized[key] = this.sanitize(data[key]);
        } else {
          sanitized[key] = data[key];
        }
      }

      return sanitized;
    }

    return data;
  }

  private persistLog(level: string, message: string, data: any): void {
    // Implement log persistence (e.g., AsyncStorage, file system)
    // For production, consider sending to remote logging service
  }

  static setLogLevel(level: LogLevel): void {
    Logger.logLevel = level;
  }
}

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
}
```

## Error Recovery Strategies

### 1. **Network Errors**
- Automatic retry with exponential backoff
- Queue requests for when network returns
- Use cached data when available

### 2. **Validation Errors**
- Show field-specific error messages
- Highlight invalid fields
- Provide correction suggestions

### 3. **Authentication Errors**
- Allow retry with delay
- Provide PIN fallback for biometric failure
- Lock account after too many failed attempts

### 4. **Blockchain Errors**
- Retry with adjusted gas/fee
- Provide clear explanation
- Allow transaction cancellation

### 5. **Storage Errors**
- Clear cache and retry
- Prompt user to free up space
- Backup critical data before retry

## User-Facing Error Messages

### Good Error Messages
✅ "Network connection lost. Retrying automatically..."
✅ "Insufficient balance. You need 0.001 BTC more."
✅ "Transaction failed: Gas price too low. Try increasing the fee."

### Bad Error Messages
❌ "Error: ECONNREFUSED 127.0.0.1:8545"
❌ "Transaction reverted"
❌ "Null reference exception"

## Monitoring & Alerting

### Critical Errors to Monitor
- Wallet unlock failures
- Transaction signing failures
- Storage corruption
- Unexpected crashes

### Metrics to Track
- Error rate by category
- Time to recovery
- User-initiated retries
- App crash rate

## References

- [React Error Boundaries](https://react.dev/reference/react/Component#catching-rendering-errors-with-an-error-boundary)
- [Sentry Error Tracking](https://docs.sentry.io/platforms/react-native/)
- [OWASP Error Handling](https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html)

---

**Related ADRs:**
- [ADR-004: Network Layer](./adr-004-network-layer.md)
- [ADR-005: State Management](./adr-005-state-management.md)
- [ADR-007: Transaction Architecture](./adr-007-transaction-architecture.md)
