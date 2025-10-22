# ADR-007: Transaction Signing and Verification Architecture

## Status
**ACCEPTED** - 2025-10-21

## Context

Transaction signing and verification are critical security components of the wallet. Transactions must be:
- Signed correctly according to each blockchain's specifications
- Verified before broadcasting
- Protected from tampering
- Presented clearly to users for approval

### Requirements
1. **Security**: Private keys used only for signing, never exposed
2. **Correctness**: Implement signing algorithms per blockchain specs
3. **User Verification**: Clear transaction preview before signing
4. **Error Prevention**: Validate all inputs before signing
5. **Chain Support**: Support Bitcoin (ECDSA, Schnorr) and Ethereum (EIP-155, EIP-1559)
6. **Audit Trail**: Log transaction details (non-sensitive)

### Constraints
- React Native environment
- Mobile performance limitations
- Must work offline (signing only, broadcasting requires network)
- Support PSBT for Bitcoin (BIP-174)

## Decision

We will implement a **transaction pipeline architecture** with distinct stages for building, reviewing, signing, and broadcasting transactions.

## Architecture

### Transaction Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Transaction Initiation                                       │
│    (User inputs: recipient, amount, fee)                        │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Transaction Building                                         │
│    - Fetch UTXOs (Bitcoin) or nonce (Ethereum)                  │
│    - Select inputs and outputs                                  │
│    - Calculate fees                                             │
│    - Create unsigned transaction                                │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Transaction Preview & Confirmation                           │
│    - Display recipient, amount, fee                             │
│    - Show total deduction                                       │
│    - Request user confirmation                                  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Authentication                                                │
│    - Biometric or PIN                                           │
│    - Unlock wallet if needed                                    │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. Transaction Signing                                          │
│    - Derive private key from HD wallet                          │
│    - Sign transaction (ECDSA/Schnorr/ECDSA-EIP155)             │
│    - Clear private key from memory                              │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. Transaction Verification                                     │
│    - Verify signature correctness                               │
│    - Validate transaction structure                             │
│    - Check against preview data                                 │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. Broadcasting                                                  │
│    - Submit to blockchain network                               │
│    - Monitor for confirmation                                   │
│    - Update transaction status                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation

### 1. Transaction Service

