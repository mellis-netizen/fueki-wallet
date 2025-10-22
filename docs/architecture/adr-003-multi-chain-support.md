# ADR-003: Multi-Chain Support Architecture

## Status
**ACCEPTED** - 2025-10-21

## Context

Fueki Mobile Wallet must support multiple blockchain networks (Bitcoin, Ethereum, and potentially others) with a unified user experience. Each blockchain has unique characteristics:

- **Bitcoin**: UTXO model, SegWit, Taproot, multiple address formats
- **Ethereum**: Account model, ERC-20 tokens, smart contracts, EIP-1559 gas
- **Future Chains**: Solana, Polygon, Arbitrum, etc.

### Requirements
1. **Unified Interface**: Consistent API across all chains
2. **Extensibility**: Easy addition of new blockchains
3. **Isolation**: Chain-specific logic contained
4. **Type Safety**: TypeScript interfaces for all chains
5. **Performance**: Efficient balance and transaction queries
6. **Flexibility**: Support chain-specific features

### Constraints
- React Native environment
- Limited device resources
- Must work offline (cached data)
- No assumptions about chain similarities

## Decision

We will implement a **Chain Adapter Pattern** with a unified domain model and pluggable blockchain-specific implementations.

## Architecture

### High-Level Multi-Chain Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Application Layer                            │
│              (React Components, Screens)                        │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Chain-Agnostic Services                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Wallet       │  │ Transaction  │  │ Balance      │         │
│  │ Manager      │  │ Manager      │  │ Manager      │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Chain Registry                                │
│            (Maps Chain ID → Chain Adapter)                      │
└─────────────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼
┌──────────────────┐  ┌──────────────┐  ┌──────────────┐
│  Bitcoin         │  │  Ethereum    │  │  Future      │
│  Adapter         │  │  Adapter     │  │  Adapters    │
│                  │  │              │  │              │
│  ├─ Address Gen │  │  ├─ Address  │  │  ├─ ...     │
│  ├─ TX Builder  │  │  ├─ TX       │  │  ├─ ...     │
│  ├─ Signer      │  │  ├─ Signer   │  │  ├─ ...     │
│  └─ RPC Client  │  │  └─ RPC      │  │  └─ ...     │
└──────────────────┘  └──────────────┘  └──────────────┘
            │               │               │
            └───────────────┼───────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Blockchain Networks                           │
│     (Bitcoin Network, Ethereum Network, etc.)                   │
└─────────────────────────────────────────────────────────────────┘
```

### Core Abstractions

#### 1. Chain Adapter Interface

```typescript
// src/core/chains/IChainAdapter.ts

/**
 * Unified interface that all chain adapters must implement
 */
export interface IChainAdapter {
  // Chain identification
  readonly chainId: string;
  readonly name: string;
  readonly symbol: string;
  readonly decimals: number;
  readonly network: Network;

  // Address operations
  generateAddress(publicKey: Uint8Array, addressType?: AddressType): string;
  validateAddress(address: string): boolean;
  deriveAddressFromPath(path: string): Promise<Address>;

  // Balance operations
  getBalance(address: string): Promise<Balance>;
  getBalances(addresses: string[]): Promise<Map<string, Balance>>;

  // Transaction operations
  buildTransaction(params: TransactionParams): Promise<UnsignedTransaction>;
  signTransaction(unsignedTx: UnsignedTransaction, privateKey: Uint8Array): Promise<SignedTransaction>;
  broadcastTransaction(signedTx: SignedTransaction): Promise<TransactionReceipt>;
  getTransaction(txHash: string): Promise<Transaction>;
  getTransactionHistory(address: string, options?: PaginationOptions): Promise<Transaction[]>;

  // Fee estimation
  estimateFee(params: FeeEstimationParams): Promise<FeeEstimate>;

  // Network operations
  getBlockHeight(): Promise<number>;
  getBlockByHeight(height: number): Promise<Block>;
  subscribeToNewBlocks(callback: (block: Block) => void): Subscription;

  // Chain-specific features
  supports(feature: ChainFeature): boolean;
  getChainSpecificData<T = any>(): T;
}

