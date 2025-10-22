//
//  BitcoinProvider.swift
//  FuekiWallet
//
//  Blockchain Integration Specialist - Bitcoin Integration (UTXO Handling)
//

import Foundation
import Combine

class BitcoinProvider: BlockchainProviderProtocol {
    let chainType: BlockchainType = .bitcoin
    private(set) var network: NetworkEnvironment
    private(set) var isConnected: Bool = false

    private let rpcClient: RPCClient
    private let wsClient: RPCClient
    private let config: ChainConfig
    private var subscriptions = Set<AnyCancellable>()

    // WebSocket subscriptions
    private let addressSubject = PassthroughSubject<BlockchainTransaction, Error>()
    private let blockSubject = PassthroughSubject<UInt64, Error>()

    init(network: NetworkEnvironment = .mainnet) {
        self.network = network
        self.config = ChainConfigManager.shared.getBitcoinConfig(network: network)

        self.rpcClient = RPCClient(endpoints: config.rpcEndpoints)
        self.wsClient = RPCClient(endpoints: config.wsEndpoints)
    }

    // MARK: - Connection Management
    func connect() async throws {
        // Test connection by getting block count
        _ = try await getCurrentBlockNumber()
        isConnected = true
    }

    func disconnect() async {
        isConnected = false
        wsClient.disconnectWebSocket()
    }

    func switchNetwork(_ network: NetworkEnvironment) async throws {
        await disconnect()
        self.network = network
        try await connect()
    }

    // MARK: - Account Management
    func getBalance(for address: String) async throws -> BlockchainBalance {
        guard validateAddress(address) else {
            throw BlockchainError.invalidAddress
        }

        // Get address info from Blockstream API
        let url = URL(string: "\(config.rpcEndpoints[0])/address/\(address)")!
        let (data, _) = try await URLSession.shared.data(from: url)

        let addressInfo = try JSONDecoder().decode(BitcoinModels.AddressInfo.self, from: data)

        // Calculate balance (funded - spent)
        let balance = addressInfo.chainStats.fundedTxoSum - addressInfo.chainStats.spentTxoSum

        return BlockchainBalance(
            address: address,
            nativeBalance: Decimal(balance),
            tokens: [],  // Bitcoin doesn't have native tokens
            timestamp: Date()
        )
    }

    func getTokenBalance(for address: String, tokenAddress: String) async throws -> Decimal {
        // Bitcoin doesn't support tokens natively
        throw BlockchainError.unsupportedOperation
    }

    func validateAddress(_ address: String) -> Bool {
        // Bitcoin addresses can be:
        // - Legacy (P2PKH): starts with 1, 26-35 chars
        // - SegWit (P2SH): starts with 3, 26-35 chars
        // - Native SegWit (Bech32): starts with bc1 (mainnet) or tb1 (testnet), 42-62 chars

        if address.hasPrefix("bc1") || address.hasPrefix("tb1") {
            // Bech32 validation
            return address.count >= 42 && address.count <= 62
        } else if address.hasPrefix("1") || address.hasPrefix("3") {
            // Base58 validation
            return address.count >= 26 && address.count <= 35
        }

        return false
    }

    // MARK: - Transaction Management
    func getTransaction(hash: String) async throws -> BlockchainTransaction {
        let url = URL(string: "\(config.rpcEndpoints[0])/tx/\(hash)")!
        let (data, _) = try await URLSession.shared.data(from: url)

        let tx = try JSONDecoder().decode(BitcoinModels.Transaction.self, from: data)

        return try convertToBlockchainTransaction(tx)
    }

    func getTransactionHistory(for address: String, limit: Int) async throws -> [BlockchainTransaction] {
        let url = URL(string: "\(config.rpcEndpoints[0])/address/\(address)/txs")!
        let (data, _) = try await URLSession.shared.data(from: url)

        let transactions = try JSONDecoder().decode([BitcoinModels.Transaction].self, from: data)

        return try transactions.prefix(limit).map { try convertToBlockchainTransaction($0) }
    }

    func estimateGas(for request: TransactionRequest) async throws -> GasEstimation {
        // Get current fee estimates
        let url = URL(string: "\(config.rpcEndpoints[0])/fee-estimates")!
        let (data, _) = try await URLSession.shared.data(from: url)

        let feeEstimate = try JSONDecoder().decode(BitcoinModels.FeeEstimate.self, from: data)

        // Estimate transaction size
        // Typical P2PKH transaction: ~250 bytes
        // SegWit transaction: ~140 vBytes
        let txSize: UInt64 = 250

        // Calculate fees (satoshis per byte * transaction size)
        let economyFee = Decimal(feeEstimate.economyFee * txSize)
        let hourFee = Decimal(feeEstimate.hourFee * txSize)
        let fastFee = Decimal(feeEstimate.fastestFee * txSize)

        return GasEstimation(
            gasLimit: txSize,  // Transaction size in bytes
            baseFee: economyFee,
            maxFeePerGas: fastFee,
            maxPriorityFeePerGas: hourFee,
            estimatedTotal: hourFee,
            confidence: 0.75
        )
    }

