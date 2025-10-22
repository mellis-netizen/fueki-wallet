/**
 * Blockchain Factory
 * Factory pattern for creating blockchain service instances
 */

import {
  ChainType,
  NetworkType,
  IBlockchainService,
  BlockchainConfig,
} from '../../types/blockchain';
import { EthereumService, EthereumConfig } from './EthereumService';
import { BitcoinService, BitcoinConfig } from './BitcoinService';
import { SolanaService, SolanaConfig } from './SolanaService';

/**
 * Blockchain service cache
 */
const serviceCache = new Map<string, IBlockchainService>();

/**
 * Get cache key for service
 */
function getCacheKey(chain: ChainType, network: NetworkType): string {
  return `${chain}-${network}`;
}

/**
 * Create Ethereum service
 */
function createEthereumService(config: BlockchainConfig): EthereumService {
  const ethConfig: EthereumConfig = {
    ...config,
    chainId: config.network === NetworkType.MAINNET ? 1 : 11155111, // Mainnet or Sepolia
  };

  return new EthereumService(ethConfig);
}

/**
 * Create Bitcoin service
 */
function createBitcoinService(config: BlockchainConfig): BitcoinService {
  const btcConfig: BitcoinConfig = {
    ...config,
    apiUrl:
      config.network === NetworkType.MAINNET
        ? 'https://blockstream.info/api'
        : 'https://blockstream.info/testnet/api',
  };

  return new BitcoinService(btcConfig);
}

/**
 * Create Solana service
 */
function createSolanaService(config: BlockchainConfig): SolanaService {
  const solConfig: SolanaConfig = {
    ...config,
    commitment: 'confirmed',
  };

  return new SolanaService(solConfig);
}

/**
 * Blockchain Factory
 * Creates and manages blockchain service instances
 */
export class BlockchainFactory {
  /**
   * Create blockchain service instance
   */
  public static createService(
    chain: ChainType,
    network: NetworkType,
    config?: Partial<BlockchainConfig>
  ): IBlockchainService {
    const cacheKey = getCacheKey(chain, network);

    // Return cached instance if exists
    if (serviceCache.has(cacheKey)) {
      return serviceCache.get(cacheKey)!;
    }

    // Get default RPC URL
    const rpcUrl = this.getDefaultRpcUrl(chain, network);

    // Merge with provided config
    const fullConfig: BlockchainConfig = {
      chain,
      network,
      rpcUrl,
      ...config,
    };

    // Create service based on chain type
    let service: IBlockchainService;

    switch (chain) {
      case ChainType.ETHEREUM:
      case ChainType.POLYGON:
      case ChainType.BSC:
      case ChainType.AVALANCHE:
        service = createEthereumService(fullConfig);
        break;

      case ChainType.BITCOIN:
        service = createBitcoinService(fullConfig);
        break;

      case ChainType.SOLANA:
        service = createSolanaService(fullConfig);
        break;

      default:
        throw new Error(`Unsupported chain type: ${chain}`);
    }

    // Cache the service
    serviceCache.set(cacheKey, service);

    return service;
  }

  /**
   * Get cached service instance
   */
  public static getService(chain: ChainType, network: NetworkType): IBlockchainService | null {
    const cacheKey = getCacheKey(chain, network);
    return serviceCache.get(cacheKey) || null;
  }

  /**
   * Clear service cache
   */
  public static clearCache(chain?: ChainType, network?: NetworkType): void {
    if (chain && network) {
      const cacheKey = getCacheKey(chain, network);
      serviceCache.delete(cacheKey);
    } else {
      serviceCache.clear();
    }
  }

  /**
   * Get default RPC URL for chain and network
   */
  private static getDefaultRpcUrl(chain: ChainType, network: NetworkType): string {
    const rpcUrls: Record<ChainType, Record<NetworkType, string>> = {
      [ChainType.ETHEREUM]: {
        [NetworkType.MAINNET]: 'https://eth.llamarpc.com',
        [NetworkType.TESTNET]: 'https://rpc.sepolia.org',
        [NetworkType.DEVNET]: 'https://rpc.sepolia.org',
      },
      [ChainType.BITCOIN]: {
        [NetworkType.MAINNET]: 'https://blockstream.info/api',
        [NetworkType.TESTNET]: 'https://blockstream.info/testnet/api',
        [NetworkType.DEVNET]: 'https://blockstream.info/testnet/api',
      },
      [ChainType.SOLANA]: {
        [NetworkType.MAINNET]: 'https://api.mainnet-beta.solana.com',
        [NetworkType.TESTNET]: 'https://api.testnet.solana.com',
        [NetworkType.DEVNET]: 'https://api.devnet.solana.com',
      },
      [ChainType.POLYGON]: {
        [NetworkType.MAINNET]: 'https://polygon-rpc.com',
        [NetworkType.TESTNET]: 'https://rpc-mumbai.maticvigil.com',
        [NetworkType.DEVNET]: 'https://rpc-mumbai.maticvigil.com',
      },
      [ChainType.BSC]: {
        [NetworkType.MAINNET]: 'https://bsc-dataseed.binance.org',
        [NetworkType.TESTNET]: 'https://data-seed-prebsc-1-s1.binance.org:8545',
        [NetworkType.DEVNET]: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      },
      [ChainType.AVALANCHE]: {
        [NetworkType.MAINNET]: 'https://api.avax.network/ext/bc/C/rpc',
        [NetworkType.TESTNET]: 'https://api.avax-test.network/ext/bc/C/rpc',
        [NetworkType.DEVNET]: 'https://api.avax-test.network/ext/bc/C/rpc',
      },
    };

    return rpcUrls[chain][network];
  }

  /**
   * Connect to all supported chains
   */
  public static async connectAll(chains: ChainType[], network: NetworkType): Promise<void> {
    const promises = chains.map((chain) => {
      const service = this.createService(chain, network);
      return service.connect();
    });

    await Promise.all(promises);
  }

  /**
   * Disconnect from all chains
   */
  public static async disconnectAll(): Promise<void> {
    const promises = Array.from(serviceCache.values()).map((service) => service.disconnect());
    await Promise.all(promises);
    serviceCache.clear();
  }

  /**
   * Get all connected services
   */
  public static getAllServices(): Map<string, IBlockchainService> {
    return new Map(serviceCache);
  }

  /**
   * Check if service is cached
   */
  public static hasService(chain: ChainType, network: NetworkType): boolean {
    const cacheKey = getCacheKey(chain, network);
    return serviceCache.has(cacheKey);
  }
}
