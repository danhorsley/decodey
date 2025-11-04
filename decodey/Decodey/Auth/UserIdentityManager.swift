// UserIdentityManager.swift
// A clean, unified approach to managing user identity across multiple auth systems

import Foundation
import CoreData
import GameKit
import AuthenticationServices

/// Single source of truth for user identity
class UserIdentityManager: ObservableObject {
    static let shared = UserIdentityManager()
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var displayName = "Player"
    @Published var primaryIdentifier = ""
    
    // MARK: - Auth System IDs
    private var appleSignInID: String? {
        didSet {
            updatePrimaryIdentifier()
        }
    }
    
    private var gameCenterID: String? {
        didSet {
            updatePrimaryIdentifier()
        }
    }
    
    private var gameCenterAlias: String? {
        didSet {
            updateDisplayName()
        }
    }
    
    private var appleSignInName: String? {
        didSet {
            updateDisplayName()
        }
    }
    
    // MARK: - Core Data
    private let coreData = CoreDataStack.shared
    
    private init() {
        loadSavedIdentity()
    }
    
    // MARK: - Public Methods
    
    /// Called when Apple Sign In completes
    func setAppleSignInUser(id: String, name: String?, email: String?) {
        
        self.appleSignInID = id
        
        // Save name if provided (only on first sign in)
        if let name = name, !name.isEmpty {
            self.appleSignInName = name
            UserDefaults.standard.set(name, forKey: "saved_display_name")
        } else {
            // Try to load saved name
            self.appleSignInName = UserDefaults.standard.string(forKey: "saved_display_name")
        }
        
        updateUserInDatabase()
    }
    
    /// Called when Game Center authenticates
    func setGameCenterUser(id: String, displayName: String, alias: String) {
        
        self.gameCenterID = id
        self.gameCenterAlias = !displayName.isEmpty ? displayName : alias
        
        // If we don't have a good name from Apple Sign In, use Game Center
        if appleSignInName == nil || appleSignInName == "Player" {
            UserDefaults.standard.set(gameCenterAlias, forKey: "saved_display_name")
        }
        
        updateUserInDatabase()
    }
    
    /// Sign out completely
    func signOut() {
        appleSignInID = nil
        gameCenterID = nil
        gameCenterAlias = nil
        appleSignInName = nil
        primaryIdentifier = ""
        displayName = "Player"
        isAuthenticated = false
        
        // Don't clear saved_display_name - keep it for next sign in
    }
    
    // MARK: - Private Methods
    
    private func loadSavedIdentity() {
        // Load any saved display name
        if let savedName = UserDefaults.standard.string(forKey: "saved_display_name"),
           !savedName.isEmpty {
            displayName = savedName
        }
        
        // Load Apple Sign In ID if exists
        if let savedAppleID = UserDefaults.standard.string(forKey: "apple_user_id"),
           !savedAppleID.isEmpty {
            appleSignInID = savedAppleID
        }
    }
    
    private func updatePrimaryIdentifier() {
        // Use Apple Sign In ID as primary if available, otherwise Game Center
        if let appleID = appleSignInID, !appleID.isEmpty {
            primaryIdentifier = appleID
            isAuthenticated = true
        } else if let gcID = gameCenterID, !gcID.isEmpty {
            primaryIdentifier = gcID
            isAuthenticated = true
        } else {
            primaryIdentifier = ""
            isAuthenticated = false
        }
        
    }
    
    private func updateDisplayName() {
        // Priority: Game Center name > Apple Sign In name > Saved name > "Player"
        if let gcAlias = gameCenterAlias, !gcAlias.isEmpty, gcAlias != "Player" {
            displayName = gcAlias
        } else if let appleName = appleSignInName, !appleName.isEmpty, appleName != "Player" {
            displayName = appleName
        } else if let savedName = UserDefaults.standard.string(forKey: "saved_display_name"),
                  !savedName.isEmpty {
            displayName = savedName
        } else {
            displayName = "Player"
        }
        
    }
    
    private func updateUserInDatabase() {
        guard !primaryIdentifier.isEmpty else { return }
        
        let context = coreData.mainContext
        
        // Find or create user
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "primaryIdentifier == %@", primaryIdentifier)
        
