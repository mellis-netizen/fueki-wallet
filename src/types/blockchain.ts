export type ChainType = 'ethereum' | 'bitcoin' | 'solana';

export interface ChainConfig {
  name: string;
  symbol: string;
  decimals: number;
  rpcUrl: string;
  explorerUrl: string;
  chainId?: number;
}

export interface WalletAccount {
  address: string;
  publicKey: string;
  chain: ChainType;
  derivationPath: string;
}

export interface TransactionParams {
  from: string;
  to: string;
  value: string;
  data?: string;
  gasLimit?: string;
  gasPrice?: string;
  nonce?: number;
}

export interface SignedTransaction {
  rawTransaction: string;
  hash: string;
}