    // MARK: - Transaction Building
    func buildTransaction(_ request: TransactionRequest) async throws -> Data {
        // Get UTXOs for the address
        let utxos = try await getUTXOs(for: request.from)

        guard !utxos.isEmpty else {
            throw BlockchainError.insufficientBalance
        }

        // Select UTXOs to cover the amount
        let selectedUTXOs = try selectUTXOs(utxos, targetAmount: request.value)

        // Build transaction
        let tx = BitcoinModels.Transaction(
            txid: "",
            version: 2,
            locktime: 0,
            vin: selectedUTXOs.map { utxo in
                BitcoinModels.Transaction.Input(
                    txid: utxo.txid,
                    vout: utxo.vout,
                    scriptSig: nil,
                    sequence: 0xffffffff,
                    witness: nil,
                    prevout: nil
                )
            },
            vout: [
                BitcoinModels.Transaction.Output(
                    value: UInt64((request.value as NSDecimalNumber).uint64Value),
                    scriptPubKey: "",
                    scriptPubKeyType: "p2pkh",
                    scriptPubKeyAddress: request.to
                )
            ],
            size: 0,
            weight: 0,
            fee: 0,
            status: BitcoinModels.Transaction.Status(
                confirmed: false,
                blockHeight: nil,
                blockHash: nil,
                blockTime: nil
            )
        )

        return try JSONEncoder().encode(tx)
    }

    func sendSignedTransaction(_ signedTx: SignedTransaction) async throws -> String {
        let txHex = signedTx.rawTransaction.toHexString()

        var request = URLRequest(url: URL(string: "\(config.rpcEndpoints[0])/tx")!)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = txHex.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BlockchainError.transactionFailed("Failed to broadcast transaction")
        }

        // Response is the transaction ID
        guard let txid = String(data: data, encoding: .utf8) else {
            throw BlockchainError.networkError(URLError(.cannotParseResponse))
        }

