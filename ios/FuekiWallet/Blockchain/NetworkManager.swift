//
//  NetworkManager.swift
//  FuekiWallet
//
//  Blockchain Integration Specialist - Network Switching (mainnet/testnet/devnet)
//

import Foundation
import Combine

// MARK: - Network Manager
class BlockchainNetworkManager {
    static let shared = BlockchainNetworkManager()

    private var providers: [BlockchainType: BlockchainProviderProtocol] = [:]
    private var currentNetwork: NetworkEnvironment = .mainnet

    private let networkChangeSubject = PassthroughSubject<(BlockchainType, NetworkEnvironment), Never>()

    var networkChangePublisher: AnyPublisher<(BlockchainType, NetworkEnvironment), Never> {
        networkChangeSubject.eraseToAnyPublisher()
    }

    private init() {
        // Initialize providers for all chains
        initializeProviders()
    }

    // MARK: - Provider Management
    func getProvider(for chainType: BlockchainType) -> BlockchainProviderProtocol? {
        return providers[chainType]
    }

    func setProvider(_ provider: BlockchainProviderProtocol, for chainType: BlockchainType) {
        providers[chainType] = provider
    }

    // MARK: - Network Switching
    func switchNetwork(_ network: NetworkEnvironment, for chainType: BlockchainType) async throws {
        guard let provider = providers[chainType] else {
            throw BlockchainError.notConnected
        }

        try await provider.switchNetwork(network)
        currentNetwork = network

        networkChangeSubject.send((chainType, network))
    }

    func switchNetworkForAllChains(_ network: NetworkEnvironment) async throws {
        for (chainType, provider) in providers {
            do {
                try await provider.switchNetwork(network)
                networkChangeSubject.send((chainType, network))
            } catch {
                print("Failed to switch network for \(chainType): \(error)")
            }
        }

        currentNetwork = network
    }

    func getCurrentNetwork() -> NetworkEnvironment {
        return currentNetwork
    }

    // MARK: - Connection Management
    func connectAll() async throws {
        for (_, provider) in providers {
            try await provider.connect()
        }
    }

    func disconnectAll() async {
        for (_, provider) in providers {
            await provider.disconnect()
        }
    }

    func reconnect(for chainType: BlockchainType) async throws {
        guard let provider = providers[chainType] else {
            throw BlockchainError.notConnected
        }

        await provider.disconnect()
        try await provider.connect()
    }

    // MARK: - Health Checks
    func checkHealth(for chainType: BlockchainType) async -> Bool {
        guard let provider = providers[chainType] else {
            return false
        }

        do {
            _ = try await provider.getCurrentBlockNumber()
            return true
        } catch {
            return false
        }
    }

    func checkAllHealth() async -> [BlockchainType: Bool] {
        var healthStatus: [BlockchainType: Bool] = [:]

        await withTaskGroup(of: (BlockchainType, Bool).self) { group in
            for chainType in BlockchainType.allCases {
                group.addTask {
                    let isHealthy = await self.checkHealth(for: chainType)
                    return (chainType, isHealthy)
                }
            }

            for await (chainType, isHealthy) in group {
                healthStatus[chainType] = isHealthy
            }
        }

        return healthStatus
    }

    // MARK: - Private Initialization
    private func initializeProviders() {
        providers[.solana] = SolanaProvider(network: currentNetwork)
        providers[.ethereum] = EthereumProvider(network: currentNetwork)
        providers[.bitcoin] = BitcoinProvider(network: currentNetwork)
    }
}

// MARK: - Network Configuration Storage
class NetworkConfigurationStorage {
    private let userDefaults = UserDefaults.standard
    private let networkKey = "selectedNetwork"
    private let customEndpointsKey = "customEndpoints"

    // MARK: - Save/Load Network
    func saveSelectedNetwork(_ network: NetworkEnvironment) {
        userDefaults.set(network.rawValue, forKey: networkKey)
    }

