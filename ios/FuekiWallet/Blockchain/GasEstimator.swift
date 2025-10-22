//
//  GasEstimator.swift
//  FuekiWallet
//
//  Blockchain Integration Specialist - Fee Estimation for All Chains
//

import Foundation
import Combine

// MARK: - Gas Estimator
class GasEstimator {
    private let provider: BlockchainProviderProtocol
    private var cachedEstimates: [String: CachedEstimate] = [:]
    private let cacheQueue = DispatchQueue(label: "io.fueki.gas.estimator")
    private let cacheDuration: TimeInterval = 15  // Cache for 15 seconds

    struct CachedEstimate {
        let estimate: GasEstimation
        let timestamp: Date
    }

    init(provider: BlockchainProviderProtocol) {
        self.provider = provider
    }

    // MARK: - Estimate Gas
    func estimateGas(
        from: String,
        to: String,
        amount: Decimal,
        data: Data? = nil,
        useCache: Bool = true
    ) async throws -> GasEstimation {
        let cacheKey = "\(from)-\(to)-\(amount)-\(data?.hashValue ?? 0)"

        // Check cache
        if useCache, let cached = getCachedEstimate(cacheKey) {
            return cached
        }

        // Create transaction request
        let request = TransactionRequest(
            from: from,
            to: to,
            value: amount,
            data: data,
            gasLimit: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil,
            nonce: nil
        )

        // Get estimate from provider
        let estimate = try await provider.estimateGas(for: request)

        // Cache the result
        cacheEstimate(estimate, for: cacheKey)

        return estimate
    }

    // MARK: - Estimate with Speed Options
    func estimateWithSpeedOptions(
        from: String,
        to: String,
        amount: Decimal,
        data: Data? = nil
    ) async throws -> SpeedOptions {
        let baseEstimate = try await estimateGas(
            from: from,
            to: to,
            amount: amount,
            data: data,
            useCache: false
        )

        switch provider.chainType {
        case .ethereum:
            return try await estimateEthereumSpeedOptions(baseEstimate)
        case .solana:
            return estimateSolanaSpeedOptions(baseEstimate)
        case .bitcoin:
            return try await estimateBitcoinSpeedOptions(baseEstimate)
        }
    }

    // MARK: - Estimate Token Transfer
    func estimateTokenTransfer(
        from: String,
        to: String,
        tokenAddress: String,
        amount: Decimal
    ) async throws -> GasEstimation {
        switch provider.chainType {
        case .ethereum:
            // ERC-20 transfer has higher gas cost
            return try await estimateGas(
                from: from,
                to: tokenAddress,
                amount: 0,
                data: buildERC20TransferData(to: to, amount: amount),
                useCache: true
            )

        case .solana:
            // SPL token transfer
            return try await estimateGas(
                from: from,
                to: to,
                amount: amount,
                data: buildSPLTransferData(),
                useCache: true
            )

        case .bitcoin:
            throw BlockchainError.unsupportedOperation
        }
    }

    // MARK: - Calculate Total Cost
    func calculateTotalCost(_ estimate: GasEstimation) -> Decimal {
        return estimate.estimatedTotal
    }

    func calculateTotalCostInUSD(_ estimate: GasEstimation, nativeTokenPrice: Decimal) -> Decimal {
        let nativeDecimals = provider.chainType.nativeDecimals
        let divisor = Decimal(pow(10.0, Double(nativeDecimals)))
        let nativeAmount = estimate.estimatedTotal / divisor

        return nativeAmount * nativeTokenPrice
    }

