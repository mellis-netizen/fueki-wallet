/**
 * RPC Client Index
 * Main entry point for blockchain RPC clients
 */

// Export factory
export { RPCClientFactory } from './RPCClientFactory';

// Export Bitcoin client
export { ElectrumClient } from './bitcoin/ElectrumClient';
export type {
  ElectrumConfig,
  ElectrumTransaction,
  ElectrumBalance,
  ElectrumUTXO,
} from './bitcoin/ElectrumClient';

// Export Ethereum client
export { Web3Client } from './ethereum/Web3Client';
export type {
  Web3Config,
  EthereumBlock,
  EthereumTransaction,
  EthereumTransactionReceipt,
  EthereumBalance,
} from './ethereum/Web3Client';

// Export common utilities
export { RateLimiter } from './common/RateLimiter';
export { ConnectionPool } from './common/ConnectionPool';
export { RetryHandler } from './common/RetryHandler';
export { WebSocketClient } from './common/WebSocketClient';

// Export network configuration
export {
  NETWORK_CONFIGS,
  getNetworkConfig,
  getPrimaryEndpoint,
  getAllEndpoints,
  getExplorerUrl,
  getChainId,
  validateNetworkConfig,
  getRecommendedPoolConfig,
  getRecommendedRateLimitConfig,
} from './common/NetworkConfig';

// Export types
export type {
  NetworkType,
  ChainType,
  RPCConfig,
  RPCResponse,
  RPCError,
  Connection,
  HealthCheck,
  FailoverConfig,
  ConnectionPoolConfig,
  RateLimitConfig,
  WebSocketConfig,
  TransactionMonitorEvent,
  WebSocketMessage,
} from './common/types';

export {
  RPCClientError,
  ConnectionError,
  TimeoutError,
  RateLimitError,
  ValidationError,
} from './common/types';
