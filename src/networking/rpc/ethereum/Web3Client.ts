/**
 * Ethereum Web3 JSON-RPC Client
 * Implements Web3-compatible JSON-RPC for Ethereum
 */

import { EventEmitter } from 'events';
import {
  RPCConfig,
  RPCResponse,
  RPCError,
  RPCClientError,
  ConnectionError,
  TimeoutError,
  ValidationError,
  NetworkType,
} from '../common/types';
import { RateLimiter } from '../common/RateLimiter';
import { ConnectionPool } from '../common/ConnectionPool';
import { RetryHandler, RetryConfig } from '../common/RetryHandler';

export interface Web3Config extends RPCConfig {
  network: NetworkType;
  chainId: number;
}

export interface EthereumBlock {
  number: string;
  hash: string;
  parentHash: string;
  nonce: string;
  sha3Uncles: string;
  logsBloom: string;
  transactionsRoot: string;
  stateRoot: string;
  receiptsRoot: string;
  miner: string;
  difficulty: string;
  totalDifficulty: string;
  extraData: string;
  size: string;
  gasLimit: string;
  gasUsed: string;
  timestamp: string;
  transactions: string[] | EthereumTransaction[];
  uncles: string[];
}

export interface EthereumTransaction {
  hash: string;
  nonce: string;
  blockHash: string | null;
  blockNumber: string | null;
  transactionIndex: string | null;
  from: string;
  to: string | null;
  value: string;
  gas: string;
  gasPrice: string;
  maxFeePerGas?: string;
  maxPriorityFeePerGas?: string;
  input: string;
  v?: string;
  r?: string;
  s?: string;
  type?: string;
}

export interface EthereumTransactionReceipt {
  transactionHash: string;
  transactionIndex: string;
  blockHash: string;
  blockNumber: string;
  from: string;
  to: string | null;
  cumulativeGasUsed: string;
  gasUsed: string;
  contractAddress: string | null;
  logs: Array<{
    address: string;
    topics: string[];
    data: string;
    blockNumber: string;
    transactionHash: string;
    transactionIndex: string;
    blockHash: string;
    logIndex: string;
    removed: boolean;
  }>;
  logsBloom: string;
  status: string;
  effectiveGasPrice?: string;
  type?: string;
}

export interface EthereumBalance {
  wei: string;
  ether: string;
}

export class Web3Client extends EventEmitter {
  private requestId: number = 0;
  private rateLimiter: RateLimiter;
  private connectionPool: ConnectionPool;
  private retryHandler: RetryHandler;
  private connected: boolean = false;

  constructor(
    private config: Web3Config,
    rateLimiter: RateLimiter,
    connectionPool: ConnectionPool,
    retryConfig?: RetryConfig
  ) {
    super();
    this.rateLimiter = rateLimiter;
    this.connectionPool = connectionPool;
    this.retryHandler = new RetryHandler(
      retryConfig || RetryHandler.createDefault()
    );
  }

