//
//  GasEstimator.swift
//  FuekiWallet
//
//  Production-grade gas estimation and pricing
//

import Foundation
import web3swift
import BigInt

/// Advanced gas estimation and pricing strategies
public final class GasEstimator {

    // MARK: - Properties

    private let web3: Web3
    private let chainID: BigUInt

    // EIP-1559 support
    private var supportsEIP1559: Bool = false

    // Gas price cache
    private var cachedGasPrice: BigUInt?
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 30 // 30 seconds

    // MARK: - Initialization

    public init(web3: Web3, chainID: BigUInt) {
        self.web3 = web3
        self.chainID = chainID
        self.detectEIP1559Support()
    }

    // MARK: - Gas Price Estimation

    /// Estimate current gas price with priority levels
    public func estimateGasPrice(priority: GasPriority = .medium) async throws -> BigUInt {
        if supportsEIP1559 {
            return try await estimateEIP1559GasPrice(priority: priority)
        } else {
            return try await estimateLegacyGasPrice(priority: priority)
        }
    }

    /// Get detailed gas price suggestions
    public func getGasPriceSuggestions() async throws -> GasPriceSuggestion {
        if supportsEIP1559 {
            return try await getEIP1559Suggestions()
        } else {
            return try await getLegacySuggestions()
        }
    }

    // MARK: - Gas Limit Estimation

    /// Estimate gas limit for transaction
    public func estimateGas(
        from: String,
        to: String,
        value: BigUInt,
        data: Data = Data()
    ) async throws -> BigUInt {

        guard let fromAddress = EthereumAddress(from),
              let toAddress = EthereumAddress(to) else {
            throw GasEstimatorError.invalidAddress
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: GasEstimatorError.estimatorDeallocated)
                    return
                }

