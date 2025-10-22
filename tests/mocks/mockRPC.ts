/**
 * Mock RPC Clients for Testing
 * Provides mock implementations of blockchain RPC clients
 */

import { EventEmitter } from 'events';
import {
  RPCResponse,
  NetworkType,
  Connection,
  HealthCheck,
} from '../../src/networking/rpc/common/types';

/**
 * Mock Electrum Client
 */
export class MockElectrumClient extends EventEmitter {
  public connected: boolean = false;
  public requestHistory: Array<{ method: string; params: any[] }> = [];
  public mockResponses: Map<string, any> = new Map();
  public shouldFail: boolean = false;
  public failureCount: number = 0;
  public latency: number = 10;

  constructor(public config: any) {
    super();
  }

  async connect(): Promise<void> {
    if (this.shouldFail && this.failureCount-- > 0) {
      throw new Error('Mock connection failed');
    }
    await this.simulateLatency();
    this.connected = true;
    this.emit('connected');
  }

  async disconnect(): Promise<void> {
    this.connected = false;
    this.emit('disconnected');
  }

  async getBlockHeight(): Promise<number> {
    this.recordRequest('blockchain.headers.subscribe', []);
    if (!this.connected) throw new Error('Not connected');
    await this.simulateLatency();
    return this.mockResponses.get('blockHeight') || 800000;
  }

  async getBalance(address: string): Promise<any> {
    this.recordRequest('blockchain.scripthash.get_balance', [address]);
    if (!this.connected) throw new Error('Not connected');
    await this.simulateLatency();
    return this.mockResponses.get(`balance:${address}`) || {
      confirmed: 1.5,
      unconfirmed: 0.1,
      total: 1.6,
    };
  }

  async getHistory(address: string): Promise<any[]> {
    this.recordRequest('blockchain.scripthash.get_history', [address]);
    if (!this.connected) throw new Error('Not connected');
    await this.simulateLatency();
    return this.mockResponses.get(`history:${address}`) || [];
  }

  async getTransaction(txid: string): Promise<any> {
    this.recordRequest('blockchain.transaction.get', [txid]);
    if (!this.connected) throw new Error('Not connected');
    await this.simulateLatency();
    return this.mockResponses.get(`tx:${txid}`) || {
      txid,
      version: 2,
      locktime: 0,
      vin: [],
      vout: [],
    };
  }

  async getUTXOs(address: string): Promise<any[]> {
    this.recordRequest('blockchain.scripthash.listunspent', [address]);
    if (!this.connected) throw new Error('Not connected');
    await this.simulateLatency();
    return this.mockResponses.get(`utxos:${address}`) || [];
  }

  async broadcastTransaction(rawTx: string): Promise<string> {
    this.recordRequest('blockchain.transaction.broadcast', [rawTx]);
    if (!this.connected) throw new Error('Not connected');
    if (this.shouldFail && this.failureCount-- > 0) {
      throw new Error('Broadcast failed');
    }
    await this.simulateLatency();
    return this.mockResponses.get('txid') || 'mock-txid-123';
  }

  async estimateFee(blocks: number): Promise<number> {
    this.recordRequest('blockchain.estimatefee', [blocks]);
    if (!this.connected) throw new Error('Not connected');
    await this.simulateLatency();
    return this.mockResponses.get('fee') || 0.00001;
  }

  async subscribeAddress(address: string, callback: Function): Promise<void> {
    this.recordRequest('blockchain.scripthash.subscribe', [address]);
    if (!this.connected) throw new Error('Not connected');
    this.on(`address:${address}`, callback);
  }

  async unsubscribeAddress(address: string): Promise<void> {
    this.removeAllListeners(`address:${address}`);
  }

  isConnected(): boolean {
    return this.connected;
  }

  // Test utilities
  setMockResponse(key: string, value: any): void {
    this.mockResponses.set(key, value);
  }

  setLatency(ms: number): void {
    this.latency = ms;
  }

  setShouldFail(count: number = 1): void {
    this.shouldFail = true;
    this.failureCount = count;
  }

