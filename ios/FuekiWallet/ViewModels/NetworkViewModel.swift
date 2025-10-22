//
//  NetworkViewModel.swift
//  FuekiWallet
//
//  Created by Fueki Team
//  Copyright © 2025 Fueki. All rights reserved.
//

import Foundation
import Combine

/// ViewModel managing network selection and configuration
@MainActor
final class NetworkViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var availableNetworks: [Network] = []
    @Published var selectedNetwork: Network?
    @Published var customNetworks: [Network] = []
    @Published var filteredNetworks: [Network] = []
    @Published var searchQuery = ""

    // MARK: - Network Status

    @Published var isConnected = false
    @Published var connectionQuality: ConnectionQuality = .unknown
    @Published var blockHeight: Int?
    @Published var gasPrice: Decimal?
    @Published var latency: TimeInterval?

    // MARK: - State

    @Published var isLoading = false
    @Published var isSwitching = false
    @Published var isTestingConnection = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Custom Network

    @Published var showAddNetwork = false
    @Published var networkName = ""
    @Published var networkSymbol = ""
    @Published var rpcURL = ""
    @Published var chainID = ""
    @Published var explorerURL = ""

    // MARK: - Dependencies

    private let networkService: NetworkServiceProtocol
    private let walletViewModel: WalletViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Status Timer

    private var statusUpdateTimer: Timer?
    private let statusUpdateInterval: TimeInterval = 10

    // MARK: - Initialization

    init(
        networkService: NetworkServiceProtocol = NetworkService.shared,
        walletViewModel: WalletViewModel
    ) {
        self.networkService = networkService
        self.walletViewModel = walletViewModel
        setupBindings()
        loadNetworks()
    }

    deinit {
        statusUpdateTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Filter networks by search
        Publishers.CombineLatest3($availableNetworks, $customNetworks, $searchQuery)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .map { [weak self] available, custom, query in
                self?.filterNetworks(available + custom, query: query) ?? []
            }
            .assign(to: &$filteredNetworks)

        // Monitor selected network from wallet view model
        walletViewModel.$selectedNetwork
            .assign(to: &$selectedNetwork)

        // Monitor error state
        $errorMessage
            .map { $0 != nil }
            .assign(to: &$showError)

        // Update connection status when network changes
        $selectedNetwork
            .sink { [weak self] network in
                guard let network = network else { return }
                Task { await self?.checkNetworkStatus(for: network) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Network Loading

    func loadNetworks() {
        isLoading = true
        errorMessage = nil

        do {
            availableNetworks = try networkService.loadAvailableNetworks()
            customNetworks = try networkService.loadCustomNetworks()

            if selectedNetwork == nil {
                selectedNetwork = availableNetworks.first
            }

            startStatusUpdates()
        } catch {
            errorMessage = "Failed to load networks: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Network Switching

    func switchNetwork(_ network: Network) async {
        guard network.id != selectedNetwork?.id else { return }

        isSwitching = true
        errorMessage = nil

        do {
            // Test connection first
            let connected = try await networkService.testConnection(to: network)

            guard connected else {
                throw NetworkError.connectionFailed
            }

            // Switch network
            await walletViewModel.switchNetwork(network)
            selectedNetwork = network

            await checkNetworkStatus(for: network)
        } catch {
            errorMessage = "Failed to switch network: \(error.localizedDescription)"
        }

        isSwitching = false
    }

    // MARK: - Custom Networks

    func addCustomNetwork() async {
        guard validateCustomNetwork() else { return }

        isLoading = true
        errorMessage = nil

        do {
            guard let chainIDInt = Int(chainID) else {
                throw NetworkError.invalidChainID
            }

            let network = Network(
                id: "custom-\(UUID().uuidString)",
                name: networkName,
                symbol: networkSymbol,
                chainId: chainIDInt,
                rpcURL: rpcURL,
                explorerURL: explorerURL
            )

            // Test connection
            let connected = try await networkService.testConnection(to: network)

            guard connected else {
                throw NetworkError.connectionFailed
            }

            // Save network
            try await networkService.addCustomNetwork(network)
            customNetworks.append(network)

            showAddNetwork = false
            resetCustomNetworkForm()
        } catch {
            errorMessage = "Failed to add network: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func removeCustomNetwork(_ network: Network) async {
        do {
            try await networkService.removeCustomNetwork(network)
            customNetworks.removeAll { $0.id == network.id }

            if selectedNetwork?.id == network.id {
                selectedNetwork = availableNetworks.first
            }
        } catch {
            errorMessage = "Failed to remove network: \(error.localizedDescription)"
        }
    }

    private func validateCustomNetwork() -> Bool {
        guard !networkName.isEmpty else {
            errorMessage = "Network name is required"
            return false
        }

        guard !networkSymbol.isEmpty else {
            errorMessage = "Network symbol is required"
            return false
        }

        guard !rpcURL.isEmpty, URL(string: rpcURL) != nil else {
            errorMessage = "Valid RPC URL is required"
            return false
        }

        guard let chainIDInt = Int(chainID), chainIDInt > 0 else {
            errorMessage = "Valid chain ID is required"
            return false
        }

        if !explorerURL.isEmpty, URL(string: explorerURL) == nil {
            errorMessage = "Explorer URL is invalid"
            return false
        }

        return true
    }

    private func resetCustomNetworkForm() {
        networkName = ""
        networkSymbol = ""
        rpcURL = ""
        chainID = ""
        explorerURL = ""
    }

    // MARK: - Network Status

    func checkNetworkStatus(for network: Network) async {
        isTestingConnection = true

        do {
            let status = try await networkService.getNetworkStatus(for: network)

            isConnected = status.isConnected
            connectionQuality = status.quality
            blockHeight = status.blockHeight
            gasPrice = status.gasPrice
            latency = status.latency
        } catch {
            isConnected = false
            connectionQuality = .poor
            print("Failed to get network status: \(error)")
        }

        isTestingConnection = false
    }

    private func startStatusUpdates() {
        statusUpdateTimer?.invalidate()

        statusUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: statusUpdateInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self = self, let network = self.selectedNetwork else { return }
            Task { await self.checkNetworkStatus(for: network) }
        }
    }

    func refreshStatus() async {
        guard let network = selectedNetwork else { return }
        await checkNetworkStatus(for: network)
    }

    // MARK: - Filtering

    private func filterNetworks(_ networks: [Network], query: String) -> [Network] {
        guard !query.isEmpty else { return networks }

        return networks.filter { network in
            network.name.localizedCaseInsensitiveContains(query) ||
            network.symbol.localizedCaseInsensitiveContains(query) ||
            String(network.chainId).contains(query)
        }
    }

    // MARK: - Computed Properties

    var mainnetNetworks: [Network] {
        filteredNetworks.filter { $0.chainId % 2 == 1 || $0.chainId == 1 }
    }

    var testnetNetworks: [Network] {
        filteredNetworks.filter { $0.chainId % 2 == 0 && $0.chainId != 1 }
    }

    var connectionStatusText: String {
        guard isConnected else { return "Disconnected" }

        switch connectionQuality {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .fair:
            return "Fair"
        case .poor:
            return "Poor"
        case .unknown:
            return "Unknown"
        }
    }

    var connectionStatusColor: String {
        guard isConnected else { return "red" }

        switch connectionQuality {
        case .excellent, .good:
            return "green"
        case .fair:
            return "orange"
        case .poor, .unknown:
            return "red"
        }
    }

    var formattedLatency: String {
        guard let latency = latency else { return "—" }
        return String(format: "%.0f ms", latency * 1000)
    }

    var formattedGasPrice: String {
        guard let gasPrice = gasPrice else { return "—" }
        return String(format: "%.2f Gwei", NSDecimalNumber(decimal: gasPrice * 1_000_000_000).doubleValue)
    }
}

// MARK: - Models

enum ConnectionQuality {
    case excellent  // < 50ms
    case good       // 50-150ms
    case fair       // 150-300ms
    case poor       // > 300ms
    case unknown

    init(latency: TimeInterval) {
        switch latency {
        case 0..<0.05:
            self = .excellent
        case 0.05..<0.15:
            self = .good
        case 0.15..<0.3:
            self = .fair
        case 0.3...:
            self = .poor
        default:
            self = .unknown
        }
    }
}

struct NetworkStatus {
    let isConnected: Bool
    let quality: ConnectionQuality
    let blockHeight: Int?
    let gasPrice: Decimal?
    let latency: TimeInterval?
}

enum NetworkError: LocalizedError {
    case connectionFailed
    case invalidChainID
    case networkNotFound
    case duplicateNetwork

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to network"
        case .invalidChainID:
            return "Invalid chain ID"
        case .networkNotFound:
            return "Network not found"
        case .duplicateNetwork:
            return "A network with this chain ID already exists"
        }
    }
}

// MARK: - Service Protocol

protocol NetworkServiceProtocol {
    func loadAvailableNetworks() throws -> [Network]
    func loadCustomNetworks() throws -> [Network]
    func addCustomNetwork(_ network: Network) async throws
    func removeCustomNetwork(_ network: Network) async throws
    func testConnection(to network: Network) async throws -> Bool
    func getNetworkStatus(for network: Network) async throws -> NetworkStatus
}
