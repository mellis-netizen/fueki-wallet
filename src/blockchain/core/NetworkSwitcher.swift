import Foundation
import Combine

/// Network switching and management for blockchain providers
public class NetworkSwitcher {

    // MARK: - Types

    public struct NetworkInfo {
        public let id: String
        public let name: String
        public let chainId: String
        public let isTestnet: Bool
        public let iconURL: URL?

        public init(id: String, name: String, chainId: String,
                   isTestnet: Bool = false, iconURL: URL? = nil) {
            self.id = id
            self.name = name
            self.chainId = chainId
            self.isTestnet = isTestnet
            self.iconURL = iconURL
        }
    }

    public enum NetworkGroup {
        case mainnet
        case testnet
        case custom

        var displayName: String {
            switch self {
            case .mainnet: return "Mainnet"
            case .testnet: return "Testnet"
            case .custom: return "Custom"
            }
        }
    }

    // MARK: - Properties

    public static let shared = NetworkSwitcher()

    private var networks: [String: NetworkInfo] = [:]
    private var currentNetwork: String?
    private let queue = DispatchQueue(label: "io.fueki.network.switcher", attributes: .concurrent)

    // Publisher for network changes
    private let networkChangeSubject = PassthroughSubject<NetworkInfo, Never>()
    public var networkChangePublisher: AnyPublisher<NetworkInfo, Never> {
        networkChangeSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private init() {
        registerDefaultNetworks()
    }

    // MARK: - Network Registration

    /// Register a network
    public func registerNetwork(_ network: NetworkInfo) {
        queue.async(flags: .barrier) {
            self.networks[network.id] = network
        }
    }

    /// Unregister a network
    public func unregisterNetwork(id: String) {
        queue.async(flags: .barrier) {
            self.networks.removeValue(forKey: id)
        }
    }

    /// Get network info
    public func getNetwork(id: String) -> NetworkInfo? {
        return queue.sync {
            networks[id]
        }
    }

    /// Get all registered networks
    public func getAllNetworks() -> [NetworkInfo] {
        return queue.sync {
            Array(networks.values)
        }
    }

    /// Get networks by group
    public func getNetworks(in group: NetworkGroup) -> [NetworkInfo] {
        return queue.sync {
            networks.values.filter { network in
                switch group {
                case .mainnet:
                    return !network.isTestnet && !isCustomNetwork(network.id)
                case .testnet:
                    return network.isTestnet
                case .custom:
                    return isCustomNetwork(network.id)
                }
            }
        }
    }

    // MARK: - Network Switching

    /// Switch to a different network
    public func switchNetwork(to networkId: String) throws {
        guard let network = getNetwork(id: networkId) else {
            throw BlockchainError.invalidChainId
        }

        queue.sync(flags: .barrier) {
            currentNetwork = networkId
        }

        networkChangeSubject.send(network)
    }

    /// Get current network
    public func getCurrentNetwork() -> NetworkInfo? {
        guard let currentId = queue.sync(execute: { currentNetwork }) else {
            return nil
        }
        return getNetwork(id: currentId)
    }

    /// Check if network is current
    public func isCurrentNetwork(_ networkId: String) -> Bool {
        return queue.sync {
            currentNetwork == networkId
        }
    }

    // MARK: - Custom Networks

    /// Add custom network
    public func addCustomNetwork(
        name: String,
        chainId: String,
        rpcURL: String,
        explorerURL: String? = nil
    ) throws -> NetworkInfo {
        let networkId = "custom_\(chainId)"

        let network = NetworkInfo(
            id: networkId,
            name: name,
            chainId: chainId,
            isTestnet: false
        )

        registerNetwork(network)
        saveCustomNetwork(network)

        return network
    }

    /// Remove custom network
    public func removeCustomNetwork(id: String) throws {
        guard isCustomNetwork(id) else {
            throw BlockchainError.unsupportedOperation
        }

        unregisterNetwork(id: id)
        deleteCustomNetwork(id)
    }

    /// Get all custom networks
    public func getCustomNetworks() -> [NetworkInfo] {
        return getNetworks(in: .custom)
    }

    // MARK: - Private Methods

    private func registerDefaultNetworks() {
        // Bitcoin networks
        registerNetwork(NetworkInfo(
            id: "bitcoin_mainnet",
            name: "Bitcoin",
            chainId: "bitcoin",
            isTestnet: false
        ))

        registerNetwork(NetworkInfo(
            id: "bitcoin_testnet",
            name: "Bitcoin Testnet",
            chainId: "bitcoin_testnet",
            isTestnet: true
        ))

        // Ethereum networks
        registerNetwork(NetworkInfo(
            id: "ethereum_mainnet",
            name: "Ethereum",
            chainId: "1",
            isTestnet: false
        ))

        registerNetwork(NetworkInfo(
            id: "ethereum_goerli",
            name: "Goerli",
            chainId: "5",
            isTestnet: true
        ))

        // Polygon
        registerNetwork(NetworkInfo(
            id: "polygon_mainnet",
            name: "Polygon",
            chainId: "137",
            isTestnet: false
        ))

        registerNetwork(NetworkInfo(
            id: "polygon_mumbai",
            name: "Mumbai",
            chainId: "80001",
            isTestnet: true
        ))

        // Binance Smart Chain
        registerNetwork(NetworkInfo(
            id: "bsc_mainnet",
            name: "BSC",
            chainId: "56",
            isTestnet: false
        ))

        // Arbitrum
        registerNetwork(NetworkInfo(
            id: "arbitrum_mainnet",
            name: "Arbitrum",
            chainId: "42161",
            isTestnet: false
        ))

        // Optimism
        registerNetwork(NetworkInfo(
            id: "optimism_mainnet",
            name: "Optimism",
            chainId: "10",
            isTestnet: false
        ))
    }

    private func isCustomNetwork(_ networkId: String) -> Bool {
        return networkId.hasPrefix("custom_")
    }

    private func saveCustomNetwork(_ network: NetworkInfo) {
        // Save to UserDefaults or persistent storage
        var customNetworks = loadCustomNetworks()
        customNetworks[network.id] = network

        if let encoded = try? JSONEncoder().encode(customNetworks) {
            UserDefaults.standard.set(encoded, forKey: "fueki.custom_networks")
        }
    }

    private func deleteCustomNetwork(_ networkId: String) {
        var customNetworks = loadCustomNetworks()
        customNetworks.removeValue(forKey: networkId)

        if let encoded = try? JSONEncoder().encode(customNetworks) {
            UserDefaults.standard.set(encoded, forKey: "fueki.custom_networks")
        }
    }

    private func loadCustomNetworks() -> [String: NetworkInfo] {
        guard let data = UserDefaults.standard.data(forKey: "fueki.custom_networks"),
              let networks = try? JSONDecoder().decode([String: NetworkInfo].self, from: data) else {
            return [:]
        }
        return networks
    }
}

// MARK: - NetworkInfo Codable

extension NetworkSwitcher.NetworkInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, chainId, isTestnet, iconURL
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        chainId = try container.decode(String.self, forKey: .chainId)
        isTestnet = try container.decode(Bool.self, forKey: .isTestnet)
        if let urlString = try container.decodeIfPresent(String.self, forKey: .iconURL) {
            iconURL = URL(string: urlString)
        } else {
            iconURL = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(chainId, forKey: .chainId)
        try container.encode(isTestnet, forKey: .isTestnet)
        try container.encodeIfPresent(iconURL?.absoluteString, forKey: .iconURL)
    }
}
