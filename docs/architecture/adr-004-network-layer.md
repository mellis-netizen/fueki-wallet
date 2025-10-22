# ADR-004: Network Layer Design

## Status
**ACCEPTED** - 2025-10-21

## Context

The Fueki Mobile Wallet needs a robust network layer to communicate with multiple blockchain networks. Each blockchain has different RPC protocols, connection requirements, and real-time capabilities.

### Requirements
1. **Multi-Provider Support**: Connect to multiple RPC providers with failover
2. **Real-Time Updates**: WebSocket support for block and transaction notifications
3. **Reliability**: Request retry, timeout handling, connection recovery
4. **Performance**: Request batching, caching, connection pooling
5. **Security**: TLS/SSL, request signing, rate limiting
6. **Offline Support**: Queue requests when offline, sync when online

### Constraints
- React Native environment (no native Node.js net module)
- Mobile network conditions (spotty connectivity, data limits)
- Different blockchain protocols (Bitcoin Core RPC, Ethereum JSON-RPC, etc.)
- Must work with third-party providers (Alchemy, Infura, etc.)

## Decision

We will implement a **layered network architecture** with provider abstraction, connection management, and resilience patterns.

## Architecture

### High-Level Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Application Layer                            │
│              (Transaction Manager, Balance Manager)             │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Chain Adapters                                │
│     (Bitcoin Adapter, Ethereum Adapter)                         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Network Service Layer                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ RPC Client   │  │ WebSocket    │  │ Request      │         │
│  │ Manager      │  │ Manager      │  │ Queue        │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Provider Layer                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Primary      │  │ Fallback     │  │ Custom       │         │
│  │ Provider     │  │ Provider     │  │ Provider     │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Transport Layer                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ HTTP/HTTPS (axios)                                       │  │
│  │ - Request/Response                                       │  │
│  │ - Interceptors (auth, logging)                           │  │
│  │ - Retry logic                                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ WebSocket (ws)                                           │  │
│  │ - Persistent connections                                 │  │
│  │ - Auto-reconnect                                         │  │
│  │ - Heartbeat/ping                                         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Component Details

#### 1. RPC Client Interface

```typescript
// src/core/network/IRPCClient.ts

export interface IRPCClient {
  // Basic RPC operations
  call<T = any>(method: string, params?: any[]): Promise<T>;
  batchCall<T = any>(requests: RPCRequest[]): Promise<T[]>;

  // Connection management
  connect(): Promise<void>;
  disconnect(): Promise<void>;
  isConnected(): boolean;

  // Provider management
  getActiveProvider(): ProviderConfig;
  switchProvider(providerId: string): void;
  addProvider(config: ProviderConfig): void;
}

export interface RPCRequest {
  id: string | number;
  method: string;
  params?: any[];
}

export interface RPCResponse<T = any> {
  id: string | number;
  result?: T;
  error?: RPCError;
}

export interface RPCError {
  code: number;
  message: string;
  data?: any;
}

export interface ProviderConfig {
  id: string;
  name: string;
  url: string;
  wsUrl?: string;
  apiKey?: string;
  priority: number;
  timeout?: number;
  maxRetries?: number;
}
```

#### 2. Base RPC Client Implementation

