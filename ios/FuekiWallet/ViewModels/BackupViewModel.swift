//
//  BackupViewModel.swift
//  FuekiWallet
//
//  Created by Fueki Team
//  Copyright © 2025 Fueki. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel managing wallet backup and restore workflows
@MainActor
final class BackupViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var backupStep: BackupStep = .warning
    @Published var mnemonicWords: [String] = []
    @Published var verificationIndices: [Int] = []
    @Published var userVerificationWords: [String: String] = [:]
    @Published var isBackedUp = false
    @Published var lastBackupDate: Date?

    // MARK: - Restore State

    @Published var restoreMethod: RestoreMethod = .mnemonic
    @Published var importedMnemonic = ""
    @Published var privateKey = ""
    @Published var keystoreFile: Data?
    @Published var keystorePassword = ""

    // MARK: - Cloud Backup

    @Published var cloudBackupEnabled = false
    @Published var cloudBackupDate: Date?
    @Published var cloudBackupEncrypted = true

    // MARK: - UI State

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSuccess = false
    @Published var successMessage: String?

    // MARK: - Dependencies

    private let backupService: BackupServiceProtocol
    private let walletService: WalletServiceProtocol
    private let biometricService: BiometricServiceProtocol
    private let walletViewModel: WalletViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        backupService: BackupServiceProtocol = BackupService.shared,
        walletService: WalletServiceProtocol = WalletService.shared,
        biometricService: BiometricServiceProtocol = BiometricService.shared,
        walletViewModel: WalletViewModel
    ) {
        self.backupService = backupService
        self.walletService = walletService
        self.biometricService = biometricService
        self.walletViewModel = walletViewModel
        setupBindings()
        loadBackupStatus()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Monitor error state
        $errorMessage
            .map { $0 != nil }
            .assign(to: &$showError)
    }

    // MARK: - Backup Status

    func loadBackupStatus() {
        guard let wallet = walletViewModel.currentWallet else { return }

        do {
            let status = try backupService.getBackupStatus(for: wallet.id)
            isBackedUp = status.isBackedUp
            lastBackupDate = status.lastBackupDate
            cloudBackupEnabled = status.cloudBackupEnabled
            cloudBackupDate = status.cloudBackupDate
        } catch {
            print("Failed to load backup status: \(error)")
        }
    }

    // MARK: - Manual Backup Flow

    func startBackup() async {
        guard let wallet = walletViewModel.currentWallet else {
            errorMessage = "No active wallet found"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // Require biometric authentication
            let authenticated = try await biometricService.authenticate(
                reason: "Authenticate to view recovery phrase"
            )

            guard authenticated else {
                throw BackupError.authenticationFailed
            }

            // Retrieve mnemonic
            let mnemonic = try await backupService.retrieveMnemonic(for: wallet.id)
            mnemonicWords = mnemonic.components(separatedBy: " ")

            // Generate verification indices
            verificationIndices = generateVerificationIndices()

            backupStep = .viewMnemonic
        } catch {
            errorMessage = "Failed to start backup: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func verifyBackup() -> Bool {
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

    func completeBackup() async {
        guard let wallet = walletViewModel.currentWallet else { return }

        guard verifyBackup() else { return }

        isLoading = true

        do {
            try await backupService.markAsBackedUp(wallet.id)

            isBackedUp = true
            lastBackupDate = Date()
            backupStep = .complete

            successMessage = "Wallet backed up successfully"
            showSuccess = true
        } catch {
            errorMessage = "Failed to complete backup: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Cloud Backup

    func toggleCloudBackup() async {
        guard let wallet = walletViewModel.currentWallet else { return }

        isLoading = true
        errorMessage = nil

        do {
            if !cloudBackupEnabled {
                // Enable cloud backup
                let authenticated = try await biometricService.authenticate(
                    reason: "Authenticate to enable cloud backup"
                )

                guard authenticated else {
                    throw BackupError.authenticationFailed
                }

                try await backupService.enableCloudBackup(
                    for: wallet.id,
                    encrypted: cloudBackupEncrypted
                )

                cloudBackupEnabled = true
                cloudBackupDate = Date()
                successMessage = "Cloud backup enabled"
            } else {
                // Disable cloud backup
                try await backupService.disableCloudBackup(for: wallet.id)

                cloudBackupEnabled = false
                cloudBackupDate = nil
                successMessage = "Cloud backup disabled"
            }

            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func syncCloudBackup() async {
        guard let wallet = walletViewModel.currentWallet else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await backupService.syncCloudBackup(for: wallet.id)

            cloudBackupDate = Date()
            successMessage = "Cloud backup synced successfully"
            showSuccess = true
        } catch {
            errorMessage = "Failed to sync cloud backup: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Restore Flow

    func restoreWallet() async {
        isLoading = true
        errorMessage = nil

        do {
            let wallet: Wallet

            switch restoreMethod {
            case .mnemonic:
                wallet = try await restoreFromMnemonic()
            case .privateKey:
                wallet = try await restoreFromPrivateKey()
            case .keystore:
                wallet = try await restoreFromKeystore()
            case .cloud:
                wallet = try await restoreFromCloud()
            }

            // Update wallet view model
            walletViewModel.currentWallet = wallet

            successMessage = "Wallet restored successfully"
            showSuccess = true

            resetRestoreForm()
        } catch {
            errorMessage = "Failed to restore wallet: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func restoreFromMnemonic() async throws -> Wallet {
        let words = importedMnemonic
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        guard words.count == 12 || words.count == 24 else {
            throw BackupError.invalidMnemonicLength
        }

        let mnemonic = words.joined(separator: " ")
        let isValid = try await walletService.validateMnemonic(mnemonic)

        guard isValid else {
            throw BackupError.invalidMnemonic
        }

        return try await walletService.restoreWallet(fromMnemonic: mnemonic)
    }

    private func restoreFromPrivateKey() async throws -> Wallet {
        let key = privateKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty else {
            throw BackupError.invalidPrivateKey
        }

        return try await walletService.restoreWallet(fromPrivateKey: key)
    }

    private func restoreFromKeystore() async throws -> Wallet {
        guard let keystoreData = keystoreFile else {
            throw BackupError.keystoreFileRequired
        }

        guard !keystorePassword.isEmpty else {
            throw BackupError.keystorePasswordRequired
        }

        return try await walletService.restoreWallet(
            fromKeystore: keystoreData,
            password: keystorePassword
        )
    }

    private func restoreFromCloud() async throws -> Wallet {
        let authenticated = try await biometricService.authenticate(
            reason: "Authenticate to restore from cloud"
        )

        guard authenticated else {
            throw BackupError.authenticationFailed
        }

        return try await backupService.restoreFromCloud()
    }

    // MARK: - Export

    func exportPrivateKey() async -> String? {
        guard let wallet = walletViewModel.currentWallet else { return nil }

        do {
            let authenticated = try await biometricService.authenticate(
                reason: "Authenticate to export private key"
            )

            guard authenticated else { return nil }

            return try await backupService.exportPrivateKey(for: wallet.id)
        } catch {
            errorMessage = "Failed to export private key: \(error.localizedDescription)"
            return nil
        }
    }

    func exportKeystore(password: String) async -> Data? {
        guard let wallet = walletViewModel.currentWallet else { return nil }

        guard !password.isEmpty else {
            errorMessage = "Password is required"
            return nil
        }

        do {
            let authenticated = try await biometricService.authenticate(
                reason: "Authenticate to export keystore"
            )

            guard authenticated else { return nil }

            return try await backupService.exportKeystore(for: wallet.id, password: password)
        } catch {
            errorMessage = "Failed to export keystore: \(error.localizedDescription)"
            return nil
        }
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

    func resetBackupFlow() {
        backupStep = .warning
        mnemonicWords = []
        verificationIndices = []
        userVerificationWords = [:]
    }

    func resetRestoreForm() {
        importedMnemonic = ""
        privateKey = ""
        keystoreFile = nil
        keystorePassword = ""
    }
}

// MARK: - Models

enum BackupStep {
    case warning
    case viewMnemonic
    case verifyMnemonic
    case complete
}

enum RestoreMethod: String, CaseIterable {
    case mnemonic = "Recovery Phrase"
    case privateKey = "Private Key"
    case keystore = "Keystore File"
    case cloud = "Cloud Backup"
}

struct BackupStatus {
    let isBackedUp: Bool
    let lastBackupDate: Date?
    let cloudBackupEnabled: Bool
    let cloudBackupDate: Date?
}

enum BackupError: LocalizedError {
    case authenticationFailed
    case invalidMnemonicLength
    case invalidMnemonic
    case invalidPrivateKey
    case keystoreFileRequired
    case keystorePasswordRequired
    case cloudBackupNotAvailable
    case backupFailed
    case restoreFailed

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed"
        case .invalidMnemonicLength:
            return "Recovery phrase must be 12 or 24 words"
        case .invalidMnemonic:
            return "Invalid recovery phrase"
        case .invalidPrivateKey:
            return "Invalid private key"
        case .keystoreFileRequired:
            return "Keystore file is required"
        case .keystorePasswordRequired:
            return "Keystore password is required"
        case .cloudBackupNotAvailable:
            return "Cloud backup is not available"
        case .backupFailed:
            return "Failed to backup wallet"
        case .restoreFailed:
            return "Failed to restore wallet"
        }
    }
}

// MARK: - Service Protocol

protocol BackupServiceProtocol {
    func getBackupStatus(for walletId: String) throws -> BackupStatus
    func retrieveMnemonic(for walletId: String) async throws -> String
    func markAsBackedUp(_ walletId: String) async throws
    func enableCloudBackup(for walletId: String, encrypted: Bool) async throws
    func disableCloudBackup(for walletId: String) async throws
    func syncCloudBackup(for walletId: String) async throws
    func restoreFromCloud() async throws -> Wallet
    func exportPrivateKey(for walletId: String) async throws -> String
    func exportKeystore(for walletId: String, password: String) async throws -> Data
}
