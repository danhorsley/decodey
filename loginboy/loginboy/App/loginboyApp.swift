import SwiftUI
import CoreData

@main
struct DecodeyApp: App {
    // Initialize Core Data stack and sound manager
    private let coreData = CoreDataStack.shared
    private let soundManager = SoundManager.shared
    private let quoteStore = QuoteStore.shared
    private let backgroundSync = BackgroundSyncManager.shared
    
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
        
        // Setup background sync monitoring
        backgroundSync.startBackgroundSync()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(UserState.shared)
                .environmentObject(GameState.shared)
                .environmentObject(SettingsState.shared)
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
        
        // Sync quotes from server on app launch (quotes are lighter, sync first)
        syncQuotesIfNeeded()
        
        // Smart game reconciliation after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.performSmartGameSync()
        }
    }
    
    private func performSmartGameSync() {
        // Only sync if user is authenticated
        guard UserState.shared.isAuthenticated else {
            print("⏭️ Skipping game sync - user not authenticated")
            return
        }
        
        GameReconciliationManager.shared.smartReconcileGames(trigger: .appLaunch) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Smart game sync completed on launch")
                    
                    // IMPORTANT: Recalculate user stats after sync
                    UserState.shared.recalculateStatsFromGames()
                } else {
                    print("❌ Game sync failed on launch: \(error ?? "Unknown error")")
                }
            }
        }
    }
    
    // ... rest of your existing methods remain the same
    
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
    
    private func syncQuotesIfNeeded() {
        guard !quoteSyncInProgress else { return }
        
        let defaults = UserDefaults.standard
        let lastSyncKey = "lastQuoteSyncDate"
        
        let shouldSync: Bool
        
        if let lastSyncDate = defaults.object(forKey: lastSyncKey) as? Date {
            let daysSinceLastSync = Calendar.current.dateComponents([.day], from: lastSyncDate, to: Date()).day ?? 0
            shouldSync = daysSinceLastSync >= 1
        } else {
            shouldSync = true
        }
        
        if shouldSync {
            quoteSyncInProgress = true
            print("🔄 Syncing quotes from server...")
            
            if let token = UserState.shared.authCoordinator.getAccessToken() {
                quoteStore.syncQuotesFromServer(auth: UserState.shared.authCoordinator) { success in
                    DispatchQueue.main.async {
                        self.quoteSyncInProgress = false
                        
                        if success {
                            print("✅ Quote sync completed successfully")
                            defaults.set(Date(), forKey: lastSyncKey)
                        } else {
                            print("❌ Quote sync failed")
                        }
                    }
                }
            } else {
                print("ℹ️ Skipping quote sync - user not authenticated")
                quoteSyncInProgress = false
            }
        } else {
            print("ℹ️ Skipping quote sync - last sync was recent")
        }
    }
}
