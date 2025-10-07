import Foundation
import Combine
import SwiftUI
import CoreData

/// AppState serves as a lightweight coordinator for the app's global state
/// SIMPLIFIED VERSION - No network/auth dependencies
class AppState: ObservableObject {
    // Access to singleton state objects
    @Published var gameState: GameState
    @Published var userManager: SimpleUserManager
    @Published var settingsState: SettingsState
    
    // For cancelling subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Core Data access
    private let coreData = CoreDataStack.shared
    
    // Singleton instance
    static let shared = AppState()
    
    private init() {
        // Access the singletons for each state
        self.gameState = GameState.shared
        self.userManager = SimpleUserManager.shared
        self.settingsState = SettingsState.shared
        
        // Setup cross-state coordination
        setupStateCoordination()
    }
    
    // Setup publisher/subscriber relationships between states
    private func setupStateCoordination() {
        // Listen for user sign-in state changes
        userManager.$isSignedIn
            .sink { [weak self] isSignedIn in
                guard let self = self else { return }
                
                if isSignedIn {
                    // Load user preferences into settings when signed in
                    self.syncUserPreferences()
                }
            }
            .store(in: &cancellables)
        
        // Apply settings changes to game state
        settingsState.$gameDifficulty
            .sink { [weak self] difficulty in
                self?.gameState.defaultDifficulty = difficulty
            }
            .store(in: &cancellables)
    }
    
    // Sync user preferences to settings state (LOCAL ONLY)
    private func syncUserPreferences() {
        guard !userManager.playerName.isEmpty else {
            return
        }
        
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        fetchRequest.predicate = NSPredicate(format: "username == %@", userManager.playerName)
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first, let prefs = user.preferences else {
                return
            }
            
            // Update settings state from user preferences
            settingsState.updateSettings(
                darkMode: prefs.darkMode,
                showHelpers: prefs.showTextHelpers,
                accessibilityText: prefs.accessibilityTextSize,
                gameDifficulty: prefs.gameDifficulty ?? "medium",
                soundEnabled: prefs.soundEnabled,
                soundVolume: prefs.soundVolume,
                useBiometricAuth: prefs.useBiometricAuth
            )
        } catch {
            print("Error syncing user preferences: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Convenience Methods (SIMPLIFIED)
    
    /// Start a new game with current settings
    func startNewGame() {
        gameState.setupCustomGame()
    }
    
    /// Start the daily challenge
    func startDailyChallenge() {
        gameState.setupDailyChallenge()
    }
    
    /// Setup local player (replaces login)
    func setupPlayer(name: String) {
        userManager.setupLocalPlayer(name: name)
    }
    
    /// Sign out local player (replaces logout)
    func signOut() {
        userManager.signOut()
    }
    
    /// Save user preferences (LOCAL ONLY)
    func saveUserPreferences() {
        guard userManager.isSignedIn, !userManager.playerName.isEmpty else {
            return
        }
        
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        fetchRequest.predicate = NSPredicate(format: "username == %@", userManager.playerName)
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first else { return }
            
            // Create preferences if needed
            if user.preferences == nil {
                let preferences = UserPreferencesCD(context: context)
                user.preferences = preferences
                preferences.user = user
            }
            
            guard let prefs = user.preferences else { return }
            
            // Update from settings state
            prefs.darkMode = settingsState.isDarkMode
            prefs.showTextHelpers = settingsState.showTextHelpers
            prefs.accessibilityTextSize = settingsState.useAccessibilityTextSize
            prefs.gameDifficulty = settingsState.gameDifficulty
            prefs.soundEnabled = settingsState.soundEnabled
            prefs.soundVolume = settingsState.soundVolume
            prefs.useBiometricAuth = settingsState.useBiometricAuth
            prefs.lastSyncDate = Date()
            
            try context.save()
            print("✅ User preferences saved locally")
            
        } catch {
            print("Error saving user preferences: \(error.localizedDescription)")
        }
    }
}
