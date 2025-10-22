/**
 * Transaction Service
 * Universal transaction handling across multiple blockchains
 */

import {
  ChainType,
  NetworkType,
  Transaction,
  TransactionReceipt,
  GasEstimate,
  SendTransactionParams,
} from '../../types/blockchain';
import { BlockchainFactory } from './BlockchainFactory';

export interface TransactionOptions {
  waitForConfirmation?: boolean;
  confirmations?: number;
  timeout?: number;
}

export interface TransactionResult {
  hash: string;
  chain: ChainType;
  network: NetworkType;
  status: 'pending' | 'confirmed' | 'failed';
  receipt?: TransactionReceipt;
}

/**
 * Transaction Service
 * Provides universal transaction handling across all supported chains
 */
export class TransactionService {
  /**
   * Send transaction on any supported chain
   */
  public static async sendTransaction(
    chain: ChainType,
    network: NetworkType,
    params: SendTransactionParams,
    privateKey: string,
    options: TransactionOptions = {}
  ): Promise<TransactionResult> {
    // Get or create blockchain service
    const service = BlockchainFactory.createService(chain, network);

    // Ensure connected
    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      // Send transaction
      const hash = await service.sendTransaction(params, privateKey);

      const result: TransactionResult = {
        hash,
        chain,
        network,
        status: 'pending',
      };

      // Wait for confirmation if requested
      if (options.waitForConfirmation) {
        const receipt = await this.waitForConfirmation(
          chain,
          network,
          hash,
          options.confirmations || 1,
          options.timeout
        );

        result.status = receipt.status ? 'confirmed' : 'failed';
        result.receipt = receipt;
      }

      return result;
    } catch (error) {
      throw new Error(
        `Failed to send transaction on ${chain}: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Estimate gas for transaction
   */
  public static async estimateGas(
    chain: ChainType,
    network: NetworkType,
    params: SendTransactionParams
  ): Promise<GasEstimate> {
    const service = BlockchainFactory.createService(chain, network);

    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      return await service.estimateGas(params);
    } catch (error) {
      throw new Error(
        `Failed to estimate gas on ${chain}: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Get transaction details
   */
  public static async getTransaction(
    chain: ChainType,
    network: NetworkType,
    hash: string
  ): Promise<Transaction> {
    const service = BlockchainFactory.createService(chain, network);

    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      return await service.getTransaction(hash);
    } catch (error) {
      throw new Error(
        `Failed to get transaction on ${chain}: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Get transaction receipt
   */
  public static async getTransactionReceipt(
    chain: ChainType,
    network: NetworkType,
    hash: string
  ): Promise<TransactionReceipt> {
    const service = BlockchainFactory.createService(chain, network);

    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      return await service.getTransactionReceipt(hash);
    } catch (error) {
      throw new Error(
        `Failed to get transaction receipt on ${chain}: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Wait for transaction confirmation
   */
  public static async waitForConfirmation(
    chain: ChainType,
    network: NetworkType,
    hash: string,
    confirmations: number = 1,
    timeout?: number
  ): Promise<TransactionReceipt> {
    const service = BlockchainFactory.createService(chain, network);

    if (!service.isConnected()) {
      await service.connect();
    }

    const startTime = Date.now();
    const timeoutMs = timeout || 300000; // 5 minutes default

    try {
      while (true) {
        // Check timeout
        if (Date.now() - startTime > timeoutMs) {
          throw new Error('Transaction confirmation timeout');
        }

        try {
          // Get transaction receipt
          const receipt = await service.getTransactionReceipt(hash);

          // Get current block number
          const currentBlock = await service.getBlockNumber();
          const txConfirmations = currentBlock - receipt.blockNumber + 1;

          // Check if enough confirmations
          if (txConfirmations >= confirmations) {
            return receipt;
          }
        } catch (error) {
          // Transaction not yet mined, continue waiting
        }

        // Wait before checking again
        await new Promise((resolve) => setTimeout(resolve, 2000));
      }
    } catch (error) {
      throw new Error(
        `Failed to wait for confirmation on ${chain}: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Batch send multiple transactions
   */
  public static async batchSendTransactions(
    chain: ChainType,
    network: NetworkType,
    transactions: Array<{ params: SendTransactionParams; privateKey: string }>,
    options: TransactionOptions = {}
  ): Promise<TransactionResult[]> {
    const results: TransactionResult[] = [];

    for (const tx of transactions) {
      try {
        const result = await this.sendTransaction(
          chain,
          network,
          tx.params,
          tx.privateKey,
          options
        );
        results.push(result);
      } catch (error) {
        results.push({
          hash: '',
          chain,
          network,
          status: 'failed',
        });
      }
    }

    return results;
  }

  /**
   * Get transaction status
   */
  public static async getTransactionStatus(
    chain: ChainType,
    network: NetworkType,
    hash: string
  ): Promise<'pending' | 'confirmed' | 'failed'> {
    try {
      const receipt = await this.getTransactionReceipt(chain, network, hash);
      return receipt.status ? 'confirmed' : 'failed';
    } catch (error) {
      // If receipt not found, transaction is still pending
      return 'pending';
    }
  }

  /**
   * Cancel/speed up transaction (Ethereum only)
   */
  public static async speedUpTransaction(
    chain: ChainType,
    network: NetworkType,
    originalTxHash: string,
    privateKey: string,
    newGasPrice: string
  ): Promise<string> {
    if (chain !== ChainType.ETHEREUM) {
      throw new Error('Speed up transaction only supported on Ethereum');
    }

    const service = BlockchainFactory.createService(chain, network);

    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      // Get original transaction
      const originalTx = await service.getTransaction(originalTxHash);

      // Create new transaction with same nonce but higher gas price
      const params: SendTransactionParams = {
        from: originalTx.from,
        to: originalTx.to,
        value: originalTx.value,
        data: originalTx.data,
        nonce: originalTx.nonce,
        gasPrice: newGasPrice,
      };

      return await service.sendTransaction(params, privateKey);
    } catch (error) {
      throw new Error(
        `Failed to speed up transaction: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Cancel transaction (Ethereum only)
   */
  public static async cancelTransaction(
    chain: ChainType,
    network: NetworkType,
    originalTxHash: string,
    privateKey: string,
    gasPrice: string
  ): Promise<string> {
    if (chain !== ChainType.ETHEREUM) {
      throw new Error('Cancel transaction only supported on Ethereum');
    }

    const service = BlockchainFactory.createService(chain, network);

    if (!service.isConnected()) {
      await service.connect();
    }

    try {
      // Get original transaction
      const originalTx = await service.getTransaction(originalTxHash);

      // Send 0 ETH to self with same nonce
      const params: SendTransactionParams = {
        from: originalTx.from,
        to: originalTx.from,
        value: '0',
        nonce: originalTx.nonce,
        gasPrice,
      };

      return await service.sendTransaction(params, privateKey);
    } catch (error) {
      throw new Error(
        `Failed to cancel transaction: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }
}
