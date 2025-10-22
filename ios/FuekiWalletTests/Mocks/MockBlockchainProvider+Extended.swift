//
//  MockBlockchainProvider+Extended.swift
//  FuekiWalletTests
//
//  Extended mock blockchain provider with full functionality
//

import Foundation
@testable import FuekiWallet

final class MockBlockchainProvider: BlockchainProviderProtocol {

    // MARK: - Properties

    let chainType: ChainType

    // MARK: - Mock Data

    var mockBalance: String = "0x0"
    var mockTransactions: [[String: Any]] = []
    var mockUTXOs: [[String: Any]] = []
    var mockTransactionHash: String = "0xabc123"
    var mockFeeRates: [String: Any] = [:]
    var mockGasEstimate: String = "0x5208"
    var mockNonce: Int = 0
    var mockChainId: Int = 1
    var mockRawTransaction: Data = Data()
    var mockGasEstimation: GasEstimation?
    var mockRecentBlockhash: String = ""
    var mockRentExemption: UInt64 = 0
    var mockTransactionSignature: String = ""
    var mockError: Error?
    var mockTransactionStatus: TransactionStatus = .pending
    var mockConfirmations: Int = 0

    // MARK: - Call Tracking

    var fetchBalanceCalled = false
    var fetchTransactionsCalled = false
    var fetchUTXOsCalled = false
    var broadcastTransactionCalled = false
    var buildTransactionWasCalled = false
    var estimateGasCalled = false
    var getNonceWasCalled = false

    // MARK: - Failure Flags

    var shouldFailBalance = false
    var shouldFailTransactions = false
    var shouldFailUTXOs = false
    var shouldFailBroadcast = false
    var shouldFailGasEstimation = false

    // MARK: - Initialization

    init(chainType: ChainType) {
        self.chainType = chainType
    }

    // MARK: - BlockchainProviderProtocol

    func fetchBalance(for address: String) async throws -> UInt64 {
        fetchBalanceCalled = true

        if shouldFailBalance {
            throw mockError ?? NetworkError.serverError(500)
        }

        // Parse hex balance
        let hex = mockBalance.hasPrefix("0x") ? String(mockBalance.dropFirst(2)) : mockBalance
        return UInt64(hex, radix: 16) ?? 0
    }

    func fetchTransactionHistory(for address: String) async throws -> [Transaction] {
        fetchTransactionsCalled = true

        if shouldFailTransactions {
            throw mockError ?? NetworkError.serverError(500)
        }

        return mockTransactions.compactMap { dict -> Transaction? in
            guard let hash = dict["hash"] as? String,
                  let from = dict["from"] as? String,
                  let to = dict["to"] as? String else {
                return nil
            }

            let value = dict["value"] as? String ?? "0x0"
            let amount = UInt64(value.dropFirst(2), radix: 16) ?? 0

            return Transaction(
                id: hash,
                hash: hash,
                from: from,
                to: to,
                amount: Decimal(amount),
                timestamp: Date(),
                status: .confirmed,
                type: from.lowercased() == address.lowercased() ? .sent : .received
            )
        }
    }

    func fetchUTXOs(for address: String) async throws -> [UTXO] {
        fetchUTXOsCalled = true

        if shouldFailUTXOs {
            throw mockError ?? NetworkError.serverError(500)
        }

        return mockUTXOs.compactMap { dict -> UTXO? in
            guard let txid = dict["txid"] as? String,
                  let vout = dict["vout"] as? Int,
                  let value = dict["value"] as? UInt64 else {
                return nil
            }

            return UTXO(
                txid: txid,
                vout: UInt32(vout),
                value: value,
                scriptPubKey: Data()
            )
        }
    }

    func broadcastTransaction(_ rawTransaction: Data) async throws -> String {
        broadcastTransactionCalled = true

        if shouldFailBroadcast {
            throw mockError ?? NetworkError.serverError(500)
        }

        return mockTransactionHash
    }

