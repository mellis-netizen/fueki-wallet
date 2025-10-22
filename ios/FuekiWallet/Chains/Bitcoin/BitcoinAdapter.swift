//
//  BitcoinAdapter.swift
//  FuekiWallet
//
//  Production-grade Bitcoin blockchain adapter
//

import Foundation
import BitcoinKit

/// Production-grade Bitcoin blockchain adapter
public final class BitcoinAdapter {

    // MARK: - Properties

    private let network: Network
    private let apiClient: BitcoinAPIClient
    private let utxoManager: UTXOManager
    private let addressGenerator: AddressGenerator

    // Network configurations
    public enum NetworkType {
        case mainnet
        case testnet
        case regtest

        var bitcoinKitNetwork: Network {
            switch self {
            case .mainnet: return .mainnet
            case .testnet: return .testnet3
            case .regtest: return .regtest
            }
        }
    }

    // MARK: - Initialization

    public init(networkType: NetworkType, apiEndpoint: String? = nil) {
        self.network = networkType.bitcoinKitNetwork
        self.apiClient = BitcoinAPIClient(network: network, endpoint: apiEndpoint)
        self.utxoManager = UTXOManager(network: network)
        self.addressGenerator = AddressGenerator(network: network)
    }

    // MARK: - Address Generation

    /// Generate Bitcoin address from private key
    public func generateAddress(privateKey: PrivateKey, addressType: AddressType = .P2WPKH) throws -> String {
        return try addressGenerator.generate(privateKey: privateKey, type: addressType)
    }

    /// Generate address from extended public key and derivation path
    public func generateAddress(
        extendedPublicKey: HDPublicKey,
        index: UInt32,
        change: Bool = false,
        addressType: AddressType = .P2WPKH
    ) throws -> String {
        let changeIndex: UInt32 = change ? 1 : 0
        let derivedKey = try extendedPublicKey.derived(at: changeIndex).derived(at: index)

        return try addressGenerator.generate(publicKey: derivedKey.key, type: addressType)
    }

    // MARK: - Balance Operations

    /// Fetch balance for an address
    public func getBalance(address: String) async throws -> BitcoinBalance {
        return try await apiClient.getBalance(address: address)
    }

    /// Fetch balances for multiple addresses
    public func getBalances(addresses: [String]) async throws -> [String: BitcoinBalance] {
        return try await withThrowingTaskGroup(of: (String, BitcoinBalance).self) { group in
            for address in addresses {
                group.addTask {
                    let balance = try await self.apiClient.getBalance(address: address)
                    return (address, balance)
                }
            }

            var balances: [String: BitcoinBalance] = [:]
            for try await (address, balance) in group {
                balances[address] = balance
            }
            return balances
        }
    }

    // MARK: - UTXO Management

    /// Fetch UTXOs for address
    public func getUTXOs(address: String) async throws -> [UTXO] {
        return try await apiClient.getUTXOs(address: address)
    }

    /// Fetch UTXOs for multiple addresses
    public func getUTXOs(addresses: [String]) async throws -> [UTXO] {
        return try await withThrowingTaskGroup(of: [UTXO].self) { group in
            for address in addresses {
                group.addTask {
                    try await self.apiClient.getUTXOs(address: address)
                }
            }

            var allUTXOs: [UTXO] = []
            for try await utxos in group {
                allUTXOs.append(contentsOf: utxos)
            }
            return allUTXOs
        }
    }

    // MARK: - Transaction Building

