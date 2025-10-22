/**
 * Signing Service
 *
 * Handles secure transaction signing for multiple blockchain networks
 * - Bitcoin transaction signing (ECDSA secp256k1)
 * - Ethereum transaction signing (ECDSA secp256k1)
 * - Message signing
 * - Signature verification
 */

import { secp256k1 } from '@noble/curves/secp256k1';
import { sha256 } from '@noble/hashes/sha256';
import { keccak_256 } from '@noble/hashes/sha3';
import { KeyManagementService, ChainType } from './KeyManagementService';
import { BiometricService } from './BiometricService';
import { EncryptionService } from './EncryptionService';
import { SecurityConfig, SecurityError, SecurityErrorCode, SecurityEventType, SecurityValidator } from './SecurityConfig';
import { SecurityLogger } from './SecurityLogger';

/**
 * Transaction data structure
 */
export interface UnsignedTransaction {
  chainType: ChainType;
  from: string;
  to: string;
  amount: string;
  data?: string;
  nonce?: number;
  gasLimit?: string;
  gasPrice?: string;
  maxFeePerGas?: string;
  maxPriorityFeePerGas?: string;
}

/**
 * Signed transaction result
 */
export interface SignedTransaction {
  transaction: UnsignedTransaction;
  signature: string;
  signedData: string;
  txHash?: string;
  signedAt: number;
}

/**
 * Message signing result
 */
export interface SignedMessage {
  message: string;
  signature: string;
  publicKey: string;
  address: string;
  signedAt: number;
}

/**
 * Signing Service
 */
export class SigningService {
  private static instance: SigningService;
  private keyManager: KeyManagementService;
  private biometricService: BiometricService;
  private logger: SecurityLogger;

  private constructor() {
    this.keyManager = KeyManagementService.getInstance();
    this.biometricService = BiometricService.getInstance();
    this.logger = SecurityLogger.getInstance();
  }

  /**
   * Get singleton instance
   */
  static getInstance(): SigningService {
    if (!SigningService.instance) {
      SigningService.instance = new SigningService();
    }
    return SigningService.instance;
  }

  /**
   * Sign transaction with biometric authentication
   */
  async signTransaction(transaction: UnsignedTransaction): Promise<SignedTransaction> {
    try {
      // Validate transaction
      this.validateTransaction(transaction);

      // Require biometric authentication if enabled
      if (SecurityConfig.signing.requireBiometric) {
        await this.requireBiometricAuth(
          `Sign transaction of ${transaction.amount} to ${this.shortenAddress(transaction.to)}`
        );
      }

      // Get signing key
      const privateKey = await this.getSigningKey(transaction.chainType);

      try {
        // Sign transaction based on chain type
        let signature: string;
        let signedData: string;

        if (transaction.chainType === ChainType.ETHEREUM || transaction.chainType === ChainType.ETHEREUM_TESTNET) {
          const result = await this.signEthereumTransaction(transaction, privateKey);
          signature = result.signature;
          signedData = result.signedData;
        } else if (transaction.chainType === ChainType.BITCOIN || transaction.chainType === ChainType.BITCOIN_TESTNET) {
          const result = await this.signBitcoinTransaction(transaction, privateKey);
          signature = result.signature;
          signedData = result.signedData;
        } else {
          throw new SecurityError(
            SecurityErrorCode.INVALID_TRANSACTION,
            'Unsupported chain type'
          );
        }

        // Calculate transaction hash
        const txHash = this.calculateTxHash(signedData, transaction.chainType);

        this.logger.logSecurityEvent(
          SecurityEventType.TRANSACTION_SIGNED,
          'Transaction signed successfully',
          {
            chainType: transaction.chainType,
            to: transaction.to,
            amount: transaction.amount,
            txHash,
          }
        );

        return {
          transaction,
          signature,
          signedData,
          txHash,
          signedAt: Date.now(),
        };
      } finally {
        // Securely wipe private key from memory
        EncryptionService.secureWipe(Buffer.from(privateKey));
      }
    } catch (error: any) {
      this.logger.error('Transaction signing failed', { error: error.message });
      throw error;
    }
  }