```typescript
// src/core/network/BaseRPCClient.ts

import axios, { AxiosInstance } from 'axios';
import { IRPCClient, RPCRequest, RPCResponse, ProviderConfig } from './IRPCClient';

export abstract class BaseRPCClient implements IRPCClient {
  protected axiosInstance: AxiosInstance;
  protected providers: ProviderConfig[];
  protected activeProviderIndex: number = 0;
  protected requestId: number = 1;

  constructor(providers: ProviderConfig[]) {
    if (providers.length === 0) {
      throw new Error('At least one provider is required');
    }

    this.providers = providers.sort((a, b) => a.priority - b.priority);
    this.axiosInstance = this.createAxiosInstance();
  }

  protected createAxiosInstance(): AxiosInstance {
    const instance = axios.create({
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // Request interceptor
    instance.interceptors.request.use(
      config => {
        const provider = this.getActiveProvider();

        // Add API key if needed
        if (provider.apiKey) {
          config.headers['Authorization'] = `Bearer ${provider.apiKey}`;
        }

        // Log request (development only)
        if (__DEV__) {
          console.log(`[RPC Request] ${config.method?.toUpperCase()} ${config.url}`);
        }

        return config;
      },
      error => Promise.reject(error)
    );

    // Response interceptor
    instance.interceptors.response.use(
      response => response,
      async error => {
        if (this.shouldRetry(error)) {
          return this.retryRequest(error.config);
        }
        return Promise.reject(error);
      }
    );

    return instance;
  }

  async call<T = any>(method: string, params: any[] = []): Promise<T> {
    const request: RPCRequest = {
      id: this.requestId++,
      method,
      params,
    };

    const response = await this.executeRequest<T>([request]);
    return response[0];
  }

  async batchCall<T = any>(requests: RPCRequest[]): Promise<T[]> {
    return await this.executeRequest<T>(requests);
  }

  protected async executeRequest<T>(requests: RPCRequest[]): Promise<T[]> {
    const provider = this.getActiveProvider();
    const isBatch = requests.length > 1;

    try {
      const response = await this.axiosInstance.post<RPCResponse<T> | RPCResponse<T>[]>(
        provider.url,
        isBatch ? requests : requests[0],
        {
          timeout: provider.timeout || 30000,
        }
      );

      const results = isBatch
        ? (response.data as RPCResponse<T>[])
        : [response.data as RPCResponse<T>];

      // Check for RPC errors
      const errors = results.filter(r => r.error);
      if (errors.length > 0) {
        throw new Error(`RPC Error: ${errors[0].error!.message}`);
      }

      return results.map(r => r.result!);
    } catch (error) {
      // Try failover provider
      if (this.canFailover()) {
        console.warn(`Provider ${provider.name} failed, trying failover...`);
        this.switchToNextProvider();
        return this.executeRequest<T>(requests);
      }

      throw error;
    }
  }

  protected shouldRetry(error: any): boolean {
    // Retry on network errors or 5xx server errors
    return (
      !error.response ||
      error.code === 'ECONNABORTED' ||
      error.code === 'ETIMEDOUT' ||
      (error.response.status >= 500 && error.response.status < 600)
    );
  }

  protected async retryRequest(config: any, attempt: number = 0): Promise<any> {
    const provider = this.getActiveProvider();
    const maxRetries = provider.maxRetries || 3;

    if (attempt >= maxRetries) {
      throw new Error('Max retries exceeded');
    }

    // Exponential backoff
    const delay = Math.min(1000 * Math.pow(2, attempt), 10000);
    await new Promise(resolve => setTimeout(resolve, delay));

    try {
      return await this.axiosInstance.request(config);
    } catch (error) {
      return this.retryRequest(config, attempt + 1);
    }
  }

  getActiveProvider(): ProviderConfig {
    return this.providers[this.activeProviderIndex];
  }

  switchProvider(providerId: string): void {
    const index = this.providers.findIndex(p => p.id === providerId);
    if (index === -1) {
      throw new Error(`Provider not found: ${providerId}`);
    }
    this.activeProviderIndex = index;
  }

  protected switchToNextProvider(): void {
    this.activeProviderIndex = (this.activeProviderIndex + 1) % this.providers.length;
  }

  protected canFailover(): boolean {
    return this.providers.length > 1;
  }

  addProvider(config: ProviderConfig): void {
    this.providers.push(config);
    this.providers.sort((a, b) => a.priority - b.priority);
  }

  async connect(): Promise<void> {
    // Test connection
    try {
      await this.axiosInstance.get(this.getActiveProvider().url, { timeout: 5000 });
    } catch (error) {
      if (this.canFailover()) {
        this.switchToNextProvider();
        return this.connect();
      }
      throw new Error('Failed to connect to any provider');
    }
  }

  async disconnect(): Promise<void> {
    // Cleanup if needed
  }

  isConnected(): boolean {
    return true; // HTTP is stateless, always "connected"
  }
}
```

#### 3. Bitcoin RPC Client

