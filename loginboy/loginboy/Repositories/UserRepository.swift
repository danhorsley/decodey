import Foundation
import GRDB

protocol UserRepositoryProtocol {
    func getUserProfile(userId: String) async throws -> UserProfile
    func updateUserProfile(profile: UserProfile) async throws
    func getUserPreferences(userId: String) async throws -> UserPreferences
    func saveUserPreferences(preferences: UserPreferences) async throws
    func isUsernameTaken(_ username: String) async throws -> Bool
}

struct UserProfile: Codable {
    var userId: String
    var username: String
    var email: String
    var displayName: String?
    var avatarUrl: String?
    var bio: String?
    var registrationDate: Date
    var lastLoginDate: Date
    var isActive: Bool
    var isVerified: Bool
    var isSubadmin: Bool
}

struct UserPreferences: Codable {
    var userId: String
    var darkMode: Bool
    var showTextHelpers: Bool
    var accessibilityTextSize: Bool
    var gameDifficulty: String
    var soundEnabled: Bool
    var soundVolume: Float
    var useBiometricAuth: Bool
    var notificationsEnabled: Bool
    var lastSyncDate: Date?
}

/// Repository implementation for user-related data
class UserRepository: UserRepositoryProtocol {
    private let database: DatabaseQueue
    
    init(database: DatabaseQueue) {
        self.database = database
    }
    
    // MARK: - User Profile Operations
    
    /// Get user profile by ID
    func getUserProfile(userId: String) async throws -> UserProfile {
        return try await Task {
            try database.read { db in
                // Check if user exists
                guard let record = try UserRecord.filter(Column("id") == userId).fetchOne(db) else {
                    throw RepositoryError.notFound("User not found")
                }
                
                // Convert to domain model
                return UserProfile(
                    userId: record.id,
                    username: record.username,
                    email: record.email,
                    displayName: record.displayName,
                    avatarUrl: record.avatarUrl,
                    bio: record.bio,
                    registrationDate: record.registrationDate,
                    lastLoginDate: record.lastLoginDate,
                    isActive: record.isActive,
                    isVerified: record.isVerified,
                    isSubadmin: record.isSubadmin
                )
            }
        }.value
    }
    
    /// Update user profile
    func updateUserProfile(profile: UserProfile) async throws {
        try await Task {
            try database.write { db in
                // Check if user exists
                guard try UserRecord.filter(Column("id") == profile.userId).fetchCount(db) > 0 else {
                    throw RepositoryError.notFound("User not found")
                }
                
                // Update user record
                var record = UserRecord(
                    id: profile.userId,
                    username: profile.username,
                    email: profile.email,
                    passwordHash: nil, // Don't modify password
                    displayName: profile.displayName,
                    avatarUrl: profile.avatarUrl,
                    bio: profile.bio,
                    registrationDate: profile.registrationDate,
                    lastLoginDate: profile.lastLoginDate,
                    isActive: profile.isActive,
                    isVerified: profile.isVerified,
                    isSubadmin: profile.isSubadmin
                )
                
                try record.update(db)
            }
        }.value
    }
    
    // MARK: - User Preferences Operations
    
    /// Get user preferences
    func getUserPreferences(userId: String) async throws -> UserPreferences {
        return try await Task {
            try database.read { db in
                // Check if preferences exist
                guard let record = try UserPreferencesRecord.filter(Column("user_id") == userId).fetchOne(db) else {
                    // Return default preferences if none exist
                    return UserPreferences(
                        userId: userId,
                        darkMode: true,
                        showTextHelpers: true,
                        accessibilityTextSize: false,
                        gameDifficulty: "medium",
                        soundEnabled: true,
                        soundVolume: 0.5,
                        useBiometricAuth: false,
                        notificationsEnabled: true,
                        lastSyncDate: nil
                    )
                }
                
                // Convert to domain model
                return UserPreferences(
                    userId: record.userId,
                    darkMode: record.darkMode,
                    showTextHelpers: record.showTextHelpers,
                    accessibilityTextSize: record.accessibilityTextSize,
                    gameDifficulty: record.gameDifficulty,
                    soundEnabled: record.soundEnabled,
                    soundVolume: record.soundVolume,
                    useBiometricAuth: record.useBiometricAuth,
                    notificationsEnabled: record.notificationsEnabled,
                    lastSyncDate: record.lastSyncDate
                )
            }
        }.value
    }
    
