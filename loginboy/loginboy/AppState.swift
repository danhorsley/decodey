import Foundation
import Combine
import SwiftUI

/// AppState serves as the central state management container for the entire application.
/// It coordinates all substates and ensures consistent data flow throughout the app.
class AppState: ObservableObject {
    // Published substates that will trigger UI updates when changed
    @Published var gameState: GameState
    @Published var userState: UserState
    @Published var settingsState: SettingsState
    
    // Private state for internal coordination
    private var cancellables = Set<AnyCancellable>()
    
    // Services and dependencies
    private let databaseManager: DatabaseManager
    
    // Singleton instance for easy access
    static let shared = AppState()
    
    // Private initializer for singleton
    private init() {
        // Initialize services
        self.databaseManager = DatabaseManager.shared
        
        // Access the singletons for each state instead of creating new instances
        // This fixes the issue with private initializers
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
                    // User logged in, load their saved data
                    self.loadUserData()
                } else {
                    // User logged out, reset states
                    self.resetStates()
                }
            }
            .store(in: &cancellables)
        
        // Listen for game completion to update stats
        gameState.$currentGame
            .compactMap { $0 }
            .filter { $0.hasWon || $0.hasLost }
            .sink { [weak self] game in
                guard let self = self, self.userState.isAuthenticated else { return }
                
                // Update user stats
                if game.hasWon {
                    self.userState.updateStats(
                        gameWon: true,
                        score: game.calculateScore(),
                        timeTaken: Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
                    )
                } else if game.hasLost {
                    self.userState.updateStats(
                        gameWon: false,
                        score: 0,
                        timeTaken: Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
                    )
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
    
    // Load user-specific data when authenticated
    private func loadUserData() {
        Task {
            do {
                // Check for saved games
                if let savedGame = try databaseManager.loadLatestGame() {
                    await MainActor.run {
                        self.gameState.savedGame = savedGame
                    }
                }
                
                // Load user stats if authenticated
                // Since userId is a non-optional String, just check if it's not empty
                if !userState.userId.isEmpty {
                    try databaseManager.checkAndSyncQuotesIfNeeded(auth: userState.authCoordinator)
                    
                    // Load other user data as needed
                    print("Loaded user data for: \(userState.userId)")
                }
            } catch {
                print("Error loading user data: \(error.localizedDescription)")
            }
        }
    }
    
    // Reset states when user logs out
    private func resetStates() {
        gameState.reset()
        // Keep settings as they are for better UX
    }
    
    // MARK: - Public Actions
    
    /// Start a new custom game
    func startNewCustomGame() {
        gameState.setupCustomGame()
    }
    
    /// Start or resume the daily challenge
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
    
    /// Update user settings
    func updateSettings(darkMode: Bool? = nil, showHelpers: Bool? = nil,
                        accessibilityText: Bool? = nil, gameDifficulty: String? = nil) {
        settingsState.updateSettings(
            darkMode: darkMode,
            showHelpers: showHelpers,
            accessibilityText: accessibilityText,
            gameDifficulty: gameDifficulty
        )
    }
}