  /**
   * Sign Ethereum transaction
   */
  private async signEthereumTransaction(
    transaction: UnsignedTransaction,
    privateKey: Uint8Array
  ): Promise<{ signature: string; signedData: string }> {
    try {
      // Prepare transaction data for signing
      const txData = this.serializeEthereumTransaction(transaction);

      // Hash transaction data
      const msgHash = keccak_256(txData);

      // Sign with secp256k1
      const sig = secp256k1.sign(msgHash, privateKey);

      // Get recovery ID (v value)
      const recovery = sig.recovery;

      // Format signature (r + s + v)
      const signature = this.formatEthereumSignature(sig.toCompactRawBytes(), recovery!);

      // Create signed transaction data
      const signedData = this.serializeSignedEthereumTransaction(transaction, signature);

      return {
        signature: `0x${Buffer.from(signature).toString('hex')}`,
        signedData: `0x${Buffer.from(signedData).toString('hex')}`,
      };
    } catch (error: any) {
      throw new SecurityError(
        SecurityErrorCode.SIGNING_FAILED,
        'Failed to sign Ethereum transaction',
        { error: error.message }
      );
    }
  }

  /**
   * Sign Bitcoin transaction
   */
  private async signBitcoinTransaction(
    transaction: UnsignedTransaction,
    privateKey: Uint8Array
  ): Promise<{ signature: string; signedData: string }> {
    try {
      // Prepare transaction data for signing
      const txData = this.serializeBitcoinTransaction(transaction);

      // Double SHA-256 hash
      const msgHash = sha256(sha256(txData));

      // Sign with secp256k1
      const sig = secp256k1.sign(msgHash, privateKey);

      // Convert to DER format
      const derSignature = this.toDERSignature(sig.toCompactRawBytes());

      // Create signed transaction data
      const signedData = this.serializeSignedBitcoinTransaction(transaction, derSignature);

      return {
        signature: Buffer.from(derSignature).toString('hex'),
        signedData: Buffer.from(signedData).toString('hex'),
      };
    } catch (error: any) {
      throw new SecurityError(
        SecurityErrorCode.SIGNING_FAILED,
        'Failed to sign Bitcoin transaction',
        { error: error.message }
      );
    }
  }

  /**
   * Sign arbitrary message
   */
  async signMessage(
    message: string,
    chainType: ChainType,
    accountIndex: number = 0
  ): Promise<SignedMessage> {
    try {
      // Require biometric authentication
      await this.requireBiometricAuth(`Sign message: "${this.truncateMessage(message)}"`);

      // Get signing key
      const addressKey = this.keyManager.deriveAddressKey(chainType, accountIndex, 0, 0);
      const privateKey = addressKey.privateKey;

      if (!privateKey) {
        throw new SecurityError(
          SecurityErrorCode.KEY_NOT_FOUND,
          'Private key not available'
        );
      }

      try {
        let msgHash: Uint8Array;
        let prefix: string;

        if (chainType === ChainType.ETHEREUM || chainType === ChainType.ETHEREUM_TESTNET) {
          // Ethereum message signing (EIP-191)
          prefix = '\x19Ethereum Signed Message:\n' + message.length;
          msgHash = keccak_256(Buffer.from(prefix + message, 'utf8'));
        } else {
          // Bitcoin message signing
          prefix = '\x18Bitcoin Signed Message:\n' + message.length;
          msgHash = sha256(sha256(Buffer.from(prefix + message, 'utf8')));
        }

        // Sign message
        const sig = secp256k1.sign(msgHash, privateKey);

        // Get public key and address
        const publicKey = addressKey.publicKey!;
        const address = this.deriveAddress(publicKey, chainType);

        this.logger.info('Message signed successfully');

        return {
          message,
          signature: Buffer.from(sig.toCompactRawBytes()).toString('hex'),
          publicKey: Buffer.from(publicKey).toString('hex'),
          address,
          signedAt: Date.now(),
        };
      } finally {
        // Securely wipe private key
        EncryptionService.secureWipe(Buffer.from(privateKey));
      }
    } catch (error: any) {
      this.logger.error('Message signing failed', { error: error.message });
      throw error;
    }
  }

