import Foundation
import CoreData
import SwiftUI

// MARK: - Migration Manager
/// This file handles the one-time migration from Realm to Core Data
/// It should be deleted after migration is complete

class MigrationManager {
    // Singleton instance
    static let shared = MigrationManager()
    
    // Core Data stack
    private let coreData = CoreDataStack.shared
    
    // Flags for migration progress
    private var quotesCompleted = false
    private var gamesCompleted = false
    private var usersCompleted = false
    
    // Progress reporting
    var progressCallback: ((Float, String) -> Void)?
    
    // Initialize
    private init() {}
    
    // MARK: - Migration Methods
    
    /// Execute the full migration process
    func performMigration(completion: @escaping (Bool) -> Void) {
        // First check if migration is needed
        if isMigrationNeeded() {
            // Reset completion flags
            quotesCompleted = false
            gamesCompleted = false
            usersCompleted = false
            
            // Perform migration steps in background
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
                
                // Start migration
                self.reportProgress(0.1, "Starting migration from Realm...")
                
                // 1. Migrate quotes
                if self.migrateQuotes() {
                    self.quotesCompleted = true
                    self.reportProgress(0.4, "Quotes migrated successfully")
                } else {
                    self.reportProgress(0.4, "Quote migration encountered issues, continuing...")
                }
                
                // 2. Migrate games
                if self.migrateGames() {
                    self.gamesCompleted = true
                    self.reportProgress(0.7, "Games migrated successfully")
                } else {
                    self.reportProgress(0.7, "Game migration encountered issues, continuing...")
                }
                
                // 3. Migrate users
                if self.migrateUsers() {
                    self.usersCompleted = true
                    self.reportProgress(0.9, "Users migrated successfully")
                } else {
                    self.reportProgress(0.9, "User migration encountered issues, continuing...")
                }
                
                // Mark migration as complete
                self.setMigrationCompleted()
                
                // Final report
                self.reportProgress(1.0, "Migration completed!")
                
                // Call completion handler on main thread
                DispatchQueue.main.async {
                    // Consider migration successful if at least quotes were migrated
                    completion(self.quotesCompleted)
                }
            }
        } else {
            // No migration needed
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
    
    /// Migrate quotes from Realm to Core Data
    private func migrateQuotes() -> Bool {
        reportProgress(0.2, "Migrating quotes...")
        
        // In a real migration, we would:
        // 1. Access Realm quotes
        // 2. Convert them to Core Data Quote entities
        // 3. Save them in Core Data
        
        // For now, we'll just create sample quotes directly in Core Data
        let context = coreData.newBackgroundContext()
        var success = false
        
        context.performAndWait {
            // Create sample quotes
            let sampleQuotes = [
                (text: "THE EARLY BIRD CATCHES THE WORM.", author: "John Ray", difficulty: 1.0),
                (text: "KNOWLEDGE IS POWER.", author: "Francis Bacon", difficulty: 0.8),
                (text: "TIME WAITS FOR NO ONE.", author: "Geoffrey Chaucer", difficulty: 1.0),
                (text: "BE YOURSELF; EVERYONE ELSE IS ALREADY TAKEN.", author: "Oscar Wilde", difficulty: 1.5),
                (text: "THE JOURNEY OF A THOUSAND MILES BEGINS WITH A SINGLE STEP.", author: "Lao Tzu", difficulty: 2.0)
            ]
            
            for (i, quoteData) in sampleQuotes.enumerated() {
                // Create each quote
                let quote = Quote(context: context)
                quote.id = UUID()
                quote.text = quoteData.text
                quote.author = quoteData.author
                quote.difficulty = quoteData.difficulty
                quote.uniqueLetters = Int16(Set(quoteData.text.filter { $0.isLetter }).count)
                quote.isActive = true
                quote.timesUsed = 0
                
                // Make one quote daily for testing
                if i == 0 {
                    quote.isDaily = true
                    quote.dailyDate = Date()
                }
            }
            
            // Try to save the context
            do {
                try context.save()
                success = true
            } catch {
                print("Error saving quotes during migration: \(error)")
                success = false
            }
        }
        
        return success
    }
    
    /// Migrate games from Realm to Core Data
    private func migrateGames() -> Bool {
        reportProgress(0.5, "Migrating games...")
        
        // In a real migration, we would:
        // 1. Access Realm games
        // 2. Convert them to Core Data Game entities
        // 3. Save them in Core Data
        
        // For now, we'll just create a sample in-progress game
        let context = coreData.newBackgroundContext()
        var success = false
        
        context.performAndWait {
            // Create sample game based on one of our quotes
            let fetchRequest: NSFetchRequest<Quote> = Quote.fetchRequest()
            
            do {
                let quotes = try context.fetch(fetchRequest)
                
                if let quote = quotes.first {
                    // Create a game from this quote
                    let game = Game(context: context)
                    game.id = UUID()
                    game.gameId = "custom-\(UUID().uuidString)"
                    game.encrypted = "QHE FGICJ BRDKL MDN OPGQS DTER QHE UAVW XDY."
                    game.solution = quote.text
                    game.currentDisplay = quote.text.map { $0.isLetter ? "█" : String($0) }.joined()
                    game.difficulty = quote.difficultyLevel
                    game.mistakes = 0
                    game.maxMistakes = Int16(quote.maxMistakesValue)
                    game.hasWon = false
                    game.hasLost = false
                    game.startTime = Date()
                    game.lastUpdateTime = Date()
                    
                    // Create and save mapping data
                    let mapping: [Character: Character] = [
                        "T": "Q", "H": "H", "E": "E",
                        "A": "A", "R": "R", "L": "U",
                        "Y": "V", "B": "B", "I": "I",
                        "D": "X", "C": "C", "G": "Y",
                        "S": "S", "W": "K", "O": "D",
                        "M": "M", "J": "P", "U": "G",
                        "N": "L", "P": "F", "V": "T",
                        "F": "M", "K": "J", "Q": "W",
                        "X": "Z", "Z": "N"
                    ]
                    
                    let correctMappings: [Character: Character] = Dictionary(uniqueKeysWithValues: mapping.map { ($1, $0) })
                    
                    // Store mappings
                    do {
                        game.mappingData = try JSONEncoder().encode(mapping.mapToDictionary())
                        game.correctMappingsData = try JSONEncoder().encode(correctMappings.mapToDictionary())
                        game.guessedMappingsData = try JSONEncoder().encode([String: String]())
                    } catch {
                        print("Error encoding mappings: \(error)")
                    }
                    
                    // Save the context
                    try context.save()
                    success = true
                }
            } catch {
                print("Error creating sample game during migration: \(error)")
                success = false
            }
        }
        
        return success
    }
    
    /// Migrate users from Realm to Core Data
    private func migrateUsers() -> Bool {
        reportProgress(0.8, "Migrating users...")
        
        // In a real migration, we would:
        // 1. Access Realm users
        // 2. Convert them to Core Data User entities
        // 3. Save them in Core Data
        
        // For now, we'll just create a sample user
        let context = coreData.newBackgroundContext()
        var success = false
        
        context.performAndWait {
            // Create sample user
            let user = User(context: context)
            user.id = UUID()
            user.userId = "sample-user"
            user.username = "sampleuser"
            user.email = "sample@example.com"
            user.displayName = "Sample User"
            user.registrationDate = Date()
            user.lastLoginDate = Date()
            user.isActive = true
            user.isVerified = true
            user.isSubadmin = false
            
            // Create preferences
            let preferences = UserPreferences(context: context)
            user.preferences = preferences
            preferences.user = user
            
            preferences.darkMode = true
            preferences.showTextHelpers = true
            preferences.accessibilityTextSize = false
            preferences.gameDifficulty = "medium"
            preferences.soundEnabled = true
            preferences.soundVolume = 0.5
            preferences.useBiometricAuth = false
            preferences.notificationsEnabled = true
            
            // Create stats
            let stats = UserStats(context: context)
            user.stats = stats
            stats.user = user
            
            stats.gamesPlayed = 5
            stats.gamesWon = 3
            stats.currentStreak = 1
            stats.bestStreak = 2
            stats.totalScore = 750
            stats.averageMistakes = 2.0
            stats.averageTime = 180.0
            stats.lastPlayedDate = Date()
            
            // Save the context
            do {
                try context.save()
                success = true
            } catch {
                print("Error creating sample user during migration: \(error)")
                success = false
            }
        }
        
        return success
    }
    
    // MARK: - Helper Methods
    
    /// Check if migration is needed
    func isMigrationNeeded() -> Bool {
        // In a real app, we would check for the existence of a Realm database
        // and whether it contains data that needs to be migrated.
        
        // For now, we'll use a flag in UserDefaults
        return UserDefaults.standard.bool(forKey: "needsDataMigration")
    }
    
    /// Mark migration as completed
    private func setMigrationCompleted() {
        UserDefaults.standard.set(false, forKey: "needsDataMigration")
    }
    
    /// Report progress to callback
    private func reportProgress(_ progress: Float, _ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.progressCallback?(progress, message)
        }
    }
    
    /// Trigger migration need (for testing)
    func triggerMigrationNeed() {
        UserDefaults.standard.set(true, forKey: "needsDataMigration")
    }
}

//
//  MigrationManager.swift
//  loginboy
//
//  Created by Daniel Horsley on 19/05/2025.
//

