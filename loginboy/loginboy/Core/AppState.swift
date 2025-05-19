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
    private let coreDataStack = CoreDataStack.shared
    
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
        guard let userId = userState.userId, !userId.isEmpty else {
            return
        }
        
        let context = coreDataStack.mainContext
        
        // Find user with preferences
        let fetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        fetchRequest.relationshipKeyPathsForPrefetching = ["preferences"]
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first, let prefs = user.preferences else {
                return
            }
            
            // Update settings state from user preferences
            settingsState.updateSettings(
                darkMode: prefs.darkMode,
                showHelpers: prefs.showTextHelpers as? Bool ?? true,
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
        guard userState.isAuthenticated, let userId = userState.userId, !userId.isEmpty else {
            return
        }
        
        let context = coreDataStack.mainContext
        
        // Find user
        let fetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            
            guard let user = users.first else { return }
            
            // Create preferences if needed
            let preferences: UserPreferencesCD
            if let existingPrefs = user.preferences {
                preferences = existingPrefs
            } else {
                preferences = UserPreferencesCD(context: context)
                user.preferences = preferences
                preferences.user = user
            }
            
            // Update from settings state
            preferences.darkMode = settingsState.isDarkMode
            preferences.showTextHelpers = settingsState.showTextHelpers as NSObject
            preferences.accessibilityTextSize = settingsState.useAccessibilityTextSize
            preferences.gameDifficulty = settingsState.gameDifficulty
            preferences.soundEnabled = settingsState.soundEnabled
            preferences.soundVolume = settingsState.soundVolume
            preferences.useBiometricAuth = settingsState.useBiometricAuth
            preferences.lastSyncDate = Date()
            
            // Save to Core Data
            try context.save()
        } catch {
            print("Error saving user preferences: \(error.localizedDescription)")
        }
    }
    
    /// Create a new user with default settings
    func createNewUser(userId: String, username: String) {
        let context = coreDataStack.mainContext
        
        // Check if user already exists
        let fetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            
            if users.isEmpty {
                // Create new user
                let user = UserCD(context: context)
                user.id = UUID()
                user.userId = userId
                user.username = username
                user.email = "\(username)@example.com" // Placeholder
                user.registrationDate = Date()
                user.lastLoginDate = Date()
                user.isActive = true
                
                // Create default preferences
                let preferences = UserPreferencesCD(context: context)
                preferences.darkMode = true
                preferences.showTextHelpers = true as NSObject
                preferences.accessibilityTextSize = false
                preferences.gameDifficulty = "medium"
                preferences.soundEnabled = true
                preferences.soundVolume = 0.5
                preferences.useBiometricAuth = false
                preferences.notificationsEnabled = true
                
                // Link preferences to user
                user.preferences = preferences
                preferences.user = user
                
                // Create initial stats
                let stats = UserStatsCD(context: context)
                stats.gamesPlayed = 0
                stats.gamesWon = 0
                stats.currentStreak = 0
                stats.bestStreak = 0
                stats.totalScore = 0
                stats.averageMistakes = 0.0
                stats.averageTime = 0.0
                
                // Link stats to user
                user.stats = stats
                stats.user = user
                
                // Save to Core Data
                try context.save()
                
                print("Created new user: \(username) with default settings")
            }
        } catch {
            print("Error creating new user: \(error.localizedDescription)")
        }
    }
    
    /// Get user stats
    func getUserStats(userId: String) -> UserStatsData? {
        let context = coreDataStack.mainContext
        
        // Find user with stats
        let fetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        fetchRequest.relationshipKeyPathsForPrefetching = ["stats"]
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first, let stats = user.stats else {
                return nil
            }
            
            return UserStatsData(
                userId: user.userId ?? "",
                gamesPlayed: Int(stats.gamesPlayed),
                gamesWon: Int(stats.gamesWon),
                currentStreak: Int(stats.currentStreak),
                bestStreak: Int(stats.bestStreak),
                totalScore: Int(stats.totalScore),
                averageScore: stats.gamesPlayed > 0 ? Double(stats.totalScore) / Double(stats.gamesPlayed) : 0,
                averageTime: stats.averageTime,
                lastPlayedDate: stats.lastPlayedDate
            )
        } catch {
            print("Error fetching user stats: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get leaderboard data
    func getLeaderboard(limit: Int = 10) -> [LeaderboardEntryData] {
        let context = coreDataStack.mainContext
        
        // Get all users with stats
        let fetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        fetchRequest.predicate = NSPredicate(format: "stats != nil")
        fetchRequest.relationshipKeyPathsForPrefetching = ["stats"]
        
        do {
            let users = try context.fetch(fetchRequest)
            
            // Sort by total score
            let sortedUsers = users.sorted {
                ($0.stats?.totalScore ?? 0) > ($1.stats?.totalScore ?? 0)
            }
            
            // Create leaderboard entries
            var entries: [LeaderboardEntryData] = []
            
            for (index, user) in sortedUsers.prefix(limit).enumerated() {
                guard let stats = user.stats else { continue }
                
                let entry = LeaderboardEntryData(
                    rank: index + 1,
                    username: user.username ?? "Unknown",
                    userId: user.userId ?? "",
                    score: Int(stats.totalScore),
                    gamesPlayed: Int(stats.gamesPlayed),
                    avgScore: stats.gamesPlayed > 0 ? Double(stats.totalScore) / Double(stats.gamesPlayed) : 0,
                    isCurrentUser: user.userId == userState.userId
                )
                
                entries.append(entry)
            }
            
            return entries
        } catch {
            print("Error fetching leaderboard: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Clear all app data (for testing or account deletion)
    func clearAllData() {
        let context = coreDataStack.mainContext
        
        // Delete all entities
        let entityNames = ["GameCD", "QuoteCD", "UserCD", "UserPreferencesCD", "UserStatsCD"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                try context.save()
            } catch {
                print("Error clearing \(entityName) data: \(error.localizedDescription)")
            }
        }
        
        // Reset application state
        userState.reset()
        gameState.reset()
        settingsState.resetToDefaults()
        
        print("All application data has been cleared")
    }
}
