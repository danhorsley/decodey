// AppState.swift - Streamlined for Realm
import Foundation
import Combine
import SwiftUI
import RealmSwift

/// AppState serves as a lightweight coordinator for the app's global state
class AppState: ObservableObject {
    // Access to singleton state objects
    @Published var gameState: GameState
    @Published var userState: UserState
    @Published var settingsState: SettingsState
    
    // For cancelling subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Realm access if needed directly
    private let realm = RealmManager.shared.getRealm()
    
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
        guard let realm = realm,
              let userId = userState.userId,
              let user = realm.object(ofType: UserRealm.self, forPrimaryKey: userId),
              let prefs = user.preferences else {
            return
        }
        
        // Update settings state from user preferences
        settingsState.updateSettings(
            darkMode: prefs.darkMode,
            showHelpers: prefs.showTextHelpers,
            accessibilityText: prefs.accessibilityTextSize,
            gameDifficulty: prefs.gameDifficulty,
            soundEnabled: prefs.soundEnabled,
            soundVolume: prefs.soundVolume,
            useBiometricAuth: prefs.useBiometricAuth
        )
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
        guard let realm = realm,
              userState.isAuthenticated,
              let userId = userState.userId,
              let user = realm.object(ofType: UserRealm.self, forPrimaryKey: userId) else {
            return
        }
        
        try? realm.write {
            // Create preferences if needed
            if user.preferences == nil {
                user.preferences = UserPreferencesRealm()
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
        }
    }
}
