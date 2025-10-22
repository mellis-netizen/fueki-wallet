//
//  BitcoinAPIClient.swift
//  FuekiWallet
//
//  Bitcoin blockchain API client
//

import Foundation

/// API client for Bitcoin blockchain data
final class BitcoinAPIClient {

    private let network: Network
    private let endpoint: String
    private let session: URLSession

    init(network: Network, endpoint: String? = nil) {
        self.network = network

        // Default endpoints
        if let endpoint = endpoint {
            self.endpoint = endpoint
        } else {
            self.endpoint = network == .mainnet
                ? "https://blockstream.info/api"
                : "https://blockstream.info/testnet/api"
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Balance

    func getBalance(address: String) async throws -> BitcoinBalance {
        let url = URL(string: "\(endpoint)/address/\(address)")!
        let (data, _) = try await session.data(from: url)

        let response = try JSONDecoder().decode(AddressResponse.self, from: data)

        return BitcoinBalance(
            confirmed: response.chain_stats.funded_txo_sum - response.chain_stats.spent_txo_sum,
            unconfirmed: response.mempool_stats.funded_txo_sum - response.mempool_stats.spent_txo_sum,
            total: (response.chain_stats.funded_txo_sum - response.chain_stats.spent_txo_sum) +
                   (response.mempool_stats.funded_txo_sum - response.mempool_stats.spent_txo_sum)
        )
    }

    // MARK: - UTXOs

    func getUTXOs(address: String) async throws -> [UTXO] {
        let url = URL(string: "\(endpoint)/address/\(address)/utxo")!
        let (data, _) = try await session.data(from: url)

        let utxoResponses = try JSONDecoder().decode([UTXOResponse].self, from: data)

        return utxoResponses.map { response in
            UTXO(
                txHash: response.txid,
                outputIndex: response.vout,
                value: response.value,
                script: Data(hex: response.scriptpubkey),
                confirmations: response.status.confirmed ? response.status.block_height ?? 0 : 0
            )
        }
    }

    // MARK: - Transactions

    func getTransactionHistory(address: String, limit: Int, offset: Int) async throws -> [BitcoinTransactionDetails] {
        let url = URL(string: "\(endpoint)/address/\(address)/txs")!
        let (data, _) = try await session.data(from: url)

        let txResponses = try JSONDecoder().decode([TransactionResponse].self, from: data)

        return try txResponses.suffix(limit).map { response in
            try mapTransactionResponse(response)
        }
    }

    func getTransactionDetails(txHash: String) async throws -> BitcoinTransactionDetails {
        let url = URL(string: "\(endpoint)/tx/\(txHash)")!
        let (data, _) = try await session.data(from: url)

        let response = try JSONDecoder().decode(TransactionResponse.self, from: data)
        return try mapTransactionResponse(response)
    }

    // MARK: - Broadcasting

    func broadcastTransaction(txHex: String) async throws -> String {
        let url = URL(string: "\(endpoint)/tx")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = txHex.data(using: .utf8)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw BitcoinAPIError.broadcastFailed
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Fee Estimation

    func estimateFee(blocks: Int) async throws -> Int64 {
        let url = URL(string: "\(endpoint)/fee-estimates")!
        let (data, _) = try await session.data(from: url)

        let estimates = try JSONDecoder().decode([String: Double].self, from: data)

        // Get estimate for target blocks, fallback to closest
        if let estimate = estimates[String(blocks)] {
            return Int64(estimate * 100000000 / 1000) // Convert BTC/kB to sat/byte
        }

        // Fallback to default
        return 10 // 10 sat/byte
    }

    // MARK: - Helpers

    private func mapTransactionResponse(_ response: TransactionResponse) throws -> BitcoinTransactionDetails {
        let inputs = response.vin.map { vin in
            TransactionInput(
                previousOutput: TransactionOutPoint(
                    hash: Data(hex: vin.txid),
                    index: UInt32(vin.vout)
                ),
                signatureScript: Data(),
                sequence: 0
            )
        }

        let outputs = response.vout.map { vout in
            TransactionOutput(
                address: vout.scriptpubkey_address ?? "",
                amount: vout.value
            )
        }

        return BitcoinTransactionDetails(
            txHash: response.txid,
            confirmations: response.status.confirmed ? (response.status.block_height ?? 0) : 0,
            blockHeight: response.status.block_height,
            timestamp: response.status.block_time.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            inputs: inputs,
            outputs: outputs,
            fee: response.fee,
            size: response.size
        )
    }
}

// MARK: - API Response Models

private struct AddressResponse: Codable {
    let address: String
    let chain_stats: Stats
    let mempool_stats: Stats

    struct Stats: Codable {
        let funded_txo_sum: Int64
        let spent_txo_sum: Int64
    }
}

private struct UTXOResponse: Codable {
    let txid: String
    let vout: Int
    let value: Int64
    let scriptpubkey: String
    let status: Status

    struct Status: Codable {
        let confirmed: Bool
        let block_height: Int?
    }
}

private struct TransactionResponse: Codable {
    let txid: String
    let size: Int
    let fee: Int64
    let vin: [Vin]
    let vout: [Vout]
    let status: Status

    struct Vin: Codable {
        let txid: String
        let vout: Int
    }

    struct Vout: Codable {
        let value: Int64
        let scriptpubkey_address: String?
    }

    struct Status: Codable {
        let confirmed: Bool
        let block_height: Int?
        let block_time: Int?
    }
}

private enum BitcoinAPIError: Error {
    case broadcastFailed
}
