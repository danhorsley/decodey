import Foundation
import GRDB

/// Central repository provider that manages access to all repositories
class RepositoryProvider {
    // Singleton instance
    static let shared = RepositoryProvider()
    
    // Database connection
    private let database: DatabaseQueue
    
    // Repositories
    private(set) lazy var quoteRepository: QuoteRepositoryProtocol = QuoteRepository(database: database)
    private(set) lazy var gameRepository: GameRepositoryProtocol = GameRepository(database: database)
    private(set) lazy var userRepository: UserRepositoryProtocol = UserRepository(database: database)
    
    // Private initializer for singleton
    private init() {
        // Initialize database
        do {
            // Get document directory
            let fileManager = FileManager.default
            let dbFolder = try fileManager.url(for: .documentDirectory, in: .userDomainMask,
                                             appropriateFor: nil, create: true)
                .appendingPathComponent("Databases", isDirectory: true)
            
            // Create folder if needed
            if !fileManager.fileExists(atPath: dbFolder.path) {
                try fileManager.createDirectory(at: dbFolder, withIntermediateDirectories: true)
            }
            
            // Database path
            let dbPath = dbFolder.appendingPathComponent("decodey.sqlite").path
            
            // Create database with configuration
            var config = Configuration()
            config.foreignKeysEnabled = true
            
            database = try DatabaseQueue(path: dbPath, configuration: config)
            
            // Run migrations
            try setupDatabase()
            
        } catch {
            fatalError("Database initialization error: \(error)")
        }
    }
    
    // Setup database schema
    private func setupDatabase() throws {
        var migrator = DatabaseMigrator()
        
        // Initial schema - use camelCase column names to match our Swift properties
        migrator.registerMigration("createTables") { db in
            // Create users table
            try db.create(table: "users") { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("username", .text).notNull().unique()
                t.column("email", .text).notNull().unique()
                t.column("password_hash", .text)
                t.column("display_name", .text)
                t.column("avatar_url", .text)
                t.column("bio", .text)
                t.column("registration_date", .datetime).notNull()
                t.column("last_login_date", .datetime).notNull()
                t.column("is_active", .boolean).notNull().defaults(to: true)
                t.column("is_verified", .boolean).notNull().defaults(to: false)
                t.column("is_subadmin", .boolean).notNull().defaults(to: false)
            }
            
            // Create user preferences table
            try db.create(table: "user_preferences") { t in
                t.column("user_id", .text).notNull().primaryKey()
                    .references("users", column: "id", onDelete: .cascade)
                t.column("dark_mode", .boolean).notNull().defaults(to: true)
                t.column("show_text_helpers", .boolean).notNull().defaults(to: true)
                t.column("accessibility_text_size", .boolean).notNull().defaults(to: false)
                t.column("game_difficulty", .text).notNull().defaults(to: "medium")
                t.column("sound_enabled", .boolean).notNull().defaults(to: true)
                t.column("sound_volume", .double).notNull().defaults(to: 0.5)
                t.column("use_biometric_auth", .boolean).notNull().defaults(to: false)
                t.column("notifications_enabled", .boolean).notNull().defaults(to: true)
                t.column("last_sync_date", .datetime)
            }
            
            // Create quotes table with camelCase column names
            try db.create(table: "quotes") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("text", .text).notNull()
                t.column("author", .text).notNull()
                t.column("attribution", .text)
                t.column("difficulty", .double).notNull()
                t.column("is_daily", .boolean).defaults(to: false)
                t.column("daily_date", .date)
                t.column("is_active", .boolean).defaults(to: true)
                t.column("times_used", .integer).defaults(to: 0)
                t.column("unique_letters", .integer)
                t.column("created_at", .datetime)
                t.column("updated_at", .datetime)
            }
            
            // Create games table with camelCase column names
            try db.create(table: "games") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("game_id", .text).notNull().unique()
                t.column("user_id", .text)
                    .references("users", column: "id", onDelete: .setNull)
                t.column("quote_id", .integer)
                    .references("quotes", onDelete: .setNull)
                t.column("original_text", .text).notNull()
                t.column("encrypted_text", .text).notNull()
                t.column("current_display", .text).notNull()
                t.column("solution", .text).notNull()
                t.column("mapping", .blob).notNull()
                t.column("reverse_mapping", .blob).notNull()
                t.column("correctly_guessed", .blob)
                t.column("mistakes", .integer).notNull().defaults(to: 0)
                t.column("max_mistakes", .integer).notNull().defaults(to: 5)
                t.column("difficulty", .text).notNull()
                t.column("has_won", .boolean).notNull().defaults(to: false)
                t.column("has_lost", .boolean).notNull().defaults(to: false)
                t.column("is_complete", .boolean).notNull().defaults(to: false)
                t.column("score", .integer)
                t.column("time_taken", .integer)
                t.column("created_at", .datetime).notNull()
                t.column("last_updated", .datetime).notNull()
            }
            