    // MARK: - Private Estimation Methods
    private func estimateEthereumSpeedOptions(_ baseEstimate: GasEstimation) async throws -> SpeedOptions {
        // Get current base fee and priority fees
        let baseFee = baseEstimate.baseFee ?? 0

        // Slow: base fee + 1 Gwei priority
        let slowPriority = Decimal(1_000_000_000)
        let slowMaxFee = baseFee * 1.1 + slowPriority
        let slowEstimate = GasEstimation(
            gasLimit: baseEstimate.gasLimit,
            baseFee: baseFee,
            maxFeePerGas: slowMaxFee,
            maxPriorityFeePerGas: slowPriority,
            estimatedTotal: Decimal(baseEstimate.gasLimit) * slowMaxFee,
            confidence: 0.7
        )

        // Standard: base fee + 2 Gwei priority
        let standardPriority = Decimal(2_000_000_000)
        let standardMaxFee = baseFee * 1.2 + standardPriority
        let standardEstimate = GasEstimation(
            gasLimit: baseEstimate.gasLimit,
            baseFee: baseFee,
            maxFeePerGas: standardMaxFee,
            maxPriorityFeePerGas: standardPriority,
            estimatedTotal: Decimal(baseEstimate.gasLimit) * standardMaxFee,
            confidence: 0.85
        )

        // Fast: base fee + 3 Gwei priority
        let fastPriority = Decimal(3_000_000_000)
        let fastMaxFee = baseFee * 1.3 + fastPriority
        let fastEstimate = GasEstimation(
            gasLimit: baseEstimate.gasLimit,
            baseFee: baseFee,
            maxFeePerGas: fastMaxFee,
            maxPriorityFeePerGas: fastPriority,
            estimatedTotal: Decimal(baseEstimate.gasLimit) * fastMaxFee,
            confidence: 0.95
        )

        return SpeedOptions(
            slow: slowEstimate,
            standard: standardEstimate,
            fast: fastEstimate
        )
    }

    private func estimateSolanaSpeedOptions(_ baseEstimate: GasEstimation) -> SpeedOptions {
        // Solana uses compute units and priority fees
        let baseFee = baseEstimate.baseFee ?? Decimal(5000)

        // Slow: no priority fee
        let slowEstimate = GasEstimation(
            gasLimit: baseEstimate.gasLimit,
            baseFee: baseFee,
            maxFeePerGas: baseFee,
            maxPriorityFeePerGas: 0,
            estimatedTotal: baseFee,
            confidence: 0.6
        )

        // Standard: 10% priority
        let standardPriority = baseFee * Decimal(0.1)
        let standardEstimate = GasEstimation(
            gasLimit: baseEstimate.gasLimit,
            baseFee: baseFee,
            maxFeePerGas: baseFee + standardPriority,
            maxPriorityFeePerGas: standardPriority,
            estimatedTotal: baseFee + standardPriority,
            confidence: 0.85
        )

        // Fast: 25% priority
        let fastPriority = baseFee * Decimal(0.25)
        let fastEstimate = GasEstimation(
            gasLimit: baseEstimate.gasLimit,
            baseFee: baseFee,
            maxFeePerGas: baseFee + fastPriority,
            maxPriorityFeePerGas: fastPriority,
            estimatedTotal: baseFee + fastPriority,
            confidence: 0.95
        )

        return SpeedOptions(
            slow: slowEstimate,
            standard: standardEstimate,
            fast: fastEstimate
        )
    }

    private func estimateBitcoinSpeedOptions(_ baseEstimate: GasEstimation) async throws -> SpeedOptions {
        // Bitcoin uses satoshis per byte
        // Estimate transaction size
        let txSize = baseEstimate.gasLimit

        // Get fee rates (sat/byte)
        let slowRate: UInt64 = 1
        let standardRate: UInt64 = 5
        let fastRate: UInt64 = 10

        let slowEstimate = GasEstimation(
            gasLimit: txSize,
            baseFee: Decimal(slowRate),
            maxFeePerGas: Decimal(slowRate * txSize),
            maxPriorityFeePerGas: 0,
            estimatedTotal: Decimal(slowRate * txSize),
            confidence: 0.5
        )

        let standardEstimate = GasEstimation(
            gasLimit: txSize,
            baseFee: Decimal(standardRate),
            maxFeePerGas: Decimal(standardRate * txSize),
            maxPriorityFeePerGas: 0,
            estimatedTotal: Decimal(standardRate * txSize),
            confidence: 0.8
        )

        let fastEstimate = GasEstimation(
            gasLimit: txSize,
            baseFee: Decimal(fastRate),
            maxFeePerGas: Decimal(fastRate * txSize),
            maxPriorityFeePerGas: 0,
            estimatedTotal: Decimal(fastRate * txSize),
            confidence: 0.95
        )

        return SpeedOptions(
            slow: slowEstimate,
            standard: standardEstimate,
            fast: fastEstimate
        )
    }