```typescript
// src/core/network/BitcoinRPCClient.ts

import { BaseRPCClient } from './BaseRPCClient';
import { Network } from 'bitcoinjs-lib';

export class BitcoinRPCClient extends BaseRPCClient {
  private network: Network;

  constructor(network: Network, providers?: ProviderConfig[]) {
    const defaultProviders = providers || BitcoinRPCClient.getDefaultProviders(network);
    super(defaultProviders);
    this.network = network;
  }

  static getDefaultProviders(network: Network): ProviderConfig[] {
    const isMainnet = network === bitcoin.networks.bitcoin;

    return [
      {
        id: 'blockstream',
        name: 'Blockstream',
        url: isMainnet
          ? 'https://blockstream.info/api'
          : 'https://blockstream.info/testnet/api',
        priority: 1,
        timeout: 30000,
        maxRetries: 3,
      },
      {
        id: 'mempool',
        name: 'Mempool.space',
        url: isMainnet
          ? 'https://mempool.space/api'
          : 'https://mempool.space/testnet/api',
        priority: 2,
        timeout: 30000,
        maxRetries: 3,
      },
    ];
  }

  // Bitcoin-specific methods

  async getUTXOs(address: string): Promise<UTXO[]> {
    const provider = this.getActiveProvider();
    const response = await this.axiosInstance.get(`${provider.url}/address/${address}/utxo`);
    return response.data.map((utxo: any) => ({
      txid: utxo.txid,
      vout: utxo.vout,
      value: utxo.value,
      scriptPubKey: utxo.scriptpubkey,
      confirmations: utxo.status.confirmed ? utxo.status.block_height : 0,
    }));
  }

  async broadcastTransaction(rawTx: string): Promise<string> {
    const provider = this.getActiveProvider();
    const response = await this.axiosInstance.post(`${provider.url}/tx`, rawTx, {
      headers: { 'Content-Type': 'text/plain' },
    });
    return response.data;
  }

  async getTransactionInfo(txId: string): Promise<BitcoinTransaction> {
    const provider = this.getActiveProvider();
    const response = await this.axiosInstance.get(`${provider.url}/tx/${txId}`);
    return this.parseBitcoinTransaction(response.data);
  }

  async estimateSmartFee(blocks: number[]): Promise<{ slow: number; medium: number; fast: number }> {
    const provider = this.getActiveProvider();
    const response = await this.axiosInstance.get(`${provider.url}/fee-estimates`);

    return {
      slow: response.data[blocks[0]] || 1,
      medium: response.data[blocks[1]] || 5,
      fast: response.data[blocks[2]] || 10,
    };
  }

  async getBlockHeight(): Promise<number> {
    const provider = this.getActiveProvider();
    const response = await this.axiosInstance.get(`${provider.url}/blocks/tip/height`);
    return response.data;
  }

  private parseBitcoinTransaction(data: any): BitcoinTransaction {
    return {
      txid: data.txid,
      version: data.version,
      locktime: data.locktime,
      vin: data.vin,
      vout: data.vout,
      size: data.size,
      weight: data.weight,
      fee: data.fee,
      status: {
        confirmed: data.status.confirmed,
        blockHeight: data.status.block_height,
        blockHash: data.status.block_hash,
        blockTime: data.status.block_time,
      },
    };
  }
}

export interface UTXO {
  txid: string;
  vout: number;
  value: number;
  scriptPubKey: string;
  confirmations: number;
}

export interface BitcoinTransaction {
  txid: string;
  version: number;
  locktime: number;
  vin: any[];
  vout: any[];
  size: number;
  weight: number;
  fee: number;
  status: {
    confirmed: boolean;
    blockHeight?: number;
    blockHash?: string;
    blockTime?: number;
  };
}
```

#### 4. Ethereum RPC Client

