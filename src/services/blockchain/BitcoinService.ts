/**
 * Bitcoin Service
 * Full Bitcoin blockchain integration with bitcoinjs-lib
 */

import * as bitcoin from 'bitcoinjs-lib';
import axios, { AxiosInstance } from 'axios';
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
  UTXO,
} from '../../types/blockchain';

export interface BitcoinConfig extends BlockchainConfig {
  apiUrl: string;
  wsUrl?: string;
}

interface BlockstreamUTXO {
  txid: string;
  vout: number;
  status: {
    confirmed: boolean;
    block_height?: number;
    block_hash?: string;
    block_time?: number;
  };
  value: number;
}

interface BlockstreamTx {
  txid: string;
  version: number;
  locktime: number;
  vin: Array<{
    txid: string;
    vout: number;
    prevout: {
      scriptpubkey: string;
      scriptpubkey_asm: string;
      scriptpubkey_type: string;
      scriptpubkey_address: string;
      value: number;
    };
    scriptsig: string;
    scriptsig_asm: string;
    is_coinbase: boolean;
    sequence: number;
  }>;
  vout: Array<{
    scriptpubkey: string;
    scriptpubkey_asm: string;
    scriptpubkey_type: string;
    scriptpubkey_address?: string;
    value: number;
  }>;
  size: number;
  weight: number;
  fee: number;
  status: {
    confirmed: boolean;
    block_height?: number;
    block_hash?: string;
    block_time?: number;
  };
}

export class BitcoinService implements IBlockchainService {
  private config: BitcoinConfig;
  private network: bitcoin.Network;
  private api: AxiosInstance;
  private connected: boolean = false;