export enum ChainFeature {
  SMART_CONTRACTS = 'smart_contracts',
  TOKENS = 'tokens',
  NFT = 'nft',
  MULTISIG = 'multisig',
  STAKING = 'staking',
  MESSAGING = 'messaging',
}

export enum Network {
  MAINNET = 'mainnet',
  TESTNET = 'testnet',
  DEVNET = 'devnet',
}

export enum AddressType {
  LEGACY = 'legacy',          // Bitcoin P2PKH
  SEGWIT = 'segwit',          // Bitcoin P2WPKH
  NESTED_SEGWIT = 'nested',   // Bitcoin P2SH-P2WPKH
  TAPROOT = 'taproot',        // Bitcoin P2TR
  DEFAULT = 'default',        // Chain's default type
}
```

#### 2. Unified Domain Models

```typescript
// src/core/chains/models/Transaction.ts

export interface Transaction {
  hash: string;
  from: string;
  to: string;
  value: BigInt;
  fee: BigInt;
  timestamp: number;
  blockHeight?: number;
  confirmations: number;
  status: TransactionStatus;
  chainId: string;
  data?: TransactionData;
}

export interface UnsignedTransaction {
  chainId: string;
  from: string;
  to: string;
  value: BigInt;
  fee: FeeEstimate;
  nonce?: number;
  data?: any;
}

export interface SignedTransaction {
  chainId: string;
  rawTransaction: string;
  hash: string;
}

export interface TransactionReceipt {
  hash: string;
  status: TransactionStatus;
  blockHeight: number;
  confirmations: number;
  fee: BigInt;
}

export enum TransactionStatus {
  PENDING = 'pending',
  CONFIRMED = 'confirmed',
  FAILED = 'failed',
}

// src/core/chains/models/Balance.ts

export interface Balance {
  address: string;
  chainId: string;
  confirmed: BigInt;
  unconfirmed: BigInt;
  total: BigInt;
  tokens?: TokenBalance[];
}

export interface TokenBalance {
  contractAddress: string;
  symbol: string;
  decimals: number;
  balance: BigInt;
}

// src/core/chains/models/Address.ts

export interface Address {
  address: string;
  chainId: string;
  addressType: AddressType;
  derivationPath: string;
  publicKey: string;
}

// src/core/chains/models/Fee.ts

export interface FeeEstimate {
  chainId: string;
  slow: BigInt;
  medium: BigInt;
  fast: BigInt;
  estimatedTime: {
    slow: number;      // seconds
    medium: number;
    fast: number;
  };
}
```

### Chain Adapter Implementations

#### 3. Bitcoin Adapter

```typescript
// src/core/chains/adapters/BitcoinAdapter.ts

import * as bitcoin from 'bitcoinjs-lib';
import { IChainAdapter, ChainFeature, AddressType } from '../IChainAdapter';
import { BitcoinRPCClient } from '../../network/BitcoinRPCClient';
import { CryptoService } from '../../crypto/CryptoService';

export class BitcoinAdapter implements IChainAdapter {
  readonly chainId = 'bitcoin';
  readonly name = 'Bitcoin';
  readonly symbol = 'BTC';
  readonly decimals = 8;
  readonly network: Network;

  private rpcClient: BitcoinRPCClient;
  private bitcoinNetwork: bitcoin.Network;

  constructor(network: Network = Network.MAINNET) {
    this.network = network;
    this.bitcoinNetwork = network === Network.MAINNET
      ? bitcoin.networks.bitcoin
      : bitcoin.networks.testnet;
    this.rpcClient = new BitcoinRPCClient(this.bitcoinNetwork);
  }

  // Address generation
  generateAddress(publicKey: Uint8Array, addressType: AddressType = AddressType.SEGWIT): string {
    switch (addressType) {
      case AddressType.LEGACY:
        return this.generateLegacyAddress(publicKey);
      case AddressType.SEGWIT:
        return this.generateSegWitAddress(publicKey);
      case AddressType.NESTED_SEGWIT:
        return this.generateNestedSegWitAddress(publicKey);
      case AddressType.TAPROOT:
        return this.generateTaprootAddress(publicKey);
      default:
        return this.generateSegWitAddress(publicKey);
    }
  }

