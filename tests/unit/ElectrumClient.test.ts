/**
 * Unit Tests for ElectrumClient
 * Tests Bitcoin Electrum protocol client
 */

import { ElectrumClient } from '../../src/networking/rpc/bitcoin/ElectrumClient';
import { MockRateLimiter, MockConnectionPool } from '../mocks/mockRPC';
import { NetworkType, ConnectionError, ValidationError } from '../../src/networking/rpc/common/types';
import { RetryHandler } from '../../src/networking/rpc/common/RetryHandler';

// Mock fetch globally
global.fetch = jest.fn();

describe('ElectrumClient', () => {
  let client: ElectrumClient;
  let mockRateLimiter: MockRateLimiter;
  let mockConnectionPool: MockConnectionPool;
  let mockFetch: jest.Mock;

  beforeEach(() => {
    mockRateLimiter = new MockRateLimiter();
    mockConnectionPool = new MockConnectionPool();
    mockFetch = global.fetch as jest.Mock;
    mockFetch.mockReset();

    const config = {
      url: 'https://electrum.example.com',
      network: NetworkType.TESTNET,
      timeout: 30000,
    };

    client = new ElectrumClient(
      config,
      mockRateLimiter as any,
      mockConnectionPool as any,
      RetryHandler.createDefault()
    );
  });

  afterEach(() => {
    mockConnectionPool.destroy();
  });

  describe('Connection Management', () => {
    it('should connect successfully', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });

      await client.connect();

      expect(client.isConnected()).toBe(true);
      expect(mockFetch).toHaveBeenCalled();
    });

    it('should emit connected event', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });

      const connectHandler = jest.fn();
      client.on('connected', connectHandler);

      await client.connect();

      expect(connectHandler).toHaveBeenCalled();
    });

    it('should throw ConnectionError on connection failure', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'));

      await expect(client.connect()).rejects.toThrow(ConnectionError);
      expect(client.isConnected()).toBe(false);
    });

    it('should disconnect properly', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });

      await client.connect();
      await client.disconnect();

      expect(client.isConnected()).toBe(false);
    });

    it('should emit disconnected event', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });

      const disconnectHandler = jest.fn();
      client.on('disconnected', disconnectHandler);

      await client.connect();
      await client.disconnect();

      expect(disconnectHandler).toHaveBeenCalled();
    });
  });

  describe('Block Operations', () => {
    beforeEach(async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should get block height', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: { height: 800000 }, id: 2 }),
      });

      const height = await client.getBlockHeight();

      expect(height).toBe(800000);
      expect(mockRateLimiter.waitCount).toBeGreaterThan(0);
    });

    it('should throw ValidationError on invalid block height response', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: {}, id: 2 }),
      });

      await expect(client.getBlockHeight()).rejects.toThrow(ValidationError);
    });

    it('should throw error when not connected', async () => {
      await client.disconnect();

      await expect(client.getBlockHeight()).rejects.toThrow(ConnectionError);
      await expect(client.getBlockHeight()).rejects.toThrow(/Not connected/);
    });
  });

  describe('Address Operations', () => {
    const validAddress = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';

    beforeEach(async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should get address balance', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          result: { confirmed: 150000000, unconfirmed: 10000000 },
          id: 2,
        }),
      });

      const balance = await client.getBalance(validAddress);

      expect(balance.confirmed).toBe(1.5);
      expect(balance.unconfirmed).toBe(0.1);
      expect(balance.total).toBe(1.6);
    });

    it('should validate address format', async () => {
      await expect(client.getBalance('invalid-address')).rejects.toThrow(ValidationError);
    });

    it('should reject mainnet addresses on testnet', async () => {
      await expect(client.getBalance('bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq'))
        .rejects.toThrow(ValidationError);
    });

    it('should reject addresses with invalid length', async () => {
      await expect(client.getBalance('tb1qshort')).rejects.toThrow(ValidationError);
    });

    it('should get transaction history', async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            result: [
              { tx_hash: 'txid1', height: 800000 },
              { tx_hash: 'txid2', height: 800001 },
            ],
            id: 2,
          }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            result: {
              txid: 'txid1',
              version: 2,
              locktime: 0,
              vin: [],
              vout: [],
            },
            id: 3,
          }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            result: {
              txid: 'txid2',
              version: 2,
              locktime: 0,
              vin: [],
              vout: [],
            },
            id: 4,
          }),
        });

      const history = await client.getHistory(validAddress);

      expect(history).toHaveLength(2);
      expect(history[0].txid).toBe('txid1');
      expect(history[1].txid).toBe('txid2');
    });

    it('should return empty array for address with no history', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: [], id: 2 }),
      });

      const history = await client.getHistory(validAddress);

      expect(history).toEqual([]);
    });
  });

  describe('Transaction Operations', () => {
    beforeEach(async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should get transaction details', async () => {
      const mockTx = {
        txid: 'abc123',
        version: 2,
        locktime: 0,
        vin: [],
        vout: [],
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: mockTx, id: 2 }),
      });

      const tx = await client.getTransaction('abc123');

      expect(tx.txid).toBe('abc123');
      expect(tx.version).toBe(2);
    });

    it('should throw ValidationError for non-existent transaction', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: null, id: 2 }),
      });

      await expect(client.getTransaction('nonexistent')).rejects.toThrow(ValidationError);
    });

    it('should broadcast raw transaction', async () => {
      const rawTx = '0200000001...';
      const expectedTxId = 'broadcasted-txid';

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: expectedTxId, id: 2 }),
      });

      const txid = await client.broadcastTransaction(rawTx);

      expect(txid).toBe(expectedTxId);
    });

    it('should throw error on broadcast failure', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: null, id: 2 }),
      });

      await expect(client.broadcastTransaction('invalid')).rejects.toThrow();
    });
  });

  describe('UTXO Operations', () => {
    const validAddress = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';

    beforeEach(async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should get UTXOs for address', async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            result: [
              { tx_hash: 'txid1', tx_pos: 0, value: 100000000, height: 799990 },
              { tx_hash: 'txid2', tx_pos: 1, value: 50000000, height: 799995 },
            ],
            id: 2,
          }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: { height: 800000 }, id: 3 }),
        });

      const utxos = await client.getUTXOs(validAddress);

      expect(utxos).toHaveLength(2);
      expect(utxos[0].txid).toBe('txid1');
      expect(utxos[0].value).toBe(1.0);
      expect(utxos[0].confirmations).toBe(11);
      expect(utxos[1].value).toBe(0.5);
      expect(utxos[1].confirmations).toBe(6);
    });

    it('should handle unconfirmed UTXOs', async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            result: [
              { tx_hash: 'txid1', tx_pos: 0, value: 100000000, height: 0 },
            ],
            id: 2,
          }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: { height: 800000 }, id: 3 }),
        });

      const utxos = await client.getUTXOs(validAddress);

      expect(utxos[0].confirmations).toBe(0);
      expect(utxos[0].height).toBe(0);
    });

    it('should return empty array for address with no UTXOs', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: [], id: 2 }),
      });

      const utxos = await client.getUTXOs(validAddress);

      expect(utxos).toEqual([]);
    });
  });

  describe('Fee Estimation', () => {
    beforeEach(async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should estimate fee for transaction', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: 0.00001, id: 2 }),
      });

      const fee = await client.estimateFee(6);

      expect(fee).toBe(0.00001);
    });

    it('should return default fee on estimation failure', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: -1, id: 2 }),
      });

      const fee = await client.estimateFee(6);

      expect(fee).toBe(0.00001);
    });

    it('should use custom block target', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: 0.00002, id: 2 }),
      });

      const fee = await client.estimateFee(1); // Fast confirmation

      expect(fee).toBeGreaterThan(0);
    });
  });

  describe('Subscription Management', () => {
    const validAddress = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';

    beforeEach(async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should subscribe to address updates', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: 'subscribed', id: 2 }),
      });

      const callback = jest.fn();
      await client.subscribeAddress(validAddress, callback);

      // Verify subscription was created
      expect(mockFetch).toHaveBeenCalled();
    });

    it('should unsubscribe from address', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: 'subscribed', id: 2 }),
      });

      const callback = jest.fn();
      await client.subscribeAddress(validAddress, callback);
      await client.unsubscribeAddress(validAddress);

      // Callback should not be called after unsubscribe
      expect(callback).not.toHaveBeenCalled();
    });
  });

  describe('Error Handling', () => {
    beforeEach(async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should handle RPC errors', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          error: { code: -32600, message: 'Invalid request' },
          id: 2,
        }),
      });

      await expect(client.getBlockHeight()).rejects.toThrow('Invalid request');
    });

    it('should handle HTTP errors', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
        statusText: 'Internal Server Error',
      });

      await expect(client.getBlockHeight()).rejects.toThrow();
    });

    it('should handle network timeouts', async () => {
      mockFetch.mockRejectedValueOnce(new Error('ETIMEDOUT'));

      await expect(client.getBlockHeight()).rejects.toThrow();
    });

    it('should use retry handler for failed requests', async () => {
      // First call fails, second succeeds
      mockFetch
        .mockRejectedValueOnce(new Error('Network error'))
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: { height: 800000 }, id: 2 }),
        });

      const height = await client.getBlockHeight();

      expect(height).toBe(800000);
      expect(mockFetch).toHaveBeenCalledTimes(2);
    });
  });

  describe('Rate Limiting', () => {
    beforeEach(async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should respect rate limits', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: async () => ({ result: { height: 800000 }, id: 2 }),
      });

      await client.getBlockHeight();

      expect(mockRateLimiter.waitCount).toBeGreaterThan(0);
    });

    it('should wait for rate limit tokens', async () => {
      mockRateLimiter.setThrottle(true);

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: { height: 800000 }, id: 2 }),
      });

      const startTime = Date.now();
      await client.getBlockHeight();
      const elapsed = Date.now() - startTime;

      expect(elapsed).toBeGreaterThan(5);
    });
  });

  describe('Connection Pool Integration', () => {
    beforeEach(async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should acquire connection from pool', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: { height: 800000 }, id: 2 }),
      });

      await client.getBlockHeight();

      expect(mockConnectionPool.acquireCount).toBeGreaterThan(0);
      expect(mockConnectionPool.releaseCount).toBeGreaterThan(0);
    });

    it('should release connection after request', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: { height: 800000 }, id: 2 }),
      });

      const acquireBefore = mockConnectionPool.acquireCount;
      const releaseBefore = mockConnectionPool.releaseCount;

      await client.getBlockHeight();

      expect(mockConnectionPool.acquireCount).toBe(acquireBefore + 1);
      expect(mockConnectionPool.releaseCount).toBe(releaseBefore + 1);
    });

    it('should release connection on error', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Request failed'));

      const releaseBefore = mockConnectionPool.releaseCount;

      try {
        await client.getBlockHeight();
      } catch (error) {
        // Expected
      }

      expect(mockConnectionPool.releaseCount).toBeGreaterThan(releaseBefore);
    });
  });
});
