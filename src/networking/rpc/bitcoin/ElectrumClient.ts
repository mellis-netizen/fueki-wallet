/**
 * Bitcoin Electrum Protocol Client
 * Implements Electrum protocol for Bitcoin RPC communication
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

export interface ElectrumConfig extends RPCConfig {
  network: NetworkType;
  protocol?: 'tcp' | 'ssl' | 'ws' | 'wss';
  version?: string;
}

export interface ElectrumTransaction {
  txid: string;
  version: number;
  locktime: number;
  vin: Array<{
    txid: string;
    vout: number;
    scriptSig: { asm: string; hex: string };
    sequence: number;
  }>;
  vout: Array<{
    value: number;
    n: number;
    scriptPubKey: {
      asm: string;
      hex: string;
      type: string;
      addresses?: string[];
    };
  }>;
  blockhash?: string;
  confirmations?: number;
  time?: number;
  blocktime?: number;
}

export interface ElectrumBalance {
  confirmed: number;
  unconfirmed: number;
  total: number;
}

export interface ElectrumUTXO {
  txid: string;
  vout: number;
  value: number;
  height: number;
  confirmations: number;
}

export class ElectrumClient extends EventEmitter {
  private requestId: number = 0;
  private rateLimiter: RateLimiter;
  private connectionPool: ConnectionPool;
  private retryHandler: RetryHandler;
  private connected: boolean = false;

  constructor(
    private config: ElectrumConfig,
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
   * Connect to Electrum server
   */
  public async connect(): Promise<void> {
    try {
      await this.rateLimiter.waitForToken();

      const result = await this.retryHandler.execute(
        async () => {
          const response = await this.sendRequest<any>(
            'server.version',
            [this.config.version || 'Fueki-Wallet 1.0', '1.4']
          );
          return response;
        },
        'connect'
      );

      this.connected = true;
      this.emit('connected', result);
    } catch (error) {
      throw new ConnectionError(
        `Failed to connect to Electrum server: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Disconnect from Electrum server
   */
  public async disconnect(): Promise<void> {
    this.connected = false;
    this.connectionPool.destroy();
    this.emit('disconnected');
  }

  /**
   * Get blockchain height
   */
  public async getBlockHeight(): Promise<number> {
    this.ensureConnected();

    const response = await this.sendRequest<{ height: number }>(
      'blockchain.headers.subscribe',
      []
    );

    if (!response.data?.height) {
      throw new ValidationError('Invalid block height response');
    }

    return response.data.height;
  }

  /**
   * Get address balance
   */
  public async getBalance(address: string): Promise<ElectrumBalance> {
    this.validateAddress(address);
    this.ensureConnected();

    const scriptHash = this.addressToScriptHash(address);
    const response = await this.sendRequest<{ confirmed: number; unconfirmed: number }>(
      'blockchain.scripthash.get_balance',
      [scriptHash]
    );

    if (!response.data) {
      throw new ValidationError('Invalid balance response');
    }

    return {
      confirmed: response.data.confirmed / 100000000, // Convert satoshis to BTC
      unconfirmed: response.data.unconfirmed / 100000000,
      total: (response.data.confirmed + response.data.unconfirmed) / 100000000,
    };
  }

  /**
   * Get transaction history for address
   */
  public async getHistory(address: string): Promise<ElectrumTransaction[]> {
    this.validateAddress(address);
    this.ensureConnected();

    const scriptHash = this.addressToScriptHash(address);
    const response = await this.sendRequest<Array<{ tx_hash: string; height: number }>>(
      'blockchain.scripthash.get_history',
      [scriptHash]
    );

    if (!response.data) {
      return [];
    }

    // Fetch full transaction details
    const transactions = await Promise.all(
      response.data.map(item => this.getTransaction(item.tx_hash))
    );

    return transactions;
  }

  /**
   * Get transaction details
   */
  public async getTransaction(txid: string): Promise<ElectrumTransaction> {
    this.ensureConnected();

    const response = await this.sendRequest<string>(
      'blockchain.transaction.get',
      [txid, true]
    );

    if (!response.data) {
      throw new ValidationError(`Transaction ${txid} not found`);
    }

    return this.parseTransaction(response.data);
  }

  /**
   * Get unspent transaction outputs (UTXOs)
   */
  public async getUTXOs(address: string): Promise<ElectrumUTXO[]> {
    this.validateAddress(address);
    this.ensureConnected();

    const scriptHash = this.addressToScriptHash(address);
    const response = await this.sendRequest<Array<{
      tx_hash: string;
      tx_pos: number;
      value: number;
      height: number;
    }>>(
      'blockchain.scripthash.listunspent',
      [scriptHash]
    );

    if (!response.data) {
      return [];
    }

    const blockHeight = await this.getBlockHeight();

    return response.data.map(utxo => ({
      txid: utxo.tx_hash,
      vout: utxo.tx_pos,
      value: utxo.value / 100000000, // Convert to BTC
      height: utxo.height,
      confirmations: utxo.height > 0 ? blockHeight - utxo.height + 1 : 0,
    }));
  }

  /**
   * Broadcast raw transaction
   */
  public async broadcastTransaction(rawTx: string): Promise<string> {
    this.ensureConnected();

    const response = await this.sendRequest<string>(
      'blockchain.transaction.broadcast',
      [rawTx]
    );

    if (!response.data) {
      throw new RPCClientError('Failed to broadcast transaction', -32005);
    }

    return response.data;
  }

  /**
   * Estimate fee for transaction
   */
  public async estimateFee(blocks: number = 6): Promise<number> {
    this.ensureConnected();

    const response = await this.sendRequest<number>(
      'blockchain.estimatefee',
      [blocks]
    );

    if (!response.data || response.data < 0) {
      // Return default fee if estimation fails
      return 0.00001; // 1000 satoshis per byte
    }

    return response.data;
  }

  /**
   * Subscribe to address notifications
   */
  public async subscribeAddress(
    address: string,
    callback: (status: any) => void
  ): Promise<void> {
    this.validateAddress(address);
    this.ensureConnected();

    const scriptHash = this.addressToScriptHash(address);

    await this.sendRequest(
      'blockchain.scripthash.subscribe',
      [scriptHash]
    );

    this.on(`scripthash:${scriptHash}`, callback);
  }

  /**
   * Unsubscribe from address notifications
   */
  public async unsubscribeAddress(address: string): Promise<void> {
    this.validateAddress(address);

    const scriptHash = this.addressToScriptHash(address);
    this.removeAllListeners(`scripthash:${scriptHash}`);
  }

  /**
   * Send RPC request
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
    }, `${method}(${params.join(', ')})`);
  }

  /**
   * Convert address to script hash (Electrum format)
   */
  private addressToScriptHash(address: string): string {
    // This is a simplified implementation
    // In production, use a proper Bitcoin library like bitcoinjs-lib
    const crypto = require('crypto');

    // Convert address to script hash
    // This should use proper address decoding and script generation
    const hash = crypto
      .createHash('sha256')
      .update(address)
      .digest('hex');

    // Reverse byte order for Electrum
    return hash.match(/../g)?.reverse().join('') || hash;
  }

  /**
   * Parse transaction data
   */
  private parseTransaction(data: any): ElectrumTransaction {
    // This is a simplified parser
    // In production, use bitcoinjs-lib for proper transaction parsing
    if (typeof data === 'string') {
      // Raw hex transaction - would need proper parsing
      return {
        txid: data.substring(0, 64),
        version: 1,
        locktime: 0,
        vin: [],
        vout: [],
      };
    }

    return data as ElectrumTransaction;
  }

  /**
   * Validate Bitcoin address
   */
  private validateAddress(address: string): void {
    // Basic validation - in production use bitcoinjs-lib
    const validPrefixes = this.config.network === NetworkType.MAINNET
      ? ['1', '3', 'bc1']
      : ['m', 'n', '2', 'tb1'];

    const hasValidPrefix = validPrefixes.some(prefix =>
      address.startsWith(prefix)
    );

    if (!hasValidPrefix) {
      throw new ValidationError(`Invalid Bitcoin address: ${address}`);
    }

    if (address.length < 26 || address.length > 90) {
      throw new ValidationError(`Invalid Bitcoin address length: ${address}`);
    }
  }

  /**
   * Ensure client is connected
   */
  private ensureConnected(): void {
    if (!this.connected) {
      throw new ConnectionError('Not connected to Electrum server');
    }
  }

  /**
   * Check if connected
   */
  public isConnected(): boolean {
    return this.connected;
  }
}