  private generateSegWitAddress(publicKey: Uint8Array): string {
    const { address } = bitcoin.payments.p2wpkh({
      pubkey: Buffer.from(publicKey),
      network: this.bitcoinNetwork,
    });
    return address!;
  }

  private generateLegacyAddress(publicKey: Uint8Array): string {
    const { address } = bitcoin.payments.p2pkh({
      pubkey: Buffer.from(publicKey),
      network: this.bitcoinNetwork,
    });
    return address!;
  }

  private generateNestedSegWitAddress(publicKey: Uint8Array): string {
    const { address } = bitcoin.payments.p2sh({
      redeem: bitcoin.payments.p2wpkh({
        pubkey: Buffer.from(publicKey),
        network: this.bitcoinNetwork,
      }),
      network: this.bitcoinNetwork,
    });
    return address!;
  }

  private generateTaprootAddress(publicKey: Uint8Array): string {
    // Taproot requires 32-byte x-only public key
    const xOnlyPubkey = publicKey.slice(1, 33);
    const { address } = bitcoin.payments.p2tr({
      internalPubkey: Buffer.from(xOnlyPubkey),
      network: this.bitcoinNetwork,
    });
    return address!;
  }

  validateAddress(address: string): boolean {
    try {
      bitcoin.address.toOutputScript(address, this.bitcoinNetwork);
      return true;
    } catch {
      return false;
    }
  }

  // Transaction building
  async buildTransaction(params: TransactionParams): Promise<UnsignedTransaction> {
    const { from, to, value, feeRate } = params;

    // Get UTXOs for sender
    const utxos = await this.rpcClient.getUTXOs(from);

    // Select UTXOs (simple algorithm - can be optimized)
    const selectedUTXOs = this.selectUTXOs(utxos, value, feeRate);

    // Create PSBT
    const psbt = new bitcoin.Psbt({ network: this.bitcoinNetwork });

    // Add inputs
    for (const utxo of selectedUTXOs) {
      psbt.addInput({
        hash: utxo.txid,
        index: utxo.vout,
        witnessUtxo: {
          script: Buffer.from(utxo.scriptPubKey, 'hex'),
          value: utxo.value,
        },
      });
    }

    // Add output (recipient)
    psbt.addOutput({
      address: to,
      value: Number(value),
    });

    // Add change output if needed
    const totalInput = selectedUTXOs.reduce((sum, utxo) => sum + utxo.value, 0);
    const fee = this.calculateFee(selectedUTXOs.length, 2, feeRate);
    const change = totalInput - Number(value) - fee;

    if (change > 0) {
      psbt.addOutput({
        address: from,
        value: change,
      });
    }

    return {
      chainId: this.chainId,
      from,
      to,
      value,
      fee: { medium: BigInt(fee) } as FeeEstimate,
      data: { psbt: psbt.toBase64() },
    };
  }

  async signTransaction(unsignedTx: UnsignedTransaction, privateKey: Uint8Array): Promise<SignedTransaction> {
    const psbt = bitcoin.Psbt.fromBase64(unsignedTx.data.psbt, { network: this.bitcoinNetwork });
    const keyPair = bitcoin.ECPair.fromPrivateKey(Buffer.from(privateKey), { network: this.bitcoinNetwork });

    // Sign all inputs
    for (let i = 0; i < psbt.inputCount; i++) {
      psbt.signInput(i, keyPair);
    }

    // Finalize and extract transaction
    psbt.finalizeAllInputs();
    const tx = psbt.extractTransaction();

    return {
      chainId: this.chainId,
      rawTransaction: tx.toHex(),
      hash: tx.getId(),
    };
  }

  async broadcastTransaction(signedTx: SignedTransaction): Promise<TransactionReceipt> {
    const txHash = await this.rpcClient.broadcastTransaction(signedTx.rawTransaction);

    return {
      hash: txHash,
      status: TransactionStatus.PENDING,
      blockHeight: 0,
      confirmations: 0,
      fee: BigInt(0), // Will be filled when confirmed
    };
  }