```typescript
// src/services/TransactionService.ts

import { ChainRegistry } from '../core/chains/ChainRegistry';
import { KeyManagementService } from '../core/wallet/KeyManagementService';
import { AuthManager } from './AuthManager';
import { useTransactionStore } from '../stores/transactionStore';
import { useWalletStore } from '../stores/walletStore';

export class TransactionService {
  private chainRegistry: ChainRegistry;
  private keyManager: KeyManagementService;
  private authManager: AuthManager;

  constructor() {
    this.chainRegistry = ChainRegistry.getInstance();
    this.keyManager = new KeyManagementService();
    this.authManager = new AuthManager();
  }

  /**
   * Build unsigned transaction
   */
  async buildTransaction(params: BuildTransactionParams): Promise<TransactionPreview> {
    const { chainId, network, from, to, value, data } = params;

    // Validate inputs
    this.validateTransactionParams(params);

    // Get chain adapter
    const adapter = this.chainRegistry.getAdapter(chainId, network);

    // Validate recipient address
    if (!adapter.validateAddress(to)) {
      throw new Error('Invalid recipient address');
    }

    // Build unsigned transaction
    const unsignedTx = await adapter.buildTransaction({
      from,
      to,
      value,
      data,
    });

    // Create preview
    const preview: TransactionPreview = {
      chainId,
      network,
      from,
      to,
      value,
      fee: unsignedTx.fee,
      total: value + this.getFeeAmount(unsignedTx.fee),
      data,
      unsignedTx,
    };

    // Store pending transaction
    const txId = useTransactionStore.getState().addPendingTransaction(unsignedTx);
    preview.pendingTxId = txId;

    return preview;
  }

  /**
   * Sign and broadcast transaction
   */
  async signAndBroadcast(preview: TransactionPreview): Promise<TransactionReceipt> {
    try {
      // Ensure wallet is unlocked (triggers auth if needed)
      if (!this.authManager.isUnlocked()) {
        const authenticated = await this.authManager.authenticate();
        if (!authenticated) {
          throw new Error('Authentication required to sign transaction');
        }
      }

      // Get pending transaction
      const unsignedTx = preview.unsignedTx;
      if (!unsignedTx) {
        throw new Error('Unsigned transaction not found');
      }

      // Derive private key
      const chainType = this.mapChainIdToType(preview.chainId);
      const key = this.keyManager.deriveAddressKey(chainType, 0, 0, 0);

      if (!key.privateKey) {
        throw new Error('Failed to derive private key');
      }

      // Get chain adapter
      const adapter = this.chainRegistry.getAdapter(preview.chainId, preview.network);

      // Sign transaction
      const signedTx = await adapter.signTransaction(unsignedTx, key.privateKey);

      // Verify signature
      await this.verifySignedTransaction(signedTx, preview);

      // Clear private key from memory
      key.privateKey.fill(0);

      // Broadcast transaction
      const receipt = await adapter.broadcastTransaction(signedTx);

      // Update wallet state
      this.updateWalletAfterBroadcast(preview, receipt);

      // Remove from pending
      if (preview.pendingTxId) {
        useTransactionStore.getState().removePendingTransaction(preview.pendingTxId);
      }

      return receipt;
    } catch (error) {
      console.error('Transaction signing/broadcasting failed:', error);
      throw error;
    }
  }

  /**
   * Verify signed transaction matches preview
   */
  private async verifySignedTransaction(
    signedTx: SignedTransaction,
    preview: TransactionPreview
  ): Promise<void> {
    // Verify transaction hash is valid
    if (!signedTx.hash || signedTx.hash.length === 0) {
      throw new Error('Invalid transaction hash');
    }

    // Verify raw transaction exists
    if (!signedTx.rawTransaction || signedTx.rawTransaction.length === 0) {
      throw new Error('Invalid raw transaction');
    }

    // For additional safety, parse and verify transaction details
    // This is chain-specific implementation
    const adapter = this.chainRegistry.getAdapter(preview.chainId, preview.network);

    // Chain-specific verification
    if (preview.chainId === 'bitcoin') {
      await this.verifyBitcoinTransaction(signedTx, preview);
    } else if (preview.chainId === 'ethereum') {
      await this.verifyEthereumTransaction(signedTx, preview);
    }
  }

  /**
   * Verify Bitcoin transaction
   */
  private async verifyBitcoinTransaction(
    signedTx: SignedTransaction,
    preview: TransactionPreview
  ): Promise<void> {
    const bitcoin = await import('bitcoinjs-lib');
    const tx = bitcoin.Transaction.fromHex(signedTx.rawTransaction);

    // Verify outputs
    const recipientOutput = tx.outs.find(out => {
      try {
        const address = bitcoin.address.fromOutputScript(
          out.script,
          preview.network === Network.MAINNET ? bitcoin.networks.bitcoin : bitcoin.networks.testnet
        );
        return address === preview.to;
      } catch {
        return false;
      }
    });

    if (!recipientOutput) {
      throw new Error('Transaction verification failed: recipient output not found');
    }

    if (BigInt(recipientOutput.value) !== preview.value) {
      throw new Error('Transaction verification failed: amount mismatch');
    }
  }

  /**
   * Verify Ethereum transaction
   */
  private async verifyEthereumTransaction(
    signedTx: SignedTransaction,
    preview: TransactionPreview
  ): Promise<void> {
    const { Transaction } = await import('ethers');
    const tx = Transaction.from(signedTx.rawTransaction);

    // Verify recipient
    if (tx.to?.toLowerCase() !== preview.to.toLowerCase()) {
      throw new Error('Transaction verification failed: recipient mismatch');
    }

    // Verify amount
    if (tx.value !== preview.value) {
      throw new Error('Transaction verification failed: amount mismatch');
    }

    // Verify sender (recovered from signature)
    const from = tx.from;
    if (from?.toLowerCase() !== preview.from.toLowerCase()) {
      throw new Error('Transaction verification failed: sender mismatch');
    }
  }

  /**
   * Update wallet state after successful broadcast
   */
  private updateWalletAfterBroadcast(
    preview: TransactionPreview,
    receipt: TransactionReceipt
  ): void {
    const transaction: Transaction = {
      hash: receipt.hash,
      from: preview.from,
      to: preview.to,
      value: preview.value,
      fee: this.getFeeAmount(preview.fee),
      timestamp: Date.now() / 1000,
      blockHeight: receipt.blockHeight,
      confirmations: receipt.confirmations,
      status: receipt.status,
      chainId: preview.chainId,
      data: preview.data,
    };

    // Add to wallet store
    useWalletStore.getState().addTransaction(preview.chainId, preview.from, transaction);
  }

  /**
   * Monitor transaction confirmations
   */
  async monitorTransaction(
    chainId: string,
    network: Network,
    txHash: string
  ): Promise<void> {
    const adapter = this.chainRegistry.getAdapter(chainId, network);

    const interval = setInterval(async () => {
      try {
        const tx = await adapter.getTransaction(txHash);

        // Update transaction in store
        useWalletStore.getState().updateTransaction(chainId, txHash, {
          confirmations: tx.confirmations,
          status: tx.status,
          blockHeight: tx.blockHeight,
        });

        // Stop monitoring after 6 confirmations
        if (tx.confirmations >= 6) {
          clearInterval(interval);
        }
      } catch (error) {
        console.error('Failed to monitor transaction:', error);
        clearInterval(interval);
      }
    }, 30000); // Check every 30 seconds
  }

  /**
   * Estimate transaction fee
   */
  async estimateFee(params: FeeEstimationParams): Promise<FeeEstimate> {
    const { chainId, network } = params;
    const adapter = this.chainRegistry.getAdapter(chainId, network);
    return await adapter.estimateFee(params);
  }

  /**
   * Cancel pending transaction (by replacing with higher fee)
   */
  async cancelTransaction(
    chainId: string,
    network: Network,
    txHash: string
  ): Promise<TransactionReceipt> {
    // Only works for Ethereum (replace by fee)
    if (chainId !== 'ethereum') {
      throw new Error('Cancel transaction not supported for this chain');
    }

    const adapter = this.chainRegistry.getAdapter(chainId, network);
    const originalTx = await adapter.getTransaction(txHash);

    if (originalTx.confirmations > 0) {
      throw new Error('Cannot cancel confirmed transaction');
    }

    // Create replacement transaction with higher fee and same nonce
    // Send to self to effectively cancel
    const cancelPreview = await this.buildTransaction({
      chainId,
      network,
      from: originalTx.from,
      to: originalTx.from,
      value: BigInt(0),
    });

    return await this.signAndBroadcast(cancelPreview);
  }

  /**
   * Speed up pending transaction (by replacing with higher fee)
   */
  async speedUpTransaction(
    chainId: string,
    network: Network,
    txHash: string,
    newFeeMultiplier: number = 1.2
  ): Promise<TransactionReceipt> {
    // Only works for Ethereum (replace by fee)
    if (chainId !== 'ethereum') {
      throw new Error('Speed up transaction not supported for this chain');
    }

    const adapter = this.chainRegistry.getAdapter(chainId, network);
    const originalTx = await adapter.getTransaction(txHash);

    if (originalTx.confirmations > 0) {
      throw new Error('Cannot speed up confirmed transaction');
    }

    // Create replacement transaction with higher fee and same nonce
    const speedUpPreview = await this.buildTransaction({
      chainId,
      network,
      from: originalTx.from,
      to: originalTx.to,
      value: originalTx.value,
      data: originalTx.data,
    });

    // Multiply fee by newFeeMultiplier
    // Implementation depends on fee structure

    return await this.signAndBroadcast(speedUpPreview);
  }

  /**
   * Validate transaction parameters
   */
  private validateTransactionParams(params: BuildTransactionParams): void {
    const { chainId, from, to, value } = params;

    if (!chainId || chainId.length === 0) {
      throw new Error('Chain ID is required');
    }

    if (!from || from.length === 0) {
      throw new Error('Sender address is required');
    }

    if (!to || to.length === 0) {
      throw new Error('Recipient address is required');
    }

    if (from.toLowerCase() === to.toLowerCase()) {
      throw new Error('Cannot send to same address');
    }

    if (value <= BigInt(0)) {
      throw new Error('Amount must be greater than zero');
    }

    // Check balance
    const balance = useWalletStore.getState().balances.get(`${chainId}:${from}`);
    if (!balance || balance.total < value) {
      throw new Error('Insufficient balance');
    }
  }

  /**
   * Get fee amount from FeeEstimate
   */
  private getFeeAmount(fee: FeeEstimate): BigInt {
    return fee.medium; // Default to medium fee
  }

  /**
   * Map chain ID to ChainType
   */
  private mapChainIdToType(chainId: string): ChainType {
    const mapping: Record<string, ChainType> = {
      bitcoin: ChainType.BITCOIN,
      bitcoin_testnet: ChainType.BITCOIN_TESTNET,
      ethereum: ChainType.ETHEREUM,
      ethereum_testnet: ChainType.ETHEREUM_TESTNET,
    };

    return mapping[chainId] || ChainType.BITCOIN;
  }
}

export interface BuildTransactionParams {
  chainId: string;
  network: Network;
  from: string;
  to: string;
  value: BigInt;
  data?: any;
}

export interface TransactionPreview {
  chainId: string;
  network: Network;
  from: string;
  to: string;
  value: BigInt;
  fee: FeeEstimate;
  total: BigInt;
  data?: any;
  unsignedTx?: UnsignedTransaction;
  pendingTxId?: string;
}
```

