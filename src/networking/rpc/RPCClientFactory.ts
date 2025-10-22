/**
 * RPC Client Factory
 * Factory for creating and managing RPC clients
 */

import { ElectrumClient, ElectrumConfig } from './bitcoin/ElectrumClient';
import { Web3Client, Web3Config } from './ethereum/Web3Client';
import { WebSocketClient } from './common/WebSocketClient';
import { RateLimiter } from './common/RateLimiter';
import { ConnectionPool } from './common/ConnectionPool';
import { RetryHandler } from './common/RetryHandler';
import {
  ChainType,
  NetworkType,
  ConnectionPoolConfig,
  RateLimitConfig,
  FailoverConfig,
  WebSocketConfig,
} from './common/types';
import {
  getNetworkConfig,
  getPrimaryEndpoint,
  getAllEndpoints,
  getChainId,
  getRecommendedPoolConfig,
  getRecommendedRateLimitConfig,
} from './common/NetworkConfig';

export interface RPCClientOptions {
  chain: ChainType;
  network: NetworkType;
  poolConfig?: Partial<ConnectionPoolConfig>;
  rateLimitConfig?: Partial<RateLimitConfig>;
  timeout?: number;
  maxRetries?: number;
  customEndpoints?: string[];
}

export class RPCClientFactory {
  private static instances: Map<string, ElectrumClient | Web3Client> = new Map();
  private static wsClients: Map<string, WebSocketClient> = new Map();

  /**
   * Create or get Bitcoin Electrum client
   */
  public static createBitcoinClient(
    options: RPCClientOptions
  ): ElectrumClient {
    const cacheKey = `${options.chain}-${options.network}`;

    // Return cached instance if exists
    if (this.instances.has(cacheKey)) {
      return this.instances.get(cacheKey) as ElectrumClient;
    }

    // Get network configuration
    const networkConfig = getNetworkConfig(options.chain, options.network);
    const endpoints = options.customEndpoints ||
      getAllEndpoints(options.chain, options.network, 'electrum');

    if (endpoints.length === 0) {
      throw new Error(`No Electrum endpoints available for ${options.chain} ${options.network}`);
    }

    // Create connection pool
    const poolConfig: ConnectionPoolConfig = {
      ...getRecommendedPoolConfig(options.chain),
      ...options.poolConfig,
    };

    const failoverConfig: FailoverConfig = {
      primaryUrl: endpoints[0],
      fallbackUrls: endpoints.slice(1),
      healthCheckInterval: 30000,
      failoverThreshold: 3,
    };

    const connectionPool = new ConnectionPool(poolConfig, failoverConfig);

    // Create rate limiter
    const rateLimitConfig: RateLimitConfig = {
      ...getRecommendedRateLimitConfig(options.chain),
      ...options.rateLimitConfig,
    };

    const rateLimiter = new RateLimiter(rateLimitConfig);

    // Create client config
    const config: ElectrumConfig = {
      url: endpoints[0],
      network: options.network,
      timeout: options.timeout || 30000,
      maxRetries: options.maxRetries || 3,
      protocol: 'ssl',
      version: '1.4',
    };

    // Create and cache client
    const client = new ElectrumClient(
      config,
      rateLimiter,
      connectionPool,
      {
        maxRetries: options.maxRetries || 3,
        initialDelay: 1000,
        maxDelay: 10000,
        backoffMultiplier: 2,
        retryableErrors: [-32000, -32001, -32603],
      }
    );

    this.instances.set(cacheKey, client);
    return client;
  }

