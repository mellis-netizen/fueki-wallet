/**
 * Unit Tests for RateLimiter
 * Tests token bucket algorithm implementation
 */

import { RateLimiter } from '../../src/networking/rpc/common/RateLimiter';
import { RateLimitError } from '../../src/networking/rpc/common/types';

describe('RateLimiter', () => {
  describe('Token Bucket Algorithm', () => {
    it('should allow requests within rate limit', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 10,
        burstSize: 10,
      });

      const result = await limiter.acquire();
      expect(result).toBe(true);
    });

    it('should reject requests exceeding burst size', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 5,
        burstSize: 3,
      });

      // Acquire all tokens
      await limiter.acquire();
      await limiter.acquire();
      await limiter.acquire();

      // Should fail on 4th request
      const result = await limiter.acquire();
      expect(result).toBe(false);
    });

    it('should refill tokens over time', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 10, // 10 tokens per second = 1 token per 100ms
        burstSize: 5,
      });

      // Exhaust tokens
      for (let i = 0; i < 5; i++) {
        await limiter.acquire();
      }

      // No tokens available
      expect(await limiter.acquire()).toBe(false);

      // Wait for refill (200ms = ~2 tokens)
      await new Promise(resolve => setTimeout(resolve, 200));

      // Should have tokens now
      expect(await limiter.acquire()).toBe(true);
    });

    it('should handle multiple token acquisition', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 10,
        burstSize: 10,
      });

      const result = await limiter.acquire(5);
      expect(result).toBe(true);
      expect(limiter.getAvailableTokens()).toBeCloseTo(5, 0);
    });

    it('should not exceed capacity when refilling', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 100,
        burstSize: 10,
      });

      // Wait to ensure full refill
      await new Promise(resolve => setTimeout(resolve, 500));

      const tokens = limiter.getAvailableTokens();
      expect(tokens).toBeLessThanOrEqual(10);
    });
  });

  describe('waitForToken', () => {
    it('should wait for token availability', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 5,
        burstSize: 1,
      });

      // Exhaust token
      await limiter.acquire();

      const startTime = Date.now();
      await limiter.waitForToken(1, 500);
      const elapsed = Date.now() - startTime;

      // Should have waited for refill
      expect(elapsed).toBeGreaterThan(50);
      expect(elapsed).toBeLessThan(500);
    });

    it('should throw RateLimitError on timeout', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 1, // Very slow refill
        burstSize: 1,
      });

      // Exhaust token
      await limiter.acquire();

      await expect(limiter.waitForToken(1, 100)).rejects.toThrow(RateLimitError);
    });

    it('should return immediately if token available', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 10,
        burstSize: 10,
      });

      const startTime = Date.now();
      await limiter.waitForToken();
      const elapsed = Date.now() - startTime;

      expect(elapsed).toBeLessThan(10);
    });
  });

  describe('Configuration Management', () => {
    it('should update configuration', () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 10,
        burstSize: 5,
      });

      limiter.updateConfig({
        requestsPerSecond: 20,
        burstSize: 10,
      });

      // Configuration should be updated
      const tokens = limiter.getAvailableTokens();
      expect(tokens).toBeLessThanOrEqual(10);
    });

    it('should reset rate limiter', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 10,
        burstSize: 5,
      });

      // Exhaust some tokens
      await limiter.acquire(3);
      expect(limiter.getAvailableTokens()).toBeCloseTo(2, 0);

      // Reset
      limiter.reset();
      expect(limiter.getAvailableTokens()).toBeCloseTo(5, 0);
    });

    it('should cap tokens at new capacity when reducing burst size', () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 10,
        burstSize: 10,
      });

      limiter.updateConfig({ burstSize: 5 });

      const tokens = limiter.getAvailableTokens();
      expect(tokens).toBeLessThanOrEqual(5);
    });
  });

  describe('Edge Cases', () => {
    it('should handle zero tokens request', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 10,
        burstSize: 10,
      });

      const result = await limiter.acquire(0);
      expect(result).toBe(true);
    });

    it('should handle fractional tokens from refill', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 7.5, // Fractional rate
        burstSize: 10,
      });

      await new Promise(resolve => setTimeout(resolve, 100));

      // Should calculate fractional tokens correctly
      expect(limiter.getAvailableTokens()).toBeGreaterThan(0);
    });

    it('should handle rapid sequential requests', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 100,
        burstSize: 50,
      });

      const results = await Promise.all(
        Array(30).fill(null).map(() => limiter.acquire())
      );

      const successCount = results.filter(r => r).length;
      expect(successCount).toBeGreaterThanOrEqual(30);
    });

    it('should handle concurrent acquisitions', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 10,
        burstSize: 5,
      });

      const results = await Promise.all([
        limiter.acquire(2),
        limiter.acquire(2),
        limiter.acquire(2),
      ]);

      const successCount = results.filter(r => r).length;
      expect(successCount).toBeLessThanOrEqual(2); // Only 5 tokens available
    });
  });

  describe('Performance', () => {
    it('should handle high-frequency requests efficiently', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 1000,
        burstSize: 1000,
      });

      const startTime = Date.now();
      const promises = Array(500).fill(null).map(() => limiter.acquire());
      await Promise.all(promises);
      const elapsed = Date.now() - startTime;

      // Should complete quickly
      expect(elapsed).toBeLessThan(100);
    });

    it('should maintain accuracy under load', async () => {
      const limiter = new RateLimiter({
        requestsPerSecond: 10,
        burstSize: 10,
      });

      let successCount = 0;
      for (let i = 0; i < 15; i++) {
        if (await limiter.acquire()) {
          successCount++;
        }
      }

      // Should allow exactly burst size
      expect(successCount).toBe(10);
    });
  });
});