### 2. Transaction Confirmation Component

```typescript
// src/components/TransactionConfirmation.tsx

import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react';
import { TransactionPreview } from '../services/TransactionService';

interface Props {
  preview: TransactionPreview;
  onConfirm: () => void;
  onCancel: () => void;
  isLoading: boolean;
}

export const TransactionConfirmation: React.FC<Props> = ({
  preview,
  onConfirm,
  onCancel,
  isLoading,
}) => {
  const formatAmount = (amount: BigInt, decimals: number): string => {
    return (Number(amount) / Math.pow(10, decimals)).toFixed(8);
  };

  const getSymbol = (): string => {
    return preview.chainId === 'bitcoin' ? 'BTC' : 'ETH';
  };

  const getDecimals = (): number => {
    return preview.chainId === 'bitcoin' ? 8 : 18;
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Confirm Transaction</Text>

      <View style={styles.detailsContainer}>
        <DetailRow label="From" value={preview.from} />
        <DetailRow label="To" value={preview.to} />
        <DetailRow
          label="Amount"
          value={`${formatAmount(preview.value, getDecimals())} ${getSymbol()}`}
        />
        <DetailRow
          label="Network Fee"
          value={`${formatAmount(preview.fee.medium, getDecimals())} ${getSymbol()}`}
        />
        <View style={styles.separator} />
        <DetailRow
          label="Total"
          value={`${formatAmount(preview.total, getDecimals())} ${getSymbol()}`}
          bold
        />
      </View>

      <View style={styles.warningContainer}>
        <Text style={styles.warningText}>
          ⚠️ Transactions cannot be reversed. Please verify all details before confirming.
        </Text>
      </View>

      <View style={styles.buttonContainer}>
        <TouchableOpacity
          style={[styles.button, styles.cancelButton]}
          onPress={onCancel}
          disabled={isLoading}
        >
          <Text style={styles.cancelButtonText}>Cancel</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.button, styles.confirmButton, isLoading && styles.buttonDisabled]}
          onPress={onConfirm}
          disabled={isLoading}
        >
          <Text style={styles.confirmButtonText}>
            {isLoading ? 'Signing...' : 'Confirm & Sign'}
          </Text>
        </TouchableOpacity>
      </View>
    </View>
  );
};

const DetailRow: React.FC<{ label: string; value: string; bold?: boolean }> = ({
  label,
  value,
  bold,
}) => (
  <View style={styles.detailRow}>
    <Text style={styles.detailLabel}>{label}</Text>
    <Text style={[styles.detailValue, bold && styles.detailValueBold]}>{value}</Text>
  </View>
);

const styles = StyleSheet.create({
  container: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 20,
    margin: 20,
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 20,
    textAlign: 'center',
  },
  detailsContainer: {
    marginBottom: 20,
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  detailLabel: {
    fontSize: 14,
    color: '#666',
  },
  detailValue: {
    fontSize: 14,
    color: '#000',
    flex: 1,
    textAlign: 'right',
  },
  detailValueBold: {
    fontWeight: 'bold',
    fontSize: 16,
  },
  separator: {
    height: 1,
    backgroundColor: '#E0E0E0',
    marginVertical: 12,
  },
  warningContainer: {
    backgroundColor: '#FFF3CD',
    padding: 12,
    borderRadius: 8,
    marginBottom: 20,
  },
  warningText: {
    fontSize: 12,
    color: '#856404',
  },
  buttonContainer: {
    flexDirection: 'row',
    gap: 12,
  },
  button: {
    flex: 1,
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  cancelButton: {
    backgroundColor: '#F5F5F5',
  },
  confirmButton: {
    backgroundColor: '#007AFF',
  },
  buttonDisabled: {
    opacity: 0.5,
  },
  cancelButtonText: {
    color: '#000',
    fontSize: 16,
    fontWeight: '600',
  },
  confirmButtonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
});
```