  async getBalance(address: string): Promise<Balance> {
    const utxos = await this.rpcClient.getUTXOs(address);

    const confirmed = utxos
      .filter(utxo => utxo.confirmations >= 6)
      .reduce((sum, utxo) => sum + BigInt(utxo.value), BigInt(0));

    const unconfirmed = utxos
      .filter(utxo => utxo.confirmations < 6)
      .reduce((sum, utxo) => sum + BigInt(utxo.value), BigInt(0));

    return {
      address,
      chainId: this.chainId,
      confirmed,
      unconfirmed,
      total: confirmed + unconfirmed,
    };
  }

  async estimateFee(params: FeeEstimationParams): Promise<FeeEstimate> {
    const feeRates = await this.rpcClient.estimateSmartFee([6, 3, 1]);

    // Estimate transaction size (inputs + outputs)
    const txSize = this.estimateTransactionSize(params.inputCount || 2, params.outputCount || 2);

    return {
      chainId: this.chainId,
      slow: BigInt(Math.ceil(txSize * feeRates.slow)),
      medium: BigInt(Math.ceil(txSize * feeRates.medium)),
      fast: BigInt(Math.ceil(txSize * feeRates.fast)),
      estimatedTime: {
        slow: 3600,      // ~1 hour
        medium: 1800,    // ~30 minutes
        fast: 600,       // ~10 minutes
      },
    };
  }

  supports(feature: ChainFeature): boolean {
    return feature === ChainFeature.MULTISIG;
  }

  getChainSpecificData() {
    return {
      network: this.bitcoinNetwork,
      addressTypes: [AddressType.LEGACY, AddressType.SEGWIT, AddressType.NESTED_SEGWIT, AddressType.TAPROOT],
    };
  }

  // Helper methods
  private selectUTXOs(utxos: UTXO[], targetValue: BigInt, feeRate: number): UTXO[] {
    // Simple greedy algorithm - can be improved with coin selection algorithms
    const sorted = utxos.sort((a, b) => b.value - a.value);
    const selected: UTXO[] = [];
    let total = 0;

    for (const utxo of sorted) {
      selected.push(utxo);
      total += utxo.value;

      const fee = this.calculateFee(selected.length, 2, feeRate);
      if (total >= Number(targetValue) + fee) {
        break;
      }
    }

    return selected;
  }

  private calculateFee(inputCount: number, outputCount: number, feeRate: number): number {
    // Estimate transaction size in vBytes
    const txSize = this.estimateTransactionSize(inputCount, outputCount);
    return Math.ceil(txSize * feeRate);
  }

  private estimateTransactionSize(inputCount: number, outputCount: number): number {
    // SegWit transaction size estimation
    // Overhead: 10 bytes
    // Input: 68 bytes (SegWit)
    // Output: 31 bytes
    return 10 + (inputCount * 68) + (outputCount * 31);
  }
}
```

#### 4. Ethereum Adapter

```typescript
// src/core/chains/adapters/EthereumAdapter.ts

import { JsonRpcProvider, Wallet, parseEther, formatEther, Transaction as EthersTransaction } from 'ethers';
import { IChainAdapter, ChainFeature } from '../IChainAdapter';
import { CryptoService } from '../../crypto/CryptoService';

export class EthereumAdapter implements IChainAdapter {
  readonly chainId = 'ethereum';
  readonly name = 'Ethereum';
  readonly symbol = 'ETH';
  readonly decimals = 18;
  readonly network: Network;

  private provider: JsonRpcProvider;
  private networkChainId: number;

  constructor(network: Network = Network.MAINNET, rpcUrl?: string) {
    this.network = network;
    this.networkChainId = network === Network.MAINNET ? 1 : 11155111; // Sepolia testnet

    const defaultRpcUrl = network === Network.MAINNET
      ? 'https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY'
      : 'https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY';

    this.provider = new JsonRpcProvider(rpcUrl || defaultRpcUrl, this.networkChainId);
  }

  // Address generation
  generateAddress(publicKey: Uint8Array): string {
    return CryptoService.toEthereumAddress(publicKey);
  }

