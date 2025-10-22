/**
 * Common RPC Types and Interfaces
 * Shared types for Bitcoin and Ethereum RPC clients
 */

export enum NetworkType {
  MAINNET = 'mainnet',
  TESTNET = 'testnet',
}

export enum ChainType {
  BITCOIN = 'bitcoin',
  ETHEREUM = 'ethereum',
}

export interface RPCConfig {
  url: string;
  timeout?: number;
  maxRetries?: number;
  retryDelay?: number;
  headers?: Record<string, string>;
}

export interface ConnectionPoolConfig {
  minConnections: number;
  maxConnections: number;
  acquireTimeout: number;
  idleTimeout: number;
}

export interface RateLimitConfig {
  requestsPerSecond: number;
  burstSize: number;
}

export interface RPCResponse<T = any> {
  success: boolean;
  data?: T;
  error?: RPCError;
  requestId?: string;
  timestamp: number;
}

export interface RPCError {
  code: number;
  message: string;
  data?: any;
}

export interface RPCRequest {
  method: string;
  params: any[];
  id: string | number;
}

export interface Connection {
  id: string;
  url: string;
  active: boolean;
  lastUsed: number;
  requestCount: number;
  errorCount: number;
}

export interface HealthCheck {
  healthy: boolean;
  latency: number;
  lastCheck: number;
  blockHeight?: number;
}

export interface FailoverConfig {
  primaryUrl: string;
  fallbackUrls: string[];
  healthCheckInterval: number;
  failoverThreshold: number;
}

export interface WebSocketConfig {
  url: string;
  reconnect: boolean;
  reconnectInterval: number;
  maxReconnectAttempts: number;
  pingInterval?: number;
}

export interface TransactionMonitorEvent {
  type: 'new_transaction' | 'confirmed' | 'failed';
  txHash: string;
  blockHeight?: number;
  confirmations?: number;
  data: any;
}

export class RPCClientError extends Error {
  constructor(
    message: string,
    public code: number,
    public data?: any
  ) {
    super(message);
    this.name = 'RPCClientError';
  }
}

export class ConnectionError extends RPCClientError {
  constructor(message: string, data?: any) {
    super(message, -32000, data);
    this.name = 'ConnectionError';
  }
}

export class TimeoutError extends RPCClientError {
  constructor(message: string, data?: any) {
    super(message, -32001, data);
    this.name = 'TimeoutError';
  }
}

export class RateLimitError extends RPCClientError {
  constructor(message: string, data?: any) {
    super(message, -32002, data);
    this.name = 'RateLimitError';
  }
}

export class ValidationError extends RPCClientError {
  constructor(message: string, data?: any) {
    super(message, -32003, data);
    this.name = 'ValidationError';
  }
}
