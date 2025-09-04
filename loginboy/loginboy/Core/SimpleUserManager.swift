//
//  SimpleUserManager.swift - Local-Only User Management
//  loginboy
//

import Foundation
import SwiftUI
import Combine

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
    
    // Singleton
    static let shared = SimpleUserManager()
    
    init() {
        loadLocalUser()
    }
    
    // MARK: - Public Methods
    
    /// Set up local player (replaces authentication)
    func setupLocalPlayer(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // Save to UserDefaults
        UserDefaults.standard.set(trimmedName, forKey: playerNameKey)
        UserDefaults.standard.set(true, forKey: hasSetupKey)
        
        // Update state
        playerName = trimmedName
        isSignedIn = true
        
        // Create local user in Core Data
        createLocalUser(name: trimmedName)
        
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
    
    private func createLocalUser(name: String) {
        let context = coreData.mainContext
        
        // Check if user already exists
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "username == %@", name)
        
        do {
            let existingUsers = try context.fetch(fetchRequest)
            
            if existingUsers.isEmpty {
                // Create new local user
                let user = UserCD(context: context)
                user.id = UUID()
                user.userId = "local-\(UUID().uuidString)"
                user.username = name
                user.displayName = name
                user.email = nil // No email for local users
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
            } else {
                // Update existing user's last login
                let user = existingUsers.first!
                user.lastLoginDate = Date()
                try context.save()
                print("✅ Updated existing local user: \(name)")
            }
            
            loadLocalStats()
        } catch {
            print("❌ Error creating local user: \(error)")
        }
    }
    
    private func loadLocalStats() {
        guard isSignedIn else {
            localStats = nil
            return
        }
        
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<UserStatsCD> = UserStatsCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "user.username == %@", playerName)
        
        do {
            let statsArray = try context.fetch(fetchRequest)
            if let statsCD = statsArray.first {
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
            }
        } catch {
            print("❌ Error loading local stats: \(error)")
            localStats = nil
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