  validateAddress(address: string): boolean {
    return /^0x[a-fA-F0-9]{40}$/.test(address);
  }

  async deriveAddressFromPath(path: string): Promise<Address> {
    // This would use the KeyManagementService to derive the key
    throw new Error('Use KeyManagementService.deriveAddressKey instead');
  }

  // Balance operations
  async getBalance(address: string): Promise<Balance> {
    const balance = await this.provider.getBalance(address);

    return {
      address,
      chainId: this.chainId,
      confirmed: balance,
      unconfirmed: BigInt(0),
      total: balance,
    };
  }

  async getBalances(addresses: string[]): Promise<Map<string, Balance>> {
    const balances = new Map<string, Balance>();

    // Batch request for efficiency
    const promises = addresses.map(addr => this.getBalance(addr));
    const results = await Promise.all(promises);

    results.forEach((balance, index) => {
      balances.set(addresses[index], balance);
    });

    return balances;
  }

  // Transaction operations
  async buildTransaction(params: TransactionParams): Promise<UnsignedTransaction> {
    const { from, to, value, data } = params;

    // Get current nonce
    const nonce = await this.provider.getTransactionCount(from, 'pending');

    // Get current gas prices (EIP-1559)
    const feeData = await this.provider.getFeeData();

    // Estimate gas limit
    const gasLimit = await this.provider.estimateGas({
      from,
      to,
      value,
      data,
    });

    return {
      chainId: this.chainId,
      from,
      to,
      value,
      nonce,
      fee: {
        slow: feeData.gasPrice! * gasLimit,
        medium: feeData.gasPrice! * gasLimit,
        fast: feeData.maxFeePerGas! * gasLimit,
      } as FeeEstimate,
      data: {
        gasLimit,
        maxFeePerGas: feeData.maxFeePerGas,
        maxPriorityFeePerGas: feeData.maxPriorityFeePerGas,
        type: 2, // EIP-1559
        data,
      },
    };
  }

  async signTransaction(unsignedTx: UnsignedTransaction, privateKey: Uint8Array): Promise<SignedTransaction> {
    const wallet = new Wallet(Buffer.from(privateKey).toString('hex'), this.provider);

    const tx = {
      to: unsignedTx.to,
      value: unsignedTx.value,
      nonce: unsignedTx.nonce,
      gasLimit: unsignedTx.data.gasLimit,
      maxFeePerGas: unsignedTx.data.maxFeePerGas,
      maxPriorityFeePerGas: unsignedTx.data.maxPriorityFeePerGas,
      type: 2,
      chainId: this.networkChainId,
      data: unsignedTx.data.data || '0x',
    };

    const signedTx = await wallet.signTransaction(tx);

    // Parse to get hash
    const parsedTx = EthersTransaction.from(signedTx);

    return {
      chainId: this.chainId,
      rawTransaction: signedTx,
      hash: parsedTx.hash!,
    };
  }

  async broadcastTransaction(signedTx: SignedTransaction): Promise<TransactionReceipt> {
    const response = await this.provider.broadcastTransaction(signedTx.rawTransaction);

    return {
      hash: response.hash,
      status: TransactionStatus.PENDING,
      blockHeight: 0,
      confirmations: 0,
      fee: BigInt(0), // Will be filled when confirmed
    };
  }

  async getTransaction(txHash: string): Promise<Transaction> {
    const tx = await this.provider.getTransaction(txHash);
    const receipt = await this.provider.getTransactionReceipt(txHash);

    if (!tx) {
      throw new Error('Transaction not found');
    }

    return {
      hash: tx.hash,
      from: tx.from,
      to: tx.to || '',
      value: tx.value,
      fee: receipt ? receipt.gasUsed * (receipt.gasPrice || tx.gasPrice!) : BigInt(0),
      timestamp: receipt ? (await this.provider.getBlock(receipt.blockNumber))!.timestamp : Date.now() / 1000,
      blockHeight: receipt?.blockNumber,
      confirmations: receipt ? await this.provider.getBlockNumber() - receipt.blockNumber : 0,
      status: receipt ? (receipt.status === 1 ? TransactionStatus.CONFIRMED : TransactionStatus.FAILED) : TransactionStatus.PENDING,
      chainId: this.chainId,
    };
  }