```typescript
// src/core/network/EthereumRPCClient.ts

import { BaseRPCClient } from './BaseRPCClient';

export class EthereumRPCClient extends BaseRPCClient {
  private chainId: number;

  constructor(chainId: number, providers?: ProviderConfig[]) {
    const defaultProviders = providers || EthereumRPCClient.getDefaultProviders(chainId);
    super(defaultProviders);
    this.chainId = chainId;
  }

  static getDefaultProviders(chainId: number): ProviderConfig[] {
    const isMainnet = chainId === 1;

    return [
      {
        id: 'alchemy',
        name: 'Alchemy',
        url: isMainnet
          ? 'https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY'
          : 'https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY',
        wsUrl: isMainnet
          ? 'wss://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY'
          : 'wss://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY',
        priority: 1,
        timeout: 30000,
        maxRetries: 3,
      },
      {
        id: 'infura',
        name: 'Infura',
        url: isMainnet
          ? 'https://mainnet.infura.io/v3/YOUR_API_KEY'
          : 'https://sepolia.infura.io/v3/YOUR_API_KEY',
        wsUrl: isMainnet
          ? 'wss://mainnet.infura.io/ws/v3/YOUR_API_KEY'
          : 'wss://sepolia.infura.io/ws/v3/YOUR_API_KEY',
        priority: 2,
        timeout: 30000,
        maxRetries: 3,
      },
    ];
  }

  // Ethereum JSON-RPC methods

  async getBlockNumber(): Promise<number> {
    const result = await this.call<string>('eth_blockNumber');
    return parseInt(result, 16);
  }

  async getBalance(address: string, blockTag: string = 'latest'): Promise<string> {
    return await this.call<string>('eth_getBalance', [address, blockTag]);
  }

  async getTransactionCount(address: string, blockTag: string = 'latest'): Promise<number> {
    const result = await this.call<string>('eth_getTransactionCount', [address, blockTag]);
    return parseInt(result, 16);
  }

  async getGasPrice(): Promise<string> {
    return await this.call<string>('eth_gasPrice');
  }

  async getFeeHistory(blockCount: number, newestBlock: string, rewardPercentiles: number[]): Promise<any> {
    return await this.call('eth_feeHistory', [
      `0x${blockCount.toString(16)}`,
      newestBlock,
      rewardPercentiles,
    ]);
  }

  async estimateGas(transaction: any): Promise<string> {
    return await this.call<string>('eth_estimateGas', [transaction]);
  }

  async sendRawTransaction(signedTx: string): Promise<string> {
    return await this.call<string>('eth_sendRawTransaction', [signedTx]);
  }

  async getTransactionByHash(txHash: string): Promise<any> {
    return await this.call('eth_getTransactionByHash', [txHash]);
  }

  async getTransactionReceipt(txHash: string): Promise<any> {
    return await this.call('eth_getTransactionReceipt', [txHash]);
  }

  async getBlockByNumber(blockNumber: number, fullTransactions: boolean = false): Promise<any> {
    const blockHex = `0x${blockNumber.toString(16)}`;
    return await this.call('eth_getBlockByNumber', [blockHex, fullTransactions]);
  }

  async call(method: string, params: any[] = []): Promise<any> {
    return super.call(method, params);
  }
}
```

#### 5. WebSocket Manager

