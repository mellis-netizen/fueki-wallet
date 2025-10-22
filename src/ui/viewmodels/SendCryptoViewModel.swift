//
//  SendCryptoViewModel.swift
//  Fueki Wallet
//
//  Send cryptocurrency view model with validation
//

import SwiftUI
import Combine

@MainActor
class SendCryptoViewModel: ObservableObject {
    @Published var isValidatingAddress = false
    @Published var addressError: String?
    @Published var estimatedFee: Decimal = 0
    @Published var estimatedFeeUSD: Decimal = 0
    @Published var isSending = false
    @Published var transactionSuccess = false
    @Published var errorMessage: String?

    private let transactionService: TransactionService
    private var validationTask: Task<Void, Never>?

    init(transactionService: TransactionService = .shared) {
        self.transactionService = transactionService
    }

    // MARK: - Address Validation

    func validateAddress(_ address: String, asset: CryptoAsset?) async {
        guard !address.isEmpty, let asset = asset else {
            addressError = nil
            return
        }

        // Cancel previous validation
        validationTask?.cancel()

        validationTask = Task {
            isValidatingAddress = true
            addressError = nil

            // Add small delay to debounce
            try? await Task.sleep(nanoseconds: 500_000_000)

            guard !Task.isCancelled else {
                isValidatingAddress = false
                return
            }

            do {
                let isValid = try await transactionService.validateAddress(
                    address,
                    blockchain: asset.blockchain
                )

                if !isValid {
                    addressError = "Invalid \(asset.blockchain) address"
                }
            } catch {
                addressError = "Failed to validate address"
            }

            isValidatingAddress = false
        }
    }

    // MARK: - Fee Estimation

    func estimateNetworkFee(asset: CryptoAsset) async {
        do {
            let fee = try await transactionService.estimateFee(
                blockchain: asset.blockchain
            )
            estimatedFee = fee
            estimatedFeeUSD = fee * asset.priceUSD
        } catch {
            print("Failed to estimate fee: \(error)")
            // Use default fee
            estimatedFee = 0.001
            estimatedFeeUSD = estimatedFee * asset.priceUSD
        }
    }

    // MARK: - Calculations

    func calculateUSDValue(amount: Decimal, asset: CryptoAsset) -> Decimal {
        return amount * asset.priceUSD
    }

    // MARK: - Send Transaction

    func sendTransaction(
        asset: CryptoAsset,
        amount: Decimal,
        recipient: String,
        memo: String
    ) async {
        isSending = true
        transactionSuccess = false
        errorMessage = nil

        do {
            let txHash = try await transactionService.sendTransaction(
                asset: asset,
                amount: amount,
                to: recipient,
                memo: memo
            )

            print("Transaction sent: \(txHash)")
            transactionSuccess = true
        } catch {
            errorMessage = "Failed to send transaction: \(error.localizedDescription)"
        }

        isSending = false
    }
}

// MARK: - Transaction Service
class TransactionService {
    static let shared = TransactionService()

    func validateAddress(_ address: String, blockchain: String) async throws -> Bool {
        // TODO: Implement real address validation
        try await Task.sleep(nanoseconds: 500_000_000)

        // Basic validation for demo
        switch blockchain {
        case "Bitcoin":
            return address.starts(with: "bc1") || address.starts(with: "1") || address.starts(with: "3")
        case "Ethereum":
            return address.starts(with: "0x") && address.count == 42
        case "Solana":
            return address.count >= 32 && address.count <= 44
        default:
            return false
        }
    }

    func estimateFee(blockchain: String) async throws -> Decimal {
        // TODO: Implement real fee estimation
        try await Task.sleep(nanoseconds: 300_000_000)

        switch blockchain {
        case "Bitcoin":
            return 0.0001
        case "Ethereum":
            return 0.002
        case "Solana":
            return 0.00001
        default:
            return 0.001
        }
    }

    func sendTransaction(
        asset: CryptoAsset,
        amount: Decimal,
        to: String,
        memo: String
    ) async throws -> String {
        // TODO: Implement real transaction sending
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Simulate transaction hash
        return "0x\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    }
}
