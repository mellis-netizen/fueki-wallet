//
//  OnboardingViewModel.swift
//  FuekiWallet
//
//  Created by Fueki Team
//  Copyright © 2025 Fueki. All rights reserved.
//

import Foundation
import Combine
import CryptoKit

/// ViewModel managing wallet creation and import flows
@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var currentStep: OnboardingStep = .welcome
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var mnemonicWords: [String] = []
    @Published var verificationIndices: [Int] = []
    @Published var userVerificationWords: [String: String] = [:]
    @Published var importedMnemonic = ""
    @Published var walletName = ""
    @Published var biometricEnabled = false

    // MARK: - State

    @Published var canProceed = false
    @Published var showError = false

    // MARK: - Dependencies

    private let walletService: WalletServiceProtocol
    private let biometricService: BiometricServiceProtocol
    private let keychain: KeychainServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        walletService: WalletServiceProtocol = WalletService.shared,
        biometricService: BiometricServiceProtocol = BiometricService.shared,
        keychain: KeychainServiceProtocol = KeychainService.shared
    ) {
        self.walletService = walletService
        self.biometricService = biometricService
        self.keychain = keychain
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Validate wallet name
        $walletName
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .map { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .assign(to: &$canProceed)

        // Monitor error state
        $errorMessage
            .map { $0 != nil }
            .assign(to: &$showError)
    }

    // MARK: - Actions

    func generateNewWallet() async {
        isLoading = true
        errorMessage = nil

        do {
            let mnemonic = try await walletService.generateMnemonic()
            mnemonicWords = mnemonic.components(separatedBy: " ")

            // Generate random verification indices
            verificationIndices = generateVerificationIndices()

            currentStep = .showMnemonic
        } catch {
            errorMessage = "Failed to generate wallet: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func verifyMnemonic() -> Bool {
        guard verificationIndices.count == 3 else { return false }

        for index in verificationIndices {
            guard let userWord = userVerificationWords[String(index)],
                  userWord.lowercased() == mnemonicWords[index].lowercased() else {
                errorMessage = "Incorrect word verification. Please try again."
                return false
            }
        }

        return true
    }

    func importWallet() async {
        isLoading = true
        errorMessage = nil

        do {
            let words = importedMnemonic
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            guard words.count == 12 || words.count == 24 else {
                throw OnboardingError.invalidMnemonicLength
            }

            let isValid = try await walletService.validateMnemonic(words.joined(separator: " "))

            if isValid {
                mnemonicWords = words
                currentStep = .setupWallet
            } else {
                throw OnboardingError.invalidMnemonic
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func createWallet() async {
        isLoading = true
        errorMessage = nil

        do {
            let mnemonic = mnemonicWords.joined(separator: " ")

            // Create wallet
            let wallet = try await walletService.createWallet(
                name: walletName.trimmingCharacters(in: .whitespaces),
                mnemonic: mnemonic
            )

            // Store in keychain
            try await keychain.saveMnemonic(mnemonic, for: wallet.id)

            // Setup biometric if enabled
            if biometricEnabled {
                try await biometricService.enableBiometric(for: wallet.id)
            }

            currentStep = .complete
        } catch {
            errorMessage = "Failed to create wallet: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .createOrImport
        case .createOrImport:
            break // Handled by button actions
        case .showMnemonic:
            currentStep = .verifyMnemonic
        case .verifyMnemonic:
            if verifyMnemonic() {
                currentStep = .setupWallet
            }
        case .setupWallet:
            Task { await createWallet() }
        case .complete:
            break
        }
    }

    func previousStep() {
        switch currentStep {
        case .welcome:
            break
        case .createOrImport:
            currentStep = .welcome
        case .showMnemonic, .importMnemonic:
            currentStep = .createOrImport
        case .verifyMnemonic:
            currentStep = .showMnemonic
        case .setupWallet:
            if !importedMnemonic.isEmpty {
                currentStep = .importMnemonic
            } else {
                currentStep = .verifyMnemonic
            }
        case .complete:
            break
        }
    }

    func reset() {
        currentStep = .welcome
        isLoading = false
        errorMessage = nil
        mnemonicWords = []
        verificationIndices = []
        userVerificationWords = [:]
        importedMnemonic = ""
        walletName = ""
        biometricEnabled = false
    }

    // MARK: - Helpers

    private func generateVerificationIndices() -> [Int] {
        guard mnemonicWords.count >= 3 else { return [] }

        var indices = Set<Int>()
        while indices.count < 3 {
            indices.insert(Int.random(in: 0..<mnemonicWords.count))
        }

        return Array(indices).sorted()
    }
}

// MARK: - Models

enum OnboardingStep: Equatable {
    case welcome
    case createOrImport
    case showMnemonic
    case verifyMnemonic
    case importMnemonic
    case setupWallet
    case complete
}

enum OnboardingError: LocalizedError {
    case invalidMnemonicLength
    case invalidMnemonic
    case walletCreationFailed
    case keychainStorageFailed
    case biometricSetupFailed

    var errorDescription: String? {
        switch self {
        case .invalidMnemonicLength:
            return "Recovery phrase must be 12 or 24 words"
        case .invalidMnemonic:
            return "Invalid recovery phrase. Please check and try again."
        case .walletCreationFailed:
            return "Failed to create wallet. Please try again."
        case .keychainStorageFailed:
            return "Failed to securely store wallet credentials"
        case .biometricSetupFailed:
            return "Failed to setup biometric authentication"
        }
    }
}

// MARK: - Service Protocols

protocol WalletServiceProtocol {
    func generateMnemonic() async throws -> String
    func validateMnemonic(_ mnemonic: String) async throws -> Bool
    func createWallet(name: String, mnemonic: String) async throws -> Wallet
}

protocol BiometricServiceProtocol {
    func enableBiometric(for walletId: String) async throws
}

protocol KeychainServiceProtocol {
    func saveMnemonic(_ mnemonic: String, for walletId: String) async throws
}
