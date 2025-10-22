/**
 * Network Configuration
 * Centralized configuration for all blockchain networks
 */

import { ChainType, NetworkType, BlockchainConfig } from '../types/blockchain';

export interface RPCEndpoint {
  url: string;
  priority: number;
  requiresAuth?: boolean;
}

export interface NetworkConfigEntry extends BlockchainConfig {
  chainId?: number;
  nativeCurrency: {
    name: string;
    symbol: string;
    decimals: number;
  };
  blockExplorer: string;
  rpcEndpoints: RPCEndpoint[];
  wsEndpoints?: RPCEndpoint[];
  iconUrl?: string;
}

/**
 * Network configurations for all supported chains
 */
export const NETWORK_CONFIG: Record<ChainType, Record<NetworkType, NetworkConfigEntry>> = {
  [ChainType.ETHEREUM]: {
    [NetworkType.MAINNET]: {
      chain: ChainType.ETHEREUM,
      network: NetworkType.MAINNET,
      chainId: 1,
      rpcUrl: 'https://eth.llamarpc.com',
      nativeCurrency: {
        name: 'Ether',
        symbol: 'ETH',
        decimals: 18,
      },
      blockExplorer: 'https://etherscan.io',
      explorerUrl: 'https://etherscan.io',
      rpcEndpoints: [
        { url: 'https://eth.llamarpc.com', priority: 1 },
        { url: 'https://rpc.ankr.com/eth', priority: 2 },
        { url: 'https://ethereum.publicnode.com', priority: 3 },
        { url: 'https://cloudflare-eth.com', priority: 4 },
      ],
      wsEndpoints: [
        { url: 'wss://eth.llamarpc.com', priority: 1 },
        { url: 'wss://ethereum.publicnode.com', priority: 2 },
      ],
    },
    [NetworkType.TESTNET]: {
      chain: ChainType.ETHEREUM,
      network: NetworkType.TESTNET,
      chainId: 11155111, // Sepolia
      rpcUrl: 'https://rpc.sepolia.org',
      nativeCurrency: {
        name: 'Sepolia Ether',
        symbol: 'ETH',
        decimals: 18,
      },
      blockExplorer: 'https://sepolia.etherscan.io',
      explorerUrl: 'https://sepolia.etherscan.io',
      rpcEndpoints: [
        { url: 'https://rpc.sepolia.org', priority: 1 },
        { url: 'https://eth-sepolia.public.blastapi.io', priority: 2 },
        { url: 'https://ethereum-sepolia.publicnode.com', priority: 3 },
      ],
      wsEndpoints: [{ url: 'wss://ethereum-sepolia.publicnode.com', priority: 1 }],
    },
    [NetworkType.DEVNET]: {
      chain: ChainType.ETHEREUM,
      network: NetworkType.DEVNET,
      chainId: 11155111, // Sepolia as devnet
      rpcUrl: 'https://rpc.sepolia.org',
      nativeCurrency: {
        name: 'Sepolia Ether',
        symbol: 'ETH',
        decimals: 18,
      },
      blockExplorer: 'https://sepolia.etherscan.io',
      explorerUrl: 'https://sepolia.etherscan.io',
      rpcEndpoints: [{ url: 'https://rpc.sepolia.org', priority: 1 }],
    },
  },
  [ChainType.BITCOIN]: {
    [NetworkType.MAINNET]: {
      chain: ChainType.BITCOIN,
      network: NetworkType.MAINNET,
      rpcUrl: 'https://blockstream.info/api',
      nativeCurrency: {
        name: 'Bitcoin',
        symbol: 'BTC',
        decimals: 8,
      },
      blockExplorer: 'https://blockstream.info',
      explorerUrl: 'https://blockstream.info',
      rpcEndpoints: [
        { url: 'https://blockstream.info/api', priority: 1 },
        { url: 'https://blockchain.info', priority: 2 },
      ],
      wsEndpoints: [{ url: 'wss://blockstream.info/api/socket.io', priority: 1 }],
    },
    [NetworkType.TESTNET]: {
      chain: ChainType.BITCOIN,
      network: NetworkType.TESTNET,
      rpcUrl: 'https://blockstream.info/testnet/api',
      nativeCurrency: {
        name: 'Test Bitcoin',
        symbol: 'tBTC',
        decimals: 8,
      },
      blockExplorer: 'https://blockstream.info/testnet',
      explorerUrl: 'https://blockstream.info/testnet',
      rpcEndpoints: [{ url: 'https://blockstream.info/testnet/api', priority: 1 }],
      wsEndpoints: [{ url: 'wss://blockstream.info/testnet/api/socket.io', priority: 1 }],
    },
    [NetworkType.DEVNET]: {
      chain: ChainType.BITCOIN,
      network: NetworkType.DEVNET,
      rpcUrl: 'https://blockstream.info/testnet/api',
      nativeCurrency: {
        name: 'Test Bitcoin',
        symbol: 'tBTC',
        decimals: 8,
      },
      blockExplorer: 'https://blockstream.info/testnet',
      explorerUrl: 'https://blockstream.info/testnet',
      rpcEndpoints: [{ url: 'https://blockstream.info/testnet/api', priority: 1 }],
    },
  },
  [ChainType.SOLANA]: {
    [NetworkType.MAINNET]: {
      chain: ChainType.SOLANA,
      network: NetworkType.MAINNET,
      rpcUrl: 'https://api.mainnet-beta.solana.com',
      nativeCurrency: {
        name: 'Solana',
        symbol: 'SOL',
        decimals: 9,
      },
      blockExplorer: 'https://explorer.solana.com',
      explorerUrl: 'https://explorer.solana.com',
      rpcEndpoints: [
        { url: 'https://api.mainnet-beta.solana.com', priority: 1 },
        { url: 'https://solana-api.projectserum.com', priority: 2 },
      ],
    },
    [NetworkType.TESTNET]: {
      chain: ChainType.SOLANA,
      network: NetworkType.TESTNET,
      rpcUrl: 'https://api.testnet.solana.com',
      nativeCurrency: {
        name: 'Solana',
        symbol: 'SOL',
        decimals: 9,
      },
      blockExplorer: 'https://explorer.solana.com?cluster=testnet',
      explorerUrl: 'https://explorer.solana.com?cluster=testnet',
      rpcEndpoints: [{ url: 'https://api.testnet.solana.com', priority: 1 }],
    },
    [NetworkType.DEVNET]: {
      chain: ChainType.SOLANA,
      network: NetworkType.DEVNET,
      rpcUrl: 'https://api.devnet.solana.com',
      nativeCurrency: {
        name: 'Solana',
        symbol: 'SOL',
        decimals: 9,
      },
      blockExplorer: 'https://explorer.solana.com?cluster=devnet',
      explorerUrl: 'https://explorer.solana.com?cluster=devnet',
      rpcEndpoints: [{ url: 'https://api.devnet.solana.com', priority: 1 }],
    },
  },
  [ChainType.POLYGON]: {
    [NetworkType.MAINNET]: {
      chain: ChainType.POLYGON,
      network: NetworkType.MAINNET,
      chainId: 137,
      rpcUrl: 'https://polygon-rpc.com',
      nativeCurrency: {
        name: 'MATIC',
        symbol: 'MATIC',
        decimals: 18,
      },
      blockExplorer: 'https://polygonscan.com',
      explorerUrl: 'https://polygonscan.com',
      rpcEndpoints: [
        { url: 'https://polygon-rpc.com', priority: 1 },
        { url: 'https://rpc-mainnet.matic.network', priority: 2 },
        { url: 'https://polygon.llamarpc.com', priority: 3 },
      ],
    },
    [NetworkType.TESTNET]: {
      chain: ChainType.POLYGON,
      network: NetworkType.TESTNET,
      chainId: 80001, // Mumbai
      rpcUrl: 'https://rpc-mumbai.maticvigil.com',
      nativeCurrency: {
        name: 'MATIC',
        symbol: 'MATIC',
        decimals: 18,
      },
      blockExplorer: 'https://mumbai.polygonscan.com',
      explorerUrl: 'https://mumbai.polygonscan.com',
      rpcEndpoints: [{ url: 'https://rpc-mumbai.maticvigil.com', priority: 1 }],
    },
    [NetworkType.DEVNET]: {
      chain: ChainType.POLYGON,
      network: NetworkType.DEVNET,
      chainId: 80001,
      rpcUrl: 'https://rpc-mumbai.maticvigil.com',
      nativeCurrency: {
        name: 'MATIC',
        symbol: 'MATIC',
        decimals: 18,
      },
      blockExplorer: 'https://mumbai.polygonscan.com',
      explorerUrl: 'https://mumbai.polygonscan.com',
      rpcEndpoints: [{ url: 'https://rpc-mumbai.maticvigil.com', priority: 1 }],
    },
  },
  [ChainType.BSC]: {
    [NetworkType.MAINNET]: {
      chain: ChainType.BSC,
      network: NetworkType.MAINNET,
      chainId: 56,
      rpcUrl: 'https://bsc-dataseed.binance.org',
      nativeCurrency: {
        name: 'BNB',
        symbol: 'BNB',
        decimals: 18,
      },
      blockExplorer: 'https://bscscan.com',
      explorerUrl: 'https://bscscan.com',
      rpcEndpoints: [
        { url: 'https://bsc-dataseed.binance.org', priority: 1 },
        { url: 'https://bsc-dataseed1.binance.org', priority: 2 },
      ],
    },
    [NetworkType.TESTNET]: {
      chain: ChainType.BSC,
      network: NetworkType.TESTNET,
      chainId: 97,
      rpcUrl: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      nativeCurrency: {
        name: 'BNB',
        symbol: 'BNB',
        decimals: 18,
      },
      blockExplorer: 'https://testnet.bscscan.com',
      explorerUrl: 'https://testnet.bscscan.com',
      rpcEndpoints: [
        { url: 'https://data-seed-prebsc-1-s1.binance.org:8545', priority: 1 },
      ],
    },
    [NetworkType.DEVNET]: {
      chain: ChainType.BSC,
      network: NetworkType.DEVNET,
      chainId: 97,
      rpcUrl: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      nativeCurrency: {
        name: 'BNB',
        symbol: 'BNB',
        decimals: 18,
      },
      blockExplorer: 'https://testnet.bscscan.com',
      explorerUrl: 'https://testnet.bscscan.com',
      rpcEndpoints: [
        { url: 'https://data-seed-prebsc-1-s1.binance.org:8545', priority: 1 },
      ],
    },
  },
  [ChainType.AVALANCHE]: {
    [NetworkType.MAINNET]: {
      chain: ChainType.AVALANCHE,
      network: NetworkType.MAINNET,
      chainId: 43114,
      rpcUrl: 'https://api.avax.network/ext/bc/C/rpc',
      nativeCurrency: {
        name: 'Avalanche',
        symbol: 'AVAX',
        decimals: 18,
      },
      blockExplorer: 'https://snowtrace.io',
      explorerUrl: 'https://snowtrace.io',
      rpcEndpoints: [
        { url: 'https://api.avax.network/ext/bc/C/rpc', priority: 1 },
        { url: 'https://rpc.ankr.com/avalanche', priority: 2 },
      ],
    },
    [NetworkType.TESTNET]: {
      chain: ChainType.AVALANCHE,
      network: NetworkType.TESTNET,
      chainId: 43113, // Fuji
      rpcUrl: 'https://api.avax-test.network/ext/bc/C/rpc',
      nativeCurrency: {
        name: 'Avalanche',
        symbol: 'AVAX',
        decimals: 18,
      },
      blockExplorer: 'https://testnet.snowtrace.io',
      explorerUrl: 'https://testnet.snowtrace.io',
      rpcEndpoints: [{ url: 'https://api.avax-test.network/ext/bc/C/rpc', priority: 1 }],
    },
    [NetworkType.DEVNET]: {
      chain: ChainType.AVALANCHE,
      network: NetworkType.DEVNET,
      chainId: 43113,
      rpcUrl: 'https://api.avax-test.network/ext/bc/C/rpc',
      nativeCurrency: {
        name: 'Avalanche',
        symbol: 'AVAX',
        decimals: 18,
      },
      blockExplorer: 'https://testnet.snowtrace.io',
      explorerUrl: 'https://testnet.snowtrace.io',
      rpcEndpoints: [{ url: 'https://api.avax-test.network/ext/bc/C/rpc', priority: 1 }],
    },
  },
};

/**
 * Get network configuration
 */
export function getNetworkConfig(
  chain: ChainType,
  network: NetworkType
): NetworkConfigEntry {
  const config = NETWORK_CONFIG[chain]?.[network];

  if (!config) {
    throw new Error(`No configuration found for ${chain} ${network}`);
  }

  return config;
}

/**
 * Get all supported chains
 */
export function getSupportedChains(): ChainType[] {
  return Object.keys(NETWORK_CONFIG) as ChainType[];
}

/**
 * Get all networks for a chain
 */
export function getSupportedNetworks(chain: ChainType): NetworkType[] {
  return Object.keys(NETWORK_CONFIG[chain] || {}) as NetworkType[];
}

/**
 * Validate chain and network combination
 */
export function isValidNetwork(chain: ChainType, network: NetworkType): boolean {
  return !!NETWORK_CONFIG[chain]?.[network];
}
