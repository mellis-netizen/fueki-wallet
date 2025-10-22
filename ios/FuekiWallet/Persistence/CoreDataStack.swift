//
//  CoreDataStack.swift
//  FuekiWallet
//
//  Core Data stack setup and management
//

import Foundation
import CoreData
import os.log

/// Core Data stack manager with support for background operations and migrations
final class CoreDataStack {
    // MARK: - Singleton
    static let shared = CoreDataStack()

    // MARK: - Properties
    private let logger = Logger(subsystem: "io.fueki.wallet", category: "CoreData")

    /// Main persistent container
    private(set) lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FuekiWallet")

        // Configure persistent store description
        let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FuekiWallet.sqlite")

        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        storeDescription.setOption(FileProtectionType.complete as NSObject, forKey: NSPersistentStoreFileProtectionKey)

        container.persistentStoreDescriptions = [storeDescription]

        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                self?.logger.error("Failed to load persistent store: \(error.localizedDescription)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }

            self?.logger.info("Core Data store loaded successfully")
        }

        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true

        return container
    }()

    /// Main context for UI operations (main thread)
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    // MARK: - Initialization
    private init() {
        // Initialize the persistent container
        _ = persistentContainer
    }

    // MARK: - Context Management

    /// Creates a new background context for heavy operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
        return context
    }

    /// Creates a child context from the view context
    func newChildContext() -> NSManagedObjectContext {
        let childContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        childContext.parent = viewContext
        childContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        childContext.undoManager = nil
        return childContext
    }

    // MARK: - Save Operations

    /// Saves the view context if it has changes
    func saveViewContext() throws {
        guard viewContext.hasChanges else { return }

        do {
            try viewContext.save()
            logger.info("View context saved successfully")
        } catch {
            logger.error("Failed to save view context: \(error.localizedDescription)")
            throw PersistenceError.saveFailed(error)
        }
    }

    /// Saves a background context if it has changes
    func saveContext(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }

        do {
            try context.save()
            logger.info("Background context saved successfully")
        } catch {
            logger.error("Failed to save background context: \(error.localizedDescription)")
            throw PersistenceError.saveFailed(error)
        }
    }

    /// Performs a save operation on a background context
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        let context = newBackgroundContext()

        try await context.perform {
            do {
                try block(context)
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                self.logger.error("Background task failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    // MARK: - Batch Operations

    /// Performs a batch insert operation
    func batchInsert<T: NSManagedObject>(
        entityName: String,
        objects: [[String: Any]]
    ) async throws {
        let context = newBackgroundContext()

        try await context.perform {
            let batchInsert = NSBatchInsertRequest(
                entityName: entityName,
                objects: objects
            )
            batchInsert.resultType = .statusOnly

            do {
                try context.execute(batchInsert)
                self.logger.info("Batch insert completed: \(objects.count) objects")
            } catch {
                self.logger.error("Batch insert failed: \(error.localizedDescription)")
                throw PersistenceError.batchOperationFailed(error)
            }
        }
    }

    /// Performs a batch update operation
    func batchUpdate(
        entityName: String,
        predicate: NSPredicate?,
        propertiesToUpdate: [String: Any]
    ) async throws {
        let context = newBackgroundContext()

        try await context.perform {
            let batchUpdate = NSBatchUpdateRequest(entityName: entityName)
            batchUpdate.predicate = predicate
            batchUpdate.propertiesToUpdate = propertiesToUpdate
            batchUpdate.resultType = .updatedObjectsCountResultType

            do {
                let result = try context.execute(batchUpdate) as? NSBatchUpdateResult
                let count = result?.result as? Int ?? 0
                self.logger.info("Batch update completed: \(count) objects updated")
            } catch {
                self.logger.error("Batch update failed: \(error.localizedDescription)")
                throw PersistenceError.batchOperationFailed(error)
            }
        }
    }

    /// Performs a batch delete operation
    func batchDelete(
        entityName: String,
        predicate: NSPredicate?
    ) async throws {
        let context = newBackgroundContext()

        try await context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fetchRequest.predicate = predicate

            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDelete.resultType = .resultTypeCount

            do {
                let result = try context.execute(batchDelete) as? NSBatchDeleteResult
                let count = result?.result as? Int ?? 0
                self.logger.info("Batch delete completed: \(count) objects deleted")
            } catch {
                self.logger.error("Batch delete failed: \(error.localizedDescription)")
                throw PersistenceError.batchOperationFailed(error)
            }
        }
    }

    // MARK: - Cleanup

    /// Clears all data from the persistent store
    func clearAllData() async throws {
        let entities = persistentContainer.managedObjectModel.entities

        for entity in entities {
            guard let entityName = entity.name else { continue }

            try await batchDelete(entityName: entityName, predicate: nil)
        }

        logger.info("All data cleared from Core Data")
    }

    /// Resets the entire Core Data stack
    func resetStack() throws {
        let coordinator = persistentContainer.persistentStoreCoordinator

        for store in coordinator.persistentStores {
            guard let storeURL = store.url else { continue }

            do {
                try coordinator.remove(store)
                try FileManager.default.removeItem(at: storeURL)
                logger.info("Store removed: \(storeURL)")
            } catch {
                logger.error("Failed to remove store: \(error.localizedDescription)")
                throw PersistenceError.resetFailed(error)
            }
        }
    }
}

// MARK: - Persistence Errors
enum PersistenceError: LocalizedError {
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case batchOperationFailed(Error)
    case resetFailed(Error)
    case migrationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Save operation failed: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Fetch operation failed: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Delete operation failed: \(error.localizedDescription)"
        case .batchOperationFailed(let error):
            return "Batch operation failed: \(error.localizedDescription)"
        case .resetFailed(let error):
            return "Reset operation failed: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Migration failed: \(error.localizedDescription)"
        }
    }
}
