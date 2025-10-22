//
//  UTXOManager.swift
//  FuekiWallet
//
//  Production-grade UTXO selection and management
//

import Foundation
import BitcoinKit

/// Manages UTXO selection and optimization
public final class UTXOManager {

    // MARK: - Properties

    private let network: Network

    // Transaction size constants (in bytes)
    private enum TransactionSize {
        static let baseSize = 10
        static let inputP2PKH = 148
        static let inputP2WPKH = 68
        static let inputP2SH_P2WPKH = 91
        static let outputP2PKH = 34
        static let outputP2WPKH = 31
        static let outputP2SH = 32
    }

    // MARK: - Initialization

    public init(network: Network) {
        self.network = network
    }

    // MARK: - UTXO Selection

    /// Select optimal UTXOs for transaction using Branch and Bound algorithm
    public func selectUTXOs(
        utxos: [UTXO],
        targetAmount: Int64,
        feeRate: Int64,
        strategy: SelectionStrategy = .optimal
    ) throws -> UTXOSelection {

        guard !utxos.isEmpty else {
            throw UTXOManagerError.noUTXOsAvailable
        }

        switch strategy {
        case .optimal:
            return try selectOptimalUTXOs(utxos: utxos, targetAmount: targetAmount, feeRate: feeRate)
        case .largest:
            return try selectLargestFirst(utxos: utxos, targetAmount: targetAmount, feeRate: feeRate)
        case .smallest:
            return try selectSmallestFirst(utxos: utxos, targetAmount: targetAmount, feeRate: feeRate)
        case .random:
            return try selectRandomUTXOs(utxos: utxos, targetAmount: targetAmount, feeRate: feeRate)
        }
    }

    // MARK: - Selection Strategies

    /// Branch and Bound algorithm for optimal UTXO selection
    private func selectOptimalUTXOs(
        utxos: [UTXO],
        targetAmount: Int64,
        feeRate: Int64
    ) throws -> UTXOSelection {

        // Sort UTXOs by effective value (descending)
        let sortedUTXOs = utxos.sorted { $0.value > $1.value }

        // Try Branch and Bound
        if let selection = branchAndBound(
            utxos: sortedUTXOs,
            targetAmount: targetAmount,
            feeRate: feeRate
        ) {
            return selection
        }

        // Fallback to largest first if BnB fails
        return try selectLargestFirst(
            utxos: sortedUTXOs,
            targetAmount: targetAmount,
            feeRate: feeRate
        )
    }

    /// Select largest UTXOs first
    private func selectLargestFirst(
        utxos: [UTXO],
        targetAmount: Int64,
        feeRate: Int64
    ) throws -> UTXOSelection {

        let sortedUTXOs = utxos.sorted { $0.value > $1.value }
        return try greedySelection(
            utxos: sortedUTXOs,
            targetAmount: targetAmount,
            feeRate: feeRate
        )
    }

    /// Select smallest UTXOs first (good for consolidation)
    private func selectSmallestFirst(
        utxos: [UTXO],
        targetAmount: Int64,
        feeRate: Int64
    ) throws -> UTXOSelection {

        let sortedUTXOs = utxos.sorted { $0.value < $1.value }
        return try greedySelection(
            utxos: sortedUTXOs,
            targetAmount: targetAmount,
            feeRate: feeRate
        )
    }

    /// Random UTXO selection (for privacy)
    private func selectRandomUTXOs(
        utxos: [UTXO],
        targetAmount: Int64,
        feeRate: Int64
    ) throws -> UTXOSelection {

        let shuffledUTXOs = utxos.shuffled()
        return try greedySelection(
            utxos: shuffledUTXOs,
            targetAmount: targetAmount,
            feeRate: feeRate
        )
    }

    // MARK: - Core Algorithms

    /// Branch and Bound UTXO selection
    private func branchAndBound(
        utxos: [UTXO],
        targetAmount: Int64,
        feeRate: Int64,
        maxIterations: Int = 100000
    ) -> UTXOSelection? {

        let target = targetAmount
        var bestSelection: [UTXO]?
        var bestWaste = Int64.max
        var iterations = 0

        func search(index: Int, selected: [UTXO], currentValue: Int64) {
            guard iterations < maxIterations else { return }
            iterations += 1

            // Calculate current fee
            let fee = calculateFee(inputCount: selected.count, outputCount: 2, feeRate: feeRate)
            let effectiveValue = currentValue - fee

            // Found exact match
            if effectiveValue == target {
                bestSelection = selected
                bestWaste = 0
                return
            }

            // Found acceptable match with less waste
            if effectiveValue > target {
                let waste = effectiveValue - target
                if waste < bestWaste {
                    bestSelection = selected
                    bestWaste = waste
                }
            }

            // Exceeded target by too much, prune this branch
            if effectiveValue > target + bestWaste {
                return
            }

            // Try including next UTXO
            if index < utxos.count {
                var newSelected = selected
                newSelected.append(utxos[index])
                search(
                    index: index + 1,
                    selected: newSelected,
                    currentValue: currentValue + utxos[index].value
                )

                // Try excluding next UTXO
                search(index: index + 1, selected: selected, currentValue: currentValue)
            }
        }

        search(index: 0, selected: [], currentValue: 0)

        guard let selection = bestSelection else { return nil }

        let fee = calculateFee(inputCount: selection.count, outputCount: 2, feeRate: feeRate)
        let totalValue = selection.reduce(0) { $0 + $1.value }

        return UTXOSelection(
            utxos: selection,
            selectedAmount: totalValue,
            fee: fee
        )
    }

