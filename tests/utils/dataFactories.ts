/**
 * Test Data Factories
 * Factory functions for generating test data
 */

import { randomHex, randomAddress, randomBitcoinAddress } from './testHelpers';

/**
 * Bitcoin Transaction Factory
 */
export class BitcoinTransactionFactory {
  static create(overrides?: Partial<any>): any {
    return {
      txid: randomHex(64),
      version: 2,
      locktime: 0,
      vin: [
        {
          txid: randomHex(64),
          vout: 0,
          scriptSig: { asm: '', hex: '' },
          sequence: 4294967295,
        },
      ],
      vout: [
        {
          value: 1.0,
          n: 0,
          scriptPubKey: {
            asm: '',
            hex: '',
            type: 'witness_v0_keyhash',
            addresses: [randomBitcoinAddress()],
          },
        },
      ],
      ...overrides,
    };
  }

  static createBatch(count: number): any[] {
    return Array.from({ length: count }, () => this.create());
  }
}

/**
 * Bitcoin UTXO Factory
 */
export class BitcoinUTXOFactory {
  static create(overrides?: Partial<any>): any {
    return {
      txid: randomHex(64),
      vout: 0,
      value: 1.0,
      height: 800000,
      confirmations: 6,
      ...overrides,
    };
  }

  static createBatch(count: number): any[] {
    return Array.from({ length: count }, () => this.create());
  }
}

/**
 * Ethereum Transaction Factory
 */
export class EthereumTransactionFactory {
  static create(overrides?: Partial<any>): any {
    return {
      hash: randomHex(64),
      nonce: '0x1',
      blockHash: randomHex(64),
      blockNumber: '0x112a880',
      transactionIndex: '0x0',
      from: randomAddress(),
      to: randomAddress(),
      value: '0xde0b6b3a7640000',
      gas: '0x5208',
      gasPrice: '0x4a817c800',
      input: '0x',
      v: '0x1b',
      r: randomHex(64),
      s: randomHex(64),
      ...overrides,
    };
  }

  static createBatch(count: number): any[] {
    return Array.from({ length: count }, () => this.create());
  }

  static createEIP1559(overrides?: Partial<any>): any {
    return this.create({
      type: '0x2',
      maxFeePerGas: '0x77359400',
      maxPriorityFeePerGas: '0x3b9aca00',
      gasPrice: undefined,
      ...overrides,
    });
  }
}

/**
 * Ethereum Block Factory
 */
export class EthereumBlockFactory {
  static create(overrides?: Partial<any>): any {
    return {
      number: '0x112a880',
      hash: randomHex(64),
      parentHash: randomHex(64),
      nonce: '0x0000000000000000',
      sha3Uncles: randomHex(64),
      logsBloom: '0x' + '0'.repeat(512),
      transactionsRoot: randomHex(64),
      stateRoot: randomHex(64),
      receiptsRoot: randomHex(64),
      miner: randomAddress(),
      difficulty: '0x0',
      totalDifficulty: '0x0',
      extraData: '0x',
      size: '0x1000',
      gasLimit: '0x1c9c380',
      gasUsed: '0x5208',
      timestamp: '0x' + Math.floor(Date.now() / 1000).toString(16),
      transactions: [],
      uncles: [],
      ...overrides,
    };
  }

  static createWithTransactions(txCount: number, overrides?: Partial<any>): any {
    return this.create({
      transactions: EthereumTransactionFactory.createBatch(txCount),
      ...overrides,
    });
  }
}

/**
 * Ethereum Receipt Factory
 */
export class EthereumReceiptFactory {
  static create(overrides?: Partial<any>): any {
    return {
      transactionHash: randomHex(64),
      transactionIndex: '0x0',
      blockHash: randomHex(64),
      blockNumber: '0x112a880',
      from: randomAddress(),
      to: randomAddress(),
      cumulativeGasUsed: '0x5208',
      gasUsed: '0x5208',
      contractAddress: null,
      logs: [],
      logsBloom: '0x' + '0'.repeat(512),
      status: '0x1',
      effectiveGasPrice: '0x4a817c800',
      type: '0x0',
      ...overrides,
    };
  }

  static createFailed(overrides?: Partial<any>): any {
    return this.create({
      status: '0x0',
      ...overrides,
    });
  }
}

/**
 * Ethereum Log Factory
 */
export class EthereumLogFactory {
  static create(overrides?: Partial<any>): any {
    return {
      address: randomAddress(),
      topics: [randomHex(64)],
      data: '0x',
      blockNumber: '0x112a880',
      transactionHash: randomHex(64),
      transactionIndex: '0x0',
      blockHash: randomHex(64),
      logIndex: '0x0',
      removed: false,
      ...overrides,
    };
  }

  static createBatch(count: number): any[] {
    return Array.from({ length: count }, () => this.create());
  }
}

/**
 * RPC Response Factory
 */
export class RPCResponseFactory {
  static success<T>(data: T, overrides?: Partial<any>): any {
    return {
      success: true,
      data,
      requestId: '1',
      timestamp: Date.now(),
      ...overrides,
    };
  }

  static error(code: number, message: string, overrides?: Partial<any>): any {
    return {
      success: false,
      error: {
        code,
        message,
        data: undefined,
      },
      requestId: '1',
      timestamp: Date.now(),
      ...overrides,
    };
  }
}

/**
 * Connection Factory
 */
export class ConnectionFactory {
  static create(overrides?: Partial<any>): any {
    return {
      id: `conn-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      url: 'https://example.com',
      active: false,
      lastUsed: Date.now(),
      requestCount: 0,
      errorCount: 0,
      ...overrides,
    };
  }

  static createBatch(count: number): any[] {
    return Array.from({ length: count }, () => this.create());
  }
}
