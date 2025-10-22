/**
 * Jest Test Setup
 * Global configuration and utilities for all tests
 */

// Extend Jest matchers
expect.extend({
  toBeWithinRange(received: number, floor: number, ceiling: number) {
    const pass = received >= floor && received <= ceiling;
    if (pass) {
      return {
        message: () => `expected ${received} not to be within range ${floor} - ${ceiling}`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received} to be within range ${floor} - ${ceiling}`,
        pass: false,
      };
    }
  },
});

// Global test timeout
jest.setTimeout(30000);

// Mock console methods to reduce noise in tests
global.console = {
  ...console,
  log: jest.fn(),
  debug: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
};

// Setup global fetch mock
global.fetch = jest.fn();

// Setup AbortController if not available
if (typeof AbortController === 'undefined') {
  global.AbortController = class AbortController {
    signal = {
      aborted: false,
      addEventListener: jest.fn(),
      removeEventListener: jest.fn(),
      dispatchEvent: jest.fn(),
    };
    abort = jest.fn(() => {
      this.signal.aborted = true;
    });
  } as any;
}

// Setup crypto if not available (for Node.js < 15)
if (typeof crypto === 'undefined') {
  const nodeCrypto = require('crypto');
  global.crypto = {
    getRandomValues: (arr: any) => nodeCrypto.randomBytes(arr.length),
    subtle: nodeCrypto.webcrypto?.subtle,
    randomUUID: () => nodeCrypto.randomUUID(),
  } as any;
}

// Clear all mocks before each test
beforeEach(() => {
  jest.clearAllMocks();
});

// Cleanup after each test
afterEach(() => {
  jest.restoreAllMocks();
});
