/**
 * Retry Handler with Exponential Backoff
 * Handles retry logic for failed RPC requests
 */

import { RPCClientError, TimeoutError } from './types';

export interface RetryConfig {
  maxRetries: number;
  initialDelay: number;
  maxDelay: number;
  backoffMultiplier: number;
  retryableErrors: number[];
}

export class RetryHandler {
  private static readonly DEFAULT_RETRYABLE_ERRORS = [
    -32000, // Connection error
    -32001, // Timeout
    -32603, // Internal error
    429,    // Rate limit
    502,    // Bad gateway
    503,    // Service unavailable
    504,    // Gateway timeout
  ];

  constructor(private config: RetryConfig) {}

  /**
   * Execute function with retry logic
   */
  public async execute<T>(
    fn: () => Promise<T>,
    context?: string
  ): Promise<T> {
    let lastError: Error | undefined;
    let delay = this.config.initialDelay;

    for (let attempt = 0; attempt <= this.config.maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          console.log(
            `Retry attempt ${attempt}/${this.config.maxRetries} for ${context || 'operation'}`
          );
          await this.sleep(delay);
          delay = Math.min(
            delay * this.config.backoffMultiplier,
            this.config.maxDelay
          );
        }

        return await fn();
      } catch (error) {
        lastError = error as Error;

        // Check if error is retryable
        if (!this.isRetryable(error)) {
          throw error;
        }

        // Don't retry if max attempts reached
        if (attempt === this.config.maxRetries) {
          break;
        }
      }
    }

    throw new RPCClientError(
      `Operation failed after ${this.config.maxRetries} retries: ${lastError?.message}`,
      -32004,
      { originalError: lastError, context }
    );
  }

  /**
   * Check if error is retryable
   */
  private isRetryable(error: any): boolean {
    // Check if it's an RPCClientError with retryable code
    if (error instanceof RPCClientError) {
      return this.config.retryableErrors.includes(error.code);
    }

    // Check for network errors
    if (
      error.name === 'AbortError' ||
      error.name === 'TimeoutError' ||
      error.message?.includes('timeout') ||
      error.message?.includes('ETIMEDOUT') ||
      error.message?.includes('ECONNREFUSED') ||
      error.message?.includes('ENOTFOUND')
    ) {
      return true;
    }

    // Check for HTTP status codes
    if (error.status && this.config.retryableErrors.includes(error.status)) {
      return true;
    }

    return false;
  }

  /**
   * Sleep for specified milliseconds
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Calculate jittered delay to prevent thundering herd
   */
  public static calculateJitteredDelay(
    baseDelay: number,
    maxJitter: number = 0.3
  ): number {
    const jitter = Math.random() * maxJitter * baseDelay;
    return baseDelay + jitter;
  }

  /**
   * Create default retry config
   */
  public static createDefault(): RetryConfig {
    return {
      maxRetries: 3,
      initialDelay: 1000,
      maxDelay: 10000,
      backoffMultiplier: 2,
      retryableErrors: RetryHandler.DEFAULT_RETRYABLE_ERRORS,
    };
  }
}