  async getTransactionHistory(address: string, options?: PaginationOptions): Promise<Transaction[]> {
    // Note: This requires an indexer like Etherscan API or TheGraph
    // For now, returning empty array
    return [];
  }

  async estimateFee(params: FeeEstimationParams): Promise<FeeEstimate> {
    const feeData = await this.provider.getFeeData();
    const gasLimit = BigInt(params.gasLimit || 21000);

    return {
      chainId: this.chainId,
      slow: feeData.gasPrice! * gasLimit,
      medium: feeData.gasPrice! * gasLimit * BigInt(12) / BigInt(10), // 1.2x
      fast: feeData.maxFeePerGas! * gasLimit,
      estimatedTime: {
        slow: 300,    // ~5 minutes
        medium: 180,  // ~3 minutes
        fast: 60,     // ~1 minute
      },
    };
  }

  async getBlockHeight(): Promise<number> {
    return await this.provider.getBlockNumber();
  }

  async getBlockByHeight(height: number): Promise<Block> {
    const block = await this.provider.getBlock(height);

    if (!block) {
      throw new Error('Block not found');
    }

    return {
      height: block.number,
      hash: block.hash!,
      timestamp: block.timestamp,
      transactions: block.transactions,
    };
  }

  subscribeToNewBlocks(callback: (block: Block) => void): Subscription {
    this.provider.on('block', async (blockNumber) => {
      const block = await this.getBlockByHeight(blockNumber);
      callback(block);
    });

    return {
      unsubscribe: () => this.provider.off('block'),
    };
  }

  supports(feature: ChainFeature): boolean {
    return [
      ChainFeature.SMART_CONTRACTS,
      ChainFeature.TOKENS,
      ChainFeature.NFT,
      ChainFeature.MULTISIG,
    ].includes(feature);
  }

  getChainSpecificData() {
    return {
      networkChainId: this.networkChainId,
      supportsEIP1559: true,
      supportsSmartContracts: true,
    };
  }
}
```

### 5. Chain Registry

```typescript
// src/core/chains/ChainRegistry.ts

import { IChainAdapter } from './IChainAdapter';
import { BitcoinAdapter } from './adapters/BitcoinAdapter';
import { EthereumAdapter } from './adapters/EthereumAdapter';

export class ChainRegistry {
  private static instance: ChainRegistry;
  private adapters: Map<string, IChainAdapter> = new Map();

  private constructor() {
    this.registerDefaultChains();
  }

  static getInstance(): ChainRegistry {
    if (!ChainRegistry.instance) {
      ChainRegistry.instance = new ChainRegistry();
    }
    return ChainRegistry.instance;
  }

  private registerDefaultChains() {
    // Register Bitcoin
    this.register(new BitcoinAdapter(Network.MAINNET));
    this.register(new BitcoinAdapter(Network.TESTNET));

    // Register Ethereum
    this.register(new EthereumAdapter(Network.MAINNET));
    this.register(new EthereumAdapter(Network.TESTNET));
  }

  register(adapter: IChainAdapter): void {
    const key = this.getRegistryKey(adapter.chainId, adapter.network);
    this.adapters.set(key, adapter);
  }

  getAdapter(chainId: string, network: Network = Network.MAINNET): IChainAdapter {
    const key = this.getRegistryKey(chainId, network);
    const adapter = this.adapters.get(key);

    if (!adapter) {
      throw new Error(`Chain adapter not found: ${chainId} (${network})`);
    }

    return adapter;
  }

  getAllAdapters(): IChainAdapter[] {
    return Array.from(this.adapters.values());
  }

  getSupportedChains(): ChainInfo[] {
    return Array.from(this.adapters.values()).map(adapter => ({
      chainId: adapter.chainId,
      name: adapter.name,
      symbol: adapter.symbol,
      network: adapter.network,
      features: this.getChainFeatures(adapter),
    }));
  }

  private getRegistryKey(chainId: string, network: Network): string {
    return `${chainId}:${network}`;
  }