    // MARK: - Cache Management
    private func getCachedEstimate(_ key: String) -> GasEstimation? {
        return cacheQueue.sync {
            guard let cached = cachedEstimates[key] else { return nil }

            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheDuration {
                return cached.estimate
            } else {
                cachedEstimates.removeValue(forKey: key)
                return nil
            }
        }
    }

    private func cacheEstimate(_ estimate: GasEstimation, for key: String) {
        cacheQueue.sync {
            cachedEstimates[key] = CachedEstimate(
                estimate: estimate,
                timestamp: Date()
            )
        }
    }

    func clearCache() {
        cacheQueue.sync {
            cachedEstimates.removeAll()
        }
    }

    // MARK: - Helper Data Builders
    private func buildERC20TransferData(to: String, amount: Decimal) -> Data {
        let functionSignature = "0xa9059cbb"
        let recipientHex = String(to.dropFirst(2)).leftPadding(toLength: 64, withPad: "0")
        let amountHex = amount.toHexString(decimals: 18)
            .dropFirst(2)
            .leftPadding(toLength: 64, withPad: "0")

        let dataHex = functionSignature + recipientHex + amountHex
        return Data.fromHexString(dataHex) ?? Data()
    }

    private func buildSPLTransferData() -> Data {
        var data = Data()
        data.append(3)  // Transfer instruction
        return data
    }
}

// MARK: - Speed Options
struct SpeedOptions {
    let slow: GasEstimation
    let standard: GasEstimation
    let fast: GasEstimation

    var all: [GasEstimation] {
        [slow, standard, fast]
    }
}

// MARK: - Gas Price Oracle
class GasPriceOracle {
    private let provider: BlockchainProviderProtocol
    private var historicalPrices: [Date: Decimal] = [:]

    init(provider: BlockchainProviderProtocol) {
        self.provider = provider
    }

    // MARK: - Get Current Gas Price
    func getCurrentGasPrice() async throws -> Decimal {
        let estimate = try await provider.estimateGas(for: TransactionRequest(
            from: "0x0000000000000000000000000000000000000000",
            to: "0x0000000000000000000000000000000000000000",
            value: 0,
            data: nil,
            gasLimit: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil,
            nonce: nil
        ))

        let currentPrice = estimate.maxFeePerGas

        // Store historical price
        historicalPrices[Date()] = currentPrice

        return currentPrice
    }

    // MARK: - Price Trend Analysis
    func analyzePriceTrend() -> PriceTrend {
        guard historicalPrices.count >= 2 else {
            return .stable
        }

        let sortedPrices = historicalPrices.sorted { $0.key < $1.key }
        let recentPrices = sortedPrices.suffix(10).map { $0.value }

        let average = recentPrices.reduce(0, +) / Decimal(recentPrices.count)
        let latest = recentPrices.last ?? 0

        let change = (latest - average) / average

        if change > 0.2 {
            return .increasing
        } else if change < -0.2 {
            return .decreasing
        } else {
            return .stable
        }
    }

    // MARK: - Recommend Best Time
    func recommendBestTime() -> TimeRecommendation {
        let trend = analyzePriceTrend()

        switch trend {
        case .increasing:
            return .sendNow
        case .decreasing:
            return .waitForLower
        case .stable:
            return .neutral
        }
    }
}

// MARK: - Supporting Types
enum PriceTrend {
    case increasing
    case decreasing
    case stable
}

enum TimeRecommendation {
    case sendNow
    case waitForLower
    case neutral

    var message: String {
        switch self {
        case .sendNow:
            return "Gas prices are rising. Send now to avoid higher fees."
        case .waitForLower:
            return "Gas prices are falling. Consider waiting for lower fees."
        case .neutral:
            return "Gas prices are stable. Safe to send anytime."
        }
    }
}

// MARK: - String Extension
private extension String {
    func leftPadding(toLength: Int, withPad: Character) -> String {
        let padLength = max(0, toLength - count)
        return String(repeating: withPad, count: padLength) + self
    }
}