    /// Save user preferences
    func saveUserPreferences(preferences: UserPreferences) async throws {
        try await Task {
            try database.write { db in
                // Check if preferences exist
                let exists = try UserPreferencesRecord.filter(Column("user_id") == preferences.userId).fetchCount(db) > 0
                
                // Create record
                let record = UserPreferencesRecord(
                    userId: preferences.userId,
                    darkMode: preferences.darkMode,
                    showTextHelpers: preferences.showTextHelpers,
                    accessibilityTextSize: preferences.accessibilityTextSize,
                    gameDifficulty: preferences.gameDifficulty,
                    soundEnabled: preferences.soundEnabled,
                    soundVolume: preferences.soundVolume,
                    useBiometricAuth: preferences.useBiometricAuth,
                    notificationsEnabled: preferences.notificationsEnabled,
                    lastSyncDate: preferences.lastSyncDate ?? Date()
                )
                
                if exists {
                    try record.update(db)
                } else {
                    try record.insert(db)
                }
            }
        }.value
    }
    
    // MARK: - User Account Management
    
    /// Check if username is already taken
    func isUsernameTaken(_ username: String) async throws -> Bool {
        return try await Task {
            try database.read { db in
                let count = try UserRecord.filter(Column("username") == username).fetchCount(db)
                return count > 0
            }
        }.value
    }
    
    /// Create new user account (typically called from authentication service)
    func createUser(username: String, email: String, passwordHash: String) async throws -> String {
        return try await Task {
            try database.write { db in
                // Check if username or email already exists
                if try UserRecord.filter(Column("username") == username).fetchCount(db) > 0 {
                    throw RepositoryError.userExistsError("Username already taken")
                }
                
                if try UserRecord.filter(Column("email") == email).fetchCount(db) > 0 {
                    throw RepositoryError.userExistsError("Email already registered")
                }
                
                // Create new user
                let userId = UUID().uuidString
                let record = UserRecord(
                    id: userId,
                    username: username,
                    email: email,
                    passwordHash: passwordHash,
                    displayName: nil,
                    avatarUrl: nil,
                    bio: nil,
                    registrationDate: Date(),
                    lastLoginDate: Date(),
                    isActive: true,
                    isVerified: false,
                    isSubadmin: false
                )
                
                try record.insert(db)
                
                // Initialize user preferences with defaults
                let preferences = UserPreferencesRecord(
                    userId: userId,
                    darkMode: true,
                    showTextHelpers: true,
                    accessibilityTextSize: false,
                    gameDifficulty: "medium",
                    soundEnabled: true,
                    soundVolume: 0.5,
                    useBiometricAuth: false,
                    notificationsEnabled: true,
                    lastSyncDate: Date()
                )
                
                try preferences.insert(db)
                
                return userId
            }
        }.value
    }
    
    /// Update user's last login date
    func updateLastLoginDate(userId: String) async throws {
        try await Task {
            try database.write { db in
                try db.execute(
                    sql: "UPDATE users SET last_login_date = ? WHERE id = ?",
                    arguments: [Date(), userId]
                )
            }
        }.value
    }
}

// MARK: - Database Records

struct UserRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "users"
    
    let id: String
    let username: String
    let email: String
    let passwordHash: String?
    let displayName: String?
    let avatarUrl: String?
    let bio: String?
    let registrationDate: Date
    let lastLoginDate: Date
    let isActive: Bool
    let isVerified: Bool
    let isSubadmin: Bool
}

struct UserPreferencesRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "user_preferences"
    
    let userId: String
    let darkMode: Bool
    let showTextHelpers: Bool
    let accessibilityTextSize: Bool
    let gameDifficulty: String
    let soundEnabled: Bool
    let soundVolume: Float
    let useBiometricAuth: Bool
    let notificationsEnabled: Bool
    let lastSyncDate: Date?
    
    // Map column names
    enum Columns {
        static let userId = Column("user_id")
        static let darkMode = Column("dark_mode")
        static let showTextHelpers = Column("show_text_helpers")
        static let accessibilityTextSize = Column("accessibility_text_size")
        static let gameDifficulty = Column("game_difficulty")
        static let soundEnabled = Column("sound_enabled")
        static let soundVolume = Column("sound_volume")
        static let useBiometricAuth = Column("use_biometric_auth")
        static let notificationsEnabled = Column("notifications_enabled")
        static let lastSyncDate = Column("last_sync_date")
    }
}

// MARK: - Additional Repository Errors
extension RepositoryError {
    static func userExistsError(_ message: String) -> RepositoryError {
        return .saveFailed("User already exists: \(message)")
    }
}
// Stats Record
struct StatsRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "statistics"
    
    let userId: String
    let gamesPlayed: Int
    let gamesWon: Int
    let currentStreak: Int
    let bestStreak: Int
    let totalScore: Int
    let averageMistakes: Double
    let averageTime: Double
    let lastPlayedDate: Date?
    
    var winPercentage: Double {
        guard gamesPlayed > 0 else { return 0 }
        return (Double(gamesWon) / Double(gamesPlayed)) * 100.0
    }
}
//
//  UserRepository.swift
//  loginboy
//
//  Created by Daniel Horsley on 15/05/2025.
//

//
//  UserRepository.swift
//  loginboy
//
//  Created by Daniel Horsley on 14/05/2025.
//