  private getChainFeatures(adapter: IChainAdapter): ChainFeature[] {
    return Object.values(ChainFeature).filter(feature => adapter.supports(feature));
  }
}

interface ChainInfo {
  chainId: string;
  name: string;
  symbol: string;
  network: Network;
  features: ChainFeature[];
}
```

## Usage Examples

### Multi-Chain Wallet Manager

```typescript
// src/services/WalletManager.ts

import { ChainRegistry } from '../core/chains/ChainRegistry';
import { KeyManagementService } from '../core/wallet/KeyManagementService';

export class WalletManager {
  private chainRegistry: ChainRegistry;
  private keyManager: KeyManagementService;

  constructor() {
    this.chainRegistry = ChainRegistry.getInstance();
    this.keyManager = new KeyManagementService();
  }

  async createWallet(): Promise<string> {
    return await this.keyManager.generateWallet();
  }

  async getAddressForChain(chainId: string, network: Network = Network.MAINNET): Promise<string> {
    await this.keyManager.unlock();

    const adapter = this.chainRegistry.getAdapter(chainId, network);
    const chainType = this.mapChainIdToType(chainId);

    const key = this.keyManager.deriveAddressKey(chainType, 0, 0, 0);
    return adapter.generateAddress(key.publicKey!);
  }

  async getAllBalances(): Promise<Map<string, Balance>> {
    const balances = new Map<string, Balance>();
    const chains = this.chainRegistry.getAllAdapters();

    for (const chain of chains) {
      const address = await this.getAddressForChain(chain.chainId, chain.network);
      const balance = await chain.getBalance(address);
      balances.set(chain.chainId, balance);
    }

    return balances;
  }

  async sendTransaction(
    chainId: string,
    to: string,
    value: BigInt,
    network: Network = Network.MAINNET
  ): Promise<TransactionReceipt> {
    await this.keyManager.unlock();

    const adapter = this.chainRegistry.getAdapter(chainId, network);
    const chainType = this.mapChainIdToType(chainId);

    const from = await this.getAddressForChain(chainId, network);

    // Build transaction
    const unsignedTx = await adapter.buildTransaction({ from, to, value });

    // Get private key
    const key = this.keyManager.deriveAddressKey(chainType, 0, 0, 0);

    // Sign transaction
    const signedTx = await adapter.signTransaction(unsignedTx, key.privateKey!);

    // Broadcast
    return await adapter.broadcastTransaction(signedTx);
  }
}
```

## Consequences

### Positive
✅ **Extensibility**: Easy to add new blockchains
✅ **Consistency**: Unified API across all chains
✅ **Type Safety**: Full TypeScript support
✅ **Testability**: Mock adapters for testing
✅ **Flexibility**: Chain-specific features supported
✅ **Maintainability**: Isolated chain logic

### Negative
⚠️ **Complexity**: More abstraction layers
⚠️ **Learning Curve**: Developers need to understand pattern
⚠️ **Bundle Size**: Multiple chain libraries

### Risks
🔴 **Breaking Changes**: Chain updates may break adapters
🟡 **Feature Parity**: Not all chains support same features
🟢 **Performance**: Abstraction overhead (minimal)

## Future Enhancements

1. **Token Support**: ERC-20, BEP-20, SPL tokens
2. **Smart Contract Interaction**: Generic ABI calling
3. **Cross-Chain Swaps**: DEX aggregation
4. **Layer 2 Support**: Lightning, Arbitrum, Optimism
5. **More Chains**: Solana, Polkadot, Cardano, etc.

## References

- [Bitcoin Developer Guide](https://developer.bitcoin.org/devguide/)
- [Ethereum JSON-RPC](https://ethereum.org/en/developers/docs/apis/json-rpc/)
- [Chain Agnostic Standards](https://github.com/ChainAgnostic)

---

**Related ADRs:**
- [ADR-001: Cryptographic Libraries](./adr-001-cryptographic-libraries.md)
- [ADR-002: Key Management](./adr-002-key-management.md)
- [ADR-004: Network Layer](./adr-004-network-layer.md)
- [ADR-007: Transaction Architecture](./adr-007-transaction-architecture.md)
