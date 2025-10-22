/**
 * Ethereum Service
 * Full Ethereum/EVM blockchain integration with ethers.js
 */

import { ethers } from 'ethers';
import {
  ChainType,
  NetworkType,
  Balance,
  Transaction,
  TransactionReceipt,
  GasEstimate,
  SendTransactionParams,
  IBlockchainService,
  BlockchainConfig,
  TokenInfo,
  Log,
} from '../../types/blockchain';

export interface EthereumConfig extends BlockchainConfig {
  chainId: number;
  infuraKey?: string;
  alchemyKey?: string;
}

export class EthereumService implements IBlockchainService {
  private provider: ethers.JsonRpcProvider | null = null;
  private config: EthereumConfig;
  private connected: boolean = false;

  constructor(config: EthereumConfig) {
    this.config = config;
  }

  /**
   * Connect to Ethereum network
   */
  public async connect(): Promise<void> {
    try {
      // Create provider with fallback RPCs
      this.provider = new ethers.JsonRpcProvider(this.config.rpcUrl, {
        chainId: this.config.chainId,
        name: this.config.network,
      });

      // Verify connection
      const network = await this.provider.getNetwork();
      if (Number(network.chainId) !== this.config.chainId) {
        throw new Error(
          `Chain ID mismatch: expected ${this.config.chainId}, got ${network.chainId}`
        );
      }

      const blockNumber = await this.provider.getBlockNumber();
      console.log(`Connected to Ethereum ${this.config.network} at block ${blockNumber}`);

      this.connected = true;
    } catch (error) {
      throw new Error(
        `Failed to connect to Ethereum: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Disconnect from network
   */
  public async disconnect(): Promise<void> {
    if (this.provider) {
      await this.provider.destroy();
      this.provider = null;
    }
    this.connected = false;
  }

  /**
   * Get ETH balance for address
   */
  public async getBalance(address: string): Promise<Balance> {
    this.ensureConnected();

    try {
      const balance = await this.provider!.getBalance(address);

      return {
        address,
        balance: ethers.formatEther(balance),
        decimals: 18,
        symbol: 'ETH',
      };
    } catch (error) {
      throw new Error(`Failed to get balance: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get ERC-20 token balance
   */
  public async getTokenBalance(tokenAddress: string, walletAddress: string): Promise<Balance> {
    this.ensureConnected();

    try {
      const tokenContract = new ethers.Contract(
        tokenAddress,
        [
          'function balanceOf(address) view returns (uint256)',
          'function decimals() view returns (uint8)',
          'function symbol() view returns (string)',
        ],
        this.provider!
      );

      const [balance, decimals, symbol] = await Promise.all([
        tokenContract.balanceOf(walletAddress),
        tokenContract.decimals(),
        tokenContract.symbol(),
      ]);

      return {
        address: walletAddress,
        balance: ethers.formatUnits(balance, decimals),
        decimals,
        symbol,
      };
    } catch (error) {
      throw new Error(`Failed to get token balance: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get transaction by hash
   */
  public async getTransaction(hash: string): Promise<Transaction> {
    this.ensureConnected();

    try {
      const tx = await this.provider!.getTransaction(hash);
      if (!tx) {
        throw new Error(`Transaction ${hash} not found`);
      }

      const blockNumber = await this.provider!.getBlockNumber();
      const confirmations = tx.blockNumber ? blockNumber - tx.blockNumber + 1 : 0;

      return {
        hash: tx.hash,
        from: tx.from,
        to: tx.to || '',
        value: ethers.formatEther(tx.value),
        data: tx.data,
        nonce: tx.nonce,
        gasLimit: tx.gasLimit.toString(),
        gasPrice: tx.gasPrice ? tx.gasPrice.toString() : undefined,
        maxFeePerGas: tx.maxFeePerGas ? tx.maxFeePerGas.toString() : undefined,
        maxPriorityFeePerGas: tx.maxPriorityFeePerGas
          ? tx.maxPriorityFeePerGas.toString()
          : undefined,
        chainId: Number(tx.chainId),
        blockNumber: tx.blockNumber || undefined,
        confirmations,
        status: tx.blockNumber ? 'confirmed' : 'pending',
      };
    } catch (error) {
      throw new Error(`Failed to get transaction: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get transaction receipt
   */
  public async getTransactionReceipt(hash: string): Promise<TransactionReceipt> {
    this.ensureConnected();

    try {
      const receipt = await this.provider!.getTransactionReceipt(hash);
      if (!receipt) {
        throw new Error(`Transaction receipt for ${hash} not found`);
      }

      return {
        hash: receipt.hash,
        blockNumber: receipt.blockNumber,
        blockHash: receipt.blockHash,
        gasUsed: receipt.gasUsed.toString(),
        effectiveGasPrice: receipt.gasPrice ? receipt.gasPrice.toString() : undefined,
        status: receipt.status === 1,
        logs: receipt.logs.map((log: ethers.Log) => ({
          address: log.address,
          topics: log.topics,
          data: log.data,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
          logIndex: log.index,
        })),
        contractAddress: receipt.contractAddress || undefined,
      };
    } catch (error) {
      throw new Error(`Failed to get transaction receipt: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Send transaction
   */
  public async sendTransaction(
    params: SendTransactionParams,
    privateKey: string
  ): Promise<string> {
    this.ensureConnected();

    try {
      const wallet = new ethers.Wallet(privateKey, this.provider!);

      const tx: ethers.TransactionRequest = {
        to: params.to,
        value: ethers.parseEther(params.value),
        data: params.data,
        gasLimit: params.gasLimit,
        nonce: params.nonce,
      };

      // Use EIP-1559 if available
      if (params.maxFeePerGas && params.maxPriorityFeePerGas) {
        tx.maxFeePerGas = params.maxFeePerGas;
        tx.maxPriorityFeePerGas = params.maxPriorityFeePerGas;
      } else if (params.gasPrice) {
        tx.gasPrice = params.gasPrice;
      }

      const txResponse = await wallet.sendTransaction(tx);
      return txResponse.hash;
    } catch (error) {
      throw new Error(`Failed to send transaction: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Estimate gas for transaction
   */
  public async estimateGas(params: SendTransactionParams): Promise<GasEstimate> {
    this.ensureConnected();

    try {
      const tx: ethers.TransactionRequest = {
        to: params.to,
        from: params.from,
        value: ethers.parseEther(params.value),
        data: params.data,
      };

      // Estimate gas limit
      const gasLimit = await this.provider!.estimateGas(tx);

      // Get current fee data
      const feeData = await this.provider!.getFeeData();

      let estimatedCost: bigint;
      let gasPrice: string | undefined;
      let maxFeePerGas: string | undefined;
      let maxPriorityFeePerGas: string | undefined;

      // EIP-1559 transaction
      if (feeData.maxFeePerGas && feeData.maxPriorityFeePerGas) {
        maxFeePerGas = feeData.maxFeePerGas.toString();
        maxPriorityFeePerGas = feeData.maxPriorityFeePerGas.toString();
        estimatedCost = gasLimit * feeData.maxFeePerGas;
      } else if (feeData.gasPrice) {
        // Legacy transaction
        gasPrice = feeData.gasPrice.toString();
        estimatedCost = gasLimit * feeData.gasPrice;
      } else {
        throw new Error('Unable to get fee data');
      }

      return {
        gasLimit: gasLimit.toString(),
        gasPrice,
        maxFeePerGas,
        maxPriorityFeePerGas,
        estimatedCost: ethers.formatEther(estimatedCost),
      };
    } catch (error) {
      throw new Error(`Failed to estimate gas: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get current block number
   */
  public async getBlockNumber(): Promise<number> {
    this.ensureConnected();

    try {
      return await this.provider!.getBlockNumber();
    } catch (error) {
      throw new Error(`Failed to get block number: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get token information
   */
  public async getTokenInfo(tokenAddress: string): Promise<TokenInfo> {
    this.ensureConnected();

    try {
      const tokenContract = new ethers.Contract(
        tokenAddress,
        [
          'function name() view returns (string)',
          'function symbol() view returns (string)',
          'function decimals() view returns (uint8)',
          'function totalSupply() view returns (uint256)',
        ],
        this.provider!
      );

      const [name, symbol, decimals, totalSupply] = await Promise.all([
        tokenContract.name(),
        tokenContract.symbol(),
        tokenContract.decimals(),
        tokenContract.totalSupply(),
      ]);

      return {
        address: tokenAddress,
        name,
        symbol,
        decimals,
        totalSupply: ethers.formatUnits(totalSupply, decimals),
      };
    } catch (error) {
      throw new Error(`Failed to get token info: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Wait for transaction confirmation
   */
  public async waitForTransaction(
    hash: string,
    confirmations: number = 1,
    timeout?: number
  ): Promise<TransactionReceipt> {
    this.ensureConnected();

    try {
      const receipt = await this.provider!.waitForTransaction(hash, confirmations, timeout);
      if (!receipt) {
        throw new Error('Transaction not found or timed out');
      }

      return this.getTransactionReceipt(hash);
    } catch (error) {
      throw new Error(`Failed to wait for transaction: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Check if connected
   */
  public isConnected(): boolean {
    return this.connected && this.provider !== null;
  }

  /**
   * Ensure provider is connected
   */
  private ensureConnected(): void {
    if (!this.connected || !this.provider) {
      throw new Error('Not connected to Ethereum network');
    }
  }

  /**
   * Get network information
   */
  public async getNetworkInfo(): Promise<{
    chainId: number;
    name: string;
    blockNumber: number;
  }> {
    this.ensureConnected();

    const network = await this.provider!.getNetwork();
    const blockNumber = await this.provider!.getBlockNumber();

    return {
      chainId: Number(network.chainId),
      name: network.name,
      blockNumber,
    };
  }

  /**
   * Get transaction history for address
   */
  public async getTransactionHistory(
    address: string,
    startBlock: number = 0,
    endBlock: number | string = 'latest'
  ): Promise<Transaction[]> {
    this.ensureConnected();

    try {
      // Note: This requires an archive node or external API like Etherscan
      // For production, integrate with Etherscan/Alchemy/Infura APIs
      throw new Error('Transaction history requires external API integration');
    } catch (error) {
      throw new Error(`Failed to get transaction history: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }
}