  /**
   * Verify message signature
   */
  verifyMessageSignature(
    message: string,
    signature: string,
    publicKey: string,
    chainType: ChainType
  ): boolean {
    try {
      let msgHash: Uint8Array;
      let prefix: string;

      if (chainType === ChainType.ETHEREUM || chainType === ChainType.ETHEREUM_TESTNET) {
        prefix = '\x19Ethereum Signed Message:\n' + message.length;
        msgHash = keccak_256(Buffer.from(prefix + message, 'utf8'));
      } else {
        prefix = '\x18Bitcoin Signed Message:\n' + message.length;
        msgHash = sha256(sha256(Buffer.from(prefix + message, 'utf8')));
      }

      const sig = Buffer.from(signature, 'hex');
      const pubKey = Buffer.from(publicKey, 'hex');

      return secp256k1.verify(sig, msgHash, pubKey);
    } catch (error: any) {
      this.logger.error('Signature verification failed', { error: error.message });
      return false;
    }
  }

  /**
   * Get signing key for chain
   */
  private async getSigningKey(chainType: ChainType, accountIndex: number = 0): Promise<Uint8Array> {
    if (!this.keyManager.isWalletUnlocked()) {
      throw new SecurityError(
        SecurityErrorCode.KEY_NOT_FOUND,
        'Wallet is locked'
      );
    }

    const addressKey = this.keyManager.deriveAddressKey(chainType, accountIndex, 0, 0);

    if (!addressKey.privateKey) {
      throw new SecurityError(
        SecurityErrorCode.KEY_NOT_FOUND,
        'Private key not available for signing'
      );
    }

    return addressKey.privateKey;
  }

  /**
   * Require biometric authentication
   */
  private async requireBiometricAuth(message: string): Promise<void> {
    const availability = await this.biometricService.isAvailable();

    if (availability.available) {
      const result = await this.biometricService.authenticate(message);

      if (!result.success) {
        throw new SecurityError(
          SecurityErrorCode.AUTH_FAILED,
          'Biometric authentication failed'
        );
      }
    }
  }

  /**
   * Validate transaction before signing
   */
  private validateTransaction(transaction: UnsignedTransaction): void {
    // Validate amount
    const amountValidation = SecurityValidator.validateTransactionAmount(transaction.amount);
    if (!amountValidation.valid) {
      throw new SecurityError(
        SecurityErrorCode.INVALID_TRANSACTION,
        amountValidation.error!
      );
    }

    // Validate address based on chain type
    if (transaction.chainType === ChainType.ETHEREUM || transaction.chainType === ChainType.ETHEREUM_TESTNET) {
      const validation = SecurityValidator.validateEthereumAddress(transaction.to);
      if (!validation.valid) {
        throw new SecurityError(
          SecurityErrorCode.INVALID_TRANSACTION,
          validation.error!
        );
      }
    } else if (transaction.chainType === ChainType.BITCOIN || transaction.chainType === ChainType.BITCOIN_TESTNET) {
      const validation = SecurityValidator.validateBitcoinAddress(transaction.to);
      if (!validation.valid) {
        throw new SecurityError(
          SecurityErrorCode.INVALID_TRANSACTION,
          validation.error!
        );
      }
    }

    // Validate gas price for Ethereum
    if (transaction.chainType === ChainType.ETHEREUM || transaction.chainType === ChainType.ETHEREUM_TESTNET) {
      if (transaction.gasPrice) {
        const gasPrice = parseInt(transaction.gasPrice, 10);
        const maxGasPrice = parseInt(SecurityConfig.signing.maxGasPrice, 10);

        if (gasPrice > maxGasPrice) {
          throw new SecurityError(
            SecurityErrorCode.INVALID_TRANSACTION,
            `Gas price ${gasPrice} exceeds maximum ${maxGasPrice}`
          );
        }
      }
    }
  }