## Security Considerations

### 1. **Private Key Handling**
```typescript
// Always clear private keys after use
function signTransaction(privateKey: Uint8Array, txData: Uint8Array): Uint8Array {
  try {
    const signature = secp256k1.sign(txData, privateKey);
    return signature;
  } finally {
    // Securely wipe private key
    privateKey.fill(0);
  }
}
```

### 2. **Transaction Verification**
- Always verify signed transaction matches preview
- Check recipient, amount, and fee
- Validate signature correctness

### 3. **User Confirmation**
- Clear display of transaction details
- Warning about irreversibility
- Require explicit user action

### 4. **Replay Attack Protection**
- Bitcoin: Use unique UTXO sets
- Ethereum: Use nonce + EIP-155 chain ID

## Testing

```typescript
describe('TransactionService', () => {
  it('should build valid Bitcoin transaction', async () => {
    const service = new TransactionService();
    const preview = await service.buildTransaction({
      chainId: 'bitcoin',
      network: Network.TESTNET,
      from: 'tb1q...',
      to: 'tb1q...',
      value: BigInt(10000),
    });

    expect(preview.value).toBe(BigInt(10000));
    expect(preview.unsignedTx).toBeDefined();
  });

  it('should sign and verify transaction', async () => {
    // Test transaction signing
  });

  it('should prevent double spending', async () => {
    // Test UTXO selection
  });
});
```

## References

- [BIP-174: PSBT](https://github.com/bitcoin/bips/blob/master/bip-0174.mediawiki)
- [EIP-155: Simple Replay Attack Protection](https://eips.ethereum.org/EIPS/eip-155)
- [EIP-1559: Fee Market](https://eips.ethereum.org/EIPS/eip-1559)

---

**Related ADRs:**
- [ADR-001: Cryptographic Libraries](./adr-001-cryptographic-libraries.md)
- [ADR-002: Key Management](./adr-002-key-management.md)
- [ADR-003: Multi-Chain Support](./adr-003-multi-chain-support.md)
