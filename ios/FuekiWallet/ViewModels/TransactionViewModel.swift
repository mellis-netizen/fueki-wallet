//
//  TransactionViewModel.swift
//  FuekiWallet
//
//  Created by Fueki Team
//  Copyright © 2025 Fueki. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

/// Comprehensive ViewModel for transaction operations
@MainActor
final class TransactionViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedTransaction: TransactionRecord?
    @Published var currentOperation: TransactionOperation = .none

    // MARK: - Transaction Creation

    @Published var recipientAddress = ""
    @Published var amount = ""
    @Published var memo = ""
    @Published var selectedAsset: Asset?

    // MARK: - Validation State

    @Published var addressValidation: ValidationState = .idle
    @Published var amountValidation: ValidationState = .idle
    @Published var canProceed = false

    // MARK: - Gas/Fee State

    @Published var estimatedGasFee: Decimal = 0
    @Published var gasPriceOption: GasPriceOption = .medium
    @Published var customGasPrice: Decimal?
    @Published var gasLimit: Int = 21000
    @Published var maxPriorityFee: Decimal = 0
    @Published var baseFee: Decimal = 0

    // MARK: - Transaction Lifecycle

    @Published var transactionStatus: TransactionLifecycleStatus = .idle
    @Published var confirmations: Int = 0
    @Published var requiredConfirmations = 12
    @Published var blockNumber: Int?
    @Published var transactionHash: String?
    @Published var estimatedTimeToConfirm: TimeInterval?

    // MARK: - UI State

    @Published var isLoading = false
    @Published var isEstimatingFee = false
    @Published var showConfirmation = false
    @Published var showSuccess = false
    @Published var showQRScanner = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Advanced Features

    @Published var enableSpeedUpTransaction = false
    @Published var enableCancelTransaction = false
    @Published var nonce: Int?
    @Published var replacementTransaction: Transaction?

    // MARK: - Dependencies

    private let transactionService: TransactionServiceProtocol
    private let gasService: GasServiceProtocol
    private let validationService: ValidationServiceProtocol
    private let blockchainService: BlockchainServiceProtocol
    private let walletViewModel: WalletViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Timers

    private var statusUpdateTimer: Timer?
    private var feeUpdateTimer: Timer?

    // MARK: - Initialization

    init(
        transactionService: TransactionServiceProtocol = TransactionService.shared,
        gasService: GasServiceProtocol = GasService.shared,
        validationService: ValidationServiceProtocol = ValidationService.shared,
        blockchainService: BlockchainServiceProtocol = BlockchainService.shared,
        walletViewModel: WalletViewModel
    ) {
        self.transactionService = transactionService
        self.gasService = gasService
        self.validationService = validationService
        self.blockchainService = blockchainService
        self.walletViewModel = walletViewModel
        setupBindings()
    }

    deinit {
        statusUpdateTimer?.invalidate()
        feeUpdateTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Address validation
        $recipientAddress
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] address in
                Task { await self?.validateAddress(address) }
            }
            .store(in: &cancellables)

        // Amount validation
        Publishers.CombineLatest($amount, $selectedAsset)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] amount, asset in
                Task { await self?.validateAmount(amount, asset: asset) }
            }
            .store(in: &cancellables)

        // Can proceed logic
        Publishers.CombineLatest3(
            $addressValidation,
            $amountValidation,
            $isLoading
        )
        .map { addressValid, amountValid, loading in
            addressValid == .valid && amountValid == .valid && !loading
        }
        .assign(to: &$canProceed)

        // Gas fee estimation
        Publishers.CombineLatest4(
            $recipientAddress,
            $amount,
            $selectedAsset,
            $gasPriceOption
        )
        .debounce(for: .milliseconds(800), scheduler: DispatchQueue.main)
        .sink { [weak self] address, amount, asset, priceOption in
            guard !address.isEmpty, !amount.isEmpty, asset != nil else { return }
            Task { await self?.estimateGasFee() }
        }
        .store(in: &cancellables)

        // Monitor error state
        $errorMessage
            .map { $0 != nil }
            .assign(to: &$showError)

        // Enable transaction replacement options
        $selectedTransaction
            .combineLatest($transactionStatus)
            .map { transaction, status in
                transaction != nil && status == .pending
            }
            .assign(to: &$enableSpeedUpTransaction)

        Publishers.CombineLatest($selectedTransaction, $transactionStatus)
            .map { transaction, status in
                transaction != nil && status == .pending
            }
            .assign(to: &$enableCancelTransaction)

        // Auto-start gas price monitoring
        $currentOperation
            .sink { [weak self] operation in
                self?.handleOperationChange(operation)
            }
            .store(in: &cancellables)
    }

    // MARK: - Address Validation

    private func validateAddress(_ address: String) async {
        guard !address.isEmpty else {
            addressValidation = .idle
            return
        }

        addressValidation = .validating

        do {
            let isValid = try await validationService.validateAddress(
                address,
                network: walletViewModel.selectedNetwork
            )

            let isContract = try await blockchainService.isContract(
                address,
                network: walletViewModel.selectedNetwork
            )

            if isValid {
                addressValidation = isContract ? .validContract : .valid
            } else {
                addressValidation = .invalid("Invalid address format")
            }
        } catch {
            addressValidation = .invalid("Validation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Amount Validation

    private func validateAmount(_ amount: String, asset: Asset?) async {
        guard !amount.isEmpty, let asset = asset else {
            amountValidation = .idle
            return
        }

        amountValidation = .validating

        guard let amountDecimal = Decimal(string: amount), amountDecimal > 0 else {
            amountValidation = .invalid("Invalid amount")
            return
        }

        // Check balance
        if amountDecimal > asset.balance {
            amountValidation = .invalid("Insufficient balance")
            return
        }

        // Check minimum transfer amount
        let minimumAmount = Decimal(string: "0.000001") ?? 0
        if amountDecimal < minimumAmount {
            amountValidation = .invalid("Amount too small")
            return
        }

        // Check if we have enough for gas
        let estimatedTotal = amountDecimal + estimatedGasFee
        if asset.symbol == walletViewModel.selectedNetwork.symbol && estimatedTotal > asset.balance {
            amountValidation = .invalid("Insufficient balance for gas fee")
            return
        }

        amountValidation = .valid
    }

    // MARK: - Gas Estimation

    func estimateGasFee() async {
        guard let asset = selectedAsset,
              let amountDecimal = Decimal(string: amount),
              addressValidation == .valid || addressValidation == .validContract else {
            return
        }

        isEstimatingFee = true
        errorMessage = nil

        do {
            let estimate = try await gasService.estimateGas(
                from: walletViewModel.currentWallet?.address ?? "",
                to: recipientAddress,
                amount: amountDecimal,
                asset: asset,
                network: walletViewModel.selectedNetwork,
                gasOption: gasPriceOption
            )

            gasLimit = estimate.gasLimit
            baseFee = estimate.baseFee
            maxPriorityFee = estimate.maxPriorityFee
            estimatedGasFee = estimate.totalFee
            estimatedTimeToConfirm = estimate.estimatedTime

            // Re-validate amount with new gas estimate
            await validateAmount(amount, asset: asset)
        } catch {
            errorMessage = "Failed to estimate gas: \(error.localizedDescription)"
            estimatedGasFee = 0
        }

        isEstimatingFee = false
    }

    func setGasPriceOption(_ option: GasPriceOption) async {
        gasPriceOption = option
        await estimateGasFee()
    }

    func setCustomGasPrice(_ price: Decimal) async {
        customGasPrice = price
        gasPriceOption = .custom
        await estimateGasFee()
    }

    // MARK: - Transaction Creation

    func prepareTransaction() {
        currentOperation = .send
        showConfirmation = true
    }

    func createAndSendTransaction() async -> Bool {
        guard let asset = selectedAsset,
              let amountDecimal = Decimal(string: amount),
              let wallet = walletViewModel.currentWallet else {
            errorMessage = "Missing required information"
            return false
        }

        isLoading = true
        errorMessage = nil
        transactionStatus = .creating

        do {
            // Get nonce
            nonce = try await blockchainService.getTransactionCount(
                address: wallet.address,
                network: walletViewModel.selectedNetwork
            )

            // Create transaction
            let transaction = Transaction(
                from: wallet.address,
                to: recipientAddress,
                amount: amountDecimal,
                asset: asset,
                gasPrice: customGasPrice ?? baseFee + maxPriorityFee,
                gasLimit: gasLimit,
                network: walletViewModel.selectedNetwork,
                nonce: nonce,
                memo: memo.isEmpty ? nil : memo
            )

            transactionStatus = .signing

            // Sign and send
            let hash = try await transactionService.sendTransaction(transaction)

            transactionHash = hash
            transactionStatus = .broadcasting

            // Monitor transaction
            await monitorTransaction(hash: hash)

            showConfirmation = false
            showSuccess = true
            transactionStatus = .confirmed

            resetForm()
            return true

        } catch {
            errorMessage = "Transaction failed: \(error.localizedDescription)"
            transactionStatus = .failed
            return false
        }

        isLoading = false
    }

    // MARK: - Transaction Monitoring

    private func monitorTransaction(hash: String) async {
        confirmations = 0

        statusUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: 3.0,
            repeats: true
        ) { [weak self] _ in
            Task { await self?.updateTransactionStatus(hash: hash) }
        }
    }

    private func updateTransactionStatus(hash: String) async {
        do {
            let status = try await blockchainService.getTransactionStatus(
                hash: hash,
                network: walletViewModel.selectedNetwork
            )

            confirmations = status.confirmations
            blockNumber = status.blockNumber

            if confirmations >= requiredConfirmations {
                transactionStatus = .confirmed
                statusUpdateTimer?.invalidate()
            } else if status.failed {
                transactionStatus = .failed
                statusUpdateTimer?.invalidate()
            } else {
                transactionStatus = .pending
            }
        } catch {
            print("Failed to update transaction status: \(error)")
        }
    }

    // MARK: - Transaction Replacement

    func speedUpTransaction() async -> Bool {
        guard let transaction = selectedTransaction,
              let currentNonce = nonce else {
            errorMessage = "Cannot speed up transaction"
            return false
        }

        isLoading = true

        do {
            // Increase gas price by 10%
            let newGasPrice = (customGasPrice ?? baseFee + maxPriorityFee) * Decimal(1.1)

            let replacementTx = Transaction(
                from: transaction.fromAddress,
                to: transaction.toAddress,
                amount: transaction.amount,
                asset: transaction.asset,
                gasPrice: newGasPrice,
                gasLimit: gasLimit,
                network: walletViewModel.selectedNetwork,
                nonce: currentNonce,
                memo: memo.isEmpty ? nil : memo
            )

            let hash = try await transactionService.sendTransaction(replacementTx)

            transactionHash = hash
            await monitorTransaction(hash: hash)

            return true
        } catch {
            errorMessage = "Failed to speed up transaction: \(error.localizedDescription)"
            return false
        }

        isLoading = false
    }

    func cancelTransaction() async -> Bool {
        guard let transaction = selectedTransaction,
              let currentNonce = nonce,
              let wallet = walletViewModel.currentWallet else {
            errorMessage = "Cannot cancel transaction"
            return false
        }

        isLoading = true

        do {
            // Send 0 value transaction to self with higher gas
            let newGasPrice = (customGasPrice ?? baseFee + maxPriorityFee) * Decimal(1.1)

            let cancellationTx = Transaction(
                from: wallet.address,
                to: wallet.address,
                amount: 0,
                asset: transaction.asset,
                gasPrice: newGasPrice,
                gasLimit: 21000,
                network: walletViewModel.selectedNetwork,
                nonce: currentNonce,
                memo: nil
            )

            let hash = try await transactionService.sendTransaction(cancellationTx)

            transactionHash = hash
            await monitorTransaction(hash: hash)

            return true
        } catch {
            errorMessage = "Failed to cancel transaction: \(error.localizedDescription)"
            return false
        }

        isLoading = false
    }

    // MARK: - QR Code

    func scanQRCode() {
        showQRScanner = true
    }

    func processQRCode(_ code: String) {
        // Parse address or payment URL
        if let paymentInfo = parsePaymentURL(code) {
            recipientAddress = paymentInfo.address
            if let amt = paymentInfo.amount {
                amount = String(describing: amt)
            }
            if let msg = paymentInfo.message {
                memo = msg
            }
        } else {
            recipientAddress = code
        }

        showQRScanner = false
    }

    private func parsePaymentURL(_ url: String) -> PaymentInfo? {
        // Parse ethereum:0x... or bitcoin:... URIs
        guard let components = URLComponents(string: url) else { return nil }

        let address = components.path
        var amount: Decimal?
        var message: String?

        if let queryItems = components.queryItems {
            for item in queryItems {
                if item.name == "amount" || item.name == "value" {
                    amount = Decimal(string: item.value ?? "")
                } else if item.name == "message" || item.name == "memo" {
                    message = item.value
                }
            }
        }

        return PaymentInfo(address: address, amount: amount, message: message)
    }

    // MARK: - Form Management

    func resetForm() {
        recipientAddress = ""
        amount = ""
        memo = ""
        addressValidation = .idle
        amountValidation = .idle
        estimatedGasFee = 0
        gasPriceOption = .medium
        customGasPrice = nil
        transactionHash = nil
        nonce = nil
        confirmations = 0
        blockNumber = nil
    }

    func dismissSuccess() {
        showSuccess = false
        currentOperation = .none
        selectedTransaction = nil
    }

    // MARK: - Helpers

    private func handleOperationChange(_ operation: TransactionOperation) {
        switch operation {
        case .send:
            startGasPriceMonitoring()
        case .none:
            stopGasPriceMonitoring()
        }
    }

    private func startGasPriceMonitoring() {
        feeUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: 15.0,
            repeats: true
        ) { [weak self] _ in
            Task { await self?.estimateGasFee() }
        }
    }

    private func stopGasPriceMonitoring() {
        feeUpdateTimer?.invalidate()
    }

    // MARK: - Formatted Values

    var formattedEstimatedFee: String {
        formatCrypto(estimatedGasFee, symbol: walletViewModel.selectedNetwork.symbol)
    }

    var formattedBaseFee: String {
        formatGwei(baseFee)
    }

    var formattedMaxPriorityFee: String {
        formatGwei(maxPriorityFee)
    }

    var formattedTotalGasPrice: String {
        formatGwei(baseFee + maxPriorityFee)
    }

    var confirmationProgress: Double {
        Double(confirmations) / Double(requiredConfirmations)
    }

    var estimatedTimeRemaining: String? {
        guard let estimatedTime = estimatedTimeToConfirm else { return nil }
        let remaining = max(0, estimatedTime - Double(confirmations * 13)) // ~13 seconds per block
        return formatDuration(remaining)
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

    private func formatGwei(_ value: Decimal) -> String {
        let gwei = value * Decimal(1_000_000_000)
        return String(format: "%.2f Gwei", NSDecimalNumber(decimal: gwei).doubleValue)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Supporting Types

enum ValidationState: Equatable {
    case idle
    case validating
    case valid
    case validContract
    case invalid(String)
}

enum TransactionOperation {
    case none
    case send
}

enum TransactionLifecycleStatus {
    case idle
    case creating
    case signing
    case broadcasting
    case pending
    case confirmed
    case failed
}

enum GasPriceOption: String, CaseIterable {
    case slow = "Slow"
    case medium = "Medium"
    case fast = "Fast"
    case custom = "Custom"

    var estimatedTime: TimeInterval {
        switch self {
        case .slow: return 300 // 5 minutes
        case .medium: return 90 // 1.5 minutes
        case .fast: return 30 // 30 seconds
        case .custom: return 90
        }
    }
}

struct PaymentInfo {
    let address: String
    let amount: Decimal?
    let message: String?
}

struct TransactionStatusInfo {
    let confirmations: Int
    let blockNumber: Int?
    let failed: Bool
}

extension Transaction {
    init(
        from: String,
        to: String,
        amount: Decimal,
        asset: Asset,
        gasPrice: Decimal,
        gasLimit: Int,
        network: Network,
        nonce: Int? = nil,
        memo: String? = nil
    ) {
        self.from = from
        self.to = to
        self.amount = amount
        self.asset = asset
        self.gasPrice = gasPrice
        self.gasLimit = gasLimit
        self.network = network
    }
}

// MARK: - Service Protocol Extensions

protocol BlockchainServiceProtocol {
    func isContract(_ address: String, network: Network) async throws -> Bool
    func getTransactionCount(address: String, network: Network) async throws -> Int
    func getTransactionStatus(hash: String, network: Network) async throws -> TransactionStatusInfo
}

extension GasEstimate {
    var baseFee: Decimal { gasPrice * Decimal(0.7) }
    var maxPriorityFee: Decimal { gasPrice * Decimal(0.3) }
    var estimatedTime: TimeInterval { 90 }
}

extension ValidationServiceProtocol {
    func validateAddress(_ address: String, network: Network) async throws -> Bool {
        return isValidAddress(address)
    }
}
