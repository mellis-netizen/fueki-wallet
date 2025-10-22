import Foundation

// MARK: - Fee Estimate
struct FeeEstimate {
    let low: Decimal
    let medium: Decimal
    let high: Decimal
    let timestamp: Date

    var recommendation: Decimal {
        return medium
    }
}

// MARK: - Ethereum Fee Estimate
struct EthereumFeeEstimate {
    let baseFee: Decimal
    let maxPriorityFeePerGas: Decimal
    let maxFeePerGas: Decimal
    let estimatedGasPrice: Decimal
    let timestamp: Date

    init(baseFee: Decimal, priorityFee: Decimal) {
        self.baseFee = baseFee
        self.maxPriorityFeePerGas = priorityFee
        // Max fee = 2 * base fee + priority fee (EIP-1559)
        self.maxFeePerGas = (baseFee * 2) + priorityFee
        self.estimatedGasPrice = baseFee + priorityFee
        self.timestamp = Date()
    }
}

// MARK: - Fee Estimator
class FeeEstimator {
    static let shared = FeeEstimator()

    private let networkService: NetworkService
    private var cachedEstimates: [BlockchainType: (estimate: Any, timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 15 // 15 seconds
    private let queue = DispatchQueue(label: "com.fueki.feeestimator", attributes: .concurrent)

    init(networkService: NetworkService = .shared) {
        self.networkService = networkService
    }

    // MARK: - Ethereum Fee Estimation
    func estimateEthereumFees(priority: FeePriority = .medium) async throws -> EthereumFeeEstimate {
        if let cached = getCachedEstimate(for: .ethereum) as? EthereumFeeEstimate {
            return adjustForPriority(cached, priority: priority)
        }

        let estimate = try await fetchEthereumFees()
        cacheEstimate(estimate, for: .ethereum)

        return adjustForPriority(estimate, priority: priority)
    }

    private func fetchEthereumFees() async throws -> EthereumFeeEstimate {
        // Fetch base fee from latest block
        let baseFee = try await networkService.getEthereumBaseFee()

        // Fetch priority fee from network
        let priorityFee = try await networkService.getEthereumPriorityFee()

        return EthereumFeeEstimate(baseFee: baseFee, priorityFee: priorityFee)
    }

    private func adjustForPriority(_ estimate: EthereumFeeEstimate, priority: FeePriority) -> EthereumFeeEstimate {
        let multiplier = priority.multiplier

        return EthereumFeeEstimate(
            baseFee: estimate.baseFee,
            priorityFee: estimate.maxPriorityFeePerGas * multiplier
        )
    }

    // MARK: - Bitcoin Fee Estimation
    func estimateBitcoinFeeRate(priority: FeePriority = .medium) async throws -> Decimal {
        if let cached = getCachedEstimate(for: .bitcoin) as? FeeEstimate {
            return selectFeeByPriority(cached, priority: priority)
        }

        let estimate = try await fetchBitcoinFees()
        cacheEstimate(estimate, for: .bitcoin)

        return selectFeeByPriority(estimate, priority: priority)
    }

    private func fetchBitcoinFees() async throws -> FeeEstimate {
        // Fetch fee estimates for different block targets
        async let lowFee = networkService.getBitcoinFeeEstimate(blocks: 6)     // ~1 hour
        async let mediumFee = networkService.getBitcoinFeeEstimate(blocks: 3)  // ~30 min
        async let highFee = networkService.getBitcoinFeeEstimate(blocks: 1)    // ~10 min

        let (low, medium, high) = try await (lowFee, mediumFee, highFee)

        return FeeEstimate(
            low: low,
            medium: medium,
            high: high,
            timestamp: Date()
        )
    }

    // MARK: - Solana Fee Estimation
    func estimateSolanaFee() async throws -> Decimal {
        if let cached = getCachedEstimate(for: .solana) as? Decimal {
            return cached
        }

        let fee = try await fetchSolanaFee()
        cacheEstimate(fee, for: .solana)

        return fee
    }

    private func fetchSolanaFee() async throws -> Decimal {
        // Solana has fixed fees per signature
        // Base fee is 5000 lamports (0.000005 SOL)
        return Decimal(0.000005)
    }

    // MARK: - Dynamic Fee Calculation
    func calculateOptimalFee(
        for transaction: any Transaction,
        targetConfirmationTime: TimeInterval = 300 // 5 minutes default
    ) async throws -> Decimal {
        switch transaction.chain {
        case .ethereum:
            let estimate = try await estimateEthereumFees()
            let priority = determinePriority(for: targetConfirmationTime, chain: .ethereum)
            let adjusted = adjustForPriority(estimate, priority: priority)

            if let ethTx = transaction as? EthereumTransaction {
                return (adjusted.maxFeePerGas * Decimal(ethTx.gasLimit)) / Decimal(1_000_000_000_000_000_000)
            }
            return Decimal(0)

        case .bitcoin:
            let priority = determinePriority(for: targetConfirmationTime, chain: .bitcoin)
            let feeRate = try await estimateBitcoinFeeRate(priority: priority)

            if let btcTx = transaction as? BitcoinTransaction {
                let txSize = try btcTx.serialize().count
                return (feeRate * Decimal(txSize)) / Decimal(100_000_000)
            }
            return Decimal(0)

        case .solana:
            return try await estimateSolanaFee()
        }
    }

    // MARK: - Helper Methods
    private func determinePriority(for targetTime: TimeInterval, chain: BlockchainType) -> FeePriority {
        switch chain {
        case .ethereum:
            if targetTime <= 60 { return .high }      // < 1 minute
            if targetTime <= 180 { return .medium }   // < 3 minutes
            return .low

        case .bitcoin:
            if targetTime <= 600 { return .high }     // < 10 minutes
            if targetTime <= 1800 { return .medium }  // < 30 minutes
            return .low

        case .solana:
            return .medium // Solana has fixed fees
        }
    }

    private func selectFeeByPriority(_ estimate: FeeEstimate, priority: FeePriority) -> Decimal {
        switch priority {
        case .low: return estimate.low
        case .medium: return estimate.medium
        case .high: return estimate.high
        }
    }

    private func getCachedEstimate(for chain: BlockchainType) -> Any? {
        return queue.sync {
            guard let cached = cachedEstimates[chain] else { return nil }

            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheValidityDuration {
                return cached.estimate
            }

            return nil
        }
    }

    private func cacheEstimate(_ estimate: Any, for chain: BlockchainType) {
        queue.async(flags: .barrier) {
            self.cachedEstimates[chain] = (estimate, Date())
        }
    }

    func clearCache() {
        queue.async(flags: .barrier) {
            self.cachedEstimates.removeAll()
        }
    }
}

// MARK: - Fee Priority
enum FeePriority {
    case low
    case medium
    case high

    var multiplier: Decimal {
        switch self {
        case .low: return Decimal(0.8)
        case .medium: return Decimal(1.0)
        case .high: return Decimal(1.5)
        }
    }

    var displayName: String {
        switch self {
        case .low: return "Slow"
        case .medium: return "Standard"
        case .high: return "Fast"
        }
    }
}

// MARK: - Network Service
class NetworkService {
    static let shared = NetworkService()

    // MARK: - Ethereum
    func getEthereumBaseFee() async throws -> Decimal {
        // Mock implementation - replace with actual RPC call to eth_getBlockByNumber
        // Get latest block and extract baseFeePerGas
        return Decimal(30) // 30 Gwei
    }

    func getEthereumPriorityFee() async throws -> Decimal {
        // Mock implementation - replace with actual RPC call to eth_maxPriorityFeePerGas
        return Decimal(2) // 2 Gwei
    }

    // MARK: - Bitcoin
    func getBitcoinFeeEstimate(blocks: Int) async throws -> Decimal {
        // Mock implementation - replace with actual RPC call to estimatesmartfee
        switch blocks {
        case 1: return Decimal(50)  // 50 sat/vB
        case 3: return Decimal(30)  // 30 sat/vB
        case 6: return Decimal(20)  // 20 sat/vB
        default: return Decimal(10) // 10 sat/vB
        }
    }

    // MARK: - Fee History Analysis
    func analyzeHistoricalFees(chain: BlockchainType, blocks: Int = 20) async throws -> FeeAnalysis {
        // Fetch historical fee data
        let feeHistory = try await fetchFeeHistory(chain: chain, blocks: blocks)

        // Calculate statistics
        let average = feeHistory.reduce(Decimal(0), +) / Decimal(feeHistory.count)
        let sorted = feeHistory.sorted()
        let median = sorted[sorted.count / 2]
        let p25 = sorted[sorted.count / 4]
        let p75 = sorted[sorted.count * 3 / 4]

        return FeeAnalysis(
            average: average,
            median: median,
            percentile25: p25,
            percentile75: p75,
            samples: feeHistory.count,
            timestamp: Date()
        )
    }

    private func fetchFeeHistory(chain: BlockchainType, blocks: Int) async throws -> [Decimal] {
        // Mock implementation - replace with actual historical data fetch
        return (0..<blocks).map { _ in Decimal.random(in: 10...50) }
    }
}

// MARK: - Fee Analysis
struct FeeAnalysis {
    let average: Decimal
    let median: Decimal
    let percentile25: Decimal
    let percentile75: Decimal
    let samples: Int
    let timestamp: Date

    var recommendation: Decimal {
        // Use median as it's less affected by outliers
        return median
    }

    var volatility: Decimal {
        // Measure spread using interquartile range
        return percentile75 - percentile25
    }
}

// MARK: - Decimal Random Extension
extension Decimal {
    static func random(in range: ClosedRange<Double>) -> Decimal {
        let random = Double.random(in: range)
        return Decimal(random)
    }
}
