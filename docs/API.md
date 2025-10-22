# Fueki Mobile Wallet API Documentation

## Table of Contents
1. [RPC Client Factory](#rpc-client-factory)
2. [Bitcoin Electrum Client](#bitcoin-electrum-client)
3. [Ethereum Web3 Client](#ethereum-web3-client)
4. [Common Utilities](#common-utilities)
5. [Types and Interfaces](#types-and-interfaces)
6. [Error Handling](#error-handling)

---

## RPC Client Factory

The `RPCClientFactory` is the main entry point for creating blockchain RPC clients with built-in connection pooling, rate limiting, and failover support.

### Creating Clients

#### Bitcoin Client

```typescript
import { RPCClientFactory, ChainType, NetworkType } from './networking/rpc';

const bitcoinClient = RPCClientFactory.createBitcoinClient({
  chain: ChainType.BITCOIN,
  network: NetworkType.MAINNET,
  timeout: 30000,
  maxRetries: 3,
  poolConfig: {
    minConnections: 2,
    maxConnections: 5,
    acquireTimeout: 5000,
    idleTimeout: 60000
  },
  rateLimitConfig: {
    requestsPerSecond: 5,
    burstSize: 10
  }
});

await bitcoinClient.connect();
```

#### Ethereum Client

```typescript
const ethereumClient = RPCClientFactory.createEthereumClient({
  chain: ChainType.ETHEREUM,
  network: NetworkType.MAINNET,
  timeout: 30000,
  maxRetries: 3,
  poolConfig: {
    minConnections: 2,
    maxConnections: 10,
    acquireTimeout: 5000,
    idleTimeout: 60000
  },
  rateLimitConfig: {
    requestsPerSecond: 10,
    burstSize: 20
  }
});

await ethereumClient.connect();
```

#### WebSocket Client

```typescript
const wsClient = RPCClientFactory.createWebSocketClient({
  chain: ChainType.ETHEREUM,
  network: NetworkType.MAINNET
});

await wsClient.connect();

wsClient.on('transaction', (event) => {
  console.log('New transaction:', event);
});
```

### Factory Methods

| Method | Description | Returns |
|--------|-------------|---------|
| `createBitcoinClient(options)` | Create Bitcoin Electrum client | `ElectrumClient` |
| `createEthereumClient(options)` | Create Ethereum Web3 client | `Web3Client` |
| `createWebSocketClient(options)` | Create WebSocket client | `WebSocketClient` |
| `getClient(chain, network)` | Get existing client instance | `ElectrumClient \| Web3Client` |
| `getWebSocketClient(chain, network)` | Get existing WebSocket client | `WebSocketClient` |
| `destroyClient(chain, network)` | Destroy specific client | `Promise<void>` |
| `destroyAll()` | Destroy all clients | `Promise<void>` |
| `getAllClients()` | Get all active clients | `Array<ClientInfo>` |

---

## Bitcoin Electrum Client

### Connection Management

```typescript
// Connect to Electrum server
await client.connect();

// Check connection status
const isConnected = client.isConnected();

// Disconnect
await client.disconnect();
```

### Address Operations

#### Get Balance

```typescript
const balance = await client.getBalance('bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh');
// Returns: { confirmed: 0.5, unconfirmed: 0.1, total: 0.6 }
```

#### Get Transaction History

```typescript
const history = await client.getHistory('bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh');
// Returns: ElectrumTransaction[]
```

#### Get UTXOs

```typescript
const utxos = await client.getUTXOs('bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh');
// Returns: ElectrumUTXO[]
```

### Transaction Operations

#### Get Transaction

```typescript
const tx = await client.getTransaction('txid');
// Returns: ElectrumTransaction
```

#### Broadcast Transaction

```typescript
const txid = await client.broadcastTransaction('0200000001...');
// Returns: transaction hash
```

#### Estimate Fee

```typescript
const feeRate = await client.estimateFee(6); // 6 blocks
// Returns: fee rate in BTC/KB
```

### Blockchain Operations

#### Get Block Height

```typescript
const height = await client.getBlockHeight();
// Returns: current block height
```

### Subscriptions

#### Subscribe to Address

```typescript
await client.subscribeAddress('bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh', (status) => {
  console.log('Address status changed:', status);
});
```

#### Unsubscribe

```typescript
await client.unsubscribeAddress('bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh');
```

### Types

```typescript
interface ElectrumBalance {
  confirmed: number;
  unconfirmed: number;
  total: number;
}

interface ElectrumUTXO {
  txid: string;
  vout: number;
  value: number;
  height: number;
  confirmations: number;
}

interface ElectrumTransaction {
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
```

---

## Ethereum Web3 Client

### Connection Management

```typescript
// Connect to Ethereum node
await client.connect();

// Check connection status
const isConnected = client.isConnected();

// Disconnect
await client.disconnect();
```

### Network Information

#### Get Chain ID

```typescript
const chainId = await client.getChainId();
// Returns: 1 (mainnet) or 11155111 (sepolia)
```

#### Get Block Number

```typescript
const blockNumber = await client.getBlockNumber();
// Returns: current block number
```

#### Get Network Info

```typescript
const info = await client.getNetworkInfo();
// Returns: { chainId, blockNumber, gasPrice }
```

### Block Operations

#### Get Block

```typescript
// By number
const block = await client.getBlock(12345678, false);

// By hash
const block = await client.getBlock('0x...', true); // with full transactions
```

### Account Operations

#### Get Balance

```typescript
const balance = await client.getBalance('0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb');
// Returns: { wei: '1000000000000000000', ether: '1.0' }
```

#### Get Transaction Count (Nonce)

```typescript
const nonce = await client.getTransactionCount('0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb');
// Returns: transaction count
```

### Transaction Operations

#### Get Transaction

```typescript
const tx = await client.getTransaction('0x...');
// Returns: EthereumTransaction
```

#### Get Transaction Receipt

```typescript
const receipt = await client.getTransactionReceipt('0x...');
// Returns: EthereumTransactionReceipt
```

#### Send Raw Transaction

```typescript
const txHash = await client.sendRawTransaction('0x...');
// Returns: transaction hash
```

### Gas Operations

#### Estimate Gas

```typescript
const gasEstimate = await client.estimateGas({
  from: '0x...',
  to: '0x...',
  value: '0x1000',
  data: '0x'
});
// Returns: estimated gas (hex string)
```

#### Get Gas Price

```typescript
const gasPrice = await client.getGasPrice();
// Returns: gas price in wei (hex string)
```

#### Get Fee History (EIP-1559)

```typescript
const feeHistory = await client.getFeeHistory(10, 'latest', [25, 50, 75]);
// Returns: { oldestBlock, baseFeePerGas, gasUsedRatio, reward }
```

### Contract Operations

#### Call Contract (Read-only)

```typescript
const result = await client.call({
  to: '0x...',
  data: '0x...' // encoded function call
});
// Returns: result (hex string)
```

#### Get Contract Code

```typescript
const code = await client.getCode('0x...');
// Returns: contract bytecode
```

#### Get Storage

```typescript
const value = await client.getStorageAt('0x...', '0x0');
// Returns: storage value at position
```

#### Get Logs

```typescript
const logs = await client.getLogs({
  fromBlock: '0x0',
  toBlock: 'latest',
  address: '0x...',
  topics: ['0x...']
});
// Returns: array of log entries
```

### Types

```typescript
interface EthereumBalance {
  wei: string;
  ether: string;
}

interface EthereumBlock {
  number: string;
  hash: string;
  parentHash: string;
  timestamp: string;
  transactions: string[] | EthereumTransaction[];
  gasLimit: string;
  gasUsed: string;
  miner: string;
  // ... additional fields
}

interface EthereumTransaction {
  hash: string;
  nonce: string;
  from: string;
  to: string | null;
  value: string;
  gas: string;
  gasPrice: string;
  input: string;
  blockHash: string | null;
  blockNumber: string | null;
  // ... additional fields
}

interface EthereumTransactionReceipt {
  transactionHash: string;
  blockHash: string;
  blockNumber: string;
  from: string;
  to: string | null;
  gasUsed: string;
  status: string;
  logs: Array<{...}>;
  // ... additional fields
}
```

---

## Common Utilities

### Rate Limiter

Token bucket rate limiting for RPC requests.

```typescript
import { RateLimiter } from './networking/rpc';

const limiter = new RateLimiter({
  requestsPerSecond: 10,
  burstSize: 20
});

// Wait for token availability
await limiter.waitForToken();

// Try to acquire token
const acquired = await limiter.acquire();

// Get available tokens
const tokens = limiter.getAvailableTokens();

// Reset limiter
limiter.reset();
```

### Connection Pool

Manages connection pooling with failover support.

```typescript
import { ConnectionPool } from './networking/rpc';

const pool = new ConnectionPool(
  {
    minConnections: 2,
    maxConnections: 10,
    acquireTimeout: 5000,
    idleTimeout: 60000
  },
  {
    primaryUrl: 'https://primary.example.com',
    fallbackUrls: ['https://backup1.example.com', 'https://backup2.example.com'],
    healthCheckInterval: 30000,
    failoverThreshold: 3
  }
);

// Acquire connection
const connection = await pool.acquire();

// Use connection...

// Release connection
pool.release(connection);

// Get pool statistics
const stats = pool.getStats();

// Destroy pool
pool.destroy();
```

### Retry Handler

Exponential backoff retry logic for failed requests.

```typescript
import { RetryHandler } from './networking/rpc';

const retryHandler = new RetryHandler({
  maxRetries: 3,
  initialDelay: 1000,
  maxDelay: 10000,
  backoffMultiplier: 2,
  retryableErrors: [-32000, -32001, -32603, 429]
});

// Execute with retry
const result = await retryHandler.execute(
  async () => {
    // Your async operation
    return await someOperation();
  },
  'operation-context'
);
```

### WebSocket Client

Real-time blockchain monitoring via WebSocket.

```typescript
import { WebSocketClient } from './networking/rpc';

const wsClient = new WebSocketClient({
  url: 'wss://example.com',
  reconnect: true,
  reconnectInterval: 5000,
  maxReconnectAttempts: 10,
  pingInterval: 30000
});

// Connect
await wsClient.connect();

// Subscribe to address
wsClient.subscribeToAddress('0x...');

// Subscribe to blocks
wsClient.subscribeToBlocks();

// Subscribe to pending transactions
wsClient.subscribeToPendingTransactions();

// Listen for events
wsClient.on('transaction', (event) => {
  console.log('Transaction event:', event);
});

wsClient.on('block', (block) => {
  console.log('New block:', block);
});

// Unsubscribe
wsClient.unsubscribe('address', '0x...');

// Disconnect
wsClient.disconnect();
```

### Network Configuration

Pre-configured network endpoints and settings.

```typescript
import {
  getNetworkConfig,
  getPrimaryEndpoint,
  getAllEndpoints,
  getExplorerUrl,
  getChainId,
  validateNetworkConfig,
  getRecommendedPoolConfig,
  getRecommendedRateLimitConfig
} from './networking/rpc';

// Get full network config
const config = getNetworkConfig(ChainType.ETHEREUM, NetworkType.MAINNET);

// Get primary endpoint
const endpoint = getPrimaryEndpoint(ChainType.ETHEREUM, NetworkType.MAINNET, 'http');

// Get all endpoints
const endpoints = getAllEndpoints(ChainType.ETHEREUM, NetworkType.MAINNET, 'http');

// Get explorer URL
const explorer = getExplorerUrl(ChainType.ETHEREUM, NetworkType.MAINNET);

// Get chain ID
const chainId = getChainId(NetworkType.MAINNET); // 1

// Validate config
const isValid = validateNetworkConfig(ChainType.ETHEREUM, NetworkType.MAINNET);

// Get recommended configs
const poolConfig = getRecommendedPoolConfig(ChainType.ETHEREUM);
const rateLimitConfig = getRecommendedRateLimitConfig(ChainType.ETHEREUM);
```

---

## Types and Interfaces

### Core Types

```typescript
enum NetworkType {
  MAINNET = 'mainnet',
  TESTNET = 'testnet'
}

enum ChainType {
  BITCOIN = 'bitcoin',
  ETHEREUM = 'ethereum'
}

interface RPCClientOptions {
  chain: ChainType;
  network: NetworkType;
  poolConfig?: Partial<ConnectionPoolConfig>;
  rateLimitConfig?: Partial<RateLimitConfig>;
  timeout?: number;
  maxRetries?: number;
  customEndpoints?: string[];
}

interface RPCResponse<T = any> {
  success: boolean;
  data?: T;
  error?: RPCError;
  requestId?: string;
  timestamp: number;
}
```

### Configuration Types

```typescript
interface ConnectionPoolConfig {
  minConnections: number;
  maxConnections: number;
  acquireTimeout: number;
  idleTimeout: number;
}

interface RateLimitConfig {
  requestsPerSecond: number;
  burstSize: number;
}

interface FailoverConfig {
  primaryUrl: string;
  fallbackUrls: string[];
  healthCheckInterval: number;
  failoverThreshold: number;
}

interface WebSocketConfig {
  url: string;
  reconnect: boolean;
  reconnectInterval: number;
  maxReconnectAttempts: number;
  pingInterval?: number;
}

interface RetryConfig {
  maxRetries: number;
  initialDelay: number;
  maxDelay: number;
  backoffMultiplier: number;
  retryableErrors: number[];
}
```

### Connection Types

```typescript
interface Connection {
  id: string;
  url: string;
  active: boolean;
  lastUsed: number;
  requestCount: number;
  errorCount: number;
}

interface HealthCheck {
  healthy: boolean;
  latency: number;
  lastCheck: number;
  blockHeight?: number;
}
```

---

## Error Handling

### Error Classes

```typescript
// Base RPC error
class RPCClientError extends Error {
  constructor(message: string, code: number, data?: any)
}

// Connection failed
class ConnectionError extends RPCClientError {
  code: -32000
}

// Request timeout
class TimeoutError extends RPCClientError {
  code: -32001
}

// Rate limit exceeded
class RateLimitError extends RPCClientError {
  code: -32002
}

// Validation failed
class ValidationError extends RPCClientError {
  code: -32003
}
```

### Error Handling Examples

```typescript
try {
  const balance = await client.getBalance(address);
} catch (error) {
  if (error instanceof ConnectionError) {
    console.error('Connection failed:', error.message);
    // Handle connection error
  } else if (error instanceof TimeoutError) {
    console.error('Request timeout:', error.message);
    // Handle timeout
  } else if (error instanceof RateLimitError) {
    console.error('Rate limit exceeded:', error.message);
    // Wait and retry
  } else if (error instanceof ValidationError) {
    console.error('Validation failed:', error.message);
    // Handle invalid input
  } else {
    console.error('Unknown error:', error);
  }
}
```

### Error Codes

| Code | Error | Description |
|------|-------|-------------|
| -32000 | ConnectionError | Failed to connect to RPC server |
| -32001 | TimeoutError | Request exceeded timeout limit |
| -32002 | RateLimitError | Rate limit exceeded |
| -32003 | ValidationError | Invalid parameters or data |
| -32004 | RPCClientError | Operation failed after retries |
| -32005 | RPCClientError | Transaction broadcast failed |
| -32006 | RPCClientError | Transaction send failed |
| -32007 | RPCClientError | WebSocket message send failed |
| -32008 | RPCClientError | WebSocket message parse failed |

---

## Best Practices

### 1. Connection Management

```typescript
// Create client once and reuse
const client = RPCClientFactory.createEthereumClient(options);
await client.connect();

// Use the same client for multiple operations
const balance = await client.getBalance(address);
const nonce = await client.getTransactionCount(address);

// Clean up when done
await client.disconnect();
```

### 2. Error Handling

```typescript
// Always handle errors appropriately
try {
  await client.sendRawTransaction(signedTx);
} catch (error) {
  if (error instanceof TimeoutError) {
    // Transaction might still succeed, check receipt later
  } else if (error instanceof ValidationError) {
    // Fix transaction parameters
  }
}
```

### 3. Rate Limiting

```typescript
// Built-in rate limiting prevents hitting API limits
const client = RPCClientFactory.createEthereumClient({
  ...options,
  rateLimitConfig: {
    requestsPerSecond: 10,
    burstSize: 20 // Allow bursts up to 20 requests
  }
});
```

### 4. Connection Pooling

```typescript
// Pool automatically manages connections
const client = RPCClientFactory.createEthereumClient({
  ...options,
  poolConfig: {
    minConnections: 2,  // Keep 2 connections warm
    maxConnections: 10, // Scale up to 10 under load
    idleTimeout: 60000  // Close idle connections after 1 minute
  }
});
```

### 5. Failover

```typescript
// Automatic failover to backup endpoints
const client = RPCClientFactory.createEthereumClient({
  ...options,
  customEndpoints: [
    'https://primary.example.com',
    'https://backup1.example.com',
    'https://backup2.example.com'
  ]
});
// Client automatically switches to backup on primary failure
```

---

## Code Examples

### Complete Bitcoin Example

```typescript
import { RPCClientFactory, ChainType, NetworkType } from './networking/rpc';

async function bitcoinExample() {
  // Create client
  const client = RPCClientFactory.createBitcoinClient({
    chain: ChainType.BITCOIN,
    network: NetworkType.MAINNET
  });

  try {
    // Connect
    await client.connect();

    // Get balance
    const address = 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
    const balance = await client.getBalance(address);
    console.log('Balance:', balance);

    // Get UTXOs
    const utxos = await client.getUTXOs(address);
    console.log('UTXOs:', utxos);

    // Get transaction history
    const history = await client.getHistory(address);
    console.log('History:', history);

    // Estimate fee
    const feeRate = await client.estimateFee(6);
    console.log('Fee rate:', feeRate);

  } finally {
    await client.disconnect();
  }
}
```

### Complete Ethereum Example

```typescript
import { RPCClientFactory, ChainType, NetworkType } from './networking/rpc';

async function ethereumExample() {
  // Create client
  const client = RPCClientFactory.createEthereumClient({
    chain: ChainType.ETHEREUM,
    network: NetworkType.MAINNET
  });

  try {
    // Connect
    await client.connect();

    // Get network info
    const info = await client.getNetworkInfo();
    console.log('Network:', info);

    // Get balance
    const address = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb';
    const balance = await client.getBalance(address);
    console.log('Balance:', balance);

    // Get nonce
    const nonce = await client.getTransactionCount(address);
    console.log('Nonce:', nonce);

    // Get gas price
    const gasPrice = await client.getGasPrice();
    console.log('Gas price:', gasPrice);

  } finally {
    await client.disconnect();
  }
}
```

### WebSocket Monitoring Example

```typescript
import { RPCClientFactory, ChainType, NetworkType } from './networking/rpc';

async function monitorTransactions() {
  const wsClient = RPCClientFactory.createWebSocketClient({
    chain: ChainType.ETHEREUM,
    network: NetworkType.MAINNET
  });

  await wsClient.connect();

  // Subscribe to address
  const address = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb';
  wsClient.subscribeToAddress(address);

  // Listen for transactions
  wsClient.on('transaction', (event) => {
    console.log('Transaction:', event);
  });

  // Subscribe to new blocks
  wsClient.subscribeToBlocks();
  wsClient.on('block', (block) => {
    console.log('New block:', block);
  });

  // Handle connection events
  wsClient.on('connected', () => console.log('Connected'));
  wsClient.on('disconnected', () => console.log('Disconnected'));
  wsClient.on('error', (err) => console.error('Error:', err));
}
```