        return txid
    }

    func getTransactionStatus(hash: String) async throws -> TransactionStatus {
        let tx = try await getTransaction(hash: hash)

        if tx.status == .failed {
            return .failed
        }

        guard let confirmations = tx.confirmations else {
            return .pending
        }

        if confirmations >= NetworkConstants.bitcoinConfirmationTarget {
            return .finalized
        } else if confirmations > 0 {
            return .confirmed
        } else {
            return .pending
        }
    }

    // MARK: - Block Information
    func getCurrentBlockNumber() async throws -> UInt64 {
        let url = URL(string: "\(config.rpcEndpoints[0])/blocks/tip/height")!
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let heightString = String(data: data, encoding: .utf8),
              let height = UInt64(heightString) else {
            throw BlockchainError.networkError(URLError(.cannotParseResponse))
        }

        return height
    }

    func getBlock(number: UInt64) async throws -> BlockInfo {
        // First get block hash from height
        let hashUrl = URL(string: "\(config.rpcEndpoints[0])/block-height/\(number)")!
        let (hashData, _) = try await URLSession.shared.data(from: hashUrl)

        guard let blockHash = String(data: hashData, encoding: .utf8) else {
            throw BlockchainError.networkError(URLError(.cannotParseResponse))
        }

        // Then get block info
        let blockUrl = URL(string: "\(config.rpcEndpoints[0])/block/\(blockHash)")!
        let (blockData, _) = try await URLSession.shared.data(from: blockUrl)

        let block = try JSONDecoder().decode(BitcoinModels.Block.self, from: blockData)

        return BlockInfo(
            number: number,
            hash: block.hash,
            timestamp: Date(timeIntervalSince1970: TimeInterval(block.timestamp)),
            transactionCount: block.txCount,
            gasUsed: nil,
            gasLimit: nil
        )
    }

    // MARK: - Real-time Updates
    func subscribeToAddress(_ address: String) -> AnyPublisher<BlockchainTransaction, Error> {
        // Subscribe via WebSocket to address transactions
        Task {
            do {
                if !config.wsEndpoints.isEmpty {
                    try wsClient.connectWebSocket(endpoint: config.wsEndpoints[0])

                    // Subscribe to address
                    let subscribeMessage = "{\"op\":\"addr_sub\",\"addr\":\"\(address)\"}"
                    if let data = subscribeMessage.data(using: .utf8) {
                        // Note: This is simplified, actual implementation depends on WebSocket API
                    }

                    wsClient.webSocketPublisher()
                        .sink(
                            receiveCompletion: { [weak self] completion in
                                if case .failure(let error) = completion {
                                    self?.addressSubject.send(completion: .failure(error))
                                }
                            },
                            receiveValue: { [weak self] data in
                                self?.handleWebSocketData(data)
                            }
                        )
                        .store(in: &subscriptions)
                }
            } catch {
                addressSubject.send(completion: .failure(error))
            }
        }

        return addressSubject.eraseToAnyPublisher()
    }

    func subscribeToNewBlocks() -> AnyPublisher<UInt64, Error> {
        Task {
            do {
                if !config.wsEndpoints.isEmpty {
                    try wsClient.connectWebSocket(endpoint: config.wsEndpoints[0])

                    let subscribeMessage = "{\"op\":\"blocks_sub\"}"
                    if let data = subscribeMessage.data(using: .utf8) {
                        // Subscribe to new blocks
                    }

                    wsClient.webSocketPublisher()
                        .sink(
                            receiveCompletion: { [weak self] completion in
                                if case .failure(let error) = completion {
                                    self?.blockSubject.send(completion: .failure(error))
                                }
                            },
                            receiveValue: { [weak self] data in
                                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let height = json["height"] as? UInt64 {
                                    self?.blockSubject.send(height)
                                }
                            }
                        )
                        .store(in: &subscriptions)
                }
            } catch {
                blockSubject.send(completion: .failure(error))
            }
        }

        return blockSubject.eraseToAnyPublisher()
    }

    // MARK: - Token Operations
    func getTokenInfo(contractAddress: String) async throws -> TokenInfo {
        // Bitcoin doesn't support smart contracts natively
        throw BlockchainError.unsupportedOperation
    }

    func getTokensForAddress(_ address: String) async throws -> [TokenInfo] {
        // Bitcoin doesn't support tokens natively
        return []
    }

    // MARK: - Private Helpers
    private func getUTXOs(for address: String) async throws -> [BitcoinModels.UTXO] {
        let url = URL(string: "\(config.rpcEndpoints[0])/address/\(address)/utxo")!
        let (data, _) = try await URLSession.shared.data(from: url)

        let utxos = try JSONDecoder().decode([BitcoinModels.UTXO].self, from: data)

        return utxos.filter { $0.spendable }
    }

    private func selectUTXOs(_ utxos: [BitcoinModels.UTXO], targetAmount: Decimal) throws -> [BitcoinModels.UTXO] {
        let targetSatoshis = UInt64((targetAmount as NSDecimalNumber).uint64Value)

        // Sort UTXOs by value (largest first for simple selection)
        let sortedUTXOs = utxos.sorted { $0.value > $1.value }

        var selectedUTXOs: [BitcoinModels.UTXO] = []
        var totalValue: UInt64 = 0

        for utxo in sortedUTXOs {
            selectedUTXOs.append(utxo)
            totalValue += utxo.value

            if totalValue >= targetSatoshis {
                break
            }
        }

        guard totalValue >= targetSatoshis else {
            throw BlockchainError.insufficientBalance
        }

        return selectedUTXOs
    }

    private func convertToBlockchainTransaction(_ tx: BitcoinModels.Transaction) throws -> BlockchainTransaction {
        // Calculate total input value
        let inputValue = tx.vin.reduce(UInt64(0)) { sum, input in
            sum + (input.prevout?.value ?? 0)
        }

        // Calculate total output value
        let outputValue = tx.vout.reduce(UInt64(0)) { sum, output in
            sum + output.value
        }

        // Fee is the difference
        let fee = inputValue > outputValue ? inputValue - outputValue : 0

        let status: TransactionStatus
        if tx.status.confirmed {
            status = .finalized
        } else {
            status = .pending
        }

        let from = tx.vin.first?.prevout?.scriptPubKeyAddress ?? ""
        let to = tx.vout.first?.scriptPubKeyAddress ?? ""

        return BlockchainTransaction(
            hash: tx.txid,
            from: from,
            to: to,
            value: Decimal(outputValue),
            fee: Decimal(fee),
            timestamp: Date(timeIntervalSince1970: TimeInterval(tx.status.blockTime ?? 0)),
            status: status,
            blockNumber: tx.status.blockHeight.map { UInt64($0) },
            confirmations: nil,
            data: nil,
            tokenTransfers: nil
        )
    }

    private func handleWebSocketData(_ data: Data) {
        // Parse WebSocket notifications
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let txid = json["txid"] as? String else {
            return
        }

        Task {
            do {
                let tx = try await getTransaction(hash: txid)
                addressSubject.send(tx)
            } catch {
                addressSubject.send(completion: .failure(error))
            }
        }
    }
}
