import CoreData
import Foundation

class CoreDataStack {
    // MARK: - Singleton
    static let shared = CoreDataStack()
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DecodeyApp")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Log the error but don't crash in production
                print("❌ Core Data error: \(error), \(error.userInfo)")
                #if DEBUG
                fatalError("Unresolved error: \(error), \(error.userInfo)")
                #else
                print("Critical database error. Some features may not work correctly.")
                #endif
            } else {
                print("✅ CoreData successfully initialized!")
                print("📊 SQLite database location: \(String(describing: storeDescription.url?.path))")
            }
        }
        
        // Configure automatic merges from parent context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    // MARK: - Main Context
    
    var mainContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Background Context Methods
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
    
    // MARK: - Saving Context
    
    func saveContext() {
        saveContext(mainContext)
    }
    
    func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
                print("✓ Context saved successfully")
            } catch {
                let nsError = error as NSError
                print("❌ Error saving context: \(nsError), \(nsError.userInfo)")
                #if DEBUG
                // In debug, we want to know immediately if there's an issue
                fatalError("Unresolved error: \(nsError), \(nsError.userInfo)")
                #endif
            }
        }
    }
    
    // MARK: - Database Info
    
    func printDatabaseInfo() {
        let context = mainContext
        
        print("📊 Database Information:")
        
        do {
            // Get entity counts - updated with CD suffix
            let quoteCount = try context.count(for: NSFetchRequest<QuoteCD>(entityName: "QuoteCD"))
            let activeQuotes = try context.count(for: configureFetchRequest(NSFetchRequest<QuoteCD>(entityName: "QuoteCD")) { request in
                request.predicate = NSPredicate(format: "isActive == YES")
            })
            let gameCount = try context.count(for: NSFetchRequest<GameCD>(entityName: "GameCD"))
            let userCount = try context.count(for: NSFetchRequest<UserCD>(entityName: "UserCD"))
            
            print("📚 Total Quotes: \(quoteCount) (Active: \(activeQuotes))")
            print("🎮 Total Games: \(gameCount)")
            print("👤 Total Users: \(userCount)")
            
            // Get file size
            if let storeURL = persistentContainer.persistentStoreCoordinator.persistentStores.first?.url {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
                    let fileSize = attributes[FileAttributeKey.size] as? UInt64 ?? 0
                    print("💾 Database Size: \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))")
                } catch {
                    print("⚠️ Could not get file size: \(error.localizedDescription)")
                }
            }
        } catch {
            print("❌ Error getting database info: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Set up automatic merge notification
        setupNotifications()
    }
    
    private func setupNotifications() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(managedObjectContextDidSave),
                                       name: .NSManagedObjectContextDidSave,
                                       object: nil)
    }
    
    @objc private func managedObjectContextDidSave(_ notification: Notification) {
        // Only merge if the saved context is not the main context
        let savedContext = notification.object as! NSManagedObjectContext
        if savedContext !== mainContext && savedContext.parent !== mainContext {
            mainContext.perform {
                self.mainContext.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
    
    // MARK: - Initial Data Creation
    
    func createInitialData() {
        let context = newBackgroundContext()
        
        context.perform {
            // Check if there are any quotes
            let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
            fetchRequest.fetchLimit = 1
            
            do {
                let quotes = try context.fetch(fetchRequest)
                if quotes.isEmpty {
                    print("Adding initial quotes to Core Data database...")
                    
                    // Default quotes
                    let defaultQuotes = [
                        (text: "THE EARLY BIRD CATCHES THE WORM.", author: "John Ray", difficulty: 1.0),
                        (text: "KNOWLEDGE IS POWER.", author: "Francis Bacon", difficulty: 0.8),
                        (text: "TIME WAITS FOR NO ONE.", author: "Geoffrey Chaucer", difficulty: 1.0),
                        (text: "BE YOURSELF; EVERYONE ELSE IS ALREADY TAKEN.", author: "Oscar Wilde", difficulty: 1.5),
                        (text: "THE JOURNEY OF A THOUSAND MILES BEGINS WITH A SINGLE STEP.", author: "Lao Tzu", difficulty: 2.0)
                    ]
                    
                    for quoteData in defaultQuotes {
                        let quote = QuoteCD(context: context)
                        quote.id = UUID()
                        quote.text = quoteData.text
                        quote.author = quoteData.author
                        quote.difficulty = quoteData.difficulty
                        quote.uniqueLetters = Int16(Set(quoteData.text.filter { $0.isLetter }).count)
                        quote.isActive = true
                        quote.timesUsed = 0
                    }
                    
                    // Save the context
                    try context.save()
                    print("Added \(defaultQuotes.count) initial quotes")
                }
            } catch {
                print("Error adding initial quotes: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Extensions

func configureFetchRequest<T: NSFetchRequestResult>(_ request: NSFetchRequest<T>,
                                                  configuration: (NSFetchRequest<T>) -> Void) -> NSFetchRequest<T> {
    configuration(request)
    return request
}