                do {
                    var options = TransactionOptions.defaultOptions
                    options.from = fromAddress
                    options.to = toAddress
                    options.value = value

                    let gasLimit = try self.web3.eth.estimateGas(
                        for: EthereumTransaction(
                            gasPrice: BigUInt(0),
                            gasLimit: BigUInt(0),
                            to: toAddress,
                            value: value,
                            data: data
                        ),
                        onBlock: "latest"
                    )

                    // Add 20% safety margin
                    let safeGasLimit = gasLimit + (gasLimit / 5)
                    continuation.resume(returning: safeGasLimit)

                } catch {
                    // Fallback to default gas limits
                    let defaultLimit: BigUInt = data.isEmpty ? 21000 : 100000
                    continuation.resume(returning: defaultLimit)
                }
            }
        }
    }

    /// Calculate total transaction cost
    public func calculateTransactionCost(
        gasLimit: BigUInt,
        gasPrice: BigUInt
    ) -> BigUInt {
        return gasLimit * gasPrice
    }

    /// Calculate transaction cost in ETH
    public func calculateTransactionCostInEther(
        gasLimit: BigUInt,
        gasPrice: BigUInt
    ) -> Decimal {
        let cost = calculateTransactionCost(gasLimit: gasLimit, gasPrice: gasPrice)
        return Web3.Utils.formatToEthereumUnits(cost, toUnits: .eth, decimals: 18) ?? 0
    }

    // MARK: - EIP-1559 Support

    private func estimateEIP1559GasPrice(priority: GasPriority) async throws -> BigUInt {
        let baseFee = try await getBaseFeePerGas()
        let priorityFee = getPriorityFee(for: priority)

        return baseFee + priorityFee
    }

    private func getEIP1559Suggestions() async throws -> GasPriceSuggestion {
        let baseFee = try await getBaseFeePerGas()

        return GasPriceSuggestion(
            low: baseFee + BigUInt(1_000_000_000), // +1 Gwei
            medium: baseFee + BigUInt(2_000_000_000), // +2 Gwei
            high: baseFee + BigUInt(3_500_000_000), // +3.5 Gwei
            baseFee: baseFee,
            isEIP1559: true
        )
    }

    private func getBaseFeePerGas() async throws -> BigUInt {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: GasEstimatorError.estimatorDeallocated)
                    return
                }

                do {
                    let block = try self.web3.eth.getBlockByNumber("latest")

                    if let baseFee = block.baseFeePerGas {
                        continuation.resume(returning: baseFee)
                    } else {
                        // Fallback to legacy estimation
                        let gasPrice = try self.web3.eth.getGasPrice()
                        continuation.resume(returning: gasPrice)
                    }
                } catch {
                    continuation.resume(throwing: GasEstimatorError.baseFeeEstimationFailed(error))
                }
            }
        }
    }

    private func getPriorityFee(for priority: GasPriority) -> BigUInt {
        switch priority {
        case .low:
            return BigUInt(1_000_000_000) // 1 Gwei
        case .medium:
            return BigUInt(2_000_000_000) // 2 Gwei
        case .high:
            return BigUInt(3_500_000_000) // 3.5 Gwei
        case .custom(let fee):
            return fee
        }
    }

    // MARK: - Legacy Gas Price

    private func estimateLegacyGasPrice(priority: GasPriority) async throws -> BigUInt {
        // Check cache
        if let cached = cachedGasPrice,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            return applyPriorityMultiplier(cached, priority: priority)
        }

        // Fetch fresh gas price
        let baseGasPrice = try await fetchCurrentGasPrice()

        // Cache it
        cachedGasPrice = baseGasPrice
        cacheTimestamp = Date()

        return applyPriorityMultiplier(baseGasPrice, priority: priority)
    }

    private func getLegacySuggestions() async throws -> GasPriceSuggestion {
        let basePrice = try await fetchCurrentGasPrice()

        return GasPriceSuggestion(
            low: basePrice,
            medium: basePrice + (basePrice / 10), // +10%
            high: basePrice + (basePrice / 4), // +25%
            baseFee: nil,
            isEIP1559: false
        )
    }

    private func fetchCurrentGasPrice() async throws -> BigUInt {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: GasEstimatorError.estimatorDeallocated)
                    return
                }

                do {
                    let gasPrice = try self.web3.eth.getGasPrice()
                    continuation.resume(returning: gasPrice)
                } catch {
                    continuation.resume(throwing: GasEstimatorError.gasPriceFetchFailed(error))
                }
            }
        }
    }

    private func applyPriorityMultiplier(_ basePrice: BigUInt, priority: GasPriority) -> BigUInt {
        switch priority {
        case .low:
            return basePrice // No increase
        case .medium:
            return basePrice + (basePrice / 10) // +10%
        case .high:
            return basePrice + (basePrice / 4) // +25%
        case .custom(let price):
            return price
        }
    }

    // MARK: - EIP-1559 Detection

    private func detectEIP1559Support() {
        // Networks that support EIP-1559
        let eip1559ChainIDs: [BigUInt] = [
            BigUInt(1),      // Ethereum Mainnet
            BigUInt(5),      // Goerli
            BigUInt(11155111), // Sepolia
            BigUInt(137),    // Polygon
            BigUInt(42161),  // Arbitrum
            BigUInt(10)      // Optimism
        ]

        supportsEIP1559 = eip1559ChainIDs.contains(chainID)
    }
}

// MARK: - Models

public enum GasPriority {
    case low
    case medium
    case high
    case custom(BigUInt)
}

public struct GasPriceSuggestion {
    public let low: BigUInt
    public let medium: BigUInt
    public let high: BigUInt
    public let baseFee: BigUInt?
    public let isEIP1559: Bool

    public func formatted(priority: GasPriority) -> String {
        let price: BigUInt
        switch priority {
        case .low: price = low
        case .medium: price = medium
        case .high: price = high
        case .custom(let custom): price = custom
        }

        let gwei = Web3.Utils.formatToEthereumUnits(price, toUnits: .gwei, decimals: 2) ?? 0
        return "\(gwei) Gwei"
    }
}

// MARK: - Errors

public enum GasEstimatorError: LocalizedError {
    case invalidAddress
    case estimatorDeallocated
    case baseFeeEstimationFailed(Error)
    case gasPriceFetchFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid Ethereum address"
        case .estimatorDeallocated:
            return "Gas estimator was deallocated"
        case .baseFeeEstimationFailed(let error):
            return "Failed to estimate base fee: \(error.localizedDescription)"
        case .gasPriceFetchFailed(let error):
            return "Failed to fetch gas price: \(error.localizedDescription)"
        }
    }
}
