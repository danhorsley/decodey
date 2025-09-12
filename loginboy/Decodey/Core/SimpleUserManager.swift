import Foundation
import SwiftUI
import Combine
import CoreData

class SimpleUserManager: ObservableObject {
    // Published state for UI
    @Published var isSignedIn = false
    @Published var playerName = ""
    @Published var localStats: LocalUserStats?
    @Published var isLoading = false
    
    // Local storage keys
    private let playerNameKey = "local_player_name"
    private let hasSetupKey = "has_completed_setup"
    
    // Core Data access
    private let coreData = CoreDataStack.shared
    
    // Constants
    private let anonymousIdentifier = "anonymous-user"
    private let anonymousDisplayName = "Anonymous"
    
    // Singleton
    static let shared = SimpleUserManager()
    
    init() {
        loadLocalUser()
    }
    
    // MARK: - Public Methods
    
    /// Set up local player (replaces authentication)
    func setupLocalPlayer(name: String, appleUserId: String? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // Save to UserDefaults
        UserDefaults.standard.set(trimmedName, forKey: playerNameKey)
        UserDefaults.standard.set(true, forKey: hasSetupKey)
        
        // Update state
        playerName = trimmedName
        isSignedIn = true
        
        // Create local user in Core Data with proper identity
        createOrUpdateLocalUser(name: trimmedName, appleUserId: appleUserId)
        
        print("✅ Local player setup: \(trimmedName)")
    }
    
    /// Sign out (clear local data)
    func signOut() {
        UserDefaults.standard.removeObject(forKey: playerNameKey)
        UserDefaults.standard.set(false, forKey: hasSetupKey)
        
        playerName = ""
        isSignedIn = false
        localStats = nil
        
        print("👋 Player signed out")
    }
    
    /// Change player name
    func changePlayerName(to newName: String) {
        setupLocalPlayer(name: newName)
    }
    
    /// Load and refresh stats
    func refreshStats() {
        loadLocalStats()
    }
    
    // MARK: - Private Methods
    
    private func loadLocalUser() {
        let hasSetup = UserDefaults.standard.bool(forKey: hasSetupKey)
        let savedName = UserDefaults.standard.string(forKey: playerNameKey) ?? ""
        
        if hasSetup && !savedName.isEmpty {
            playerName = savedName
            isSignedIn = true
            loadLocalStats()
        } else {
            // First time - stay signed out until setup
            isSignedIn = false
        }
    }
    
    private func createOrUpdateLocalUser(name: String, appleUserId: String? = nil) {
        let context = coreData.mainContext
        
        // Determine the primary identifier
        let primaryId = appleUserId ?? name.lowercased()
        
        // Check if user already exists by primary identifier
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "primaryIdentifier == %@", primaryId)
        
