// CoreDataStack.swift
// Decodey
//
// Modern Core Data stack with graceful error handling and recovery

import CoreData
import Foundation
import os.log

/// Core Data stack with production-ready error handling
final class CoreDataStack {
    // MARK: - Singleton
    static let shared = CoreDataStack()
    
    // MARK: - Properties
    
    /// Logger for Core Data events
    private let logger = Logger(subsystem: "com.decodey.app", category: "CoreData")
    
    /// Track if persistent store failed to load
    private(set) var isStoreLoaded = false
    
    /// Track if we're using in-memory store as fallback
    private(set) var isUsingInMemoryStore = false
    
    /// Error that occurred during store loading (if any)
    private(set) var storeError: Error?
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DecodeyApp")
        
        // Configure for better performance
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Set up store description with modern options
        if let storeDescription = container.persistentStoreDescriptions.first {
            // Enable lightweight migration
            storeDescription.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            storeDescription.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            
            // Enable history tracking for better sync if needed later
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            
            // Optimize for performance
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        // Load persistent stores with comprehensive error handling
        loadPersistentStores(for: container)
        
        return container
    }()
    
    // MARK: - Private Init
    private init() {}
    
    // MARK: - Store Loading with Recovery
    
    private func loadPersistentStores(for container: NSPersistentContainer) {
        container.loadPersistentStores { [weak self] (storeDescription, error) in
            guard let self = self else { return }
            
            if let error = error as NSError? {
                self.storeError = error
                self.logger.error("Failed to load persistent store: \(error), \(error.userInfo)")
                
                // Attempt recovery strategies
                self.handlePersistentStoreError(error, container: container)
            } else {
                self.isStoreLoaded = true
                self.logger.info("Core Data stack successfully initialized")
                
                #if DEBUG
                self.logger.debug("Store URL: \(storeDescription.url?.absoluteString ?? "unknown")")
                #endif
            }
        }
    }
    
    // MARK: - Error Recovery Strategies
    