    func buildTransaction(_ request: TransactionRequest) async throws -> Data {
        buildTransactionWasCalled = true
        return mockRawTransaction
    }

    func estimateGas(for request: TransactionRequest) async throws -> GasEstimation {
        estimateGasCalled = true

        if shouldFailGasEstimation {
            throw mockError ?? NetworkError.serverError(500)
        }

        if let estimation = mockGasEstimation {
            return estimation
        }

        // Default estimation
        return GasEstimation(
            gasLimit: 21000,
            maxFeePerGas: Decimal(50),
            maxPriorityFeePerGas: Decimal(2),
            estimatedCost: Decimal(0.00105)
        )
    }

    func validateAddress(_ address: String) -> Bool {
        switch chainType {
        case .ethereum:
            return address.hasPrefix("0x") && address.count == 42

        case .bitcoin:
            return address.hasPrefix("bc1") || address.hasPrefix("tb1") ||
                   address.hasPrefix("1") || address.hasPrefix("m") ||
                   address.hasPrefix("3") || address.hasPrefix("2")

        case .solana:
            return address.count >= 32 && address.count <= 44
        }
    }

    func getNonce(for address: String) async throws -> UInt64 {
        getNonceWasCalled = true
        return UInt64(mockNonce)
    }

    func getChainId() async throws -> Int {
        return mockChainId
    }

    func fetchFeeRates() async throws -> FeeRates {
        if let fast = mockFeeRates["fastestFee"] as? Int,
           let medium = mockFeeRates["halfHourFee"] as? Int,
           let slow = mockFeeRates["hourFee"] as? Int {
            return FeeRates(fast: fast, medium: medium, slow: slow)
        }

        return FeeRates(fast: 50, medium: 30, slow: 10)
    }

    func getTransactionStatus(hash: String) async throws -> TransactionStatus {
        return mockTransactionStatus
    }

    func getTransactionConfirmations(hash: String) async throws -> Int {
        return mockConfirmations
    }

    func getRecentBlockhash() async throws -> String {
        return mockRecentBlockhash
    }

    func calculateRentExemption(dataLength: Int) async throws -> UInt64 {
        return mockRentExemption
    }

    // MARK: - Helper Methods

    func reset() {
        mockBalance = "0x0"
        mockTransactions = []
        mockUTXOs = []
        mockTransactionHash = "0xabc123"
        mockFeeRates = [:]
        mockGasEstimate = "0x5208"
        mockNonce = 0
        mockChainId = 1
        mockRawTransaction = Data()
        mockGasEstimation = nil
        mockRecentBlockhash = ""
        mockRentExemption = 0
        mockTransactionSignature = ""
        mockError = nil
        mockTransactionStatus = .pending
        mockConfirmations = 0

        fetchBalanceCalled = false
        fetchTransactionsCalled = false
        fetchUTXOsCalled = false
        broadcastTransactionCalled = false
        buildTransactionWasCalled = false
        estimateGasCalled = false
        getNonceWasCalled = false

        shouldFailBalance = false
        shouldFailTransactions = false
        shouldFailUTXOs = false
        shouldFailBroadcast = false
        shouldFailGasEstimation = false
    }
}

// MARK: - Supporting Types

enum ChainType {
    case ethereum
    case bitcoin
    case solana
}

struct UTXO {
    let txid: String
    let vout: UInt32
    let value: UInt64
    let scriptPubKey: Data
}

struct FeeRates {
    let fast: Int
    let medium: Int
    let slow: Int
}

enum TransactionStatus {
    case pending
    case confirmed
    case failed
}

enum BlockchainError: Error, Equatable {
    case invalidAddress
    case invalidTransaction
    case insufficientBalance
    case insufficientGas
    case unsupportedOperation
    case networkError
    case secureEnclaveKeyGenerationFailed
    case secureEnclaveOperationFailed(String)
    case keyGenerationFailed
    case publicKeyGenerationFailed
    case invalidData
}
