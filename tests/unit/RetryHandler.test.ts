/**
 * Unit Tests for RetryHandler
 * Tests exponential backoff and retry logic
 */

import { RetryHandler, RetryConfig } from '../../src/networking/rpc/common/RetryHandler';
import { RPCClientError, TimeoutError, ConnectionError } from '../../src/networking/rpc/common/types';

describe('RetryHandler', () => {
  const defaultConfig: RetryConfig = {
    maxRetries: 3,
    initialDelay: 100,
    maxDelay: 5000,
    backoffMultiplier: 2,
    retryableErrors: [-32000, -32001, -32603, 429, 502, 503, 504],
  };

  describe('Successful Execution', () => {
    it('should execute function without retries on success', async () => {
      const handler = new RetryHandler(defaultConfig);
      let callCount = 0;

      const result = await handler.execute(async () => {
        callCount++;
        return 'success';
      });

      expect(result).toBe('success');
      expect(callCount).toBe(1);
    });

    it('should return result immediately on first success', async () => {
      const handler = new RetryHandler(defaultConfig);

      const startTime = Date.now();
      await handler.execute(async () => 'fast');
      const elapsed = Date.now() - startTime;

      expect(elapsed).toBeLessThan(50);
    });
  });

  describe('Retry Logic', () => {
    it('should retry on retryable errors', async () => {
      const handler = new RetryHandler(defaultConfig);
      let attemptCount = 0;

      const result = await handler.execute(async () => {
        attemptCount++;
        if (attemptCount < 3) {
          throw new ConnectionError('Connection failed');
        }
        return 'success';
      });

      expect(result).toBe('success');
      expect(attemptCount).toBe(3);
    });

    it('should not retry on non-retryable errors', async () => {
      const handler = new RetryHandler(defaultConfig);
      let attemptCount = 0;

      await expect(handler.execute(async () => {
        attemptCount++;
        throw new RPCClientError('Invalid params', -32602);
      })).rejects.toThrow('Invalid params');

      expect(attemptCount).toBe(1);
    });

    it('should respect maxRetries limit', async () => {
      const handler = new RetryHandler({
        ...defaultConfig,
        maxRetries: 2,
        initialDelay: 10,
      });
      let attemptCount = 0;

      await expect(handler.execute(async () => {
        attemptCount++;
        throw new ConnectionError('Always fails');
      })).rejects.toThrow(/Operation failed after 2 retries/);

      expect(attemptCount).toBe(3); // Initial + 2 retries
    });

    it('should include context in error message', async () => {
      const handler = new RetryHandler({
        ...defaultConfig,
        maxRetries: 1,
        initialDelay: 10,
      });

      await expect(handler.execute(
        async () => {
          throw new TimeoutError('Request timeout');
        },
        'getBalance'
      )).rejects.toThrow(/getBalance/);
    });
  });

  describe('Exponential Backoff', () => {
    it('should implement exponential backoff', async () => {
      const handler = new RetryHandler({
        ...defaultConfig,
        initialDelay: 50,
        maxRetries: 3,
        backoffMultiplier: 2,
      });

      const delays: number[] = [];
      let attemptCount = 0;
      const startTime = Date.now();

      try {
        await handler.execute(async () => {
          if (attemptCount > 0) {
            delays.push(Date.now() - startTime);
          }
          attemptCount++;
          throw new ConnectionError('Fail');
        });
      } catch (error) {
        // Expected to fail
      }

      // Verify exponential increase in delays
      // Attempt 1: ~50ms, Attempt 2: ~100ms, Attempt 3: ~200ms
      expect(delays[0]).toBeGreaterThanOrEqual(40);
      expect(delays[1]).toBeGreaterThanOrEqual(140);
      expect(delays[2]).toBeGreaterThanOrEqual(340);
    });

    it('should cap delay at maxDelay', async () => {
      const handler = new RetryHandler({
        ...defaultConfig,
        initialDelay: 1000,
        maxDelay: 2000,
        maxRetries: 5,
        backoffMultiplier: 10,
      });

      let attemptCount = 0;
      const delays: number[] = [];
      let lastTime = Date.now();

      try {
        await handler.execute(async () => {
          if (attemptCount > 0) {
            const now = Date.now();
            delays.push(now - lastTime);
            lastTime = now;
          }
          attemptCount++;
          throw new ConnectionError('Fail');
        });
      } catch (error) {
        // Expected to fail
      }

      // Later delays should be capped at maxDelay
      const lastDelay = delays[delays.length - 1];
      expect(lastDelay).toBeLessThanOrEqual(2500); // Allow some margin
    });
  });

  describe('Error Detection', () => {
    it('should detect network timeout errors', async () => {
      const handler = new RetryHandler(defaultConfig);
      let attemptCount = 0;

      await expect(handler.execute(async () => {
        attemptCount++;
        const error: any = new Error('Request timeout');
        error.name = 'TimeoutError';
        throw error;
      })).rejects.toThrow();

      expect(attemptCount).toBeGreaterThan(1);
    });

    it('should detect ETIMEDOUT errors', async () => {
      const handler = new RetryHandler(defaultConfig);
      let attemptCount = 0;

      await expect(handler.execute(async () => {
        attemptCount++;
        throw new Error('ETIMEDOUT');
      })).rejects.toThrow();

      expect(attemptCount).toBeGreaterThan(1);
    });

    it('should detect ECONNREFUSED errors', async () => {
      const handler = new RetryHandler(defaultConfig);
      let attemptCount = 0;

      await expect(handler.execute(async () => {
        attemptCount++;
        throw new Error('ECONNREFUSED');
      })).rejects.toThrow();

      expect(attemptCount).toBeGreaterThan(1);
    });

    it('should detect HTTP status code errors', async () => {
      const handler = new RetryHandler(defaultConfig);
      let attemptCount = 0;

      await expect(handler.execute(async () => {
        attemptCount++;
        const error: any = new Error('Service unavailable');
        error.status = 503;
        throw error;
      })).rejects.toThrow();

      expect(attemptCount).toBeGreaterThan(1);
    });

    it('should detect RPCClientError with retryable codes', async () => {
      const handler = new RetryHandler(defaultConfig);
      let attemptCount = 0;

      await expect(handler.execute(async () => {
        attemptCount++;
        throw new RPCClientError('Internal error', -32603);
      })).rejects.toThrow();

      expect(attemptCount).toBeGreaterThan(1);
    });
  });

  describe('Static Methods', () => {
    it('should create default configuration', () => {
      const config = RetryHandler.createDefault();

      expect(config).toHaveProperty('maxRetries');
      expect(config).toHaveProperty('initialDelay');
      expect(config).toHaveProperty('maxDelay');
      expect(config).toHaveProperty('backoffMultiplier');
      expect(config).toHaveProperty('retryableErrors');
      expect(config.maxRetries).toBeGreaterThan(0);
    });

    it('should calculate jittered delay', () => {
      const baseDelay = 1000;
      const jittered = RetryHandler.calculateJitteredDelay(baseDelay, 0.3);

      expect(jittered).toBeGreaterThanOrEqual(baseDelay);
      expect(jittered).toBeLessThanOrEqual(baseDelay * 1.3);
    });

    it('should apply different jitter amounts', () => {
      const delays = Array(100).fill(null).map(() =>
        RetryHandler.calculateJitteredDelay(1000, 0.5)
      );

      // All delays should be within range
      delays.forEach(delay => {
        expect(delay).toBeGreaterThanOrEqual(1000);
        expect(delay).toBeLessThanOrEqual(1500);
      });

      // Should have variance (not all the same)
      const unique = new Set(delays);
      expect(unique.size).toBeGreaterThan(50);
    });
  });

  describe('Edge Cases', () => {
    it('should handle zero retries configuration', async () => {
      const handler = new RetryHandler({
        ...defaultConfig,
        maxRetries: 0,
      });

      let attemptCount = 0;

      await expect(handler.execute(async () => {
        attemptCount++;
        throw new ConnectionError('Fail');
      })).rejects.toThrow();

      expect(attemptCount).toBe(1);
    });

    it('should handle synchronous throw', async () => {
      const handler = new RetryHandler(defaultConfig);

      await expect(handler.execute(() => {
        throw new Error('Sync error');
      })).rejects.toThrow('Sync error');
    });

    it('should preserve original error data', async () => {
      const handler = new RetryHandler({
        ...defaultConfig,
        maxRetries: 1,
        initialDelay: 10,
      });

      const originalError = new RPCClientError('Test error', -32000, { foo: 'bar' });

      try {
        await handler.execute(async () => {
          throw originalError;
        });
      } catch (error: any) {
        expect(error.data).toHaveProperty('originalError');
        expect(error.data.originalError.data).toEqual({ foo: 'bar' });
      }
    });

    it('should handle undefined error messages', async () => {
      const handler = new RetryHandler({
        ...defaultConfig,
        maxRetries: 1,
        initialDelay: 10,
      });

      await expect(handler.execute(async () => {
        throw {};
      })).rejects.toThrow(/Operation failed after 1 retries/);
    });
  });

  describe('Performance', () => {
    it('should not add unnecessary delay on first attempt', async () => {
      const handler = new RetryHandler(defaultConfig);

      const startTime = Date.now();
      await handler.execute(async () => 'fast');
      const elapsed = Date.now() - startTime;

      expect(elapsed).toBeLessThan(50);
    });

    it('should handle rapid sequential executions', async () => {
      const handler = new RetryHandler(defaultConfig);

      const results = await Promise.all(
        Array(100).fill(null).map((_, i) =>
          handler.execute(async () => i)
        )
      );

      expect(results).toHaveLength(100);
      expect(results[0]).toBe(0);
      expect(results[99]).toBe(99);
    });

    it('should handle concurrent retry operations', async () => {
      const handler = new RetryHandler({
        ...defaultConfig,
        maxRetries: 2,
        initialDelay: 50,
      });

      let counts = [0, 0, 0];

      const promises = counts.map((_, i) =>
        handler.execute(async () => {
          counts[i]++;
          if (counts[i] < 2) {
            throw new ConnectionError('Retry me');
          }
          return `success-${i}`;
        })
      );

      const results = await Promise.all(promises);
      expect(results).toEqual(['success-0', 'success-1', 'success-2']);
      expect(counts).toEqual([2, 2, 2]);
    });
  });

  describe('Integration with RPCClientError', () => {
    it('should handle RPCClientError hierarchy', async () => {
      const handler = new RetryHandler(defaultConfig);

      const errors = [
        new ConnectionError('Connection failed'),
        new TimeoutError('Timeout'),
        new RPCClientError('Generic RPC error', -32603),
      ];

      for (const error of errors) {
        let attemptCount = 0;
        try {
          await handler.execute(async () => {
            attemptCount++;
            if (attemptCount < 2) throw error;
            return 'success';
          });
        } catch (e) {
          // May fail, that's ok
        }
        expect(attemptCount).toBeGreaterThan(1);
      }
    });

    it('should wrap final error in RPCClientError', async () => {
      const handler = new RetryHandler({
        ...defaultConfig,
        maxRetries: 1,
        initialDelay: 10,
      });

      try {
        await handler.execute(async () => {
          throw new ConnectionError('Original error');
        });
        fail('Should have thrown');
      } catch (error) {
        expect(error).toBeInstanceOf(RPCClientError);
        expect((error as RPCClientError).code).toBe(-32004);
        expect((error as RPCClientError).data).toHaveProperty('originalError');
      }
    });
  });
});