  clearRequestHistory(): void {
    this.requestHistory = [];
  }

  getRequestCount(method?: string): number {
    if (method) {
      return this.requestHistory.filter(r => r.method === method).length;
    }
    return this.requestHistory.length;
  }

  private recordRequest(method: string, params: any[]): void {
    this.requestHistory.push({ method, params });
  }

  private async simulateLatency(): Promise<void> {
    if (this.latency > 0) {
      await new Promise(resolve => setTimeout(resolve, this.latency));
    }
  }
}

/**
 * Mock Web3 Client
 */
export class MockWeb3Client extends EventEmitter {
  public connected: boolean = false;
  public requestHistory: Array<{ method: string; params: any[] }> = [];
  public mockResponses: Map<string, any> = new Map();
  public shouldFail: boolean = false;
  public failureCount: number = 0;
  public latency: number = 10;

  constructor(public config: any) {
    super();
  }

  async connect(): Promise<void> {
    if (this.shouldFail && this.failureCount-- > 0) {
      throw new Error('Mock connection failed');
    }
    await this.simulateLatency();
    this.connected = true;
    this.emit('connected');
  }

  async disconnect(): Promise<void> {
    this.connected = false;
    this.emit('disconnected');
  }

  async getBlockNumber(): Promise<number> {
    this.recordRequest('eth_blockNumber', []);
    if (!this.connected) throw new Error('Not connected');
    await this.simulateLatency();
    return this.mockResponses.get('blockNumber') || 18000000;
  }

  async getBalance(address: string): Promise<string> {
    this.recordRequest('eth_getBalance', [address]);
    if (!this.connected) throw new Error('Not connected');
    await this.simulateLatency();
    return this.mockResponses.get(`balance:${address}`) || '1000000000000000000';
  }

  async getTransactionCount(address: string): Promise<number> {
    this.recordRequest('eth_getTransactionCount', [address]);
    if (!this.connected) throw new Error('Not connected');
    await this.simulateLatency();
    return this.mockResponses.get(`nonce:${address}`) || 0;
  }

  async getTransaction(txHash: string): Promise<any> {
    this.recordRequest('eth_getTransactionByHash', [txHash]);
    if (!this.connected) throw new Error('Not connected');
    await this.simulateLatency();
    return this.mockResponses.get(`tx:${txHash}`) || null;
  }

  async getTransactionReceipt(txHash: string): Promise<any> {
    this.recordRequest('eth_getTransactionReceipt', [txHash]);
    if (!this.connected) throw new Error('Not connected');
    await this.simulateLatency();
    return this.mockResponses.get(`receipt:${txHash}`) || null;
  }

  async sendRawTransaction(signedTx: string): Promise<string> {
    this.recordRequest('eth_sendRawTransaction', [signedTx]);
    if (!this.connected) throw new Error('Not connected');
    if (this.shouldFail && this.failureCount-- > 0) {
      throw new Error('Transaction failed');
    }
    await this.simulateLatency();
    return this.mockResponses.get('txHash') || '0xmockhash123';
  }

  async estimateGas(transaction: any): Promise<string> {
    this.recordRequest('eth_estimateGas', [transaction]);
    if (!this.connected) throw new Error('Not connected');
    await this.simulateLatency();
    return this.mockResponses.get('gasEstimate') || '21000';
  }

  async getGasPrice(): Promise<string> {
    this.recordRequest('eth_gasPrice', []);
    if (!this.connected) throw new Error('Not connected');
    await this.simulateLatency();
    return this.mockResponses.get('gasPrice') || '20000000000';
  }

  async call(transaction: any, block: string = 'latest'): Promise<string> {
    this.recordRequest('eth_call', [transaction, block]);
    if (!this.connected) throw new Error('Not connected');
    await this.simulateLatency();
    return this.mockResponses.get('callResult') || '0x';
  }