  /**
   * Create or get Ethereum Web3 client
   */
  public static createEthereumClient(
    options: RPCClientOptions
  ): Web3Client {
    const cacheKey = `${options.chain}-${options.network}`;

    // Return cached instance if exists
    if (this.instances.has(cacheKey)) {
      return this.instances.get(cacheKey) as Web3Client;
    }

    // Get network configuration
    const networkConfig = getNetworkConfig(options.chain, options.network);
    const endpoints = options.customEndpoints ||
      getAllEndpoints(options.chain, options.network, 'http');

    if (endpoints.length === 0) {
      throw new Error(`No HTTP endpoints available for ${options.chain} ${options.network}`);
    }

    // Create connection pool
    const poolConfig: ConnectionPoolConfig = {
      ...getRecommendedPoolConfig(options.chain),
      ...options.poolConfig,
    };

    const failoverConfig: FailoverConfig = {
      primaryUrl: endpoints[0],
      fallbackUrls: endpoints.slice(1),
      healthCheckInterval: 30000,
      failoverThreshold: 3,
    };

    const connectionPool = new ConnectionPool(poolConfig, failoverConfig);

    // Create rate limiter
    const rateLimitConfig: RateLimitConfig = {
      ...getRecommendedRateLimitConfig(options.chain),
      ...options.rateLimitConfig,
    };

    const rateLimiter = new RateLimiter(rateLimitConfig);

    // Create client config
    const config: Web3Config = {
      url: endpoints[0],
      network: options.network,
      chainId: getChainId(options.network),
      timeout: options.timeout || 30000,
      maxRetries: options.maxRetries || 3,
    };

    // Create and cache client
    const client = new Web3Client(
      config,
      rateLimiter,
      connectionPool,
      {
        maxRetries: options.maxRetries || 3,
        initialDelay: 1000,
        maxDelay: 10000,
        backoffMultiplier: 2,
        retryableErrors: [-32000, -32001, -32603, 429],
      }
    );

    this.instances.set(cacheKey, client);
    return client;
  }

  /**
   * Create WebSocket client for real-time monitoring
   */
  public static createWebSocketClient(
    options: RPCClientOptions
  ): WebSocketClient {
    const cacheKey = `ws-${options.chain}-${options.network}`;

    // Return cached instance if exists
    if (this.wsClients.has(cacheKey)) {
      return this.wsClients.get(cacheKey)!;
    }

    // Get WebSocket endpoints
    const wsEndpoints = getAllEndpoints(options.chain, options.network, 'ws');

    if (wsEndpoints.length === 0) {
      throw new Error(`No WebSocket endpoints available for ${options.chain} ${options.network}`);
    }

    // Create WebSocket config
    const wsConfig: WebSocketConfig = {
      url: wsEndpoints[0],
      reconnect: true,
      reconnectInterval: 5000,
      maxReconnectAttempts: 10,
      pingInterval: 30000,
    };

    // Create and cache client
    const client = new WebSocketClient(wsConfig);
    this.wsClients.set(cacheKey, client);

    return client;
  }

  /**
   * Get existing client instance
   */
  public static getClient(
    chain: ChainType,
    network: NetworkType
  ): ElectrumClient | Web3Client | undefined {
    const cacheKey = `${chain}-${network}`;
    return this.instances.get(cacheKey);
  }

  /**
   * Get existing WebSocket client
   */
  public static getWebSocketClient(
    chain: ChainType,
    network: NetworkType
  ): WebSocketClient | undefined {
    const cacheKey = `ws-${chain}-${network}`;
    return this.wsClients.get(cacheKey);
  }

  /**
   * Destroy client and cleanup resources
   */
  public static async destroyClient(
    chain: ChainType,
    network: NetworkType
  ): Promise<void> {
    const cacheKey = `${chain}-${network}`;
    const client = this.instances.get(cacheKey);

    if (client) {
      await client.disconnect();
      this.instances.delete(cacheKey);
    }

    const wsCacheKey = `ws-${chain}-${network}`;
    const wsClient = this.wsClients.get(wsCacheKey);

    if (wsClient) {
      wsClient.disconnect();
      this.wsClients.delete(wsCacheKey);
    }
  }

  /**
   * Destroy all clients
   */
  public static async destroyAll(): Promise<void> {
    const disconnectPromises = Array.from(this.instances.values()).map(
      client => client.disconnect()
    );

    await Promise.all(disconnectPromises);
    this.instances.clear();

    for (const wsClient of this.wsClients.values()) {
      wsClient.disconnect();
    }
    this.wsClients.clear();
  }

  /**
   * Get all active clients
   */
  public static getAllClients(): Array<{
    chain: string;
    network: string;
    connected: boolean;
  }> {
    return Array.from(this.instances.entries()).map(([key, client]) => {
      const [chain, network] = key.split('-');
      return {
        chain,
        network,
        connected: client.isConnected(),
      };
    });
  }
}