            // Create stats table with camelCase column names
            try db.create(table: "statistics") { t in
                t.column("user_id", .text).notNull().primaryKey()
                    .references("users", column: "id", onDelete: .cascade)
                t.column("games_played", .integer).notNull().defaults(to: 0)
                t.column("games_won", .integer).notNull().defaults(to: 0)
                t.column("current_streak", .integer).notNull().defaults(to: 0)
                t.column("best_streak", .integer).notNull().defaults(to: 0)
                t.column("total_score", .integer).notNull().defaults(to: 0)
                t.column("average_mistakes", .double).notNull().defaults(to: 0)
                t.column("average_time", .double).notNull().defaults(to: 0)
                t.column("last_played_date", .date)
            }
        }
        
        // Seed data migration
        migrator.registerMigration("seedData") { db in
            // Insert default quotes
            let quotes: [[String: Any]] = [
                ["text": "THE EARLY BIRD CATCHES THE WORM.", "author": "John Ray", "difficulty": 1.0],
                ["text": "KNOWLEDGE IS POWER.", "author": "Francis Bacon", "difficulty": 0.8],
                ["text": "TIME WAITS FOR NO ONE.", "author": "Geoffrey Chaucer", "difficulty": 1.0],
                ["text": "BE YOURSELF; EVERYONE ELSE IS ALREADY TAKEN.", "author": "Oscar Wilde", "difficulty": 1.5],
                ["text": "THE JOURNEY OF A THOUSAND MILES BEGINS WITH A SINGLE STEP.", "author": "Lao Tzu", "difficulty": 2.0]
            ]
            
            for quote in quotes {
                try QuoteRecord(
                    text: quote["text"] as! String,
                    author: quote["author"] as! String,
                    difficulty: quote["difficulty"] as! Double,
                    isActive: true
                ).insert(db)
            }
            
            // Insert test user
            try UserRecord(
                id: "test-user-1",
                username: "testuser",
                email: "test@example.com",
                passwordHash: "$2y$10$92jJqMp3F4QCbwmGYI.wJuLnhrpGxBgBNUNuZ2O41oGG/pz5UbLOe", // "password"
                displayName: "Test User",
                avatarUrl: nil,
                bio: nil,
                registrationDate: Date(),
                lastLoginDate: Date(),
                isActive: true,
                isVerified: true,
                isSubadmin: false
            ).insert(db)
            
            // Insert test user preferences
            try UserPreferencesRecord(
                userId: "test-user-1",
                darkMode: true,
                showTextHelpers: true,
                accessibilityTextSize: false,
                gameDifficulty: "medium",
                soundEnabled: true,
                soundVolume: 0.5,
                useBiometricAuth: false,
                notificationsEnabled: true,
                lastSyncDate: Date()
            ).insert(db)
        }
        
        try migrator.migrate(database)
    }
    
    // Method to reset the database (for testing or user-requested data wipe)
    func resetDatabase() async throws {
        try await Task {
            // Drop all tables and recreate them
            try database.write { db in
                try db.drop(table: "statistics")
                try db.drop(table: "games")
                try db.drop(table: "quotes")
                try db.drop(table: "user_preferences")
                try db.drop(table: "users")
            }
            
            // Re-run migrations
            try setupDatabase()
        }.value
    }
}

//
//  RepositoryProvider.swift
//  loginboy
//
//  Created by Daniel Horsley on 15/05/2025.
//

//
//  RepositoryProvider.swift
//  loginboy
//
//  Created by Daniel Horsley on 14/05/2025.
//

