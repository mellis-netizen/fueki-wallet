/**
 * Token Bucket Rate Limiter
 * Implements token bucket algorithm for rate limiting RPC requests
 */

import { RateLimitConfig, RateLimitError } from './types';

export class RateLimiter {
  private tokens: number;
  private lastRefill: number;
  private readonly capacity: number;
  private readonly refillRate: number;

  constructor(private config: RateLimitConfig) {
    this.capacity = config.burstSize;
    this.tokens = this.capacity;
    this.refillRate = config.requestsPerSecond;
    this.lastRefill = Date.now();
  }

  /**
   * Attempt to acquire a token
   * @param tokensNeeded Number of tokens to acquire (default: 1)
   * @returns True if token acquired, false otherwise
   */
  public async acquire(tokensNeeded: number = 1): Promise<boolean> {
    this.refill();

    if (this.tokens >= tokensNeeded) {
      this.tokens -= tokensNeeded;
      return true;
    }

    return false;
  }

  /**
   * Wait until token is available
   * @param tokensNeeded Number of tokens to wait for
   * @param maxWaitMs Maximum wait time in milliseconds
   */
  public async waitForToken(
    tokensNeeded: number = 1,
    maxWaitMs: number = 5000
  ): Promise<void> {
    const startTime = Date.now();

    while (Date.now() - startTime < maxWaitMs) {
      if (await this.acquire(tokensNeeded)) {
        return;
      }

      // Calculate wait time until next token
      const tokensPerMs = this.refillRate / 1000;
      const waitMs = Math.min(
        (tokensNeeded - this.tokens) / tokensPerMs,
        100 // Max 100ms per iteration
      );

      await new Promise(resolve => setTimeout(resolve, waitMs));
    }

    throw new RateLimitError(
      `Rate limit exceeded: could not acquire ${tokensNeeded} token(s) within ${maxWaitMs}ms`
    );
  }

  /**
   * Refill tokens based on elapsed time
   */
  private refill(): void {
    const now = Date.now();
    const elapsedMs = now - this.lastRefill;
    const tokensToAdd = (elapsedMs / 1000) * this.refillRate;

    this.tokens = Math.min(this.capacity, this.tokens + tokensToAdd);
    this.lastRefill = now;
  }

  /**
   * Get current token count
   */
  public getAvailableTokens(): number {
    this.refill();
    return this.tokens;
  }

  /**
   * Reset rate limiter
   */
  public reset(): void {
    this.tokens = this.capacity;
    this.lastRefill = Date.now();
  }

  /**
   * Update configuration
   */
  public updateConfig(config: Partial<RateLimitConfig>): void {
    if (config.requestsPerSecond !== undefined) {
      this.refillRate = config.requestsPerSecond;
    }
    if (config.burstSize !== undefined) {
      this.capacity = config.burstSize;
      this.tokens = Math.min(this.tokens, this.capacity);
    }
  }
}
