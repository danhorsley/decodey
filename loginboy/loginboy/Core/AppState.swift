import Foundation
import Combine
import SwiftUI
import CoreData

/// AppState serves as a lightweight coordinator for the app's global state
class AppState: ObservableObject {
    // Access to singleton state objects
    @Published var gameState: GameState
    @Published var userState: UserState
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
        self.userState = UserState.shared
        self.settingsState = SettingsState.shared
        
        // Setup cross-state coordination
        setupStateCoordination()
    }
    
    // Setup publisher/subscriber relationships between states
    private func setupStateCoordination() {
        // Listen for auth state changes
        userState.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                
                if isAuthenticated {
                    // Load user preferences into settings
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
    
    // Sync user preferences to settings state
    private func syncUserPreferences() {
        guard let userId = userState.userId.isEmpty ? nil : userState.userId else {
            return
        }
        
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first, let prefs = user.preferences else {
                return
            }
            
            // Update settings state from user preferences
            settingsState.updateSettings(
                darkMode: prefs.darkMode,
                showHelpers: prefs.showTextHelpers as? Bool,
                accessibilityText: prefs.accessibilityTextSize,
                gameDifficulty: prefs.gameDifficulty,
                soundEnabled: prefs.soundEnabled,
                soundVolume: prefs.soundVolume,
                useBiometricAuth: prefs.useBiometricAuth
            )
        } catch {
            print("Error syncing user preferences: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Convenience Methods
    
    /// Start a new game with current settings
    func startNewGame() {
        gameState.setupCustomGame()
    }
    
    /// Start the daily challenge
    func startDailyChallenge() {
        gameState.setupDailyChallenge()
    }
    
    /// Login the user
    func login(username: String, password: String, rememberMe: Bool) async throws {
        try await userState.login(username: username, password: password, rememberMe: rememberMe)
    }
    
    /// Logout the user
    func logout() {
        userState.logout()
    }
    
    /// Save user preferences
    func saveUserPreferences() {
        guard userState.isAuthenticated, !userState.userId.isEmpty else {
            return
        }
        
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userState.userId)
        
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
            
            // Sync to server if available
            if let settings = userState.authCoordinator as? SettingsSync {
                settings.syncSettingsToServer(preferences: UserPreferencesModel(
                    darkMode: settingsState.isDarkMode,
                    showTextHelpers: settingsState.showTextHelpers,
                    accessibilityTextSize: settingsState.useAccessibilityTextSize,
                    gameDifficulty: settingsState.gameDifficulty,
                    soundEnabled: settingsState.soundEnabled,
                    soundVolume: settingsState.soundVolume,
                    useBiometricAuth: settingsState.useBiometricAuth,
                    notificationsEnabled: prefs.notificationsEnabled,
                    lastSyncDate: Date()
                ))
            }
        } catch {
            print("Error saving user preferences: \(error.localizedDescription)")
        }
    }
}