        do {
            let users = try context.fetch(fetchRequest)
            let user: UserCD
            
            if let existingUser = users.first {
                user = existingUser
            } else {
                user = UserCD(context: context)
                user.id = UUID()
                user.primaryIdentifier = primaryIdentifier
                user.registrationDate = Date()
                user.isActive = true
            }
            
            // Update user fields
            user.username = displayName
            user.displayName = displayName
            user.userId = appleSignInID ?? gameCenterID ?? primaryIdentifier
            user.lastLoginDate = Date()
            
            // Ensure stats exist
            if user.stats == nil {
                let stats = UserStatsCD(context: context)
                stats.user = user
                user.stats = stats
                stats.gamesPlayed = 0
                stats.gamesWon = 0
                stats.totalScore = 0
                stats.currentStreak = 0
                stats.bestStreak = 0
                stats.averageMistakes = 0.0
                stats.averageTime = 0.0
            }
            
            try context.save()
            
        } catch {
            #if DEBUG
            print("❌ Error updating user in database: \(error)")
            #endif
        }
    }
    
    // MARK: - Stats Methods
    
    func getUserStats() -> UserStatsCD? {
        guard !primaryIdentifier.isEmpty else { return nil }
        
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "primaryIdentifier == %@", primaryIdentifier)
        
        do {
            let users = try context.fetch(fetchRequest)
            return users.first?.stats
        } catch {
            #if DEBUG
            print("❌ Error fetching user stats: \(error)")
            #endif
            return nil
        }
    }
    
    func updateStatsAfterGame(won: Bool, score: Int, mistakes: Int, timeTaken: Int) {
        // IMPORTANT: Get fresh context and user to avoid stale data
        let context = CoreDataStack.shared.mainContext
        
        guard let user = getCurrentUser() else {
            #if DEBUG
            print("❌ No user found to update stats")
            #endif
            return
        }
        
        // Get or create stats
        let stats: UserStatsCD
        if let existingStats = user.stats {
            stats = existingStats
            #if DEBUG
            print("📊 Found existing stats")
            #endif
        } else {
            stats = UserStatsCD(context: context)
            stats.user = user
            user.stats = stats
            #if DEBUG
            print("📊 Created new stats")
            #endif
        }
        
        // Update basic stats
        stats.gamesPlayed += 1
        
        if won {
            stats.gamesWon += 1
            stats.totalScore += Int32(score)
            
            // IMPORTANT: Increment streak for wins
            let newStreak = stats.currentStreak + 1
            stats.currentStreak = newStreak
            
            // Update best streak if needed
            if newStreak > stats.bestStreak {
                stats.bestStreak = newStreak
            }
            
            print("✅ WON! Streak incremented from \(newStreak - 1) to \(newStreak)")
        } else {
            // IMPORTANT: Only reset streak on loss
            let oldStreak = stats.currentStreak
            stats.currentStreak = 0
        }
        
        // Update averages
        let games = Double(stats.gamesPlayed)
        if games > 1 {
            let oldMistakesTotal = stats.averageMistakes * (games - 1)
            stats.averageMistakes = (oldMistakesTotal + Double(mistakes)) / games
            
            let oldTimeTotal = stats.averageTime * (games - 1)
            stats.averageTime = (oldTimeTotal + Double(timeTaken)) / games
        } else {
            stats.averageMistakes = Double(mistakes)
            stats.averageTime = Double(timeTaken)
        }
        
        stats.lastPlayedDate = Date()
        
        // Save changes
        do {
            try context.save()
            
            // Verify the save worked by fetching again
            context.refresh(stats, mergeChanges: false)
            
        } catch {
            #if DEBUG
            print("❌ Error saving stats: \(error)")
            #endif
        }
    }
    
    /// Find user for game submission (used by GameState)
    func getCurrentUser() -> UserCD? {
        guard !primaryIdentifier.isEmpty else { return nil }
        
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "primaryIdentifier == %@", primaryIdentifier)
        
        do {
            let users = try context.fetch(fetchRequest)
            return users.first
        } catch {
            #if DEBUG
            print("❌ Error fetching current user: \(error)")
            #endif
            return nil
        }
    }
}
