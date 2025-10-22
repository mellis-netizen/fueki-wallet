//
//  ReceiveViewModel.swift
//  FuekiWallet
//
//  Created by Fueki Team
//  Copyright © 2025 Fueki. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import CoreImage.CIFilterBuiltins

/// ViewModel managing receive address and QR code generation
@MainActor
final class ReceiveViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var address: String = ""
    @Published var qrCodeImage: UIImage?
    @Published var selectedAsset: Asset?
    @Published var requestAmount: String = ""
    @Published var requestNote: String = ""

    // MARK: - UI State

    @Published var isLoading = false
    @Published var showCopiedConfirmation = false
    @Published var showShareSheet = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - QR Code Customization

    @Published var includeAmount = false
    @Published var qrCodeSize: CGFloat = 300

    // MARK: - Dependencies

    private let walletViewModel: WalletViewModel
    private var cancellables = Set<AnyCancellable>()

    // QR Code Generator
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    // MARK: - Initialization

    init(walletViewModel: WalletViewModel) {
        self.walletViewModel = walletViewModel
        setupBindings()
        loadAddress()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Regenerate QR code when address or amount changes
        Publishers.CombineLatest3($address, $includeAmount, $requestAmount)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] address, includeAmt, amount in
                guard !address.isEmpty else { return }
                self?.generateQRCode()
            }
            .store(in: &cancellables)

        // Monitor selected asset changes
        $selectedAsset
            .sink { [weak self] asset in
                self?.updateAddressForAsset(asset)
            }
            .store(in: &cancellables)

        // Monitor error state
        $errorMessage
            .map { $0 != nil }
            .assign(to: &$showError)
    }

    // MARK: - Address Management

    private func loadAddress() {
        guard let wallet = walletViewModel.currentWallet else {
            errorMessage = "No active wallet found"
            return
        }

        address = wallet.address
        generateQRCode()
    }

    private func updateAddressForAsset(_ asset: Asset?) {
        guard let wallet = walletViewModel.currentWallet else { return }

        // For now, use same address for all ERC-20 tokens
        // In future, could support different addresses for different chains
        address = wallet.address
        generateQRCode()
    }

    // MARK: - QR Code Generation

    func generateQRCode() {
        isLoading = true

        let qrContent = buildQRContent()

        guard let data = qrContent.data(using: .utf8) else {
            errorMessage = "Failed to generate QR code"
            isLoading = false
            return
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else {
            errorMessage = "Failed to generate QR code"
            isLoading = false
            return
        }

        // Scale QR code to desired size
        let scaleX = qrCodeSize / outputImage.extent.size.width
        let scaleY = qrCodeSize / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
            qrCodeImage = UIImage(cgImage: cgImage)
        }

        isLoading = false
    }

    private func buildQRContent() -> String {
        var content = ""

        // Build EIP-681 compatible payment request
        if let asset = selectedAsset {
            if asset.contractAddress.isEmpty {
                // Native token (ETH)
                content = "ethereum:\(address)"
            } else {
                // ERC-20 token
                content = "ethereum:\(asset.contractAddress)/transfer?address=\(address)"
            }

            // Add amount if specified
            if includeAmount, let amount = Decimal(string: requestAmount), amount > 0 {
                let separator = content.contains("?") ? "&" : "?"

                // Convert to wei (for native) or token units
                let decimals = asset.decimals
                let multiplier = Decimal(sign: .plus, exponent: decimals, significand: 1)
                let weiAmount = amount * multiplier

                content += "\(separator)value=\(weiAmount)"
            }
        } else {
            // Fallback to plain address
            content = address
        }

        return content
    }

    // MARK: - Actions

    func copyAddress() {
        UIPasteboard.general.string = address
        showCopiedConfirmation = true

        // Hide confirmation after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showCopiedConfirmation = false
        }
    }

    func shareAddress() {
        showShareSheet = true
    }

    func shareQRCode() -> [Any] {
        var items: [Any] = []

        if let qrImage = qrCodeImage {
            items.append(qrImage)
        }

        items.append(buildShareMessage())

        return items
    }

    private func buildShareMessage() -> String {
        var message = "My \(walletViewModel.selectedNetwork.name) address:\n\(address)"

        if let asset = selectedAsset {
            message += "\n\nAsset: \(asset.name) (\(asset.symbol))"
        }

        if includeAmount, let amount = Decimal(string: requestAmount), amount > 0 {
            message += "\nAmount: \(requestAmount) \(selectedAsset?.symbol ?? "")"
        }

        if !requestNote.isEmpty {
            message += "\n\nNote: \(requestNote)"
        }

        return message
    }

    func resetRequest() {
        requestAmount = ""
        requestNote = ""
        includeAmount = false
        selectedAsset = nil
    }

    // MARK: - Formatted Values

    var formattedAddress: String {
        guard address.count > 10 else { return address }

        let start = String(address.prefix(6))
        let end = String(address.suffix(4))
        return "\(start)...\(end)"
    }

    var fullAddressWithLineBreaks: String {
        guard address.count > 20 else { return address }

        var result = ""
        var currentIndex = address.startIndex

        while currentIndex < address.endIndex {
            let lineEnd = address.index(currentIndex, offsetBy: 20, limitedBy: address.endIndex) ?? address.endIndex
            result += String(address[currentIndex..<lineEnd])

            if lineEnd < address.endIndex {
                result += "\n"
            }

            currentIndex = lineEnd
        }

        return result
    }

    var requestSummary: String? {
        guard includeAmount,
              let amount = Decimal(string: requestAmount),
              amount > 0,
              let asset = selectedAsset else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8

        let formattedAmount = formatter.string(from: NSDecimalNumber(decimal: amount)) ?? requestAmount

        return "Requesting \(formattedAmount) \(asset.symbol)"
    }
}