    private func handlePersistentStoreError(_ error: NSError, container: NSPersistentContainer) {
        // Check the error domain and code
        if error.domain == NSCocoaErrorDomain {
            switch error.code {
            case 134110: // NSPersistentStoreIncompatibleVersionHashError
                logger.warning("Incompatible version hash, attempting recovery...")
                attemptStoreRecovery(container: container)
                
            case 134100: // NSPersistentStoreIncompatibleSchemaError
                logger.warning("Schema incompatibility, attempting recovery...")
                attemptStoreRecovery(container: container)
                
            case 134130, 134140: // Migration errors
                logger.warning("Migration error detected, attempting recovery...")
                attemptStoreRecovery(container: container)
                
            case 260: // NSFileReadNoSuchFileError
                // File doesn't exist - this is actually OK for first launch
                logger.info("Store file doesn't exist yet, will be created on first save")
                isStoreLoaded = true
                
            default:
                // Check for SQLite-specific errors
                if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                    handleSQLiteError(underlyingError, container: container)
                } else {
                    // Unknown error - try to delete and recreate
                    logger.warning("Unknown Core Data error (code: \(error.code)), attempting to rebuild...")
                    deleteAndRecreateStore(container: container)
                }
            }
        } else {
            // Non-Cocoa error, likely SQLite
            handleSQLiteError(error, container: container)
        }
    }
    
    private func handleSQLiteError(_ error: NSError, container: NSPersistentContainer) {
        // SQLite error codes
        switch error.code {
        case 11: // SQLITE_CORRUPT
            logger.warning("SQLite corruption detected, rebuilding store...")
            deleteAndRecreateStore(container: container)
            
        case 26: // SQLITE_NOTADB
            logger.warning("File is not a database, rebuilding...")
            deleteAndRecreateStore(container: container)
            
        default:
            logger.warning("SQLite error \(error.code), falling back to in-memory store")
            fallbackToInMemoryStore(container: container)
        }
    }
    
    private func attemptStoreRecovery(container: NSPersistentContainer) {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            fallbackToInMemoryStore(container: container)
            return
        }
        
        // Backup existing store
        backupStore(at: storeURL)
        
        // Try to migrate with a mapping model
        do {
            let psc = container.persistentStoreCoordinator
            
            // Remove all existing stores
            for store in psc.persistentStores {
                try psc.remove(store)
            }
            
            // Try to add store again with migration options
            let options = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
                NSSQLitePragmasOption: ["journal_mode": "DELETE"] // More resilient mode
            ] as [String : Any]
            
            try psc.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: options
            )
            
            isStoreLoaded = true
            logger.info("Store recovery successful")
            
        } catch {
            logger.error("Store recovery failed: \(error)")
            deleteAndRecreateStore(container: container)
        }
    }
    
    private func deleteAndRecreateStore(container: NSPersistentContainer) {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            fallbackToInMemoryStore(container: container)
            return
        }
        
        // Backup before deletion
        backupStore(at: storeURL)
        
        // Delete the store file
        do {
            let fileManager = FileManager.default
            
            // Remove SQLite files
            let storePath = storeURL.path
            let walPath = "\(storePath)-wal"
            let shmPath = "\(storePath)-shm"
            
            for path in [storePath, walPath, shmPath] {
                if fileManager.fileExists(atPath: path) {
                    try fileManager.removeItem(atPath: path)
                }
            }
            
            // Recreate persistent store
            let psc = container.persistentStoreCoordinator
            
            // Remove all stores first
            for store in psc.persistentStores {
                try psc.remove(store)
            }
            
            // Add new store
            try psc.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: nil
            )
            
            isStoreLoaded = true
            logger.info("Store successfully recreated")
            
        } catch {
            logger.error("Failed to delete and recreate store: \(error)")
            fallbackToInMemoryStore(container: container)
        }
    }
    
    private func fallbackToInMemoryStore(container: NSPersistentContainer) {
        do {
            let psc = container.persistentStoreCoordinator
            
            // Remove all existing stores
            for store in psc.persistentStores {
                try psc.remove(store)
            }
            
            // Add in-memory store
            try psc.addPersistentStore(
                ofType: NSInMemoryStoreType,
                configurationName: nil,
                at: nil,
                options: nil
            )
            
            isStoreLoaded = true
            isUsingInMemoryStore = true
            
            logger.warning("Using in-memory store - data will not persist between app launches")
            
            // Notify user if needed
            NotificationCenter.default.post(
                name: .coreDataDidFallbackToInMemory,
                object: nil
            )
            
        } catch {
            logger.critical("Failed to create in-memory store: \(error)")
            // At this point, the app cannot function properly
            // You might want to show an alert to the user
            NotificationCenter.default.post(
                name: .coreDataDidFailCompletely,
                object: error
            )
        }
    }
    
    private func backupStore(at url: URL) {
        let fileManager = FileManager.default
        let backupURL = url.appendingPathExtension("backup")
        
        do {
            // Remove old backup if exists
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            
            // Create backup
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.copyItem(at: url, to: backupURL)
                logger.info("Store backed up to: \(backupURL.lastPathComponent)")
            }
        } catch {
            logger.error("Failed to backup store: \(error)")
        }
    }
    
    // MARK: - Core Data Saving
    
    /// Save context with proper error handling
    func save() {
        guard isStoreLoaded else {
            logger.warning("Attempted to save but store is not loaded")
            return
        }
        
        let context = persistentContainer.viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            logger.debug("Context saved successfully")
        } catch {
            logger.error("Failed to save context: \(error)")
            
            // Handle specific save errors
            handleSaveError(error)
        }
    }
    
    private func handleSaveError(_ error: Error) {
        let nsError = error as NSError
        
        // Check for specific Core Data errors
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case 1560: // NSValidationMultipleErrorsError
                logger.error("Multiple validation errors occurred")
                if let errors = nsError.userInfo[NSDetailedErrorsKey] as? [NSError] {
                    for detailedError in errors {
                        logger.error("Validation error: \(detailedError)")
                    }
                }
                
            case 1570: // NSValidationMissingMandatoryPropertyError
                let propertyName = nsError.userInfo["NSValidationKeyErrorKey"] as? String ?? "unknown"
                logger.error("Missing required property: \(propertyName)")
                
            case 1550: // NSManagedObjectConstraintValidationError
                logger.error("Constraint violation: \(nsError.userInfo)")
                
            default:
                logger.error("Save error code: \(nsError.code)")
            }
        }
        
        // Attempt to rollback
        persistentContainer.viewContext.rollback()
        logger.info("Context rolled back after save error")
    }
    
    // MARK: - Batch Operations
    
    /// Perform batch operation with error handling
    func performBatchOperation<T>(_ operation: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        guard isStoreLoaded else {
            throw CoreDataError.storeNotLoaded
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let context = newBackgroundContext()
            context.perform {
                do {
                    let result = try operation(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Fetch Helpers
    
    func fetch<T: NSManagedObject>(_ type: T.Type,
                                   predicate: NSPredicate? = nil,
                                   sortDescriptors: [NSSortDescriptor]? = nil,
                                   fetchLimit: Int? = nil) -> [T] {
        guard isStoreLoaded else {
            logger.warning("Attempted to fetch but store is not loaded")
            return []
        }
        
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        if let limit = fetchLimit {
            request.fetchLimit = limit
        }
        
        do {
            return try persistentContainer.viewContext.fetch(request)
        } catch {
            logger.error("Fetch error for \(type): \(error)")
            return []
        }
    }
    
    // MARK: - Delete Helpers
    
    func delete(_ object: NSManagedObject) {
        guard isStoreLoaded else { return }
        
        persistentContainer.viewContext.delete(object)
        save()
    }
    
    func deleteAll<T: NSManagedObject>(_ type: T.Type) async throws {
        guard isStoreLoaded else {
            throw CoreDataError.storeNotLoaded
        }
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: type))
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        try await performBatchOperation { context in
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            
            // Merge changes to view context
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: changes,
                    into: [self.persistentContainer.viewContext]
                )
            }
        }
    }
    
    // MARK: - Context Management
    
    var mainContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Health Check
    
    /// Check if Core Data is functioning properly
    var isHealthy: Bool {
        return isStoreLoaded && !isUsingInMemoryStore && storeError == nil
    }
    
    /// Get a user-friendly status message
    var statusMessage: String {
        if !isStoreLoaded {
            return "Database is loading..."
        } else if isUsingInMemoryStore {
            return "Using temporary storage (data won't be saved)"
        } else if storeError != nil {
            return "Database error occurred (some features may be limited)"
        } else {
            return "Database is functioning normally"
        }
    }
}

// MARK: - Custom Errors

enum CoreDataError: LocalizedError {
    case storeNotLoaded
    case migrationFailed
    case dataCorruption
    
    var errorDescription: String? {
        switch self {
        case .storeNotLoaded:
            return "The data store is not available"
        case .migrationFailed:
            return "Failed to migrate data to new format"
        case .dataCorruption:
            return "Data corruption detected"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let coreDataDidFallbackToInMemory = Notification.Name("coreDataDidFallbackToInMemory")
    static let coreDataDidFailCompletely = Notification.Name("coreDataDidFailCompletely")
    static let coreDataDidRecover = Notification.Name("coreDataDidRecover")
}
