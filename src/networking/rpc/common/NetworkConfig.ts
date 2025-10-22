/**
 * Network Configuration
 * Testnet and mainnet configurations for all supported chains
 */

import { NetworkType, ChainType } from './types';

export interface NetworkEndpoint {
  http: string[];
  ws?: string[];
  electrum?: string[];
}

export interface ChainConfig {
  chainId?: number;
  network: NetworkType;
  endpoints: NetworkEndpoint;
  explorer: string;
}

export const NETWORK_CONFIGS: Record<ChainType, Record<NetworkType, ChainConfig>> = {
  [ChainType.BITCOIN]: {
    [NetworkType.MAINNET]: {
      network: NetworkType.MAINNET,
      endpoints: {
        electrum: [
          'electrum.blockstream.info:50002',
          'bitcoin.aranguren.org:50002',
          'electrum3.bluewallet.io:50002',
          'electrum.emzy.de:50002',
        ],
        http: [
          'https://blockstream.info/api',
          'https://blockchain.info',
        ],
        ws: [
          'wss://blockstream.info/api/socket.io',
        ],
      },
      explorer: 'https://blockstream.info',
    },
    [NetworkType.TESTNET]: {
      network: NetworkType.TESTNET,
      endpoints: {
        electrum: [
          'testnet.aranguren.org:51002',
          'electrum.blockstream.info:60002',
          'testnet.qtornado.com:51002',
        ],
        http: [
          'https://blockstream.info/testnet/api',
        ],
        ws: [
          'wss://blockstream.info/testnet/api/socket.io',
        ],
      },
      explorer: 'https://blockstream.info/testnet',
    },
  },
  [ChainType.ETHEREUM]: {
    [NetworkType.MAINNET]: {
      chainId: 1,
      network: NetworkType.MAINNET,
      endpoints: {
        http: [
          'https://eth.llamarpc.com',
          'https://rpc.ankr.com/eth',
          'https://ethereum.publicnode.com',
          'https://cloudflare-eth.com',
        ],
        ws: [
          'wss://eth.llamarpc.com',
          'wss://ethereum.publicnode.com',
        ],
      },
      explorer: 'https://etherscan.io',
    },
    [NetworkType.TESTNET]: {
      chainId: 11155111, // Sepolia
      network: NetworkType.TESTNET,
      endpoints: {
        http: [
          'https://rpc.sepolia.org',
          'https://eth-sepolia.public.blastapi.io',
          'https://ethereum-sepolia.publicnode.com',
        ],
        ws: [
          'wss://ethereum-sepolia.publicnode.com',
        ],
      },
      explorer: 'https://sepolia.etherscan.io',
    },
  },
};

/**
 * Get network configuration
 */
export function getNetworkConfig(
  chain: ChainType,
  network: NetworkType
): ChainConfig {
  const config = NETWORK_CONFIGS[chain]?.[network];

  if (!config) {
    throw new Error(`No configuration found for ${chain} ${network}`);
  }

  return config;
}

/**
 * Get primary endpoint for chain
 */
export function getPrimaryEndpoint(
  chain: ChainType,
  network: NetworkType,
  type: 'http' | 'ws' | 'electrum' = 'http'
): string {
  const config = getNetworkConfig(chain, network);
  const endpoints = config.endpoints[type];

  if (!endpoints || endpoints.length === 0) {
    throw new Error(`No ${type} endpoints available for ${chain} ${network}`);
  }

  return endpoints[0];
}

/**
 * Get all endpoints for chain
 */
export function getAllEndpoints(
  chain: ChainType,
  network: NetworkType,
  type: 'http' | 'ws' | 'electrum' = 'http'
): string[] {
  const config = getNetworkConfig(chain, network);
  return config.endpoints[type] || [];
}

/**
 * Get block explorer URL
 */
export function getExplorerUrl(
  chain: ChainType,
  network: NetworkType
): string {
  const config = getNetworkConfig(chain, network);
  return config.explorer;
}

/**
 * Get chain ID for Ethereum networks
 */
export function getChainId(network: NetworkType): number {
  const config = NETWORK_CONFIGS[ChainType.ETHEREUM][network];

  if (!config.chainId) {
    throw new Error(`No chain ID configured for Ethereum ${network}`);
  }

  return config.chainId;
}

/**
 * Validate network configuration
 */
export function validateNetworkConfig(
  chain: ChainType,
  network: NetworkType
): boolean {
  try {
    const config = getNetworkConfig(chain, network);

    // Ensure at least one endpoint exists
    const hasEndpoints =
      (config.endpoints.http && config.endpoints.http.length > 0) ||
      (config.endpoints.ws && config.endpoints.ws.length > 0) ||
      (config.endpoints.electrum && config.endpoints.electrum.length > 0);

    return hasEndpoints && !!config.explorer;
  } catch {
    return false;
  }
}

/**
 * Get recommended connection pool config
 */
export function getRecommendedPoolConfig(chain: ChainType) {
  return {
    minConnections: 2,
    maxConnections: chain === ChainType.ETHEREUM ? 10 : 5,
    acquireTimeout: 5000,
    idleTimeout: 60000,
  };
}

/**
 * Get recommended rate limit config
 */
export function getRecommendedRateLimitConfig(chain: ChainType) {
  return {
    requestsPerSecond: chain === ChainType.ETHEREUM ? 10 : 5,
    burstSize: chain === ChainType.ETHEREUM ? 20 : 10,
  };
}