    /// Build Bitcoin transaction
    public func buildTransaction(
        from: String,
        to: String,
        amount: Int64,
        feeRate: Int64? = nil,
        utxos: [UTXO]? = nil,
        changeAddress: String? = nil
    ) async throws -> BitcoinTransaction {

        // Validate addresses
        guard addressGenerator.validate(address: from),
              addressGenerator.validate(address: to) else {
            throw BitcoinAdapterError.invalidAddress
        }

        // Fetch UTXOs if not provided
        let availableUTXOs = try await utxos ?? self.getUTXOs(address: from)

        guard !availableUTXOs.isEmpty else {
            throw BitcoinAdapterError.insufficientFunds
        }

        // Estimate fee rate if not provided
        let estimatedFeeRate = try await feeRate ?? self.estimateFeeRate()

        // Select UTXOs and calculate fee
        let selection = try utxoManager.selectUTXOs(
            utxos: availableUTXOs,
            targetAmount: amount,
            feeRate: estimatedFeeRate
        )

        guard selection.selectedAmount >= amount + selection.fee else {
            throw BitcoinAdapterError.insufficientFunds
        }

        // Calculate change
        let changeAmount = selection.selectedAmount - amount - selection.fee
        let finalChangeAddress = changeAddress ?? from

        // Build transaction
        let transaction = try buildRawTransaction(
            inputs: selection.utxos,
            outputs: [
                TransactionOutput(address: to, amount: amount),
                changeAmount > 0 ? TransactionOutput(address: finalChangeAddress, amount: changeAmount) : nil
            ].compactMap { $0 }
        )

        return BitcoinTransaction(
            transaction: transaction,
            inputs: selection.utxos,
            outputs: transaction.outputs,
            fee: selection.fee,
            feeRate: estimatedFeeRate
        )
    }

    // MARK: - Transaction Signing

    /// Sign transaction with private key
    public func signTransaction(
        _ transaction: BitcoinTransaction,
        privateKey: PrivateKey
    ) throws -> BitcoinTransaction {

        var signedTx = transaction

        for (index, input) in transaction.inputs.enumerated() {
            let sighash = try signedTx.transaction.signatureHash(
                for: input.output,
                inputIndex: index,
                hashType: SighashType.ALL
            )

            let signature = try privateKey.sign(sighash)
            let publicKey = privateKey.publicKey()

            // Create script signature based on address type
            let scriptSig: Script
            if input.output.scriptPubKey.isP2PKH {
                scriptSig = try Script()
                    .append(.data(signature.serialized()))
                    .append(.data(publicKey.data))
            } else if input.output.scriptPubKey.isP2WPKH {
                // SegWit witness
                signedTx.transaction.inputs[index].witness = [
                    signature.serialized(),
                    publicKey.data
                ]
                scriptSig = Script()
            } else {
                throw BitcoinAdapterError.unsupportedScriptType
            }

            signedTx.transaction.inputs[index].scriptSig = scriptSig
        }

        return signedTx
    }

    /// Sign transaction with multiple private keys (for multi-sig)
    public func signTransaction(
        _ transaction: BitcoinTransaction,
        privateKeys: [PrivateKey]
    ) throws -> BitcoinTransaction {

        var signedTx = transaction

        for privateKey in privateKeys {
            signedTx = try signTransaction(signedTx, privateKey: privateKey)
        }

        return signedTx
    }

    // MARK: - Transaction Broadcasting

    /// Broadcast signed transaction to network
    public func broadcastTransaction(_ transaction: BitcoinTransaction) async throws -> String {
        let txHex = transaction.transaction.serialized().hex
        return try await apiClient.broadcastTransaction(txHex: txHex)
    }

    /// Send Bitcoin (build, sign, broadcast)
    public func sendTransaction(
        from: String,
        to: String,
        amount: Int64,
        privateKey: PrivateKey,
        feeRate: Int64? = nil
    ) async throws -> String {

        var transaction = try await buildTransaction(
            from: from,
            to: to,
            amount: amount,
            feeRate: feeRate
        )

        transaction = try signTransaction(transaction, privateKey: privateKey)
        return try await broadcastTransaction(transaction)
    }

    // MARK: - Transaction History

