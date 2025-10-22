//
//  SendViewModel.swift
//  FuekiWallet
//
//  Created by Fueki Team
//  Copyright © 2025 Fueki. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel managing send transaction workflow
@MainActor
final class SendViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedAsset: Asset?
    @Published var recipientAddress = ""
    @Published var amount = ""
    @Published var fiatAmount = ""
    @Published var useMaxAmount = false

    // MARK: - Transaction Details

    @Published var gasPrice: Decimal = 0
    @Published var gasLimit: Int = 21000
    @Published var estimatedFee: Decimal = 0
    @Published var totalCost: Decimal = 0

    // MARK: - Validation State

    @Published var isValidAddress = false
    @Published var isValidAmount = false
    @Published var hasInsufficientBalance = false
    @Published var canSend = false

    // MARK: - UI State

    @Published var isLoading = false
    @Published var isEstimatingFee = false
    @Published var showConfirmation = false
    @Published var showSuccess = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Transaction Result

    @Published var transactionHash: String?

    // MARK: - Dependencies

    private let transactionService: TransactionServiceProtocol
    private let gasService: GasServiceProtocol
    private let validationService: ValidationServiceProtocol
    private let walletViewModel: WalletViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        transactionService: TransactionServiceProtocol = TransactionService.shared,
        gasService: GasServiceProtocol = GasService.shared,
        validationService: ValidationServiceProtocol = ValidationService.shared,
        walletViewModel: WalletViewModel
    ) {
        self.transactionService = transactionService
        self.gasService = gasService
        self.validationService = validationService
        self.walletViewModel = walletViewModel
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Validate recipient address
        $recipientAddress
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .map { [weak self] address in
                self?.validationService.isValidAddress(address) ?? false
            }
            .assign(to: &$isValidAddress)

        // Validate amount
        Publishers.CombineLatest3($amount, $selectedAsset, $useMaxAmount)
            .map { [weak self] amount, asset, useMax in
                self?.validateAmount(amount, asset: asset, useMax: useMax) ?? false
            }
            .assign(to: &$isValidAmount)

        // Check for insufficient balance
        Publishers.CombineLatest3($amount, $selectedAsset, $estimatedFee)
            .map { [weak self] amount, asset, fee in
                self?.checkInsufficientBalance(amount, asset: asset, fee: fee) ?? false
            }
            .assign(to: &$hasInsufficientBalance)

        // Update can send state
        Publishers.CombineLatest4($isValidAddress, $isValidAmount, $hasInsufficientBalance, $isLoading)
            .map { isValidAddr, isValidAmt, insufficient, loading in
                isValidAddr && isValidAmt && !insufficient && !loading
            }
            .assign(to: &$canSend)

        // Sync amount conversions
        $amount
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] amount in
                self?.updateFiatAmount(from: amount)
            }
            .store(in: &cancellables)

        $fiatAmount
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] fiat in
                self?.updateCryptoAmount(from: fiat)
            }
            .store(in: &cancellables)

        // Estimate gas when inputs change
        Publishers.CombineLatest3($recipientAddress, $amount, $selectedAsset)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] address, amount, asset in
                guard !address.isEmpty, !amount.isEmpty, asset != nil else { return }
                Task { await self?.estimateGas() }
            }
            .store(in: &cancellables)

        // Monitor error state
        $errorMessage
            .map { $0 != nil }
            .assign(to: &$showError)
    }

    // MARK: - Validation

    private func validateAmount(_ amount: String, asset: Asset?, useMax: Bool) -> Bool {
        guard !amount.isEmpty, let asset = asset else { return false }

        guard let amountDecimal = Decimal(string: amount), amountDecimal > 0 else {
            return false
        }

        return amountDecimal <= asset.balance
    }

    private func checkInsufficientBalance(_ amount: String, asset: Asset?, fee: Decimal) -> Bool {
        guard let amount = Decimal(string: amount), let asset = asset else { return false }

        let total = amount + (asset.symbol == walletViewModel.selectedNetwork.symbol ? fee : 0)
        return total > asset.balance
    }

    // MARK: - Amount Calculations

    func setMaxAmount() {
        guard let asset = selectedAsset else { return }

        useMaxAmount = true

        // Subtract gas fee if sending native token
        if asset.symbol == walletViewModel.selectedNetwork.symbol {
            let maxAmount = max(0, asset.balance - estimatedFee)
            amount = String(describing: maxAmount)
        } else {
            amount = String(describing: asset.balance)
        }
    }

    private func updateFiatAmount(from crypto: String) {
        guard let cryptoAmount = Decimal(string: crypto),
              let asset = selectedAsset else {
            fiatAmount = ""
            return
        }

        let fiat = cryptoAmount * asset.currentPrice
        fiatAmount = String(format: "%.2f", NSDecimalNumber(decimal: fiat).doubleValue)
    }

    private func updateCryptoAmount(from fiat: String) {
        guard let fiatAmount = Decimal(string: fiat),
              let asset = selectedAsset,
              asset.currentPrice > 0 else {
            amount = ""
            return
        }

        let crypto = fiatAmount / asset.currentPrice
        amount = String(describing: crypto)
    }

    // MARK: - Gas Estimation

    func estimateGas() async {
        guard let asset = selectedAsset,
              let amountDecimal = Decimal(string: amount),
              isValidAddress else { return }

        isEstimatingFee = true

        do {
            let estimate = try await gasService.estimateGas(
                from: walletViewModel.currentWallet?.address ?? "",
                to: recipientAddress,
                amount: amountDecimal,
                asset: asset,
                network: walletViewModel.selectedNetwork
            )

            gasPrice = estimate.gasPrice
            gasLimit = estimate.gasLimit
            estimatedFee = estimate.totalFee
            totalCost = amountDecimal + (asset.symbol == walletViewModel.selectedNetwork.symbol ? estimatedFee : 0)
        } catch {
            errorMessage = "Failed to estimate gas: \(error.localizedDescription)"
        }

        isEstimatingFee = false
    }

    // MARK: - Transaction Submission

    func prepareTransaction() {
        showConfirmation = true
    }

    func sendTransaction() async {
        guard let asset = selectedAsset,
              let amountDecimal = Decimal(string: amount),
              let wallet = walletViewModel.currentWallet else { return }

        isLoading = true
        errorMessage = nil

        do {
            let transaction = Transaction(
                from: wallet.address,
                to: recipientAddress,
                amount: amountDecimal,
                asset: asset,
                gasPrice: gasPrice,
                gasLimit: gasLimit,
                network: walletViewModel.selectedNetwork
            )

            let hash = try await transactionService.sendTransaction(transaction)

            transactionHash = hash
            showConfirmation = false
            showSuccess = true

            // Reset form
            resetForm()
        } catch {
            errorMessage = "Transaction failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Form Management

    func resetForm() {
        recipientAddress = ""
        amount = ""
        fiatAmount = ""
        useMaxAmount = false
        gasPrice = 0
        gasLimit = 21000
        estimatedFee = 0
        totalCost = 0
        transactionHash = nil
    }

    func dismissSuccess() {
        showSuccess = false
        selectedAsset = nil
    }

    // MARK: - Formatted Values

    var formattedEstimatedFee: String {
        formatCrypto(estimatedFee, symbol: walletViewModel.selectedNetwork.symbol)
    }

    var formattedTotalCost: String {
        formatCrypto(totalCost, symbol: selectedAsset?.symbol ?? "")
    }

    var formattedGasPrice: String {
        String(format: "%.2f Gwei", NSDecimalNumber(decimal: gasPrice * 1_000_000_000).doubleValue)
    }

    private func formatCrypto(_ value: Decimal, symbol: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8

        let number = NSDecimalNumber(decimal: value)
        let formatted = formatter.string(from: number) ?? "0.00"

        return "\(formatted) \(symbol)"
    }
}

// MARK: - Models

struct Transaction {
    let from: String
    let to: String
    let amount: Decimal
    let asset: Asset
    let gasPrice: Decimal
    let gasLimit: Int
    let network: Network
}

struct GasEstimate {
    let gasPrice: Decimal
    let gasLimit: Int
    let totalFee: Decimal
}

// MARK: - Service Protocols

protocol TransactionServiceProtocol {
    func sendTransaction(_ transaction: Transaction) async throws -> String
}

protocol GasServiceProtocol {
    func estimateGas(from: String, to: String, amount: Decimal, asset: Asset, network: Network) async throws -> GasEstimate
}

protocol ValidationServiceProtocol {
    func isValidAddress(_ address: String) -> Bool
}