  constructor(config: BitcoinConfig) {
    this.config = config;
    this.network =
      config.network === NetworkType.MAINNET ? bitcoin.networks.bitcoin : bitcoin.networks.testnet;

    this.api = axios.create({
      baseURL: config.apiUrl,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  /**
   * Connect to Bitcoin network
   */
  public async connect(): Promise<void> {
    try {
      // Verify connection by getting block height
      const response = await this.api.get('/blocks/tip/height');
      const blockHeight = response.data;

      console.log(`Connected to Bitcoin ${this.config.network} at block ${blockHeight}`);
      this.connected = true;
    } catch (error) {
      throw new Error(
        `Failed to connect to Bitcoin: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  /**
   * Disconnect from network
   */
  public async disconnect(): Promise<void> {
    this.connected = false;
  }

  /**
   * Get BTC balance for address
   */
  public async getBalance(address: string): Promise<Balance> {
    this.ensureConnected();

    try {
      const response = await this.api.get(`/address/${address}`);
      const data = response.data;

      const satoshis =
        data.chain_stats.funded_txo_sum - data.chain_stats.spent_txo_sum;
      const btc = satoshis / 100000000;

      return {
        address,
        balance: btc.toString(),
        decimals: 8,
        symbol: 'BTC',
      };
    } catch (error) {
      throw new Error(`Failed to get balance: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get transaction by hash
   */
  public async getTransaction(hash: string): Promise<Transaction> {
    this.ensureConnected();

    try {
      const response = await this.api.get<BlockstreamTx>(`/tx/${hash}`);
      const tx = response.data;

      const blockHeight = tx.status.block_height || 0;
      const currentHeight = await this.getBlockNumber();
      const confirmations = blockHeight > 0 ? currentHeight - blockHeight + 1 : 0;

      // Calculate total input and output
      const totalInput = tx.vin.reduce((sum, input) => sum + (input.prevout?.value || 0), 0);
      const totalOutput = tx.vout.reduce((sum, output) => sum + output.value, 0);

      return {
        hash: tx.txid,
        from: tx.vin[0]?.prevout?.scriptpubkey_address || '',
        to: tx.vout[0]?.scriptpubkey_address || '',
        value: (totalOutput / 100000000).toString(),
        nonce: 0, // Bitcoin doesn't use nonces
        blockNumber: tx.status.block_height,
        timestamp: tx.status.block_time,
        confirmations,
        status: tx.status.confirmed ? 'confirmed' : 'pending',
      };
    } catch (error) {
      throw new Error(`Failed to get transaction: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get transaction receipt (Bitcoin uses transaction status)
   */
  public async getTransactionReceipt(hash: string): Promise<TransactionReceipt> {
    this.ensureConnected();

    try {
      const response = await this.api.get<BlockstreamTx>(`/tx/${hash}`);
      const tx = response.data;

      return {
        hash: tx.txid,
        blockNumber: tx.status.block_height || 0,
        blockHash: tx.status.block_hash || '',
        gasUsed: tx.fee.toString(),
        status: tx.status.confirmed,
        logs: [], // Bitcoin doesn't have logs like Ethereum
      };
    } catch (error) {
      throw new Error(`Failed to get transaction receipt: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Send Bitcoin transaction
   */
  public async sendTransaction(
    params: SendTransactionParams,
    privateKeyWIF: string
  ): Promise<string> {
    this.ensureConnected();

    try {
      // Get UTXOs for the sender address
      const utxos = await this.getUTXOs(params.from);

      if (utxos.length === 0) {
        throw new Error('No UTXOs available for transaction');
      }

      // Create transaction
      const psbt = new bitcoin.Psbt({ network: this.network });
      const keyPair = bitcoin.ECPair.fromWIF(privateKeyWIF, this.network);

      // Calculate amount in satoshis
      const amountSatoshis = Math.floor(parseFloat(params.value) * 100000000);

      // Calculate fee (simplified - should use proper fee estimation)
      const feeRate = parseInt(params.gasPrice || '10'); // satoshis per byte
      const estimatedSize = 180 * utxos.length + 34 * 2 + 10; // Rough estimate
      const fee = feeRate * estimatedSize;

      // Select UTXOs to cover amount + fee
      let totalInput = 0;
      const selectedUTXOs: UTXO[] = [];

      for (const utxo of utxos) {
        selectedUTXOs.push(utxo);
        totalInput += Math.floor(utxo.value * 100000000);

        if (totalInput >= amountSatoshis + fee) {
          break;
        }
      }

      if (totalInput < amountSatoshis + fee) {
        throw new Error('Insufficient funds');
      }

      // Add inputs
      for (const utxo of selectedUTXOs) {
        const txHex = await this.getTransactionHex(utxo.txid);
        psbt.addInput({
          hash: utxo.txid,
          index: utxo.vout,
          nonWitnessUtxo: Buffer.from(txHex, 'hex'),
        });
      }

      // Add outputs
      psbt.addOutput({
        address: params.to,
        value: amountSatoshis,
      });

      // Add change output if necessary
      const change = totalInput - amountSatoshis - fee;
      if (change > 546) {
        // Dust threshold
        psbt.addOutput({
          address: params.from,
          value: change,
        });
      }

      // Sign all inputs
      for (let i = 0; i < selectedUTXOs.length; i++) {
        psbt.signInput(i, keyPair);
      }

      // Finalize and extract transaction
      psbt.finalizeAllInputs();
      const txHex = psbt.extractTransaction().toHex();

      // Broadcast transaction
      const response = await this.api.post('/tx', txHex, {
        headers: {
          'Content-Type': 'text/plain',
        },
      });

      return response.data;
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
      // Get recommended fee rates
      const response = await this.api.get('/fee-estimates');
      const feeRates = response.data;

      // Use medium priority (6 blocks)
      const feeRate = Math.ceil(feeRates['6'] || 10);

      // Estimate transaction size
      const utxos = await this.getUTXOs(params.from);
      const numInputs = Math.min(utxos.length, 3); // Assume max 3 inputs
      const numOutputs = 2; // One output + change

      const estimatedSize = 180 * numInputs + 34 * numOutputs + 10;
      const estimatedFee = feeRate * estimatedSize;

      return {
        gasLimit: estimatedSize.toString(),
        gasPrice: feeRate.toString(),
        estimatedCost: (estimatedFee / 100000000).toString(),
      };
    } catch (error) {
      throw new Error(`Failed to estimate fee: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get current block height
   */
  public async getBlockNumber(): Promise<number> {
    this.ensureConnected();

    try {
      const response = await this.api.get('/blocks/tip/height');
      return response.data;
    } catch (error) {
      throw new Error(`Failed to get block number: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get UTXOs for address
   */
  public async getUTXOs(address: string): Promise<UTXO[]> {
    this.ensureConnected();

    try {
      const response = await this.api.get<BlockstreamUTXO[]>(`/address/${address}/utxo`);
      const utxos = response.data;

      const currentHeight = await this.getBlockNumber();

      return utxos.map((utxo) => ({
        txid: utxo.txid,
        vout: utxo.vout,
        value: utxo.value / 100000000,
        scriptPubKey: '',
        confirmations: utxo.status.block_height
          ? currentHeight - utxo.status.block_height + 1
          : 0,
        address,
      }));
    } catch (error) {
      throw new Error(`Failed to get UTXOs: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get transaction hex
   */
  private async getTransactionHex(txid: string): Promise<string> {
    try {
      const response = await this.api.get(`/tx/${txid}/hex`);
      return response.data;
    } catch (error) {
      throw new Error(`Failed to get transaction hex: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Get transaction history for address
   */
  public async getTransactionHistory(address: string): Promise<Transaction[]> {
    this.ensureConnected();

    try {
      const response = await this.api.get<BlockstreamTx[]>(`/address/${address}/txs`);
      const txs = response.data;

      const currentHeight = await this.getBlockNumber();

      return txs.map((tx) => {
        const confirmations = tx.status.block_height
          ? currentHeight - tx.status.block_height + 1
          : 0;

        const totalOutput = tx.vout.reduce((sum, output) => sum + output.value, 0);

        return {
          hash: tx.txid,
          from: tx.vin[0]?.prevout?.scriptpubkey_address || '',
          to: tx.vout[0]?.scriptpubkey_address || '',
          value: (totalOutput / 100000000).toString(),
          nonce: 0,
          blockNumber: tx.status.block_height,
          timestamp: tx.status.block_time,
          confirmations,
          status: tx.status.confirmed ? 'confirmed' : 'pending',
        };
      });
    } catch (error) {
      throw new Error(`Failed to get transaction history: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Check if connected
   */
  public isConnected(): boolean {
    return this.connected;
  }

  /**
   * Ensure connected
   */
  private ensureConnected(): void {
    if (!this.connected) {
      throw new Error('Not connected to Bitcoin network');
    }
  }
}
