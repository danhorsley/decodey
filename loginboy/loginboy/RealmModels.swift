// Create RealmModels.swift
import RealmSwift
import Foundation

// MARK: - Game Model
class GameRealm: Object {
    @Persisted(primaryKey: true) var gameId: String = UUID().uuidString
    @Persisted var encrypted: String = ""
    @Persisted var solution: String = ""
    @Persisted var currentDisplay: String = ""
    @Persisted var mapping: Map<String, String> = Map<String, String>()
    @Persisted var correctMappings: Map<String, String> = Map<String, String>()
    @Persisted var guessedMappings: Map<String, String> = Map<String, String>()
    @Persisted var mistakes: Int = 0
    @Persisted var maxMistakes: Int = 5
    @Persisted var hasWon: Bool = false
    @Persisted var hasLost: Bool = false
    @Persisted var difficulty: String = "medium"
    @Persisted var userId: String? = nil
    @Persisted var startTime: Date = Date()
    @Persisted var lastUpdateTime: Date = Date()
    @Persisted var isDaily: Bool = false
    @Persisted var score: Int? = nil
    @Persisted var timeTaken: Int? = nil
    
    // Computed property (not stored)
    var letterFrequency: [Character: Int] {
        var freq: [Character: Int] = [:]
        for char in encrypted where char.isLetter {
            freq[char, default: 0] += 1
        }
        return freq
    }
}

// MARK: - Quote Model
class QuoteRealm: Object {
    @Persisted(primaryKey: true) var id: ObjectId
    @Persisted var serverId: Int? = nil // To track server's quote ID
    @Persisted var text: String = ""
    @Persisted var author: String = ""
    @Persisted var attribution: String? = nil
    @Persisted var difficulty: Double = 1.0
    @Persisted var isDaily: Bool = false
    @Persisted var dailyDate: Date? = nil
    @Persisted var isActive: Bool = true
    @Persisted var timesUsed: Int = 0
    @Persisted var uniqueLetters: Int = 0
    
    // For convenience
    func toQuote() -> Quote {
        return Quote(
            text: text,
            author: author,
            attribution: attribution,
            difficulty: difficulty
        )
    }
}



// MARK: - User Model
class UserRealm: Object {
    @Persisted(primaryKey: true) var userId: String
    @Persisted var username: String
    @Persisted var email: String
    @Persisted var displayName: String?
    @Persisted var avatarUrl: String?
    @Persisted var bio: String?
    @Persisted var passwordHash: String?
    @Persisted var registrationDate: Date
    @Persisted var lastLoginDate: Date
    @Persisted var isActive: Bool = true
    @Persisted var isVerified: Bool = false
    @Persisted var isSubadmin: Bool = false
    
    // Relationships
    @Persisted var preferences: UserPreferencesRealm?
    @Persisted var stats: UserStatsRealm?
}

// MARK: - User Preferences
class UserPreferencesRealm: EmbeddedObject {
    @Persisted var darkMode: Bool = true
    @Persisted var showTextHelpers: Bool = true
    @Persisted var accessibilityTextSize: Bool = false
    @Persisted var gameDifficulty: String = "medium"
    @Persisted var soundEnabled: Bool = true
    @Persisted var soundVolume: Float = 0.5
    @Persisted var useBiometricAuth: Bool = false
    @Persisted var notificationsEnabled: Bool = true
    @Persisted var lastSyncDate: Date? = nil
}

// MARK: - User Stats
class UserStatsRealm: EmbeddedObject {
    @Persisted var gamesPlayed: Int = 0
    @Persisted var gamesWon: Int = 0
    @Persisted var currentStreak: Int = 0
    @Persisted var bestStreak: Int = 0
    @Persisted var totalScore: Int = 0
    @Persisted var averageMistakes: Double = 0.0
    @Persisted var averageTime: Double = 0.0
    @Persisted var lastPlayedDate: Date? = nil
}



//
//  RealmModels.swift
//  loginboy
//
//  Created by Daniel Horsley on 14/05/2025.
//

