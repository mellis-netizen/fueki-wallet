import Foundation
@testable import FuekiWallet

final class MockSecureStorage: SecureStorageProtocol {

    // MARK: - Mock Data

    var storedData: [String: Data] = [:]
    var storedStrings: [String: String] = [:]

    // MARK: - Behavior Flags

    var shouldFailStore = false
    var shouldFailRetrieve = false
    var shouldFailDelete = false

    // MARK: - Call Tracking

    var storeWasCalled = false
    var retrieveWasCalled = false
    var deleteWasCalled = false
    var deleteAllWasCalled = false
    var existsWasCalled = false

    var lastKeyStored: String?
    var lastKeyRetrieved: String?
    var lastKeyDeleted: String?

    // MARK: - SecureStorageProtocol Implementation

    func store(_ data: Data, forKey key: String, password: String? = nil, requireAuth: Bool = false) throws {
        storeWasCalled = true
        lastKeyStored = key

        if shouldFailStore {
            throw SecureStorageError.storeFailed
        }

        storedData[key] = data
    }

    func retrieve(forKey key: String, password: String? = nil) throws -> Data {
        retrieveWasCalled = true
        lastKeyRetrieved = key

        if shouldFailRetrieve {
            throw SecureStorageError.retrieveFailed
        }

        guard let data = storedData[key] else {
            throw SecureStorageError.notFound
        }

        return data
    }

    func delete(forKey key: String) throws {
        deleteWasCalled = true
        lastKeyDeleted = key

        if shouldFailDelete {
            throw SecureStorageError.deleteFailed
        }

        storedData.removeValue(forKey: key)
        storedStrings.removeValue(forKey: key)
    }

    func deleteAll() throws {
        deleteAllWasCalled = true

        if shouldFailDelete {
            throw SecureStorageError.deleteFailed
        }

        storedData.removeAll()
        storedStrings.removeAll()
    }

    func exists(forKey key: String) -> Bool {
        existsWasCalled = true
        return storedData[key] != nil || storedStrings[key] != nil
    }

    func storeString(_ string: String, forKey key: String, requireAuth: Bool = false) throws {
        storeWasCalled = true
        lastKeyStored = key

        if shouldFailStore {
            throw SecureStorageError.storeFailed
        }

        storedStrings[key] = string
    }

    func retrieveString(forKey key: String) throws -> String {
        retrieveWasCalled = true
        lastKeyRetrieved = key

        if shouldFailRetrieve {
            throw SecureStorageError.retrieveFailed
        }

        guard let string = storedStrings[key] else {
            throw SecureStorageError.notFound
        }

        return string
    }

    // MARK: - Helper Methods

    func reset() {
        storedData.removeAll()
        storedStrings.removeAll()

        shouldFailStore = false
        shouldFailRetrieve = false
        shouldFailDelete = false

        storeWasCalled = false
        retrieveWasCalled = false
        deleteWasCalled = false
        deleteAllWasCalled = false
        existsWasCalled = false

        lastKeyStored = nil
        lastKeyRetrieved = nil
        lastKeyDeleted = nil
    }

    // MARK: - Test Helpers

    func setMockData(_ data: Data, forKey key: String) {
        storedData[key] = data
    }

    func setMockString(_ string: String, forKey key: String) {
        storedStrings[key] = string
    }

    func getAllStoredKeys() -> [String] {
        return Array(Set(storedData.keys).union(storedStrings.keys))
    }

    func getStorageCount() -> Int {
        return Set(storedData.keys).union(storedStrings.keys).count
    }
}
