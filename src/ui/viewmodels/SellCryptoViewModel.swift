//
//  SellCryptoViewModel.swift
//  Fueki Wallet
//
//  Sell cryptocurrency view model with bank account handling
//

import SwiftUI
import Combine

@MainActor
class SellCryptoViewModel: ObservableObject {
    @Published var bankAccounts: [BankAccount] = []
    @Published var isProcessing = false
    @Published var saleSuccess = false
    @Published var errorMessage: String?

    private let rampService: RampService

    init(rampService: RampService = .shared) {
        self.rampService = rampService
        loadBankAccounts()
    }

    // MARK: - Bank Accounts

    private func loadBankAccounts() {
        bankAccounts = BankAccount.samples
    }

    // MARK: - Calculations

    func calculateUSDValue(amount: Decimal, asset: CryptoAsset) -> Decimal {
        return amount * asset.priceUSD
    }

    func calculateFee(usdAmount: Decimal) -> Decimal {
        // 1.5% fee for sales
        return usdAmount * 0.015
    }

    // MARK: - Sale Processing

    func processSale(
        asset: CryptoAsset,
        amount: Decimal,
        bankAccount: BankAccount
    ) async {
        isProcessing = true
        saleSuccess = false
        errorMessage = nil

        do {
            let transactionId = try await rampService.processSale(
                asset: asset,
                amount: amount,
                bankAccount: bankAccount
            )

            print("Sale successful: \(transactionId)")
            saleSuccess = true
        } catch {
            errorMessage = "Sale failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }
}
