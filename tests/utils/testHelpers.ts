/**
 * Test Helper Utilities
 * Common utilities for test scenarios
 */

/**
 * Wait for a condition to be true
 */
export async function waitFor(
  condition: () => boolean | Promise<boolean>,
  timeout: number = 5000,
  interval: number = 100
): Promise<void> {
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    if (await condition()) {
      return;
    }
    await sleep(interval);
  }

  throw new Error(`Timeout waiting for condition after ${timeout}ms`);
}

/**
 * Sleep for specified milliseconds
 */
export function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Create a deferred promise
 */
export function createDeferred<T>(): {
  promise: Promise<T>;
  resolve: (value: T) => void;
  reject: (error: any) => void;
} {
  let resolve!: (value: T) => void;
  let reject!: (error: any) => void;

  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });

  return { promise, resolve, reject };
}

/**
 * Measure execution time
 */
export async function measureTime<T>(
  fn: () => Promise<T>
): Promise<{ result: T; duration: number }> {
  const startTime = Date.now();
  const result = await fn();
  const duration = Date.now() - startTime;

  return { result, duration };
}

/**
 * Retry a function until it succeeds or max attempts reached
 */
export async function retry<T>(
  fn: () => Promise<T>,
  maxAttempts: number = 3,
  delay: number = 100
): Promise<T> {
  let lastError: Error;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;
      if (attempt < maxAttempts - 1) {
        await sleep(delay);
      }
    }
  }

  throw lastError!;
}

/**
 * Generate random hex string
 */
export function randomHex(length: number): string {
  const bytes = new Uint8Array(length / 2);
  crypto.getRandomValues(bytes);
  return '0x' + Array.from(bytes)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Generate random address
 */
export function randomAddress(): string {
  return randomHex(40);
}

/**
 * Generate random Bitcoin address
 */
export function randomBitcoinAddress(testnet: boolean = true): string {
  const prefix = testnet ? 'tb1q' : 'bc1q';
  const chars = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';
  let address = prefix;

  for (let i = 0; i < 38; i++) {
    address += chars[Math.floor(Math.random() * chars.length)];
  }

  return address;
}

/**
 * Mock fetch response builder
 */
export class MockFetchBuilder {
  private responses: Array<{ ok: boolean; json: () => Promise<any> }> = [];

  success(data: any): this {
    this.responses.push({
      ok: true,
      json: async () => data,
    });
    return this;
  }

  error(status: number, message: string): this {
    this.responses.push({
      ok: false,
      json: async () => ({ error: { code: status, message } }),
    } as any);
    return this;
  }

  rpcSuccess(result: any, id: number = 1): this {
    return this.success({ result, id });
  }

  rpcError(code: number, message: string, id: number = 1): this {
    return this.success({ error: { code, message }, id });
  }

  build(): jest.Mock {
    const mock = jest.fn();
    this.responses.forEach(response => {
      mock.mockResolvedValueOnce(response);
    });
    return mock;
  }

  buildWithLatency(latency: number): jest.Mock {
    const mock = jest.fn();
    this.responses.forEach(response => {
      mock.mockImplementationOnce(async () => {
        await sleep(latency);
        return response;
      });
    });
    return mock;
  }
}

/**
 * Assert that a function throws async
 */
export async function expectAsync(
  fn: () => Promise<any>
): Promise<jest.JestMatchers<any>> {
  try {
    await fn();
    throw new Error('Expected function to throw');
  } catch (error) {
    return expect(error);
  }
}

/**
 * Create a spy that tracks all calls
 */
export function createCallTracker<T extends (...args: any[]) => any>(): {
  fn: T;
  calls: Array<{ args: Parameters<T>; result: ReturnType<T> }>;
  callCount: number;
} {
  const calls: any[] = [];

  const fn = ((...args: any[]) => {
    const result = undefined;
    calls.push({ args, result });
    return result;
  }) as T;

  return {
    fn,
    calls,
    get callCount() {
      return calls.length;
    },
  };
}

/**
 * Create a mock timer controller
 */
export function createMockTimer() {
  let currentTime = 0;
  const timers: Array<{
    callback: () => void;
    time: number;
    interval?: boolean;
    id: number;
  }> = [];
  let nextId = 1;

  return {
    setTimeout(callback: () => void, ms: number): number {
      const id = nextId++;
      timers.push({ callback, time: currentTime + ms, id });
      return id;
    },

    setInterval(callback: () => void, ms: number): number {
      const id = nextId++;
      timers.push({ callback, time: currentTime + ms, interval: true, id });
      return id;
    },

    clearTimeout(id: number): void {
      const index = timers.findIndex(t => t.id === id);
      if (index !== -1) {
        timers.splice(index, 1);
      }
    },

    clearInterval(id: number): void {
      this.clearTimeout(id);
    },

    tick(ms: number): void {
      currentTime += ms;
      const readyTimers = timers.filter(t => t.time <= currentTime);

      readyTimers.forEach(timer => {
        timer.callback();

        if (timer.interval) {
          timer.time = currentTime + (timer.time - currentTime);
        } else {
          const index = timers.indexOf(timer);
          if (index !== -1) {
            timers.splice(index, 1);
          }
        }
      });
    },

    getCurrentTime(): number {
      return currentTime;
    },

    getPendingTimers(): number {
      return timers.length;
    },
  };
}

/**
 * Batch test helper for testing multiple scenarios
 */
export function testBatch(
  description: string,
  scenarios: Array<{
    name: string;
    input: any;
    expected: any;
  }>,
  testFn: (input: any) => any
): void {
  describe(description, () => {
    scenarios.forEach(scenario => {
      it(scenario.name, async () => {
        const result = await testFn(scenario.input);
        expect(result).toEqual(scenario.expected);
      });
    });
  });
}
