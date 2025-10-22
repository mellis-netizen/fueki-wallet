//
//  MockWalletService.swift
//  FuekiWalletTests
//
//  Mock wallet service for testing
//

import Foundation
@testable import FuekiWallet

final class MockWalletService: WalletServiceProtocol {

    // MARK: - Mock Data

    var mockWallet: Wallet?
    var mockWallets: [Wallet] = []
    var mockError: Error?

    // MARK: - Call Tracking

    var loadActiveWalletCalled = false
    var unlockCalled = false
    var lockCalled = false
    var createWalletCalled = false
    var importWalletCalled = false
    var deleteWalletCalled = false

    // MARK: - Failure Flags

    var shouldFailLoadWallet = false
    var shouldFailUnlock = false
    var shouldFailCreate = false
    var shouldFailImport = false

    // MARK: - WalletServiceProtocol

    func loadActiveWallet() async throws -> Wallet? {
        loadActiveWalletCalled = true

        if shouldFailLoadWallet {
            throw mockError ?? WalletError.noActiveWallet
        }

        return mockWallet
    }

    func unlock(_ wallet: Wallet) async throws {
        unlockCalled = true

        if shouldFailUnlock {
            throw mockError ?? WalletError.unlockFailed
        }
    }

    func lock() {
        lockCalled = true
    }

    func createWallet(name: String, password: String) async throws -> Wallet {
        createWalletCalled = true

        if shouldFailCreate {
            throw mockError ?? WalletError.walletCreationFailed
        }

        let wallet = Wallet(
            id: UUID().uuidString,
            name: name,
            address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            createdAt: Date(),
            isActive: true
        )

        mockWallet = wallet
        return wallet
    }

    func importWallet(mnemonic: String, password: String) async throws -> Wallet {
        importWalletCalled = true

        if shouldFailImport {
            throw mockError ?? WalletError.invalidMnemonic
        }

        let wallet = Wallet(
            id: UUID().uuidString,
            name: "Imported Wallet",
            address: "0x1234567890123456789012345678901234567890",
            createdAt: Date(),
            isActive: true
        )

        mockWallet = wallet
        return wallet
    }

    func deleteWallet(_ wallet: Wallet) async throws {
        deleteWalletCalled = true
        mockWallet = nil
    }

    func getAllWallets() async throws -> [Wallet] {
        return mockWallets
    }

    func setActiveWallet(_ wallet: Wallet) async throws {
        mockWallet = wallet
    }

    // MARK: - Helper Methods

    func reset() {
        mockWallet = nil
        mockWallets = []
        mockError = nil

        loadActiveWalletCalled = false
        unlockCalled = false
        lockCalled = false
        createWalletCalled = false
        importWalletCalled = false
        deleteWalletCalled = false

        shouldFailLoadWallet = false
        shouldFailUnlock = false
        shouldFailCreate = false
        shouldFailImport = false
    }
}