    func loadSelectedNetwork() -> NetworkEnvironment {
        guard let rawValue = userDefaults.string(forKey: networkKey),
              let network = NetworkEnvironment(rawValue: rawValue) else {
            return .mainnet
        }
        return network
    }

    // MARK: - Custom Endpoints
    func saveCustomEndpoint(_ endpoint: String, for chainType: BlockchainType, network: NetworkEnvironment) {
        let key = "\(customEndpointsKey)_\(chainType.rawValue)_\(network.rawValue)"
        userDefaults.set(endpoint, forKey: key)
    }

    func loadCustomEndpoint(for chainType: BlockchainType, network: NetworkEnvironment) -> String? {
        let key = "\(customEndpointsKey)_\(chainType.rawValue)_\(network.rawValue)"
        return userDefaults.string(forKey: key)
    }

    func removeCustomEndpoint(for chainType: BlockchainType, network: NetworkEnvironment) {
        let key = "\(customEndpointsKey)_\(chainType.rawValue)_\(network.rawValue)"
        userDefaults.removeObject(forKey: key)
    }
}

// MARK: - Network Monitor
class NetworkMonitor {
    private let networkManager: BlockchainNetworkManager
    private var healthCheckTimer: Timer?
    private let healthCheckInterval: TimeInterval = 60  // Check every 60 seconds

    private let healthStatusSubject = PassthroughSubject<[BlockchainType: Bool], Never>()

    var healthStatusPublisher: AnyPublisher<[BlockchainType: Bool], Never> {
        healthStatusSubject.eraseToAnyPublisher()
    }

    init(networkManager: BlockchainNetworkManager = .shared) {
        self.networkManager = networkManager
    }

    // MARK: - Start/Stop Monitoring
    func startMonitoring() {
        stopMonitoring()

        healthCheckTimer = Timer.scheduledTimer(
            withTimeInterval: healthCheckInterval,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.performHealthCheck()
            }
        }

        // Perform initial check
        Task {
            await performHealthCheck()
        }
    }

    func stopMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    // MARK: - Manual Health Check
    func performHealthCheck() async {
        let healthStatus = await networkManager.checkAllHealth()
        healthStatusSubject.send(healthStatus)

        // Auto-reconnect unhealthy connections
        for (chainType, isHealthy) in healthStatus where !isHealthy {
            do {
                try await networkManager.reconnect(for: chainType)
            } catch {
                print("Failed to reconnect \(chainType): \(error)")
            }
        }
    }

    deinit {
        stopMonitoring()
    }
}

// MARK: - Chain Selector Helper
class ChainSelector {
    private let networkManager: BlockchainNetworkManager

    init(networkManager: BlockchainNetworkManager = .shared) {
        self.networkManager = networkManager
    }

    // MARK: - Get Best Provider
    func getBestProvider(for chains: [BlockchainType]) async -> BlockchainProviderProtocol? {
        for chainType in chains {
            if let provider = networkManager.getProvider(for: chainType),
               await networkManager.checkHealth(for: chainType) {
                return provider
            }
        }
        return nil
    }

    // MARK: - Get Provider for Token
    func getProviderForToken(contractAddress: String) -> BlockchainProviderProtocol? {
        // Determine chain based on address format
        if contractAddress.hasPrefix("0x") && contractAddress.count == 42 {
            return networkManager.getProvider(for: .ethereum)
        } else if contractAddress.count >= 32 && contractAddress.count <= 44 {
            return networkManager.getProvider(for: .solana)
        } else {
            return networkManager.getProvider(for: .bitcoin)
        }
    }

    // MARK: - Get All Active Providers
    func getAllActiveProviders() async -> [BlockchainType: BlockchainProviderProtocol] {
        var activeProviders: [BlockchainType: BlockchainProviderProtocol] = [:]

        for chainType in BlockchainType.allCases {
            if let provider = networkManager.getProvider(for: chainType),
               await networkManager.checkHealth(for: chainType) {
                activeProviders[chainType] = provider
            }
        }

        return activeProviders
    }
}
