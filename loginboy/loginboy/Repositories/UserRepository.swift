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
                    displayName: record.display_name,
                    avatarUrl: record.avatar_url,
                    bio: record.bio,
                    registrationDate: record.registration_date,
                    lastLoginDate: record.last_login_date,
                    isActive: record.is_active,
                    isVerified: record.is_verified,
                    isSubadmin: record.is_subadmin
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
                    password_hash: nil, // Don't modify password
                    display_name: profile.displayName,
                    avatar_url: profile.avatarUrl,
                    bio: profile.bio,
                    registration_date: profile.registrationDate,
                    last_login_date: profile.lastLoginDate,
                    is_active: profile.isActive,
                    is_verified: profile.isVerified,
                    is_subadmin: profile.isSubadmin
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
                    userId: record.user_id,
                    darkMode: record.dark_mode,
                    showTextHelpers: record.show_text_helpers,
                    accessibilityTextSize: record.accessibility_text_size,
                    gameDifficulty: record.game_difficulty,
                    soundEnabled: record.sound_enabled,
                    soundVolume: record.sound_volume,
                    useBiometricAuth: record.use_biometric_auth,
                    notificationsEnabled: record.notifications_enabled,
                    lastSyncDate: record.last_sync_date
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
                    user_id: preferences.userId,
                    dark_mode: preferences.darkMode,
                    show_text_helpers: preferences.showTextHelpers,
                    accessibility_text_size: preferences.accessibilityTextSize,
                    game_difficulty: preferences.gameDifficulty,
                    sound_enabled: preferences.soundEnabled,
                    sound_volume: preferences.soundVolume,
                    use_biometric_auth: preferences.useBiometricAuth,
                    notifications_enabled: preferences.notificationsEnabled,
                    last_sync_date: preferences.lastSyncDate ?? Date()
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
                    password_hash: passwordHash,
                    display_name: nil,
                    avatar_url: nil,
                    bio: nil,
                    registration_date: Date(),
                    last_login_date: Date(),
                    is_active: true,
                    is_verified: false,
                    is_subadmin: false
                )

                
                try record.insert(db)
                
                // Initialize user preferences with defaults
                let preferences = UserPreferencesRecord(
                    user_id: userId,
                    dark_mode: true,
                    show_text_helpers: true,
                    accessibility_text_size: false,
                    game_difficulty: "medium",
                    sound_enabled: true,
                    sound_volume: 0.5,
                    use_biometric_auth: false,
                    notifications_enabled: true,
                    last_sync_date: Date()
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
    let password_hash: String?
    let display_name: String?
    let avatar_url: String?
    let bio: String?
    let registration_date: Date
    let last_login_date: Date
    let is_active: Bool
    let is_verified: Bool
    let is_subadmin: Bool
}

struct UserPreferencesRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "user_preferences"
    
    let user_id: String
    let dark_mode: Bool
    let show_text_helpers: Bool
    let accessibility_text_size: Bool
    let game_difficulty: String
    let sound_enabled: Bool
    let sound_volume: Float
    let use_biometric_auth: Bool
    let notifications_enabled: Bool
    let last_sync_date: Date?
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
    
    let user_id: String
    let games_played: Int
    let games_won: Int
    let current_streak: Int
    let best_streak: Int
    let total_score: Int
    let average_mistakes: Double
    let average_time: Double
    let last_played_date: Date?
    
    var winPercentage: Double {
        guard games_played > 0 else { return 0 }
        return (Double(games_won) / Double(games_played)) * 100.0
    }
}