  async subscribeNewHeads(callback: Function): Promise<string> {
    this.recordRequest('eth_subscribe', ['newHeads']);
    if (!this.connected) throw new Error('Not connected');
    const subId = 'mock-sub-' + Date.now();
    this.on(`newHeads:${subId}`, callback);
    return subId;
  }

  async subscribeLogs(filter: any, callback: Function): Promise<string> {
    this.recordRequest('eth_subscribe', ['logs', filter]);
    if (!this.connected) throw new Error('Not connected');
    const subId = 'mock-sub-' + Date.now();
    this.on(`logs:${subId}`, callback);
    return subId;
  }

  async unsubscribe(subscriptionId: string): Promise<boolean> {
    this.recordRequest('eth_unsubscribe', [subscriptionId]);
    this.removeAllListeners(`newHeads:${subscriptionId}`);
    this.removeAllListeners(`logs:${subscriptionId}`);
    return true;
  }

  isConnected(): boolean {
    return this.connected;
  }

  // Test utilities
  setMockResponse(key: string, value: any): void {
    this.mockResponses.set(key, value);
  }

  setLatency(ms: number): void {
    this.latency = ms;
  }

  setShouldFail(count: number = 1): void {
    this.shouldFail = true;
    this.failureCount = count;
  }

  clearRequestHistory(): void {
    this.requestHistory = [];
  }

  getRequestCount(method?: string): number {
    if (method) {
      return this.requestHistory.filter(r => r.method === method).length;
    }
    return this.requestHistory.length;
  }

  private recordRequest(method: string, params: any[]): void {
    this.requestHistory.push({ method, params });
  }

  private async simulateLatency(): Promise<void> {
    if (this.latency > 0) {
      await new Promise(resolve => setTimeout(resolve, this.latency));
    }
  }
}

/**
 * Mock Connection Pool
 */
export class MockConnectionPool {
  private connections: Map<string, Connection> = new Map();
  private availableIds: string[] = [];
  public acquireCount: number = 0;
  public releaseCount: number = 0;

  constructor(minConnections: number = 2) {
    for (let i = 0; i < minConnections; i++) {
      const conn: Connection = {
        id: `mock-conn-${i}`,
        url: `https://mock-${i}.example.com`,
        active: false,
        lastUsed: Date.now(),
        requestCount: 0,
        errorCount: 0,
      };
      this.connections.set(conn.id, conn);
      this.availableIds.push(conn.id);
    }
  }

  async acquire(): Promise<Connection> {
    this.acquireCount++;
    const id = this.availableIds.shift();
    if (!id) {
      throw new Error('No connections available');
    }
    const conn = this.connections.get(id)!;
    conn.active = true;
    conn.lastUsed = Date.now();
    return conn;
  }

  release(connection: Connection): void {
    this.releaseCount++;
    connection.active = false;
    connection.lastUsed = Date.now();
    if (!this.availableIds.includes(connection.id)) {
      this.availableIds.push(connection.id);
    }
  }

  markFailed(connection: Connection): void {
    connection.errorCount++;
  }

  getStats() {
    return {
      totalConnections: this.connections.size,
      availableConnections: this.availableIds.length,
      activeConnections: Array.from(this.connections.values()).filter(c => c.active).length,
      primaryUrl: 'https://mock.example.com',
    };
  }

  destroy(): void {
    this.connections.clear();
    this.availableIds = [];
  }
}

/**
 * Mock Rate Limiter
 */
export class MockRateLimiter {
  public acquireCount: number = 0;
  public waitCount: number = 0;
  private shouldThrottle: boolean = false;

  async acquire(tokens: number = 1): Promise<boolean> {
    this.acquireCount++;
    return !this.shouldThrottle;
  }

  async waitForToken(tokens: number = 1): Promise<void> {
    this.waitCount++;
    if (this.shouldThrottle) {
      await new Promise(resolve => setTimeout(resolve, 10));
    }
  }

  setThrottle(throttle: boolean): void {
    this.shouldThrottle = throttle;
  }

  reset(): void {
    this.acquireCount = 0;
    this.waitCount = 0;
    this.shouldThrottle = false;
  }
}