```typescript
// src/core/network/WebSocketManager.ts

import { EventEmitter } from 'events';

export class WebSocketManager extends EventEmitter {
  private ws: WebSocket | null = null;
  private url: string;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 5;
  private reconnectDelay: number = 1000;
  private heartbeatInterval: NodeJS.Timeout | null = null;
  private subscriptions: Map<string, Set<string>> = new Map();

  constructor(url: string) {
    super();
    this.url = url;
  }

  async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        this.ws = new WebSocket(this.url);

        this.ws.onopen = () => {
          console.log('[WebSocket] Connected');
          this.reconnectAttempts = 0;
          this.startHeartbeat();
          this.resubscribe();
          resolve();
        };

        this.ws.onmessage = (event) => {
          this.handleMessage(event.data);
        };

        this.ws.onerror = (error) => {
          console.error('[WebSocket] Error:', error);
          this.emit('error', error);
        };

        this.ws.onclose = () => {
          console.log('[WebSocket] Disconnected');
          this.stopHeartbeat();
          this.reconnect();
        };
      } catch (error) {
        reject(error);
      }
    });
  }

  disconnect(): void {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this.stopHeartbeat();
  }

  subscribe(channel: string, subscriptionId: string): void {
    if (!this.subscriptions.has(channel)) {
      this.subscriptions.set(channel, new Set());
    }
    this.subscriptions.get(channel)!.add(subscriptionId);

    if (this.isConnected()) {
      this.sendSubscription(channel, subscriptionId);
    }
  }

  unsubscribe(channel: string, subscriptionId: string): void {
    const subs = this.subscriptions.get(channel);
    if (subs) {
      subs.delete(subscriptionId);
      if (subs.size === 0) {
        this.subscriptions.delete(channel);
      }
    }

    if (this.isConnected()) {
      this.sendUnsubscription(channel, subscriptionId);
    }
  }

  private sendSubscription(channel: string, subscriptionId: string): void {
    if (!this.ws) return;

    const message = JSON.stringify({
      jsonrpc: '2.0',
      id: subscriptionId,
      method: 'eth_subscribe',
      params: [channel],
    });

    this.ws.send(message);
  }

  private sendUnsubscription(channel: string, subscriptionId: string): void {
    if (!this.ws) return;

    const message = JSON.stringify({
      jsonrpc: '2.0',
      id: Date.now(),
      method: 'eth_unsubscribe',
      params: [subscriptionId],
    });

    this.ws.send(message);
  }

  private handleMessage(data: string): void {
    try {
      const message = JSON.parse(data);

      // Handle subscription updates
      if (message.method === 'eth_subscription') {
        this.emit('subscription', message.params);
      } else if (message.result) {
        this.emit('message', message);
      } else if (message.error) {
        this.emit('error', message.error);
      }
    } catch (error) {
      console.error('[WebSocket] Failed to parse message:', error);
    }
  }

  private startHeartbeat(): void {
    this.heartbeatInterval = setInterval(() => {
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify({ type: 'ping' }));
      }
    }, 30000); // 30 seconds
  }

  private stopHeartbeat(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
  }

  private async reconnect(): Promise<void> {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('[WebSocket] Max reconnect attempts reached');
      this.emit('max_reconnect_attempts');
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);

    console.log(`[WebSocket] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);

    setTimeout(() => {
      this.connect().catch(error => {
        console.error('[WebSocket] Reconnect failed:', error);
      });
    }, delay);
  }

  private resubscribe(): void {
    for (const [channel, subscriptionIds] of this.subscriptions.entries()) {
      for (const id of subscriptionIds) {
        this.sendSubscription(channel, id);
      }
    }
  }

  isConnected(): boolean {
    return this.ws !== null && this.ws.readyState === WebSocket.OPEN;
  }
}
```

#### 6. Request Queue (Offline Support)

```typescript
// src/core/network/RequestQueue.ts

import AsyncStorage from '@react-native-async-storage/async-storage';
import NetInfo from '@react-native-community/netinfo';

export class RequestQueue {
  private queue: QueuedRequest[] = [];
  private isProcessing: boolean = false;
  private storageKey: string = '@fueki:request_queue';

  constructor() {
    this.loadQueue();
    this.listenToNetworkChanges();
  }

  async enqueue(request: QueuedRequest): Promise<void> {
    this.queue.push(request);
    await this.saveQueue();

    if (await this.isOnline()) {
      this.processQueue();
    }
  }

  private async processQueue(): Promise<void> {
    if (this.isProcessing || this.queue.length === 0) {
      return;
    }

    this.isProcessing = true;

    while (this.queue.length > 0) {
      const request = this.queue[0];

      try {
        await this.executeRequest(request);
        this.queue.shift(); // Remove from queue on success
        await this.saveQueue();
      } catch (error) {
        console.error('[RequestQueue] Failed to execute request:', error);

        // Check if should retry
        if (request.retries < request.maxRetries) {
          request.retries++;
          await this.saveQueue();
        } else {
          // Remove failed request after max retries
          this.queue.shift();
          await this.saveQueue();
        }

        break; // Stop processing on error
      }
    }

    this.isProcessing = false;
  }

  private async executeRequest(request: QueuedRequest): Promise<void> {
    // Execute the request based on type
    switch (request.type) {
      case 'broadcast_transaction':
        // Broadcast transaction
        break;
      case 'api_call':
        // Make API call
        break;
      default:
        throw new Error(`Unknown request type: ${request.type}`);
    }
  }