    /// Greedy UTXO selection
    private func greedySelection(
        utxos: [UTXO],
        targetAmount: Int64,
        feeRate: Int64
    ) throws -> UTXOSelection {

        var selected: [UTXO] = []
        var totalValue: Int64 = 0

        for utxo in utxos {
            selected.append(utxo)
            totalValue += utxo.value

            let fee = calculateFee(inputCount: selected.count, outputCount: 2, feeRate: feeRate)

            if totalValue >= targetAmount + fee {
                return UTXOSelection(
                    utxos: selected,
                    selectedAmount: totalValue,
                    fee: fee
                )
            }
        }

        throw UTXOManagerError.insufficientFunds
    }

    // MARK: - Fee Calculation

    /// Calculate transaction fee
    public func calculateFee(
        inputCount: Int,
        outputCount: Int,
        feeRate: Int64,
        addressType: AddressType = .P2WPKH
    ) -> Int64 {
        let size = estimateTransactionSize(
            inputCount: inputCount,
            outputCount: outputCount,
            addressType: addressType
        )
        return Int64(size) * feeRate
    }

    /// Estimate transaction size in bytes
    public func estimateTransactionSize(
        inputCount: Int,
        outputCount: Int,
        addressType: AddressType
    ) -> Int {
        let inputSize: Int
        switch addressType {
        case .P2PKH:
            inputSize = TransactionSize.inputP2PKH
        case .P2WPKH:
            inputSize = TransactionSize.inputP2WPKH
        case .P2SH_P2WPKH:
            inputSize = TransactionSize.inputP2SH_P2WPKH
        }

        let outputSize = TransactionSize.outputP2WPKH

        let baseSize = TransactionSize.baseSize
        let totalInputSize = inputCount * inputSize
        let totalOutputSize = outputCount * outputSize

        return baseSize + totalInputSize + totalOutputSize
    }

    // MARK: - UTXO Consolidation

    /// Check if UTXOs should be consolidated
    public func shouldConsolidate(utxos: [UTXO], threshold: Int = 20) -> Bool {
        return utxos.count > threshold
    }

    /// Create consolidation transaction
    public func createConsolidationTransaction(
        utxos: [UTXO],
        targetAddress: String,
        feeRate: Int64
    ) throws -> UTXOSelection {

        let totalValue = utxos.reduce(0) { $0 + $1.value }
        let fee = calculateFee(inputCount: utxos.count, outputCount: 1, feeRate: feeRate)

        guard totalValue > fee else {
            throw UTXOManagerError.insufficientFunds
        }

        return UTXOSelection(
            utxos: utxos,
            selectedAmount: totalValue,
            fee: fee
        )
    }

    // MARK: - UTXO Analysis

    /// Get UTXO statistics
    public func analyzeUTXOs(_ utxos: [UTXO]) -> UTXOStats {
        guard !utxos.isEmpty else {
            return UTXOStats(
                count: 0,
                totalValue: 0,
                averageValue: 0,
                medianValue: 0,
                dustCount: 0
            )
        }

        let total = utxos.reduce(0) { $0 + $1.value }
        let average = total / Int64(utxos.count)

        let sorted = utxos.map { $0.value }.sorted()
        let median = sorted[sorted.count / 2]

        // Dust threshold: 546 satoshis
        let dustThreshold: Int64 = 546
        let dustCount = utxos.filter { $0.value <= dustThreshold }.count

        return UTXOStats(
            count: utxos.count,
            totalValue: total,
            averageValue: average,
            medianValue: median,
            dustCount: dustCount
        )
    }
}

// MARK: - Models

public struct UTXO {
    public let txHash: String
    public let outputIndex: Int
    public let value: Int64
    public let script: Data
    public let confirmations: Int

    public var output: TxOutput {
        return TxOutput(value: value, scriptPubKey: script)
    }
}

public struct UTXOSelection {
    public let utxos: [UTXO]
    public let selectedAmount: Int64
    public let fee: Int64

    public var total: Int64 {
        return selectedAmount
    }
}

public enum SelectionStrategy {
    case optimal        // Branch and Bound
    case largest        // Largest first
    case smallest       // Smallest first
    case random         // Random (privacy)
}

public struct UTXOStats {
    public let count: Int
    public let totalValue: Int64
    public let averageValue: Int64
    public let medianValue: Int64
    public let dustCount: Int
}

// MARK: - Errors

public enum UTXOManagerError: LocalizedError {
    case noUTXOsAvailable
    case insufficientFunds
    case invalidSelection

    public var errorDescription: String? {
        switch self {
        case .noUTXOsAvailable:
            return "No UTXOs available for selection"
        case .insufficientFunds:
            return "Insufficient funds to cover amount and fees"
        case .invalidSelection:
            return "Invalid UTXO selection"
        }
    }
}
