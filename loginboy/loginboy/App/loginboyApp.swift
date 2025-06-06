import SwiftUI
import CoreData

@main
struct DecodeyApp: App {
    // Initialize Core Data stack and sound manager
    private let coreData = CoreDataStack.shared
    private let soundManager = SoundManager.shared
    private let quoteStore = QuoteStore.shared
    
    // Create state objects at the app level
    @StateObject private var userState = UserState.shared
    @StateObject private var gameState = GameState.shared
    @StateObject private var settingsState = SettingsState.shared
    
    // State to track sync status
    @State private var quoteSyncInProgress = false
    @State private var appDidFinishLaunching = false
    
    init() {
        // Print database path during initialization
        printDatabasePath()
        
        // Perform one-time setup tasks
        performFirstLaunchSetup()
        
        // Clean up any duplicate games
        GameState.shared.cleanupDuplicateGames()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(userState)
                .environmentObject(gameState)
                .environmentObject(settingsState)
                .preferredColorScheme(settingsState.isDarkMode ? .dark : .light)
                .onAppear {
                    handleAppLaunch()
                }
                .environment(\.managedObjectContext, coreData.mainContext)
        }
    }
    
    private func handleAppLaunch() {
        guard !appDidFinishLaunching else { return }
        appDidFinishLaunching = true
        
        print("🚀 App Started")
        
        // Print database info when UI appears
        CoreDataStack.shared.printDatabaseInfo()
    }
    
    private func printDatabasePath() {
        print("==================================")
        print("📂 CORE DATA DATABASE PATH:")
        
        if let storeURL = CoreDataStack.shared.persistentContainer.persistentStoreCoordinator.persistentStores.first?.url {
            print(storeURL.path)
        } else {
            print("No persistent store found")
        }
        
        print("==================================")
        
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            print("📁 Documents Directory:")
            print(documentsPath)
            print("==================================")
        }
    }
    
    private func performFirstLaunchSetup() {
        let defaults = UserDefaults.standard
        let lastVersionKey = "lastInstalledVersion"
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        
        let lastVersion = defaults.string(forKey: lastVersionKey)
        
        if lastVersion == nil || lastVersion != currentVersion {
            print("🆕 First launch of version \(currentVersion)")
            CoreDataStack.shared.createInitialData()
            defaults.set(currentVersion, forKey: lastVersionKey)
        }
    }
    
    // In loginboyApp.swift
    private func syncQuotesIfNeeded() {
        guard !quoteSyncInProgress else { return }
        
        quoteSyncInProgress = true
        QuoteStore.shared.syncIfNeeded { success in
            DispatchQueue.main.async {
                self.quoteSyncInProgress = false
                if !success && self.getLocalQuoteCount() == 0 {
                    // Emergency fallback
                    CoreDataStack.shared.createInitialData()
                }
            }
        }
    }

    // Helper to count quotes
    private func getLocalQuoteCount() -> Int {
        let context = CoreDataStack.shared.mainContext
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            return try context.count(for: fetchRequest)
        } catch {
            print("Error counting quotes: \(error)")
            return 0
        }
    }

    // Verify quotes actually loaded
    private func verifyQuotesLoaded() {
        let count = getLocalQuoteCount()
        if count > 0 {
            print("✅ Verified \(count) active quotes in database")
        } else {
            print("❌ WARNING: Still no quotes after sync!")
        }
    }
}
