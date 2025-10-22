/**
 * NFT Service
 * NFT support for ERC-721 and ERC-1155 tokens
 */

import { ethers } from 'ethers';
import axios from 'axios';
import { NFT, ChainType, NetworkType } from '../../types/blockchain';
import { BlockchainFactory } from './BlockchainFactory';
import { EthereumService } from './EthereumService';

// ERC-721 ABI
const ERC721_ABI = [
  'function balanceOf(address owner) view returns (uint256)',
  'function ownerOf(uint256 tokenId) view returns (address)',
  'function tokenURI(uint256 tokenId) view returns (string)',
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function totalSupply() view returns (uint256)',
  'function tokenOfOwnerByIndex(address owner, uint256 index) view returns (uint256)',
  'function safeTransferFrom(address from, address to, uint256 tokenId)',
];

// ERC-1155 ABI
const ERC1155_ABI = [
  'function balanceOf(address account, uint256 id) view returns (uint256)',
  'function balanceOfBatch(address[] accounts, uint256[] ids) view returns (uint256[])',
  'function uri(uint256 id) view returns (string)',
  'function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes data)',
];

export interface NFTMetadata {
  name?: string;
  description?: string;
  image?: string;
  attributes?: Array<{
    trait_type: string;
    value: string | number;
  }>;
}

/**
 * NFT Service
 * Handles NFT operations for ERC-721 and ERC-1155 tokens
 */
