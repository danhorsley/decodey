import Foundation
import CoreData
import SwiftUI

// MARK: - Core Data Generated Model Extensions
// These are the extensions to the generated Core Data model classes

// MARK: - Quote Extensions
extension Quote {
    
    // MARK: - Helper methods for Quote
    
    /// Converts to a QuoteModel struct for use in business logic
    func toModel() -> QuoteModel {
        return QuoteModel(
            text: text,
            author: author,
            attribution: attribution,
            difficulty: difficulty
        )
    }
    
    /// Creates or updates a Quote from a QuoteModel
    static func createOrUpdate(from model: QuoteModel, in context: NSManagedObjectContext) -> Quote {
        let quote = Quote(context: context)
        quote.id = UUID()
        quote.text = model.text
        quote.author = model.author
        quote.attribution = model.attribution
        quote.difficulty = model.difficulty ?? 0.0
        quote.uniqueLetters = Int16(Set(model.text.filter { $0.isLetter }).count)
        quote.isActive = true
        quote.timesUsed = 0
        
        return quote
    }
}

// MARK: - Game Extensions
extension Game {
    
    // MARK: - Computed properties for mappings
    
    /// Converts binary mapping data to dictionary
    var mapping: [Character: Character] {
        get {
            guard let data = mappingData else { return [:] }
            
            do {
                let dict = try JSONDecoder().decode([String: String].self, from: data)
                return dict.convertToCharacterDictionary()
            } catch {
                print("Error decoding mapping: \(error)")
                return [:]
            }
        }
        set {
            do {
                mappingData = try JSONEncoder().encode(newValue.mapToDictionary())
            } catch {
                print("Error encoding mapping: \(error)")
                mappingData = nil
            }
        }
    }
    
    /// Converts binary correct mappings data to dictionary
    var correctMappings: [Character: Character] {
        get {
            guard let data = correctMappingsData else { return [:] }
            
            do {
                let dict = try JSONDecoder().decode([String: String].self, from: data)
                return dict.convertToCharacterDictionary()
            } catch {
                print("Error decoding correctMappings: \(error)")
                return [:]
            }
        }
        set {
            do {
                correctMappingsData = try JSONEncoder().encode(newValue.mapToDictionary())
            } catch {
                print("Error encoding correctMappings: \(error)")
                correctMappingsData = nil
            }
        }
    }
    
    /// Converts binary guessed mappings data to dictionary
    var guessedMappings: [Character: Character] {
        get {
            guard let data = guessedMappingsData else { return [:] }
            
            do {
                let dict = try JSONDecoder().decode([String: String].self, from: data)
                return dict.convertToCharacterDictionary()
            } catch {
                print("Error decoding guessedMappings: \(error)")
                return [:]
            }
        }
        set {
            do {
                guessedMappingsData = try JSONEncoder().encode(newValue.mapToDictionary())
            } catch {
                print("Error encoding guessedMappings: \(error)")
                guessedMappingsData = nil
            }
        }
    }
    
    /// Calculates letter frequency from the encrypted text
    var letterFrequency: [Character: Int] {
        var frequency: [Character: Int] = [:]
        
        for char in encrypted where char.isLetter {
            frequency[char, default: 0] += 1
        }
        
        return frequency
    }
    
    // MARK: - Helper methods
    
    /// Converts to a GameModel struct for use in business logic
    func toModel() -> GameModel {
        return GameModel(
            gameId: gameId,
            encrypted: encrypted,
            solution: solution,
            currentDisplay: currentDisplay,
            mapping: mapping,
            correctMappings: correctMappings,
            guessedMappings: guessedMappings,
            mistakes: Int(mistakes),
            maxMistakes: Int(maxMistakes),
            hasWon: hasWon,
            hasLost: hasLost,
            difficulty: difficulty,
            startTime: startTime,
            lastUpdateTime: lastUpdateTime
        )
    }
    
    /// Creates or updates a Game from a GameModel
    static func createOrUpdate(from model: GameModel, in context: NSManagedObjectContext) -> Game {
        // Check if this game already exists
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        
        if let gameId = model.gameId {
            fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameId)
            
            do {
                let results = try context.fetch(fetchRequest)
                if let existingGame = results.first {
                    // Update existing game
                    updateGame(existingGame, with: model)
                    return existingGame
                }
            } catch {
                print("Error fetching game: \(error)")
            }
        }
        
