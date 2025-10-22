/**
 * Unit Tests for Web3Client
 * Tests Ethereum Web3 JSON-RPC client
 */

import { Web3Client } from '../../src/networking/rpc/ethereum/Web3Client';
import { MockRateLimiter, MockConnectionPool } from '../mocks/mockRPC';
import { NetworkType, ConnectionError, ValidationError } from '../../src/networking/rpc/common/types';
import { RetryHandler } from '../../src/networking/rpc/common/RetryHandler';

// Mock fetch globally
global.fetch = jest.fn();

describe('Web3Client', () => {
  let client: Web3Client;
  let mockRateLimiter: MockRateLimiter;
  let mockConnectionPool: MockConnectionPool;
  let mockFetch: jest.Mock;

  beforeEach(() => {
    mockRateLimiter = new MockRateLimiter();
    mockConnectionPool = new MockConnectionPool();
    mockFetch = global.fetch as jest.Mock;
    mockFetch.mockReset();

    const config = {
      url: 'https://ethereum.example.com',
      network: NetworkType.MAINNET,
      chainId: 1,
      timeout: 30000,
    };

    client = new Web3Client(
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
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 1 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });

      await client.connect();

      expect(client.isConnected()).toBe(true);
    });

    it('should throw error on chain ID mismatch', async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x3', id: 1 }), // Wrong chain ID
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });

      await expect(client.connect()).rejects.toThrow(/Chain ID mismatch/);
    });

    it('should disconnect properly', async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 1 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });

      await client.connect();
      await client.disconnect();

      expect(client.isConnected()).toBe(false);
    });
  });

  describe('Block Operations', () => {
    beforeEach(async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 1 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should get current block number', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x112a880', id: 3 }),
      });

      const blockNumber = await client.getBlockNumber();

      expect(blockNumber).toBe(18000000);
    });

    it('should get block by number', async () => {
      const mockBlock = {
        number: '0x112a880',
        hash: '0xabc123',
        transactions: [],
        gasLimit: '0x1c9c380',
        gasUsed: '0x5208',
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: mockBlock, id: 3 }),
      });

      const block = await client.getBlock(18000000);

      expect(block.number).toBe('0x112a880');
      expect(block.hash).toBe('0xabc123');
    });

    it('should get block by hash', async () => {
      const mockBlock = {
        number: '0x112a880',
        hash: '0xabc123',
        transactions: [],
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: mockBlock, id: 3 }),
      });

      const block = await client.getBlock('0xabc123');

      expect(block.hash).toBe('0xabc123');
    });

    it('should get block with full transactions', async () => {
      const mockBlock = {
        number: '0x112a880',
        hash: '0xabc123',
        transactions: [{ hash: '0xtx1' }, { hash: '0xtx2' }],
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: mockBlock, id: 3 }),
      });

      const block = await client.getBlock(18000000, true);

      expect(block.transactions).toHaveLength(2);
    });
  });

  describe('Account Operations', () => {
    const validAddress = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1';

    beforeEach(async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 1 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should get account balance', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0xde0b6b3a7640000', id: 3 }), // 1 ETH in wei
      });

      const balance = await client.getBalance(validAddress);

      expect(balance.wei).toBe('1000000000000000000');
      expect(parseFloat(balance.ether)).toBeCloseTo(1.0, 10);
    });

    it('should get balance at specific block', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x0', id: 3 }),
      });

      const balance = await client.getBalance(validAddress, '0x1000');

      expect(balance.wei).toBe('0');
    });

    it('should validate address format', async () => {
      await expect(client.getBalance('invalid-address')).rejects.toThrow(ValidationError);
    });

    it('should get transaction count', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x5', id: 3 }),
      });

      const nonce = await client.getTransactionCount(validAddress);

      expect(nonce).toBe(5);
    });

    it('should get pending transaction count', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x7', id: 3 }),
      });

      const nonce = await client.getTransactionCount(validAddress, 'pending');

      expect(nonce).toBe(7);
    });
  });

  describe('Transaction Operations', () => {
    const txHash = '0xabc123def456789';

    beforeEach(async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 1 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should get transaction by hash', async () => {
      const mockTx = {
        hash: txHash,
        nonce: '0x1',
        from: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1',
        to: '0x123456789abcdef',
        value: '0xde0b6b3a7640000',
        gas: '0x5208',
        gasPrice: '0x4a817c800',
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: mockTx, id: 3 }),
      });

      const tx = await client.getTransaction(txHash);

      expect(tx.hash).toBe(txHash);
      expect(tx.value).toBe('0xde0b6b3a7640000');
    });

    it('should get transaction receipt', async () => {
      const mockReceipt = {
        transactionHash: txHash,
        blockNumber: '0x112a880',
        status: '0x1',
        gasUsed: '0x5208',
        logs: [],
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: mockReceipt, id: 3 }),
      });

      const receipt = await client.getTransactionReceipt(txHash);

      expect(receipt.transactionHash).toBe(txHash);
      expect(receipt.status).toBe('0x1');
    });

    it('should send raw transaction', async () => {
      const signedTx = '0xf86c...';
      const expectedHash = '0xnewtxhash';

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: expectedHash, id: 3 }),
      });

      const txHash = await client.sendRawTransaction(signedTx);

      expect(txHash).toBe(expectedHash);
    });

    it('should throw error on send transaction failure', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: null, id: 3 }),
      });

      await expect(client.sendRawTransaction('0xinvalid')).rejects.toThrow();
    });
  });

  describe('Gas Operations', () => {
    beforeEach(async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 1 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should get current gas price', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x4a817c800', id: 3 }), // 20 gwei
      });

      const gasPrice = await client.getGasPrice();

      expect(gasPrice).toBe('0x4a817c800');
    });

    it('should estimate gas for transaction', async () => {
      const transaction = {
        from: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1',
        to: '0x123456789abcdef',
        value: '0xde0b6b3a7640000',
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x5208', id: 3 }), // 21000 gas
      });

      const gasEstimate = await client.estimateGas(transaction);

      expect(gasEstimate).toBe('0x5208');
    });

    it('should get fee history (EIP-1559)', async () => {
      const mockFeeHistory = {
        oldestBlock: '0x112a880',
        baseFeePerGas: ['0x1', '0x2', '0x3'],
        gasUsedRatio: [0.5, 0.6, 0.7],
        reward: [['0xa'], ['0xb'], ['0xc']],
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: mockFeeHistory, id: 3 }),
      });

      const feeHistory = await client.getFeeHistory(3);

      expect(feeHistory.baseFeePerGas).toHaveLength(3);
      expect(feeHistory.gasUsedRatio).toHaveLength(3);
    });
  });

  describe('Contract Operations', () => {
    const contractAddress = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';

    beforeEach(async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 1 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should call contract method', async () => {
      const transaction = {
        to: contractAddress,
        data: '0x70a08231000000000000000000000000742d35cc6634c0532925a3b844bc9e7595f0beb1',
      };

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0xde0b6b3a7640000', id: 3 }),
      });

      const result = await client.call(transaction);

      expect(result).toBe('0xde0b6b3a7640000');
    });

    it('should get contract code', async () => {
      const mockCode = '0x6080604052...';

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: mockCode, id: 3 }),
      });

      const code = await client.getCode(contractAddress);

      expect(code).toBe(mockCode);
    });

    it('should return 0x for non-contract address', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x', id: 3 }),
      });

      const code = await client.getCode('0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1');

      expect(code).toBe('0x');
    });

    it('should get storage at position', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x123', id: 3 }),
      });

      const storage = await client.getStorageAt(contractAddress, '0x0');

      expect(storage).toBe('0x123');
    });

    it('should get logs', async () => {
      const filter = {
        fromBlock: '0x112a880',
        toBlock: '0x112a890',
        address: contractAddress,
      };

      const mockLogs = [
        {
          address: contractAddress,
          topics: ['0xddf252ad'],
          data: '0x123',
          blockNumber: '0x112a881',
          transactionHash: '0xabc',
          transactionIndex: '0x0',
          blockHash: '0xdef',
          logIndex: '0x0',
          removed: false,
        },
      ];

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: mockLogs, id: 3 }),
      });

      const logs = await client.getLogs(filter);

      expect(logs).toHaveLength(1);
      expect(logs[0].address).toBe(contractAddress);
    });
  });

  describe('Network Information', () => {
    beforeEach(async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 1 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should get chain ID', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x1', id: 3 }),
      });

      const chainId = await client.getChainId();

      expect(chainId).toBe(1);
    });

    it('should get network information', async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 3 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 4 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x4a817c800', id: 5 }),
        });

      const networkInfo = await client.getNetworkInfo();

      expect(networkInfo.chainId).toBe(1);
      expect(networkInfo.blockNumber).toBe(18000000);
      expect(networkInfo.gasPrice).toBe('0x4a817c800');
    });
  });

  describe('Error Handling', () => {
    beforeEach(async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 1 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should handle RPC errors', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          error: { code: -32600, message: 'Invalid request' },
          id: 3,
        }),
      });

      await expect(client.getBlockNumber()).rejects.toThrow('Invalid request');
    });

    it('should handle HTTP errors', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 503,
        statusText: 'Service Unavailable',
      });

      await expect(client.getBlockNumber()).rejects.toThrow();
    });

    it('should throw error when not connected', async () => {
      await client.disconnect();

      await expect(client.getBlockNumber()).rejects.toThrow(ConnectionError);
    });
  });

  describe('Rate Limiting', () => {
    beforeEach(async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 1 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should respect rate limits', async () => {
      mockFetch.mockResolvedValue({
        ok: true,
        json: async () => ({ result: '0x112a880', id: 3 }),
      });

      await client.getBlockNumber();

      expect(mockRateLimiter.waitCount).toBeGreaterThan(0);
    });
  });

  describe('Connection Pool Integration', () => {
    beforeEach(async () => {
      mockFetch
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x1', id: 1 }),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: async () => ({ result: '0x112a880', id: 2 }),
        });
      await client.connect();
      mockFetch.mockClear();
    });

    it('should acquire and release connections', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ result: '0x112a880', id: 3 }),
      });

      const acquireBefore = mockConnectionPool.acquireCount;
      const releaseBefore = mockConnectionPool.releaseCount;

      await client.getBlockNumber();

      expect(mockConnectionPool.acquireCount).toBe(acquireBefore + 1);
      expect(mockConnectionPool.releaseCount).toBe(releaseBefore + 1);
    });

    it('should release connection on error', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Request failed'));

      const releaseBefore = mockConnectionPool.releaseCount;

      try {
        await client.getBlockNumber();
      } catch (error) {
        // Expected
      }

      expect(mockConnectionPool.releaseCount).toBeGreaterThan(releaseBefore);
    });
  });
});
