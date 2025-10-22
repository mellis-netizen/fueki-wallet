//
//  MockKeychainManager.swift
//  FuekiWalletTests
//
//  Mock keychain manager for secure storage testing
//

import Foundation
@testable import FuekiWallet

final class MockKeychainManager {

    // MARK: - Storage

    private var storage: [String: Data] = [:]
    var savedData: [Data] = []
    var mockAllKeys: [String] = []

    // MARK: - Call Tracking

    var saveWasCalled = false
    var loadWasCalled = false
    var deleteWasCalled = false

    // MARK: - Failure Flags

    var shouldFailSave = false
    var shouldFailLoad = false
    var shouldFailDelete = false

    // MARK: - Methods

    func save(_ data: Data, forKey key: String) throws {
        saveWasCalled = true
        savedData.append(data)

        if shouldFailSave {
            throw KeychainError.saveFailed
        }

        storage[key] = data
    }

    func load(forKey key: String) throws -> Data {
        loadWasCalled = true

        if shouldFailLoad {
            throw KeychainError.loadFailed
        }

        guard let data = storage[key] else {
            throw KeychainError.notFound
        }

        return data
    }

    func delete(forKey key: String) throws {
        deleteWasCalled = true

        if shouldFailDelete {
            throw KeychainError.deleteFailed
        }

        storage.removeValue(forKey: key)
    }

    func allKeys() throws -> [String] {
        return mockAllKeys.isEmpty ? Array(storage.keys) : mockAllKeys
    }

    func clear() throws {
        storage.removeAll()
    }

    // MARK: - Helper Methods

    func reset() {
        storage.removeAll()
        savedData.removeAll()
        mockAllKeys.removeAll()

        saveWasCalled = false
        loadWasCalled = false
        deleteWasCalled = false

        shouldFailSave = false
        shouldFailLoad = false
        shouldFailDelete = false
    }
}

enum KeychainError: Error {
    case saveFailed
    case loadFailed
    case notFound
    case deleteFailed
}
