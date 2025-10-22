/**
 * Blockchain Types
 * Common types for blockchain services
 */

export enum ChainType {
  ETHEREUM = 'ethereum',
  BITCOIN = 'bitcoin',
  SOLANA = 'solana',
  POLYGON = 'polygon',
  BSC = 'bsc',
  AVALANCHE = 'avalanche',
}

export enum NetworkType {
  MAINNET = 'mainnet',
  TESTNET = 'testnet',
  DEVNET = 'devnet',
}

export interface Balance {
  address: string;
  balance: string;
  decimals: number;
  symbol: string;
  usdValue?: string;
}

export interface Transaction {
  hash: string;
  from: string;
  to: string;
  value: string;
  data?: string;
  nonce: number;
  gasLimit?: string;
  gasPrice?: string;
  maxFeePerGas?: string;
  maxPriorityFeePerGas?: string;
  chainId?: number;
  timestamp?: number;
  blockNumber?: number;
  confirmations?: number;
  status?: 'pending' | 'confirmed' | 'failed';
}

export interface TransactionReceipt {
  hash: string;
  blockNumber: number;
  blockHash: string;
  gasUsed: string;
  effectiveGasPrice?: string;
  status: boolean;
  logs: Log[];
  contractAddress?: string;
}

export interface Log {
  address: string;
  topics: string[];
  data: string;
  blockNumber: number;
  transactionHash: string;
  logIndex: number;
}

export interface GasEstimate {
  gasLimit: string;
  gasPrice?: string;
  maxFeePerGas?: string;
  maxPriorityFeePerGas?: string;
  estimatedCost: string;
  estimatedCostUSD?: string;
}

export interface UTXO {
  txid: string;
  vout: number;
  value: number;
  scriptPubKey: string;
  confirmations: number;
  address: string;
}

export interface NFT {
  tokenId: string;
  contractAddress: string;
  name?: string;
  description?: string;
  image?: string;
  tokenURI?: string;
  owner: string;
  standard: 'ERC721' | 'ERC1155';
  balance?: string; // For ERC1155
}

export interface TokenInfo {
  address: string;
  name: string;
  symbol: string;
  decimals: number;
  totalSupply?: string;
  balance?: string;
}

export interface BlockchainConfig {
  chain: ChainType;
  network: NetworkType;
  rpcUrl: string;
  apiKey?: string;
  wsUrl?: string;
  explorerUrl?: string;
}

export interface SendTransactionParams {
  from: string;
  to: string;
  value: string;
  data?: string;
  gasLimit?: string;
  gasPrice?: string;
  maxFeePerGas?: string;
  maxPriorityFeePerGas?: string;
  nonce?: number;
}

export interface IBlockchainService {
  connect(): Promise<void>;
  disconnect(): Promise<void>;
  getBalance(address: string): Promise<Balance>;
  getTransaction(hash: string): Promise<Transaction>;
  getTransactionReceipt(hash: string): Promise<TransactionReceipt>;
  sendTransaction(params: SendTransactionParams, privateKey: string): Promise<string>;
  estimateGas(params: SendTransactionParams): Promise<GasEstimate>;
  getBlockNumber(): Promise<number>;
  isConnected(): boolean;
}