  private async loadQueue(): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(this.storageKey);
      if (data) {
        this.queue = JSON.parse(data);
      }
    } catch (error) {
      console.error('[RequestQueue] Failed to load queue:', error);
    }
  }

  private async saveQueue(): Promise<void> {
    try {
      await AsyncStorage.setItem(this.storageKey, JSON.stringify(this.queue));
    } catch (error) {
      console.error('[RequestQueue] Failed to save queue:', error);
    }
  }

  private listenToNetworkChanges(): void {
    NetInfo.addEventListener(state => {
      if (state.isConnected) {
        console.log('[RequestQueue] Network connected, processing queue');
        this.processQueue();
      }
    });
  }

  private async isOnline(): Promise<boolean> {
    const state = await NetInfo.fetch();
    return state.isConnected ?? false;
  }
}

interface QueuedRequest {
  id: string;
  type: string;
  data: any;
  retries: number;
  maxRetries: number;
  timestamp: number;
}
```

## Security Considerations

### 1. **Certificate Pinning**
```typescript
// Validate server certificates for known providers
const trustedCertificates = {
  'alchemy.com': 'SHA256_FINGERPRINT',
  'infura.io': 'SHA256_FINGERPRINT',
};
```

### 2. **API Key Management**
- Store API keys in encrypted storage
- Never log API keys
- Rotate keys periodically

### 3. **Request Signing**
- Sign sensitive requests
- Validate responses
- Prevent replay attacks

### 4. **Rate Limiting**
```typescript
class RateLimiter {
  private requests: number[] = [];
  private maxRequests: number = 100;
  private timeWindow: number = 60000; // 1 minute

  async checkLimit(): Promise<boolean> {
    const now = Date.now();
    this.requests = this.requests.filter(t => t > now - this.timeWindow);

    if (this.requests.length >= this.maxRequests) {
      throw new Error('Rate limit exceeded');
    }

    this.requests.push(now);
    return true;
  }
}
```

## Performance Optimizations

### 1. **Request Batching**
```typescript
// Batch multiple requests into one
const results = await rpcClient.batchCall([
  { id: 1, method: 'eth_getBalance', params: [address1] },
  { id: 2, method: 'eth_getBalance', params: [address2] },
  { id: 3, method: 'eth_getBalance', params: [address3] },
]);
```

### 2. **Response Caching**
```typescript
class ResponseCache {
  private cache: Map<string, CacheEntry> = new Map();
  private ttl: number = 30000; // 30 seconds

  set(key: string, value: any): void {
    this.cache.set(key, { value, timestamp: Date.now() });
  }

  get(key: string): any | null {
    const entry = this.cache.get(key);
    if (!entry) return null;

    if (Date.now() - entry.timestamp > this.ttl) {
      this.cache.delete(key);
      return null;
    }

    return entry.value;
  }
}
```

### 3. **Connection Pooling**
- Reuse HTTP connections
- Limit concurrent connections
- Close idle connections

## Testing Strategy

### Unit Tests
```typescript
describe('BitcoinRPCClient', () => {
  it('should failover to backup provider on error', async () => {
    const client = new BitcoinRPCClient(bitcoin.networks.bitcoin);
    // Mock primary provider failure
    // Verify failover to secondary provider
  });

  it('should retry failed requests', async () => {
    // Test exponential backoff
  });

  it('should batch requests correctly', async () => {
    // Test batch request formatting
  });
});
```

### Integration Tests
- Test real provider connections
- Test WebSocket reconnection
- Test offline queue persistence

## Monitoring & Observability

### Metrics
- Request latency per provider
- Success/failure rates
- Failover frequency
- Cache hit rates
- Queue size

### Logging
```typescript
class NetworkLogger {
  logRequest(provider: string, method: string, duration: number) {
    console.log(`[Network] ${provider} - ${method} - ${duration}ms`);
  }

  logError(provider: string, error: Error) {
    console.error(`[Network] ${provider} - Error:`, error.message);
  }
}
```

## References

- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)
- [Ethereum JSON-RPC API](https://ethereum.org/en/developers/docs/apis/json-rpc/)
- [Bitcoin Core RPC API](https://developer.bitcoin.org/reference/rpc/)
- [WebSocket Protocol](https://datatracker.ietf.org/doc/html/rfc6455)

---

**Related ADRs:**
- [ADR-003: Multi-Chain Support](./adr-003-multi-chain-support.md)
- [ADR-005: State Management](./adr-005-state-management.md)
- [ADR-008: Error Handling](./adr-008-error-handling.md)