        // Create new game
        let game = Game(context: context)
        game.id = UUID()
        game.gameId = model.gameId ?? UUID().uuidString
        game.startTime = model.startTime
        
        // Update with model data
        updateGame(game, with: model)
        
        return game
    }
    
    /// Updates an existing Game with data from a GameModel
    private static func updateGame(_ game: Game, with model: GameModel) {
        game.encrypted = model.encrypted
        game.solution = model.solution
        game.currentDisplay = model.currentDisplay
        game.mistakes = Int16(model.mistakes)
        game.maxMistakes = Int16(model.maxMistakes)
        game.hasWon = model.hasWon
        game.hasLost = model.hasLost
        game.difficulty = model.difficulty
        game.lastUpdateTime = model.lastUpdateTime
        game.isDaily = model.gameId?.starts(with: "daily-") ?? false
        
        // Update mappings
        game.mapping = model.mapping
        game.correctMappings = model.correctMappings
        game.guessedMappings = model.guessedMappings
        
        // Update score and time taken if game is completed
        if model.hasWon || model.hasLost {
            game.score = Int32(model.calculateScore())
            game.timeTaken = Int32(model.lastUpdateTime.timeIntervalSince(model.startTime))
        }
    }
    
    /// Calculate score based on game state
    func calculateScore() -> Int {
        let timeInSeconds = Int(lastUpdateTime.timeIntervalSince(startTime))
        
        // Base score by difficulty
        let baseScore: Int
        switch difficulty.lowercased() {
        case "easy": baseScore = 100
        case "hard": baseScore = 300
        default: baseScore = 200
        }
        
        // Time bonus/penalty
        let timeScore: Int
        if timeInSeconds < 60 { timeScore = 50 }
        else if timeInSeconds < 180 { timeScore = 30 }
        else if timeInSeconds < 300 { timeScore = 10 }
        else if timeInSeconds > 600 { timeScore = -20 }
        else { timeScore = 0 }
        
        // Mistake penalty
        let mistakePenalty = Int(mistakes) * 20
        
        // Total (never negative)
        return max(0, baseScore - mistakePenalty + timeScore)
    }
}

// MARK: - User Extensions
extension User {
    
    /// Converts to a UserModel struct
    func toModel() -> UserModel {
        return UserModel(
            userId: userId,
            username: username,
            email: email,
            displayName: displayName,
            avatarUrl: avatarUrl,
            bio: bio,
            registrationDate: registrationDate,
            lastLoginDate: lastLoginDate,
            isActive: isActive,
            isVerified: isVerified,
            isSubadmin: isSubadmin
        )
    }
    
    /// Creates or updates a User from a UserModel
    static func createOrUpdate(from model: UserModel, in context: NSManagedObjectContext) -> User {
        // Check if this user already exists
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", model.userId)
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingUser = results.first {
                // Update existing user
                existingUser.username = model.username
                existingUser.email = model.email
                existingUser.displayName = model.displayName
                existingUser.avatarUrl = model.avatarUrl
                existingUser.bio = model.bio
                existingUser.lastLoginDate = model.lastLoginDate
                existingUser.isActive = model.isActive
                existingUser.isVerified = model.isVerified
                existingUser.isSubadmin = model.isSubadmin
                
                return existingUser
            }
        } catch {
            print("Error fetching user: \(error)")
        }
        
        // Create new user
        let user = User(context: context)
        user.id = UUID()
        user.userId = model.userId
        user.username = model.username
        user.email = model.email
        user.displayName = model.displayName
        user.avatarUrl = model.avatarUrl
        user.bio = model.bio
        user.registrationDate = model.registrationDate
        user.lastLoginDate = model.lastLoginDate
        user.isActive = model.isActive
        user.isVerified = model.isVerified
        user.isSubadmin = model.isSubadmin
        
        return user
    }
}

// MARK: - UserPreferences Extensions
extension UserPreferences {
    
    /// Converts to a UserPreferencesModel struct
    func toModel() -> UserPreferencesModel {
        return UserPreferencesModel(
            darkMode: darkMode,
            showTextHelpers: showTextHelpers,
            accessibilityTextSize: accessibilityTextSize,
            gameDifficulty: gameDifficulty,
            soundEnabled: soundEnabled,
            soundVolume: soundVolume,
            useBiometricAuth: useBiometricAuth,
            notificationsEnabled: notificationsEnabled,
            lastSyncDate: lastSyncDate
        )
    }
    