        do {
            let existingUsers = try context.fetch(fetchRequest)
            
            if let existingUser = existingUsers.first {
                // Update existing user
                existingUser.displayName = name
                existingUser.username = name
                existingUser.lastLoginDate = Date()
                
                // Update userId if we have Apple ID
                if let appleId = appleUserId {
                    existingUser.userId = appleId
                }
                
                try context.save()
                print("✅ Updated existing user: \(name)")
                
                // Check for anonymous games to claim
                offerToClaimAnonymousGames(for: existingUser)
            } else {
                // Create new local user
                let user = UserCD(context: context)
                user.id = UUID()
                user.primaryIdentifier = primaryId
                user.userId = appleUserId ?? "local-\(UUID().uuidString)"
                user.username = name
                user.displayName = name
                user.email = nil
                user.registrationDate = Date()
                user.lastLoginDate = Date()
                user.isActive = true
                user.isVerified = true
                user.isSubadmin = false
                
                // Create initial stats
                let stats = UserStatsCD(context: context)
                stats.user = user
                stats.totalScore = 0
                stats.gamesPlayed = 0
                stats.gamesWon = 0
                stats.currentStreak = 0
                stats.bestStreak = 0
                stats.averageMistakes = 0.0
                stats.averageTime = 0.0
                stats.lastPlayedDate = nil
                
                user.stats = stats
                
                try context.save()
                print("✅ Created local user: \(name)")
                
                // Check for anonymous games to claim
                offerToClaimAnonymousGames(for: user)
            }
            
            loadLocalStats()
        } catch {
            print("❌ Error creating/updating local user: \(error)")
        }
    }
    
    private func offerToClaimAnonymousGames(for user: UserCD) {
        let context = coreData.mainContext
        
        // Find anonymous games from the last 24 hours
        let oneDayAgo = Date().addingTimeInterval(-86400)
        let gameFetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
        
        // Get anonymous user
        let anonUserRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        anonUserRequest.predicate = NSPredicate(format: "primaryIdentifier == %@", anonymousIdentifier)
        
        do {
            if let anonUser = try context.fetch(anonUserRequest).first {
                // Find recent anonymous games
                gameFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "user == %@", anonUser),
                    NSPredicate(format: "lastUpdateTime >= %@", oneDayAgo as NSDate)
                ])
                
                let recentAnonGames = try context.fetch(gameFetchRequest)
                
                if !recentAnonGames.isEmpty {
                    print("📊 Found \(recentAnonGames.count) recent anonymous games")
                    
                    // In a real app, you'd show a dialog here
                    // For now, auto-claim recent games
                    claimAnonymousGames(recentAnonGames, for: user)
                }
            }
        } catch {
            print("❌ Error checking for anonymous games: \(error)")
        }
    }
    
    private func claimAnonymousGames(_ games: [GameCD], for user: UserCD) {
        let context = coreData.mainContext
        
        do {
            for game in games {
                game.user = user
            }
            
            // Recalculate user stats
            if let stats = user.stats {
                let completedGames = games.filter { $0.hasWon || $0.hasLost }
                stats.gamesPlayed += Int32(completedGames.count)
                stats.gamesWon += Int32(completedGames.filter { $0.hasWon }.count)
                stats.totalScore += completedGames.reduce(0) { $0 + $1.score }
                
                // Recalculate averages
                if stats.gamesPlayed > 0 {
                    let totalTime = completedGames.reduce(0) { $0 + Double($1.timeTaken) }
                    stats.averageTime = totalTime / Double(stats.gamesPlayed)
                    
                    let totalMistakes = completedGames.reduce(0) { $0 + Double($1.mistakes) }
                    stats.averageMistakes = totalMistakes / Double(stats.gamesPlayed)
                }
            }
            
            try context.save()
            print("✅ Claimed \(games.count) anonymous games")
        } catch {
            print("❌ Error claiming anonymous games: \(error)")
        }
    }
    
    private func loadLocalStats() {
        guard isSignedIn else {
            localStats = nil
            return
        }
        
        let context = coreData.mainContext
        
        // First, find the user correctly
        let userFetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        
        // Check if we have an Apple ID (from UserState)
        if !UserState.shared.userId.isEmpty {
            // User signed in with Apple - use Apple ID as primary identifier
            userFetchRequest.predicate = NSPredicate(format: "primaryIdentifier == %@", UserState.shared.userId)
        } else {
            // Local user - use playerName lowercased as primary identifier
            userFetchRequest.predicate = NSPredicate(format: "primaryIdentifier == %@", playerName.lowercased())
        }
        
        do {
            let users = try context.fetch(userFetchRequest)
            
            if let user = users.first, let statsCD = user.stats {
                localStats = LocalUserStats(
                    totalScore: Int(statsCD.totalScore),
                    gamesPlayed: Int(statsCD.gamesPlayed),
                    gamesWon: Int(statsCD.gamesWon),
                    winRate: statsCD.gamesPlayed > 0 ? Double(statsCD.gamesWon) / Double(statsCD.gamesPlayed) : 0.0,
                    currentStreak: Int(statsCD.currentStreak),
                    bestStreak: Int(statsCD.bestStreak),
                    averageMistakes: statsCD.averageMistakes,
                    averageTime: statsCD.averageTime,
                    lastPlayedDate: statsCD.lastPlayedDate
                )
                print("✅ Loaded stats for user with primaryId: \(user.primaryIdentifier ?? "unknown")")
            } else {
                // Try fallback - search by username
                let fallbackRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
                fallbackRequest.predicate = NSPredicate(format: "username == %@", playerName)
                
                let fallbackUsers = try context.fetch(fallbackRequest)
                if let user = fallbackUsers.first, let statsCD = user.stats {
                    localStats = LocalUserStats(
                        totalScore: Int(statsCD.totalScore),
                        gamesPlayed: Int(statsCD.gamesPlayed),
                        gamesWon: Int(statsCD.gamesWon),
                        winRate: statsCD.gamesPlayed > 0 ? Double(statsCD.gamesWon) / Double(statsCD.gamesPlayed) : 0.0,
                        currentStreak: Int(statsCD.currentStreak),
                        bestStreak: Int(statsCD.bestStreak),
                        averageMistakes: statsCD.averageMistakes,
                        averageTime: statsCD.averageTime,
                        lastPlayedDate: statsCD.lastPlayedDate
                    )
                    print("✅ Loaded stats via fallback for username: \(playerName)")
                } else {
                    // Create default stats if none exist
                    localStats = LocalUserStats(
                        totalScore: 0,
                        gamesPlayed: 0,
                        gamesWon: 0,
                        winRate: 0.0,
                        currentStreak: 0,
                        bestStreak: 0,
                        averageMistakes: 0.0,
                        averageTime: 0.0,
                        lastPlayedDate: nil
                    )
                    print("⚠️ No stats found for user, using defaults")
                }
            }
        } catch {
            print("❌ Error loading local stats: \(error)")
            localStats = nil
        }
    }
    
    // MARK: - Anonymous User Management
    
    func getOrCreateAnonymousUser() -> UserCD? {
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "primaryIdentifier == %@", anonymousIdentifier)
        
        do {
            if let anonUser = try context.fetch(fetchRequest).first {
                return anonUser
            } else {
                // Create anonymous user
                let anonUser = UserCD(context: context)
                anonUser.id = UUID()
                anonUser.primaryIdentifier = anonymousIdentifier
                anonUser.userId = anonymousIdentifier
                anonUser.username = anonymousDisplayName
                anonUser.displayName = anonymousDisplayName
                anonUser.registrationDate = Date()
                anonUser.isActive = true
                
                // Create stats for anonymous user
                let stats = UserStatsCD(context: context)
                stats.user = anonUser
                stats.totalScore = 0
                stats.gamesPlayed = 0
                stats.gamesWon = 0
                stats.currentStreak = 0
                stats.bestStreak = 0
                stats.averageMistakes = 0.0
                stats.averageTime = 0.0
                
                anonUser.stats = stats
                
                try context.save()
                print("✅ Created anonymous user")
                return anonUser
            }
        } catch {
            print("❌ Error managing anonymous user: \(error)")
            return nil
        }
    }
}

// MARK: - Local User Stats Model

struct LocalUserStats {
    let totalScore: Int
    let gamesPlayed: Int
    let gamesWon: Int
    let winRate: Double
    let currentStreak: Int
    let bestStreak: Int
    let averageMistakes: Double
    let averageTime: Double
    let lastPlayedDate: Date?
    
    var formattedWinRate: String {
        return String(format: "%.1f%%", winRate * 100)
    }
    
    var formattedAverageTime: String {
        let minutes = Int(averageTime) / 60
        let seconds = Int(averageTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