    /// Fetch transaction history for address
    public func getTransactionHistory(
        address: String,
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [BitcoinTransactionDetails] {
        return try await apiClient.getTransactionHistory(
            address: address,
            limit: limit,
            offset: offset
        )
    }

    /// Get transaction details by hash
    public func getTransactionDetails(txHash: String) async throws -> BitcoinTransactionDetails {
        return try await apiClient.getTransactionDetails(txHash: txHash)
    }

    /// Get transaction confirmation count
    public func getConfirmations(txHash: String) async throws -> Int {
        let details = try await getTransactionDetails(txHash: txHash)
        return details.confirmations
    }

    // MARK: - Fee Estimation

    /// Estimate fee rate (satoshis per byte)
    public func estimateFeeRate(blocks: Int = 6) async throws -> Int64 {
        return try await apiClient.estimateFee(blocks: blocks)
    }

    /// Get fee rate suggestions
    public func getFeeSuggestions() async throws -> FeeSuggestions {
        async let slow = estimateFeeRate(blocks: 24)    // ~4 hours
        async let medium = estimateFeeRate(blocks: 6)   // ~1 hour
        async let fast = estimateFeeRate(blocks: 2)     // ~20 minutes

        return try await FeeSuggestions(
            slow: slow,
            medium: medium,
            fast: fast
        )
    }

    /// Calculate transaction size estimate
    public func estimateTransactionSize(
        inputCount: Int,
        outputCount: Int,
        addressType: AddressType = .P2WPKH
    ) -> Int {
        return utxoManager.estimateTransactionSize(
            inputCount: inputCount,
            outputCount: outputCount,
            addressType: addressType
        )
    }

    // MARK: - Private Helpers

    private func buildRawTransaction(
        inputs: [UTXO],
        outputs: [TransactionOutput]
    ) throws -> Transaction {

        var txInputs: [TransactionInput] = []
        for utxo in inputs {
            let outpoint = TransactionOutPoint(
                hash: Data(hex: utxo.txHash),
                index: UInt32(utxo.outputIndex)
            )

            let input = TransactionInput(
                previousOutput: outpoint,
                signatureScript: Data(),
                sequence: 0xfffffffe // Enable RBF
            )

            txInputs.append(input)
        }

        var txOutputs: [TxOutput] = []
        for output in outputs {
            guard let script = try? addressGenerator.getScriptPubKey(address: output.address) else {
                throw BitcoinAdapterError.invalidAddress
            }

            let txOutput = TxOutput(
                value: output.amount,
                scriptPubKey: script
            )

            txOutputs.append(txOutput)
        }

        return Transaction(
            version: 2,
            inputs: txInputs,
            outputs: txOutputs,
            lockTime: 0
        )
    }
}

// MARK: - Models

public struct BitcoinBalance {
    public let confirmed: Int64
    public let unconfirmed: Int64
    public let total: Int64
}

public struct BitcoinTransaction {
    public var transaction: Transaction
    public let inputs: [UTXO]
    public let outputs: [TxOutput]
    public let fee: Int64
    public let feeRate: Int64

    public var txHash: String {
        return transaction.txHash.hex
    }

    public var size: Int {
        return transaction.serialized().count
    }
}

public struct TransactionOutput {
    public let address: String
    public let amount: Int64
}

public struct BitcoinTransactionDetails {
    public let txHash: String
    public let confirmations: Int
    public let blockHeight: Int?
    public let timestamp: Date?
    public let inputs: [TransactionInput]
    public let outputs: [TransactionOutput]
    public let fee: Int64
    public let size: Int
}

public struct FeeSuggestions {
    public let slow: Int64    // satoshis per byte
    public let medium: Int64
    public let fast: Int64
}

public enum AddressType {
    case P2PKH      // Legacy (1...)
    case P2WPKH     // Native SegWit (bc1...)
    case P2SH_P2WPKH // Nested SegWit (3...)
}

// MARK: - Errors

public enum BitcoinAdapterError: LocalizedError {
    case invalidAddress
    case insufficientFunds
    case unsupportedScriptType
    case transactionBuildFailed
    case signingFailed
    case broadcastFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid Bitcoin address"
        case .insufficientFunds:
            return "Insufficient funds for transaction"
        case .unsupportedScriptType:
            return "Unsupported script type"
        case .transactionBuildFailed:
            return "Failed to build transaction"
        case .signingFailed:
            return "Failed to sign transaction"
        case .broadcastFailed(let error):
            return "Failed to broadcast transaction: \(error.localizedDescription)"
        }
    }
}
