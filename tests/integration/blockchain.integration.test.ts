/**
 * Integration Tests for Blockchain Operations
 * Tests end-to-end RPC client functionality with mocked blockchain
 */

import { ElectrumClient } from '../../src/networking/rpc/bitcoin/ElectrumClient';
import { Web3Client } from '../../src/networking/rpc/ethereum/Web3Client';
import { RateLimiter } from '../../src/networking/rpc/common/RateLimiter';
import { ConnectionPool } from '../../src/networking/rpc/common/ConnectionPool';
import { RetryHandler } from '../../src/networking/rpc/common/RetryHandler';
import { NetworkType } from '../../src/networking/rpc/common/types';

// Mock fetch globally
global.fetch = jest.fn();

describe('Blockchain Integration Tests', () => {
  describe('Bitcoin Operations', () => {
    let electrumClient: ElectrumClient;
    let rateLimiter: RateLimiter;
    let connectionPool: ConnectionPool;
    let mockFetch: jest.Mock;

    beforeEach(() => {
      mockFetch = global.fetch as jest.Mock;
      mockFetch.mockReset();

      rateLimiter = new RateLimiter({
        requestsPerSecond: 10,
        burstSize: 10,
      });

      connectionPool = new ConnectionPool(
        {
          minConnections: 1,
          maxConnections: 3,
          acquireTimeout: 5000,
          idleTimeout: 30000,
        },
        {
          primaryUrl: 'https://electrum.example.com',
          fallbackUrls: ['https://electrum-backup.example.com'],
          healthCheckInterval: 60000,
          failoverThreshold: 3,
        }
      );

      electrumClient = new ElectrumClient(
        {
          url: 'https://electrum.example.com',
          network: NetworkType.TESTNET,
          timeout: 30000,
        },
        rateLimiter,
        connectionPool,
        RetryHandler.createDefault()
      );
    });

    afterEach(() => {
      connectionPool.destroy();
    });

    it('should complete full transaction lifecycle', async () => {
      const testAddress = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';

      // Mock connection
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });

      await electrumClient.connect();

      // Mock get balance
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          result: { confirmed: 200000000, unconfirmed: 0 },
          id: 2,
        }),
      });

      const balance = await electrumClient.getBalance(testAddress);
      expect(balance.confirmed).toBe(2.0);

      // Mock get UTXOs
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({
            result: [
              { tx_hash: 'utxo1', tx_pos: 0, value: 200000000, height: 799990 },
            ],
            id: 3,
          }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: { height: 800000 }, id: 4 }),
        });

      const utxos = await electrumClient.getUTXOs(testAddress);
      expect(utxos).toHaveLength(1);
      expect(utxos[0].value).toBe(2.0);

      // Mock estimate fee
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: 0.00001, id: 5 }),
      });

      const fee = await electrumClient.estimateFee(6);
      expect(fee).toBe(0.00001);

      // Mock broadcast transaction
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: 'broadcasted-txid', id: 6 }),
      });

      const txid = await electrumClient.broadcastTransaction('0x...');
      expect(txid).toBe('broadcasted-txid');

      await electrumClient.disconnect();
    });

    it('should handle concurrent requests', async () => {
      // Mock connection
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });

      await electrumClient.connect();

      // Mock multiple parallel requests
      mockFetch.mockImplementation(async () => ({
        ok: true,
        json: async () => ({
          result: { height: 800000 },
          id: Math.random(),
        }),
      }));

      const promises = Array(10).fill(null).map(() => electrumClient.getBlockHeight());
      const results = await Promise.all(promises);

      expect(results).toHaveLength(10);
      results.forEach(height => expect(height).toBe(800000));
    });

    it('should handle failover on connection error', async () => {
      // First connection fails
      mockFetch.mockRejectedValueOnce(new Error('Connection refused'));

      // Second attempt succeeds
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });

      await electrumClient.connect();
      expect(electrumClient.isConnected()).toBe(true);
    });
  });

  describe('Ethereum Operations', () => {
    let web3Client: Web3Client;
    let rateLimiter: RateLimiter;
    let connectionPool: ConnectionPool;
    let mockFetch: jest.Mock;

    beforeEach(() => {
      mockFetch = global.fetch as jest.Mock;
      mockFetch.mockReset();

      rateLimiter = new RateLimiter({
        requestsPerSecond: 10,
        burstSize: 10,
      });

      connectionPool = new ConnectionPool(
        {
          minConnections: 1,
          maxConnections: 3,
          acquireTimeout: 5000,
          idleTimeout: 30000,
        },
        {
          primaryUrl: 'https://ethereum.example.com',
          fallbackUrls: ['https://ethereum-backup.example.com'],
          healthCheckInterval: 60000,
          failoverThreshold: 3,
        }
      );

      web3Client = new Web3Client(
        {
          url: 'https://ethereum.example.com',
          network: NetworkType.MAINNET,
          chainId: 1,
          timeout: 30000,
        },
        rateLimiter,
        connectionPool,
        RetryHandler.createDefault()
      );
    });

    afterEach(() => {
      connectionPool.destroy();
    });

    it('should complete full transaction lifecycle', async () => {
      const testAddress = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1';

      // Mock connection
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 1 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });

      await web3Client.connect();

      // Mock get balance
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0xde0b6b3a7640000', id: 3 }),
      });

      const balance = await web3Client.getBalance(testAddress);
      expect(parseFloat(balance.ether)).toBeCloseTo(1.0, 10);

      // Mock get nonce
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x5', id: 4 }),
      });

      const nonce = await web3Client.getTransactionCount(testAddress);
      expect(nonce).toBe(5);

      // Mock estimate gas
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x5208', id: 5 }),
      });

      const gasEstimate = await web3Client.estimateGas({
        from: testAddress,
        to: '0x123456789abcdef',
        value: '0xde0b6b3a7640000',
      });
      expect(gasEstimate).toBe('0x5208');

      // Mock get gas price
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x4a817c800', id: 6 }),
      });

      const gasPrice = await web3Client.getGasPrice();
      expect(gasPrice).toBe('0x4a817c800');

      // Mock send transaction
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0xtxhash123', id: 7 }),
      });

      const txHash = await web3Client.sendRawTransaction('0x...');
      expect(txHash).toBe('0xtxhash123');

      // Mock get transaction receipt
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          result: {
            transactionHash: '0xtxhash123',
            blockNumber: '0x112a881',
            status: '0x1',
            gasUsed: '0x5208',
            logs: [],
          },
          id: 8,
        }),
      });

      const receipt = await web3Client.getTransactionReceipt('0xtxhash123');
      expect(receipt.status).toBe('0x1');
      expect(receipt.transactionHash).toBe('0xtxhash123');

      await web3Client.disconnect();
    });

    it('should handle contract interactions', async () => {
      const contractAddress = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';

      // Mock connection
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 1 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });

      await web3Client.connect();

      // Mock get contract code
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x6080604052...', id: 3 }),
      });

      const code = await web3Client.getCode(contractAddress);
      expect(code).toContain('0x');
      expect(code.length).toBeGreaterThan(2);

      // Mock contract call (balanceOf)
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0xde0b6b3a7640000', id: 4 }),
      });

      const result = await web3Client.call({
        to: contractAddress,
        data: '0x70a08231000000000000000000000000742d35cc6634c0532925a3b844bc9e7595f0beb1',
      });

      expect(result).toBe('0xde0b6b3a7640000');

      // Mock get logs
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          result: [
            {
              address: contractAddress,
              topics: ['0xddf252ad'],
              data: '0x123',
              blockNumber: '0x112a880',
              transactionHash: '0xabc',
              transactionIndex: '0x0',
              blockHash: '0xdef',
              logIndex: '0x0',
              removed: false,
            },
          ],
          id: 5,
        }),
      });

      const logs = await web3Client.getLogs({
        address: contractAddress,
        fromBlock: '0x112a880',
        toBlock: 'latest',
      });

      expect(logs).toHaveLength(1);
      expect(logs[0].address).toBe(contractAddress);
    });

    it('should handle concurrent requests', async () => {
      // Mock connection
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 1 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });

      await web3Client.connect();

      // Mock multiple parallel requests
      mockFetch.mockImplementation(async () => ({
        ok: true,
        json: async () => ({
          result: '0x112a880',
          id: Math.random(),
        }),
      }));

      const promises = Array(10).fill(null).map(() => web3Client.getBlockNumber());
      const results = await Promise.all(promises);

      expect(results).toHaveLength(10);
      results.forEach(blockNumber => expect(blockNumber).toBe(18000000));
    });
  });

  describe('Multi-Chain Operations', () => {
    it('should handle Bitcoin and Ethereum operations concurrently', async () => {
      const mockFetch = global.fetch as jest.Mock;
      mockFetch.mockReset();

      // Setup Bitcoin client
      const btcRateLimiter = new RateLimiter({
        requestsPerSecond: 10,
        burstSize: 10,
      });

      const btcConnectionPool = new ConnectionPool(
        {
          minConnections: 1,
          maxConnections: 3,
          acquireTimeout: 5000,
          idleTimeout: 30000,
        },
        {
          primaryUrl: 'https://electrum.example.com',
          fallbackUrls: [],
          healthCheckInterval: 60000,
          failoverThreshold: 3,
        }
      );

      const btcClient = new ElectrumClient(
        {
          url: 'https://electrum.example.com',
          network: NetworkType.TESTNET,
          timeout: 30000,
        },
        btcRateLimiter,
        btcConnectionPool,
        RetryHandler.createDefault()
      );

      // Setup Ethereum client
      const ethRateLimiter = new RateLimiter({
        requestsPerSecond: 10,
        burstSize: 10,
      });

      const ethConnectionPool = new ConnectionPool(
        {
          minConnections: 1,
          maxConnections: 3,
          acquireTimeout: 5000,
          idleTimeout: 30000,
        },
        {
          primaryUrl: 'https://ethereum.example.com',
          fallbackUrls: [],
          healthCheckInterval: 60000,
          failoverThreshold: 3,
        }
      );

      const ethClient = new Web3Client(
        {
          url: 'https://ethereum.example.com',
          network: NetworkType.MAINNET,
          chainId: 1,
          timeout: 30000,
        },
        ethRateLimiter,
        ethConnectionPool,
        RetryHandler.createDefault()
      );

      // Mock Bitcoin connection
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: ['ElectrumX', '1.4'], id: 1 }),
      });

      // Mock Ethereum connection
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 2 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 3 }),
        });

      // Connect both clients
      await Promise.all([btcClient.connect(), ethClient.connect()]);

      // Mock Bitcoin block height
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: { height: 800000 }, id: 4 }),
      });

      // Mock Ethereum block number
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x112a880', id: 5 }),
      });

      // Get block heights concurrently
      const [btcHeight, ethHeight] = await Promise.all([
        btcClient.getBlockHeight(),
        ethClient.getBlockNumber(),
      ]);

      expect(btcHeight).toBe(800000);
      expect(ethHeight).toBe(18000000);

      // Cleanup
      btcConnectionPool.destroy();
      ethConnectionPool.destroy();
    });
  });
});