  /**
   * Connect to Ethereum node
   */
  public async connect(): Promise<void> {
    try {
      await this.rateLimiter.waitForToken();

      const result = await this.retryHandler.execute(
        async () => {
          const chainId = await this.getChainId();
          const blockNumber = await this.getBlockNumber();
          return { chainId, blockNumber };
        },
        'connect'
      );

      if (result.chainId !== this.config.chainId) {
        throw new ConnectionError(
          `Chain ID mismatch: expected ${this.config.chainId}, got ${result.chainId}`
        );
      }

      this.connected = true;
      this.emit('connected', result);
    } catch (error) {
      throw new ConnectionError(
        `Failed to connect to Ethereum node: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Disconnect from Ethereum node
   */
  public async disconnect(): Promise<void> {
    this.connected = false;
    this.connectionPool.destroy();
    this.emit('disconnected');
  }

  /**
   * Get chain ID
   */
  public async getChainId(): Promise<number> {
    const response = await this.sendRequest<string>('eth_chainId', []);

    if (!response.data) {
      throw new ValidationError('Invalid chain ID response');
    }

    return parseInt(response.data, 16);
  }

  /**
   * Get current block number
   */
  public async getBlockNumber(): Promise<number> {
    this.ensureConnected();

    const response = await this.sendRequest<string>('eth_blockNumber', []);

    if (!response.data) {
      throw new ValidationError('Invalid block number response');
    }

    return parseInt(response.data, 16);
  }

  /**
   * Get block by number or hash
   */
  public async getBlock(
    blockHashOrNumber: string | number,
    fullTransactions: boolean = false
  ): Promise<EthereumBlock> {
    this.ensureConnected();

    const blockId = typeof blockHashOrNumber === 'number'
      ? '0x' + blockHashOrNumber.toString(16)
      : blockHashOrNumber;

    const method = typeof blockHashOrNumber === 'number'
      ? 'eth_getBlockByNumber'
      : 'eth_getBlockByHash';

    const response = await this.sendRequest<EthereumBlock>(
      method,
      [blockId, fullTransactions]
    );

    if (!response.data) {
      throw new ValidationError(`Block ${blockHashOrNumber} not found`);
    }

    return response.data;
  }

  /**
   * Get balance for address
   */
  public async getBalance(address: string, blockNumber: string = 'latest'): Promise<EthereumBalance> {
    this.validateAddress(address);
    this.ensureConnected();

    const response = await this.sendRequest<string>(
      'eth_getBalance',
      [address, blockNumber]
    );

    if (!response.data) {
      throw new ValidationError('Invalid balance response');
    }

    const weiValue = BigInt(response.data);
    const etherValue = Number(weiValue) / 1e18;

    return {
      wei: weiValue.toString(),
      ether: etherValue.toString(),
    };
  }

  /**
   * Get transaction count (nonce) for address
   */
  public async getTransactionCount(
    address: string,
    blockNumber: string = 'latest'
  ): Promise<number> {
    this.validateAddress(address);
    this.ensureConnected();

    const response = await this.sendRequest<string>(
      'eth_getTransactionCount',
      [address, blockNumber]
    );

    if (!response.data) {
      throw new ValidationError('Invalid transaction count response');
    }

    return parseInt(response.data, 16);
  }

  /**
   * Get transaction by hash
   */
  public async getTransaction(txHash: string): Promise<EthereumTransaction> {
    this.ensureConnected();

    const response = await this.sendRequest<EthereumTransaction>(
      'eth_getTransactionByHash',
      [txHash]
    );

    if (!response.data) {
      throw new ValidationError(`Transaction ${txHash} not found`);
    }

    return response.data;
  }

  /**
   * Get transaction receipt
   */
  public async getTransactionReceipt(txHash: string): Promise<EthereumTransactionReceipt> {
    this.ensureConnected();

    const response = await this.sendRequest<EthereumTransactionReceipt>(
      'eth_getTransactionReceipt',
      [txHash]
    );

    if (!response.data) {
      throw new ValidationError(`Transaction receipt for ${txHash} not found`);
    }

    return response.data;
  }

  /**
   * Send raw transaction
   */
  public async sendRawTransaction(signedTx: string): Promise<string> {
    this.ensureConnected();

    const response = await this.sendRequest<string>(
      'eth_sendRawTransaction',
      [signedTx]
    );

    if (!response.data) {
      throw new RPCClientError('Failed to send transaction', -32006);
    }

    return response.data;
  }

  /**
   * Estimate gas for transaction
   */
  public async estimateGas(transaction: {
    from?: string;
    to?: string;
    gas?: string;
    gasPrice?: string;
    value?: string;
    data?: string;
  }): Promise<string> {
    this.ensureConnected();

    const response = await this.sendRequest<string>(
      'eth_estimateGas',
      [transaction]
    );

    if (!response.data) {
      throw new ValidationError('Failed to estimate gas');
    }

    return response.data;
  }

  /**
   * Get current gas price
   */
  public async getGasPrice(): Promise<string> {
    this.ensureConnected();

    const response = await this.sendRequest<string>('eth_gasPrice', []);

    if (!response.data) {
      throw new ValidationError('Failed to get gas price');
    }

    return response.data;
  }

  /**
   * Get fee history (EIP-1559)
   */
  public async getFeeHistory(
    blockCount: number,
    newestBlock: string = 'latest',
    rewardPercentiles: number[] = [25, 50, 75]
  ): Promise<{
    oldestBlock: string;
    baseFeePerGas: string[];
    gasUsedRatio: number[];
    reward?: string[][];
  }> {
    this.ensureConnected();

    const response = await this.sendRequest<any>(
      'eth_feeHistory',
      [blockCount, newestBlock, rewardPercentiles]
    );

    if (!response.data) {
      throw new ValidationError('Failed to get fee history');
    }

    return response.data;
  }

  /**
   * Call contract method (read-only)
   */
  public async call(
    transaction: {
      from?: string;
      to: string;
      gas?: string;
      gasPrice?: string;
      value?: string;
      data: string;
    },
    blockNumber: string = 'latest'
  ): Promise<string> {
    this.ensureConnected();

    const response = await this.sendRequest<string>(
      'eth_call',
      [transaction, blockNumber]
    );

    if (!response.data) {
      throw new ValidationError('Contract call failed');
    }

    return response.data;
  }

  /**
   * Get contract code
   */
  public async getCode(address: string, blockNumber: string = 'latest'): Promise<string> {
    this.validateAddress(address);
    this.ensureConnected();

    const response = await this.sendRequest<string>(
      'eth_getCode',
      [address, blockNumber]
    );

    if (!response.data) {
      throw new ValidationError('Failed to get contract code');
    }

    return response.data;
  }

  /**
   * Get storage at position
   */
  public async getStorageAt(
    address: string,
    position: string,
    blockNumber: string = 'latest'
  ): Promise<string> {
    this.validateAddress(address);
    this.ensureConnected();

    const response = await this.sendRequest<string>(
      'eth_getStorageAt',
      [address, position, blockNumber]
    );

    if (!response.data) {
      throw new ValidationError('Failed to get storage');
    }

    return response.data;
  }

  /**
   * Get logs matching filter
   */
  public async getLogs(filter: {
    fromBlock?: string;
    toBlock?: string;
    address?: string | string[];
    topics?: Array<string | string[] | null>;
    blockHash?: string;
  }): Promise<Array<{
    address: string;
    topics: string[];
    data: string;
    blockNumber: string;
    transactionHash: string;
    transactionIndex: string;
    blockHash: string;
    logIndex: string;
    removed: boolean;
  }>> {
    this.ensureConnected();

    const response = await this.sendRequest<any[]>('eth_getLogs', [filter]);

    if (!response.data) {
      return [];
    }

    return response.data;
  }

  /**
   * Send JSON-RPC request
   */
  private async sendRequest<T>(
    method: string,
    params: any[] = []
  ): Promise<RPCResponse<T>> {
    await this.rateLimiter.waitForToken();

    return await this.retryHandler.execute(async () => {
      const connection = await this.connectionPool.acquire(
        this.config.timeout || 30000
      );

      try {
        const requestId = ++this.requestId;
        const payload = {
          jsonrpc: '2.0',
          method,
          params,
          id: requestId,
        };

        const controller = new AbortController();
        const timeout = setTimeout(
          () => controller.abort(),
          this.config.timeout || 30000
        );

        const response = await fetch(connection.url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...this.config.headers,
          },
          body: JSON.stringify(payload),
          signal: controller.signal,
        });

        clearTimeout(timeout);

        if (!response.ok) {
          throw new RPCClientError(
            `HTTP ${response.status}: ${response.statusText}`,
            response.status
          );
        }

        const data = await response.json();

        if (data.error) {
          const error: RPCError = data.error;
          throw new RPCClientError(error.message, error.code, error.data);
        }

        connection.requestCount++;
        this.connectionPool.release(connection);

        return {
          success: true,
          data: data.result as T,
          requestId: String(requestId),
          timestamp: Date.now(),
        };
      } catch (error) {
        connection.errorCount++;
        this.connectionPool.markFailed(connection);
        this.connectionPool.release(connection);
        throw error;
      }
    }, `${method}(${params.slice(0, 2).join(', ')})`);
  }

  /**
   * Validate Ethereum address
   */
  private validateAddress(address: string): void {
    if (!/^0x[a-fA-F0-9]{40}$/.test(address)) {
      throw new ValidationError(`Invalid Ethereum address: ${address}`);
    }
  }

  /**
   * Ensure client is connected
   */
  private ensureConnected(): void {
    if (!this.connected) {
      throw new ConnectionError('Not connected to Ethereum node');
    }
  }

  /**
   * Check if connected
   */
  public isConnected(): boolean {
    return this.connected;
  }

  /**
   * Get network information
   */
  public async getNetworkInfo(): Promise<{
    chainId: number;
    blockNumber: number;
    gasPrice: string;
    peerCount?: number;
  }> {
    this.ensureConnected();

    const [chainId, blockNumber, gasPrice] = await Promise.all([
      this.getChainId(),
      this.getBlockNumber(),
      this.getGasPrice(),
    ]);

    return {
      chainId,
      blockNumber,
      gasPrice,
    };
  }
}