  /**
   * Serialize Ethereum transaction (simplified - use proper library in production)
   */
  private serializeEthereumTransaction(tx: UnsignedTransaction): Uint8Array {
    // This is a simplified version. In production, use @ethereumjs/tx or similar
    const data = Buffer.concat([
      Buffer.from(tx.nonce?.toString(16) || '0', 'hex'),
      Buffer.from(tx.gasPrice?.toString(16) || '0', 'hex'),
      Buffer.from(tx.gasLimit?.toString(16) || '0', 'hex'),
      Buffer.from(tx.to.replace('0x', ''), 'hex'),
      Buffer.from(tx.amount.toString(16), 'hex'),
      Buffer.from(tx.data || '', 'hex'),
    ]);

    return data;
  }

  /**
   * Serialize Bitcoin transaction (simplified)
   */
  private serializeBitcoinTransaction(tx: UnsignedTransaction): Uint8Array {
    // This is a simplified version. In production, use bitcoinjs-lib
    const data = Buffer.concat([
      Buffer.from(tx.to, 'hex'),
      Buffer.from(tx.amount.toString(16), 'hex'),
    ]);

    return data;
  }

  /**
   * Serialize signed Ethereum transaction
   */
  private serializeSignedEthereumTransaction(tx: UnsignedTransaction, signature: Uint8Array): Uint8Array {
    // Simplified version
    return Buffer.concat([
      this.serializeEthereumTransaction(tx),
      Buffer.from(signature),
    ]);
  }

  /**
   * Serialize signed Bitcoin transaction
   */
  private serializeSignedBitcoinTransaction(tx: UnsignedTransaction, signature: Uint8Array): Uint8Array {
    // Simplified version
    return Buffer.concat([
      this.serializeBitcoinTransaction(tx),
      Buffer.from(signature),
    ]);
  }

  /**
   * Format Ethereum signature (r + s + v)
   */
  private formatEthereumSignature(signature: Uint8Array, recovery: number): Uint8Array {
    const v = recovery + 27; // EIP-155
    return Buffer.concat([Buffer.from(signature), Buffer.from([v])]);
  }

  /**
   * Convert signature to DER format
   */
  private toDERSignature(signature: Uint8Array): Uint8Array {
    // Simplified DER encoding
    const r = signature.slice(0, 32);
    const s = signature.slice(32, 64);

    return Buffer.concat([
      Buffer.from([0x30, r.length + s.length + 4]),
      Buffer.from([0x02, r.length]),
      Buffer.from(r),
      Buffer.from([0x02, s.length]),
      Buffer.from(s),
    ]);
  }

  /**
   * Calculate transaction hash
   */
  private calculateTxHash(signedData: string, chainType: ChainType): string {
    const data = Buffer.from(signedData.replace('0x', ''), 'hex');

    if (chainType === ChainType.ETHEREUM || chainType === ChainType.ETHEREUM_TESTNET) {
      return '0x' + Buffer.from(keccak_256(data)).toString('hex');
    } else {
      return Buffer.from(sha256(sha256(data))).toString('hex');
    }
  }

  /**
   * Derive address from public key
   */
  private deriveAddress(publicKey: Uint8Array, chainType: ChainType): string {
    if (chainType === ChainType.ETHEREUM || chainType === ChainType.ETHEREUM_TESTNET) {
      // Ethereum address (last 20 bytes of keccak256 hash)
      const hash = keccak_256(publicKey.slice(1)); // Remove 0x04 prefix
      return '0x' + Buffer.from(hash.slice(-20)).toString('hex');
    } else {
      // Bitcoin address (simplified)
      const hash = sha256(publicKey);
      return Buffer.from(hash).toString('hex');
    }
  }

  /**
   * Shorten address for display
   */
  private shortenAddress(address: string): string {
    if (address.length > 16) {
      return `${address.substring(0, 6)}...${address.substring(address.length - 4)}`;
    }
    return address;
  }

  /**
   * Truncate message for display
   */
  private truncateMessage(message: string): string {
    if (message.length > 50) {
      return message.substring(0, 47) + '...';
    }
    return message;
  }
}

export default SigningService;
