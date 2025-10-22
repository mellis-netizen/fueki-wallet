import Foundation
import Combine

/// Multi-chain API client supporting multiple blockchain networks
final class MultiChainAPIClient {

    private var clients: [ChainID: BlockchainAPIClient] = [:]
    private let networkClient: NetworkClient

    enum ChainID: String, CaseIterable {
        case ethereum = "ethereum"
        case polygon = "polygon"
        case binance = "binance"
        case arbitrum = "arbitrum"
        case optimism = "optimism"

        var rpcEndpoint: String {
            switch self {
            case .ethereum:
                return "https://mainnet.infura.io/v3/YOUR_PROJECT_ID"
            case .polygon:
                return "https://polygon-rpc.com"
            case .binance:
                return "https://bsc-dataseed.binance.org"
            case .arbitrum:
                return "https://arb1.arbitrum.io/rpc"
            case .optimism:
                return "https://mainnet.optimism.io"
            }
        }

        var wsEndpoint: String {
            switch self {
            case .ethereum:
                return "wss://mainnet.infura.io/ws/v3/YOUR_PROJECT_ID"
            case .polygon:
                return "wss://polygon-rpc.com"
            case .binance:
                return "wss://bsc-dataseed.binance.org"
            case .arbitrum:
                return "wss://arb1.arbitrum.io/ws"
            case .optimism:
                return "wss://mainnet.optimism.io/ws"
            }
        }

        var chainIdHex: String {
            switch self {
            case .ethereum: return "0x1"
            case .polygon: return "0x89"
            case .binance: return "0x38"
            case .arbitrum: return "0xa4b1"
            case .optimism: return "0xa"
            }
        }
    }

    init(networkClient: NetworkClient = .shared) {
        self.networkClient = networkClient
        setupClients()
    }

    private func setupClients() {
        for chain in ChainID.allCases {
            clients[chain] = BlockchainAPIClient(
                rpcEndpoint: chain.rpcEndpoint,
                wsEndpoint: chain.wsEndpoint,
                networkClient: networkClient
            )
        }
    }

    // MARK: - Multi-Chain Operations

    func getBalance(address: String, on chain: ChainID) async throws -> String {
        guard let client = clients[chain] else {
            throw NetworkError.invalidURL("Chain not configured: \(chain.rawValue)")
        }
        return try await client.getBalance(address: address)
    }

    func getAllBalances(address: String) async throws -> [ChainID: String] {
        try await withThrowingTaskGroup(of: (ChainID, String).self) { group in
            for chain in ChainID.allCases {
                group.addTask {
                    let balance = try await self.getBalance(address: address, on: chain)
                    return (chain, balance)
                }
            }

            var balances: [ChainID: String] = [:]
            for try await (chain, balance) in group {
                balances[chain] = balance
            }
            return balances
        }
    }

    func sendTransaction(
        signedTx: String,
        on chain: ChainID
    ) async throws -> String {
        guard let client = clients[chain] else {
            throw NetworkError.invalidURL("Chain not configured: \(chain.rawValue)")
        }
        return try await client.sendRawTransaction(signedTx: signedTx)
    }

    func getGasPrice(on chain: ChainID) async throws -> String {
        guard let client = clients[chain] else {
            throw NetworkError.invalidURL("Chain not configured: \(chain.rawValue)")
        }
        return try await client.getGasPrice()
    }

    func estimateGas(
        transaction: TransactionParams,
        on chain: ChainID
    ) async throws -> String {
        guard let client = clients[chain] else {
            throw NetworkError.invalidURL("Chain not configured: \(chain.rawValue)")
        }
        return try await client.estimateGas(transaction: transaction)
    }

    // MARK: - Cross-Chain Monitoring

    func subscribeToAllChains() -> AnyPublisher<(ChainID, BlockResponse), Error> {
        let subject = PassthroughSubject<(ChainID, BlockResponse), Error>()

        for (chainID, client) in clients {
            client.subscribeToNewBlocks()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            subject.send(completion: .failure(error))
                        }
                    },
                    receiveValue: { block in
                        subject.send((chainID, block))
                    }
                )
                .store(in: &cancellables)
        }

        return subject.eraseToAnyPublisher()
    }

    private var cancellables = Set<AnyCancellable>()
}
