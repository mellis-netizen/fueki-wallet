/**
 * Solana Service
 * Full Solana blockchain integration with @solana/web3.js
 */

import {
  Connection,
  PublicKey,
  Transaction as SolanaTransaction,
  SystemProgram,
  Keypair,
  LAMPORTS_PER_SOL,
  sendAndConfirmTransaction,
  TransactionSignature,
  ParsedTransactionWithMeta,
  ConfirmedSignatureInfo,
} from '@solana/web3.js';
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
} from '../../types/blockchain';

export interface SolanaConfig extends BlockchainConfig {
  commitment?: 'processed' | 'confirmed' | 'finalized';
}

export class SolanaService implements IBlockchainService {
  private connection: Connection | null = null;
  private config: SolanaConfig;
  private connected: boolean = false;

  constructor(config: SolanaConfig) {
    this.config = config;
  }

  /**
   * Connect to Solana network
   */
  public async connect(): Promise<void> {
    try {
      this.connection = new Connection(
        this.config.rpcUrl,
        this.config.commitment || 'confirmed'
      );

      // Verify connection
      const version = await this.connection.getVersion();
      const slot = await this.connection.getSlot();

      console.log(
        `Connected to Solana ${this.config.network} (version ${version['solana-core']}) at slot ${slot}`
      );

      this.connected = true;
    } catch (error) {
      throw new Error(
        `Failed to connect to Solana: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Disconnect from network
   */
  public async disconnect(): Promise<void> {
    this.connection = null;
    this.connected = false;
  }

  /**
   * Get SOL balance for address
   */
  public async getBalance(address: string): Promise<Balance> {
    this.ensureConnected();

    try {
      const publicKey = new PublicKey(address);
      const lamports = await this.connection!.getBalance(publicKey);
      const sol = lamports / LAMPORTS_PER_SOL;

      return {
        address,
        balance: sol.toString(),
        decimals: 9,
        symbol: 'SOL',
      };
    } catch (error) {
      throw new Error(`Failed to get balance: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get SPL token balance
   */
  public async getTokenBalance(tokenMint: string, walletAddress: string): Promise<Balance> {
    this.ensureConnected();

    try {
      const publicKey = new PublicKey(walletAddress);
      const mintPublicKey = new PublicKey(tokenMint);

      // Get token accounts for the wallet
      const tokenAccounts = await this.connection!.getTokenAccountsByOwner(publicKey, {
        mint: mintPublicKey,
      });

      if (tokenAccounts.value.length === 0) {
        return {
          address: walletAddress,
          balance: '0',
          decimals: 9,
          symbol: 'SPL',
        };
      }

      const accountInfo = await this.connection!.getTokenAccountBalance(
        tokenAccounts.value[0].pubkey
      );

      return {
        address: walletAddress,
        balance: accountInfo.value.uiAmountString || '0',
        decimals: accountInfo.value.decimals,
        symbol: 'SPL',
      };
    } catch (error) {
      throw new Error(`Failed to get token balance: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get transaction by signature
   */
  public async getTransaction(signature: string): Promise<Transaction> {
    this.ensureConnected();

    try {
      const tx = await this.connection!.getParsedTransaction(signature, {
        maxSupportedTransactionVersion: 0,
      });

      if (!tx) {
        throw new Error(`Transaction ${signature} not found`);
      }

      const slot = await this.connection!.getSlot();
      const confirmations = tx.slot ? slot - tx.slot : 0;

      // Extract transaction details
      const message = tx.transaction.message;
      const accountKeys = message.accountKeys;

      const from = accountKeys[0]?.pubkey.toBase58() || '';
      const to = accountKeys[1]?.pubkey.toBase58() || '';

      // Calculate value from pre/post balances
      let value = '0';
      if (tx.meta && tx.meta.preBalances && tx.meta.postBalances) {
        const diff = tx.meta.postBalances[1] - tx.meta.preBalances[1];
        value = (diff / LAMPORTS_PER_SOL).toString();
      }

      return {
        hash: signature,
        from,
        to,
        value,
        nonce: 0,
        blockNumber: tx.slot,
        timestamp: tx.blockTime || undefined,
        confirmations,
        status: tx.meta?.err ? 'failed' : 'confirmed',
      };
    } catch (error) {
      throw new Error(`Failed to get transaction: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get transaction receipt
   */
  public async getTransactionReceipt(signature: string): Promise<TransactionReceipt> {
    this.ensureConnected();

    try {
      const tx = await this.connection!.getParsedTransaction(signature, {
        maxSupportedTransactionVersion: 0,
      });

      if (!tx) {
        throw new Error(`Transaction ${signature} not found`);
      }

      return {
        hash: signature,
        blockNumber: tx.slot || 0,
        blockHash: tx.transaction.message.recentBlockhash || '',
        gasUsed: tx.meta?.fee.toString() || '0',
        status: !tx.meta?.err,
        logs: [],
      };
    } catch (error) {
      throw new Error(`Failed to get transaction receipt: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Send SOL transaction
   */
  public async sendTransaction(
    params: SendTransactionParams,
    privateKey: string
  ): Promise<string> {
    this.ensureConnected();

    try {
      // Convert private key from hex/base58 to Keypair
      const secretKey = Buffer.from(privateKey, 'hex');
      const fromKeypair = Keypair.fromSecretKey(secretKey);

      const toPubkey = new PublicKey(params.to);
      const lamports = Math.floor(parseFloat(params.value) * LAMPORTS_PER_SOL);

      // Create transaction
      const transaction = new SolanaTransaction().add(
        SystemProgram.transfer({
          fromPubkey: fromKeypair.publicKey,
          toPubkey,
          lamports,
        })
      );

      // Send and confirm transaction
      const signature = await sendAndConfirmTransaction(
        this.connection!,
        transaction,
        [fromKeypair],
        {
          commitment: 'confirmed',
        }
      );

      return signature;
    } catch (error) {
      throw new Error(`Failed to send transaction: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Estimate fee for transaction
   */
  public async estimateGas(params: SendTransactionParams): Promise<GasEstimate> {
    this.ensureConnected();

    try {
      // Get recent prioritization fees
      const recentFees = await this.connection!.getRecentPrioritizationFees();

      const avgFee =
        recentFees.length > 0
          ? recentFees.reduce((sum, fee) => sum + fee.prioritizationFee, 0) / recentFees.length
          : 5000;

      // Base fee is ~5000 lamports
      const baseFee = 5000;
      const totalFee = baseFee + avgFee;

      return {
        gasLimit: '1',
        gasPrice: totalFee.toString(),
        estimatedCost: (totalFee / LAMPORTS_PER_SOL).toString(),
      };
    } catch (error) {
      // Return default estimate if API fails
      return {
        gasLimit: '1',
        gasPrice: '5000',
        estimatedCost: '0.000005',
      };
    }
  }

  /**
   * Get current slot (equivalent to block number)
   */
  public async getBlockNumber(): Promise<number> {
    this.ensureConnected();

    try {
      return await this.connection!.getSlot();
    } catch (error) {
      throw new Error(`Failed to get slot: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get transaction history for address
   */
  public async getTransactionHistory(
    address: string,
    limit: number = 10
  ): Promise<Transaction[]> {
    this.ensureConnected();

    try {
      const publicKey = new PublicKey(address);

      const signatures = await this.connection!.getSignaturesForAddress(publicKey, {
        limit,
      });

      const transactions: Transaction[] = [];

      for (const sig of signatures) {
        try {
          const tx = await this.getTransaction(sig.signature);
          transactions.push(tx);
        } catch (error) {
          console.error(`Failed to fetch transaction ${sig.signature}:`, error);
        }
      }

      return transactions;
    } catch (error) {
      throw new Error(`Failed to get transaction history: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Wait for transaction confirmation
   */
  public async waitForTransaction(
    signature: string,
    commitment: 'processed' | 'confirmed' | 'finalized' = 'confirmed'
  ): Promise<TransactionReceipt> {
    this.ensureConnected();

    try {
      const result = await this.connection!.confirmTransaction(signature, commitment);

      if (result.value.err) {
        throw new Error(`Transaction failed: ${JSON.stringify(result.value.err)}`);
      }

      return await this.getTransactionReceipt(signature);
    } catch (error) {
      throw new Error(`Failed to wait for transaction: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Check if connected
   */
  public isConnected(): boolean {
    return this.connected && this.connection !== null;
  }

  /**
   * Ensure connected
   */
  private ensureConnected(): void {
    if (!this.connected || !this.connection) {
      throw new Error('Not connected to Solana network');
    }
  }

  /**
   * Get network information
   */
  public async getNetworkInfo(): Promise<{
    version: string;
    slot: number;
    epochInfo: any;
  }> {
    this.ensureConnected();

    const version = await this.connection!.getVersion();
    const slot = await this.connection!.getSlot();
    const epochInfo = await this.connection!.getEpochInfo();

    return {
      version: version['solana-core'],
      slot,
      epochInfo,
    };
  }
}