    /// Creates or updates preferences from a model
    static func createOrUpdate(from model: UserPreferencesModel, for user: User, in context: NSManagedObjectContext) -> UserPreferences {
        let preferences: UserPreferences
        
        if let existingPrefs = user.preferences {
            // Update existing preferences
            preferences = existingPrefs
        } else {
            // Create new preferences
            preferences = UserPreferences(context: context)
            user.preferences = preferences
            preferences.user = user
        }
        
        // Update properties
        preferences.darkMode = model.darkMode
        preferences.showTextHelpers = model.showTextHelpers
        preferences.accessibilityTextSize = model.accessibilityTextSize
        preferences.gameDifficulty = model.gameDifficulty
        preferences.soundEnabled = model.soundEnabled
        preferences.soundVolume = model.soundVolume
        preferences.useBiometricAuth = model.useBiometricAuth
        preferences.notificationsEnabled = model.notificationsEnabled
        preferences.lastSyncDate = model.lastSyncDate
        
        return preferences
    }
}

// MARK: - UserStats Extensions
extension UserStats {
    
    /// Converts to a UserStatsModel struct
    func toModel() -> UserStatsModel {
        return UserStatsModel(
            userId: user?.userId ?? "",
            gamesPlayed: Int(gamesPlayed),
            gamesWon: Int(gamesWon),
            currentStreak: Int(currentStreak),
            bestStreak: Int(bestStreak),
            totalScore: Int(totalScore),
            averageScore: gamesPlayed > 0 ? Double(totalScore) / Double(gamesPlayed) : 0.0,
            averageTime: averageTime,
            lastPlayedDate: lastPlayedDate
        )
    }
    
    /// Creates or updates stats from a model
    static func createOrUpdate(from model: UserStatsModel, for user: User, in context: NSManagedObjectContext) -> UserStats {
        let stats: UserStats
        
        if let existingStats = user.stats {
            // Update existing stats
            stats = existingStats
        } else {
            // Create new stats
            stats = UserStats(context: context)
            user.stats = stats
            stats.user = user
        }
        
        // Update properties
        stats.gamesPlayed = Int32(model.gamesPlayed)
        stats.gamesWon = Int32(model.gamesWon)
        stats.currentStreak = Int32(model.currentStreak)
        stats.bestStreak = Int32(model.bestStreak)
        stats.totalScore = Int32(model.totalScore)
        stats.averageTime = model.averageTime
        stats.lastPlayedDate = model.lastPlayedDate
        
        return stats
    }
}

// MARK: - Helper Extensions
extension Dictionary where Key == Character, Value == Character {
    func mapToDictionary() -> [String: String] {
        var result = [String: String]()
        for (key, value) in self {
            result[String(key)] = String(value)
        }
        return result
    }
}

extension Dictionary where Key == String, Value == String {
    func convertToCharacterDictionary() -> [Character: Character] {
        var result = [Character: Character]()
        for (key, value) in self {
            if let keyChar = key.first, let valueChar = value.first {
                result[keyChar] = valueChar
            }
        }
        return result
    }
}

// MARK: - NSFetchRequest Extensions
extension NSFetchRequest where ResultType == Quote {
    static func fetchRequest() -> NSFetchRequest<Quote> {
        return NSFetchRequest<Quote>(entityName: "Quote")
    }
}

extension NSFetchRequest where ResultType == Game {
    static func fetchRequest() -> NSFetchRequest<Game> {
        return NSFetchRequest<Game>(entityName: "Game")
    }
}

extension NSFetchRequest where ResultType == User {
    static func fetchRequest() -> NSFetchRequest<User> {
        return NSFetchRequest<User>(entityName: "User")
    }
}

extension NSFetchRequest where ResultType == UserPreferences {
    static func fetchRequest() -> NSFetchRequest<UserPreferences> {
        return NSFetchRequest<UserPreferences>(entityName: "UserPreferences")
    }
}

extension NSFetchRequest where ResultType == UserStats {
    static func fetchRequest() -> NSFetchRequest<UserStats> {
        return NSFetchRequest<UserStats>(entityName: "UserStats")
    }
}

//
//  CoreDataModelExtensions.swift
//  loginboy
//
//  Created by Daniel Horsley on 19/05/2025.
//

