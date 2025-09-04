//
//  loginboyApp.swift - Nuclear Cleanup: Local-Only App
//  loginboy
//

import SwiftUI
import CoreData

@main
struct LoginboyApp: App {
    // Core managers (local-only)
    @StateObject private var userManager = SimpleUserManager.shared
    @StateObject private var localQuotes = LocalQuoteManager.shared
    @StateObject private var gameState = GameState.shared
    @StateObject private var navigation = NavigationCoordinator(userManager: SimpleUserManager.shared)
    @StateObject private var settings = UserSettings.shared
    @StateObject private var settingsState = SettingsState.shared
    
    // Core Data
    let coreDataStack = CoreDataStack.shared
    
    // Loading state
    @State private var isInitializing = true
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isInitializing {
                    LoadingView()
                        .onAppear {
                            performInitialSetup()
                        }
                } else {
                    ContentView()
                        .environmentObject(userManager)
                        .environmentObject(localQuotes)
                        .environmentObject(gameState)
                        .environmentObject(navigation)
                        .environmentObject(settings)
                        .environmentObject(settingsState)
                        .environment(\.managedObjectContext, coreDataStack.mainContext)
                }
            }
            .sheet(item: $navigation.activeSheet) { sheet in
                navigation.sheetContent(for: sheet)
                    .environmentObject(userManager)
                    .environmentObject(localQuotes)
                    .environmentObject(gameState)
                    .environmentObject(navigation)
                    .environmentObject(settings)
                    .environmentObject(settingsState)
            }
        }
    }
    
    // MARK: - Initial Setup
    
    private func performInitialSetup() {
        Task {
            // Setup Core Data first
            setupCoreData()
            
            // Wait for quotes to load
            await waitForQuotesToLoad()
            
            // Small delay for smooth transition
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                isInitializing = false
                print("✅ App initialization complete")
            }
        }
    }
    
    private func setupCoreData() {
        // Check if this is first launch
        let defaults = UserDefaults.standard
        let lastVersionKey = "lastLaunchedVersion"
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        
        let lastVersion = defaults.string(forKey: lastVersionKey)
        
        if lastVersion == nil || lastVersion != currentVersion {
            print("🆕 First launch of version \(currentVersion)")
            coreDataStack.createInitialData()
            defaults.set(currentVersion, forKey: lastVersionKey)
        }
    }
    
    private func waitForQuotesToLoad() async {
        // Wait for LocalQuoteManager to finish loading
        while !localQuotes.isLoaded {
            if let error = localQuotes.loadingError {
                print("❌ Quote loading error: \(error)")
                // Continue anyway with fallback quotes from Core Data
                break
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Verify we have quotes available
        let quoteCount = localQuotes.getQuoteCount()
        print("📚 Available quotes: \(quoteCount)")
        
        if quoteCount == 0 {
            print("⚠️ No quotes loaded - using Core Data fallback")
            coreDataStack.createInitialData()
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    @State private var progress = 0.0
    @State private var statusText = "Loading quotes..."
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App icon or logo
            VStack(spacing: 16) {
                Text("🔤")
                    .font(.system(size: 80))
                
                Text("Cryptogram")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            // Loading indicator
            VStack(spacing: 16) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            startLoadingAnimation()
        }
    }
    
    private func startLoadingAnimation() {
        // Animate progress bar
        withAnimation(.easeInOut(duration: 2.0)) {
            progress = 0.8
        }
        
        // Update status text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            statusText = "Preparing game..."
            
            withAnimation(.easeInOut(duration: 1.0)) {
                progress = 1.0
            }
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var navigation: NavigationCoordinator
    
    var body: some View {
        navigation.rootView()
    }
}

// MARK: - App Lifecycle Extensions

extension LoginboyApp {
    
    /// Handle app going to background
    private func handleAppBackground() {
        // Save any current game state
        gameState.saveGameState()
        
        // Save Core Data changes
        do {
            try coreDataStack.mainContext.save()
        } catch {
            print("Error saving context on background: \(error)")
        }
    }
    
    /// Handle app coming to foreground
    private func handleAppForeground() {
        // Refresh user stats
        userManager.refreshStats()
        
        // Check for any saved games
        gameState.checkForInProgressGame()
    }
    
    /// Get local quote count for verification
    private func getLocalQuoteCount() -> Int {
        let context = coreDataStack.mainContext
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            return try context.count(for: fetchRequest)
        } catch {
            print("Error counting quotes: \(error)")
            return 0
        }
    }
    
    /// Verify quotes are actually loaded
    private func verifyQuotesLoaded() {
        let count = getLocalQuoteCount()
        if count > 0 {
            print("✅ Verified \(count) active quotes in database")
        } else {
            print("❌ WARNING: Still no quotes after initialization!")
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension LoginboyApp {
    
    /// Reset all app data (development only)
    private func resetAllAppData() {
        // Clear UserDefaults
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        
        // Clear Core Data - delete all entities manually
        let context = coreDataStack.mainContext
        let entityNames = ["QuoteCD", "GameCD", "UserCD", "UserStatsCD", "UserPreferencesCD"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                print("Error deleting \(entityName): \(error)")
            }
        }
        
        // Save context
        do {
            try context.save()
        } catch {
            print("Error saving after data deletion: \(error)")
        }
        
        // Reset quote loading flag
        localQuotes.resetQuoteData()
        
        print("🧹 All app data reset")
    }
    
    /// Print debug information
    private func printDebugInfo() {
        print("=== Debug Info ===")
        print("User signed in: \(userManager.isSignedIn)")
        print("Player name: \(userManager.playerName)")
        print("Quotes loaded: \(localQuotes.isLoaded)")
        print("Quote count: \(localQuotes.getQuoteCount())")
        print("Current route: \(navigation.currentRoute)")
        print("==================")
    }
}
#endif