export class NFTService {
  /**
   * Get NFT balance for address (ERC-721)
   */
  public static async getERC721Balance(
    chain: ChainType,
    network: NetworkType,
    contractAddress: string,
    ownerAddress: string
  ): Promise<number> {
    const service = BlockchainFactory.createService(chain, network) as EthereumService;

    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      const provider = (service as any).provider;
      const contract = new ethers.Contract(contractAddress, ERC721_ABI, provider);

      const balance = await contract.balanceOf(ownerAddress);
      return Number(balance);
    } catch (error) {
      throw new Error(
        `Failed to get ERC-721 balance: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Get NFT balance for specific token ID (ERC-1155)
   */
  public static async getERC1155Balance(
    chain: ChainType,
    network: NetworkType,
    contractAddress: string,
    ownerAddress: string,
    tokenId: string
  ): Promise<string> {
    const service = BlockchainFactory.createService(chain, network) as EthereumService;

    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      const provider = (service as any).provider;
      const contract = new ethers.Contract(contractAddress, ERC1155_ABI, provider);

      const balance = await contract.balanceOf(ownerAddress, tokenId);
      return balance.toString();
    } catch (error) {
      throw new Error(
        `Failed to get ERC-1155 balance: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Get all NFTs owned by address (ERC-721)
   */
  public static async getOwnedERC721Tokens(
    chain: ChainType,
    network: NetworkType,
    contractAddress: string,
    ownerAddress: string
  ): Promise<NFT[]> {
    const service = BlockchainFactory.createService(chain, network) as EthereumService;

    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      const provider = (service as any).provider;
      const contract = new ethers.Contract(contractAddress, ERC721_ABI, provider);

      const balance = await contract.balanceOf(ownerAddress);
      const nfts: NFT[] = [];

      for (let i = 0; i < Number(balance); i++) {
        try {
          const tokenId = await contract.tokenOfOwnerByIndex(ownerAddress, i);
          const tokenURI = await contract.tokenURI(tokenId);

          const nft: NFT = {
            tokenId: tokenId.toString(),
            contractAddress,
            tokenURI,
            owner: ownerAddress,
            standard: 'ERC721',
          };

          // Fetch metadata if available
          try {
            const metadata = await this.fetchMetadata(tokenURI);
            nft.name = metadata.name;
            nft.description = metadata.description;
            nft.image = metadata.image;
          } catch (error) {
            console.error(`Failed to fetch metadata for token ${tokenId}:`, error);
          }

          nfts.push(nft);
        } catch (error) {
          console.error(`Failed to fetch token at index ${i}:`, error);
        }
      }

      return nfts;
    } catch (error) {
      throw new Error(
        `Failed to get owned ERC-721 tokens: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Get NFT metadata
   */
  public static async getNFTMetadata(
    chain: ChainType,
    network: NetworkType,
    contractAddress: string,
    tokenId: string,
    standard: 'ERC721' | 'ERC1155' = 'ERC721'
  ): Promise<NFT> {
    const service = BlockchainFactory.createService(chain, network) as EthereumService;

    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      const provider = (service as any).provider;
      const abi = standard === 'ERC721' ? ERC721_ABI : ERC1155_ABI;
      const contract = new ethers.Contract(contractAddress, abi, provider);

      // Get token URI
      const tokenURI =
        standard === 'ERC721'
          ? await contract.tokenURI(tokenId)
          : await contract.uri(tokenId);

      // Get owner (ERC-721 only)
      let owner = '';
      if (standard === 'ERC721') {
        owner = await contract.ownerOf(tokenId);
      }

      const nft: NFT = {
        tokenId,
        contractAddress,
        tokenURI,
        owner,
        standard,
      };

      // Fetch metadata
      try {
        const metadata = await this.fetchMetadata(tokenURI);
        nft.name = metadata.name;
        nft.description = metadata.description;
        nft.image = metadata.image;
      } catch (error) {
        console.error('Failed to fetch metadata:', error);
      }

      return nft;
    } catch (error) {
      throw new Error(
        `Failed to get NFT metadata: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Transfer ERC-721 NFT
   */
  public static async transferERC721(
    chain: ChainType,
    network: NetworkType,
    contractAddress: string,
    fromAddress: string,
    toAddress: string,
    tokenId: string,
    privateKey: string
  ): Promise<string> {
    const service = BlockchainFactory.createService(chain, network) as EthereumService;

    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      const provider = (service as any).provider;
      const wallet = new ethers.Wallet(privateKey, provider);
      const contract = new ethers.Contract(contractAddress, ERC721_ABI, wallet);

      const tx = await contract.safeTransferFrom(fromAddress, toAddress, tokenId);
      await tx.wait();

      return tx.hash;
    } catch (error) {
      throw new Error(
        `Failed to transfer ERC-721: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Transfer ERC-1155 NFT
   */
  public static async transferERC1155(
    chain: ChainType,
    network: NetworkType,
    contractAddress: string,
    fromAddress: string,
    toAddress: string,
    tokenId: string,
    amount: string,
    privateKey: string
  ): Promise<string> {
    const service = BlockchainFactory.createService(chain, network) as EthereumService;

    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      const provider = (service as any).provider;
      const wallet = new ethers.Wallet(privateKey, provider);
      const contract = new ethers.Contract(contractAddress, ERC1155_ABI, wallet);

      const tx = await contract.safeTransferFrom(
        fromAddress,
        toAddress,
        tokenId,
        amount,
        '0x'
      );
      await tx.wait();

      return tx.hash;
    } catch (error) {
      throw new Error(
        `Failed to transfer ERC-1155: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Fetch NFT metadata from URI
   */
  private static async fetchMetadata(tokenURI: string): Promise<NFTMetadata> {
    try {
      // Handle IPFS URIs
      let url = tokenURI;
      if (tokenURI.startsWith('ipfs://')) {
        url = tokenURI.replace('ipfs://', 'https://ipfs.io/ipfs/');
      }

      const response = await axios.get(url, {
        timeout: 10000,
        headers: {
          Accept: 'application/json',
        },
      });

      return response.data;
    } catch (error) {
      throw new Error(
        `Failed to fetch metadata: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Check if contract is ERC-721
   */
  public static async isERC721(
    chain: ChainType,
    network: NetworkType,
    contractAddress: string
  ): Promise<boolean> {
    const service = BlockchainFactory.createService(chain, network) as EthereumService;

    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      const provider = (service as any).provider;
      const contract = new ethers.Contract(
        contractAddress,
        ['function supportsInterface(bytes4 interfaceId) view returns (bool)'],
        provider
      );

      // ERC-721 interface ID
      const erc721InterfaceId = '0x80ac58cd';
      return await contract.supportsInterface(erc721InterfaceId);
    } catch (error) {
      return false;
    }
  }

  /**
   * Check if contract is ERC-1155
   */
  public static async isERC1155(
    chain: ChainType,
    network: NetworkType,
    contractAddress: string
  ): Promise<boolean> {
    const service = BlockchainFactory.createService(chain, network) as EthereumService;

    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      const provider = (service as any).provider;
      const contract = new ethers.Contract(
        contractAddress,
        ['function supportsInterface(bytes4 interfaceId) view returns (bool)'],
        provider
      );

      // ERC-1155 interface ID
      const erc1155InterfaceId = '0xd9b67a26';
      return await contract.supportsInterface(erc1155InterfaceId);
    } catch (error) {
      return false;
    }
  }

  /**
   * Get NFT collection info
   */
  public static async getCollectionInfo(
    chain: ChainType,
    network: NetworkType,
    contractAddress: string
  ): Promise<{
    name: string;
    symbol: string;
    totalSupply?: string;
  }> {
    const service = BlockchainFactory.createService(chain, network) as EthereumService;

    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      const provider = (service as any).provider;
      const contract = new ethers.Contract(contractAddress, ERC721_ABI, provider);

      const [name, symbol] = await Promise.all([contract.name(), contract.symbol()]);

      let totalSupply: string | undefined;
      try {
        const supply = await contract.totalSupply();
        totalSupply = supply.toString();
      } catch (error) {
        // totalSupply not available
      }

      return { name, symbol, totalSupply };
    } catch (error) {
      throw new Error(
        `Failed to get collection info: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }
}
