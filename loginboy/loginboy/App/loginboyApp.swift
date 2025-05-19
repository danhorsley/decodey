import SwiftUI
import CoreData

@main
struct DecodeyApp: App {
    // Initialize Core Data stack and sound manager
    private let coreData = CoreDataStack.shared
    private let soundManager = SoundManager.shared
    
    init() {
        // Print database path during initialization
        printDatabasePath()
        
        // Perform one-time setup tasks
        performFirstLaunchSetup()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(UserState.shared)
                .environmentObject(GameState.shared)
                .environmentObject(SettingsState.shared)
                .onAppear {
                    print("App Started")
                    
                    // Print database info when UI appears
                    CoreDataStack.shared.printDatabaseInfo()
                }
                .environment(\.managedObjectContext, coreData.mainContext)
        }
    }
    
    // Helper function to print database path
    private func printDatabasePath() {
        // Print the Database path with formatting for console visibility
        print("==================================")
        print("📂 CORE DATA DATABASE PATH:")
        
        // Get persistent store URL
        if let storeURL = CoreDataStack.shared.persistentContainer.persistentStoreCoordinator.persistentStores.first?.url {
            print(storeURL.path)
        } else {
            print("No persistent store found")
        }
        
        print("==================================")
        
        // Also print the Documents directory for reference
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            print("📁 Documents Directory:")
            print(documentsPath)
            print("==================================")
        }
    }
    
    // Perform first launch setup tasks
    private func performFirstLaunchSetup() {
        // Check if this is the first launch of this version
        let defaults = UserDefaults.standard
        let lastVersionKey = "lastInstalledVersion"
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        
        // Get the last installed version if any
        let lastVersion = defaults.string(forKey: lastVersionKey)
        
        // If this is first launch or a new version
        if lastVersion == nil || lastVersion != currentVersion {
            print("First launch of version \(currentVersion)")
            
            // Create initial data in Core Data
            CoreDataStack.shared.createInitialData()
            
            // Save the current version
            defaults.set(currentVersion, forKey: lastVersionKey)
        }
    }
}
