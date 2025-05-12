import Foundation
import GRDB

/// Database manager for the Decodey app
class DatabaseManager {
    // Shared instance
    static let shared = DatabaseManager()
    
    // GRDB database queue
    private var dbQueue: DatabaseQueue!
    
    // Private initializer for singleton
    private init() {
        do {
            // Get the document directory - improved path handling
            let fileManager = FileManager.default
            let folderURL = try fileManager.url(for: .documentDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true)
            
            // Database path - create subdirectory for better organization
            let dbFolderURL = folderURL.appendingPathComponent("Databases", isDirectory: true)
            
            // Create the directory if it doesn't exist
            if !fileManager.fileExists(atPath: dbFolderURL.path) {
                try fileManager.createDirectory(at: dbFolderURL, withIntermediateDirectories: true)
            }
            
            let dbURL = dbFolderURL.appendingPathComponent("decodey.sqlite")
            let dbPath = dbURL.path
            
            // Log the path for debugging
            print("DEBUG: Attempting to create/open database at: \(dbPath)")
            
            // Check if we have write permissions to the directory
            if fileManager.isWritableFile(atPath: dbFolderURL.path) {
                print("DEBUG: Directory is writable")
            } else {
                print("DEBUG: Directory is NOT writable")
            }
            
            // Create the database with additional configuration
            var configuration = Configuration()
            configuration.foreignKeysEnabled = true // Enable foreign key constraints
            configuration.busyMode = .timeout(5.0) // Set timeout for busy database

            dbQueue = try DatabaseQueue(path: dbPath, configuration: configuration)
            
            // Create tables
            try setupDatabase()
            
            // Verify the database was created
            if fileManager.fileExists(atPath: dbPath) {
                print("DEBUG: Database file exists after initialization at: \(dbPath)")
                print("DEBUG: Database file size: \(try fileManager.attributesOfItem(atPath: dbPath)[.size] ?? 0) bytes")
            } else {
                print("DEBUG: WARNING - Database file does not exist after initialization!")
            }
            
        } catch {
            print("DEBUG: Database initialization error: \(error)")
            // Add more detailed error logging
            if let grdbError = error as? DatabaseError {
                print("DEBUG: GRDB error code: \(grdbError.resultCode), message: \(grdbError.message)")
            }
        }
    }
    
    // Set up the database schema
    private func setupDatabase() throws {
        try migrator.migrate(dbQueue)
    }
    
    // Database migrations
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        // Initial migration - create tables
        migrator.registerMigration("createTables") { db in
            // Quotes table
            try db.create(table: "quotes") { t in
                t.column("id", .integer).primaryKey()
                t.column("text", .text).notNull()
                t.column("author", .text).notNull()
                t.column("attribution", .text)
                t.column("difficulty", .double).notNull()
                t.column("is_daily", .boolean).notNull().defaults(to: false)
                t.column("daily_date", .date)
                t.column("is_active", .boolean).notNull().defaults(to: true)
                t.column("times_used", .integer).notNull().defaults(to: 0)
                t.column("unique_letters", .integer)
                t.column("created_at", .datetime)
                t.column("updated_at", .datetime)
            }
    
            // Games table
            try db.create(table: "games") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("game_id", .text).notNull().unique()
                t.column("user_id", .text)
                t.column("quote_id", .integer).references("quotes")
                t.column("original_text", .text).notNull()
                t.column("encrypted_text", .text).notNull()
                t.column("current_display", .text).notNull()
                t.column("solution", .text).notNull()
                t.column("mapping", .blob).notNull()  // Serialized dictionary
                t.column("reverse_mapping", .blob).notNull()  // Serialized dictionary
                t.column("correctly_guessed", .blob)  // Serialized array
                t.column("mistakes", .integer).notNull().defaults(to: 0)
                t.column("max_mistakes", .integer).notNull().defaults(to: 5)
                t.column("difficulty", .text).notNull()
                t.column("has_won", .boolean).notNull().defaults(to: false)
                t.column("has_lost", .boolean).notNull().defaults(to: false)
                t.column("is_complete", .boolean).notNull().defaults(to: false)
                t.column("score", .integer).defaults(to: 0)
                t.column("time_taken", .integer)  // In seconds
                t.column("created_at", .datetime).notNull()
                t.column("last_updated", .datetime).notNull()
            }
            
            // Statistics table
            try db.create(table: "statistics") { t in
                t.column("user_id", .text).notNull().primaryKey()
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
        
        // Add seed data migration
        migrator.registerMigration("seedData") { db in
            try self.insertInitialQuotes(db: db)
        }
        
        return migrator
    }

    // Insert initial quotes when the database is first created
    private func insertInitialQuotes(db: Database) throws {
        // Sample quotes with different difficulties
        let quotes = [
            // Easy quotes (shorter, common words)
            ["text": "Manners maketh man.", "author": "William Horman", "difficulty": "easy"],
            ["text": "The early bird catches the worm.", "author": "John Ray", "difficulty": "easy"],
            ["text": "Actions speak louder than words.", "author": "Abraham Lincoln", "difficulty": "easy"],
            ["text": "Knowledge is power.", "author": "Francis Bacon", "difficulty": "easy"],
            ["text": "Time waits for no one.", "author": "Geoffrey Chaucer", "difficulty": "easy"],
            
            // Medium quotes (moderate length, some less common words)
            ["text": "Be yourself; everyone else is already taken.", "author": "Oscar Wilde", "difficulty": "medium"],
            ["text": "The only thing we have to fear is fear itself.", "author": "Franklin D. Roosevelt", "difficulty": "medium"],
            ["text": "Life is what happens when you're busy making other plans.", "author": "John Lennon", "difficulty": "medium"],
            ["text": "The journey of a thousand miles begins with a single step.", "author": "Lao Tzu", "difficulty": "medium"],
            ["text": "The unexamined life is not worth living.", "author": "Socrates", "difficulty": "medium"],
            
            // Hard quotes (longer, more complex words or structure)
            ["text": "The measure of intelligence is the ability to change.", "author": "Albert Einstein", "difficulty": "hard"],
            ["text": "It is during our darkest moments that we must focus to see the light.", "author": "Aristotle", "difficulty": "hard"],
            ["text": "Imagination is more important than knowledge.", "author": "Albert Einstein", "difficulty": "hard"],
            ["text": "The future belongs to those who believe in the beauty of their dreams.", "author": "Eleanor Roosevelt", "difficulty": "hard"],
            ["text": "Be the change that you wish to see in the world.", "author": "Mahatma Gandhi", "difficulty": "hard"]
        ]
        
        // Insert each quote
        for quote in quotes {
            try db.execute(
                sql: "INSERT INTO quotes (text, author, difficulty, is_active) VALUES (?, ?, ?, ?)",
                arguments: [quote["text"], quote["author"], quote["difficulty"], true]
            )
        }
    }

    // Helper function to convert Character dictionary to String dictionary for serialization
    private func characterDictToStringDict(_ dict: [Character: Character]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in dict {
            result[String(key)] = String(value)
        }
        return result
    }

    // Helper function to convert String dictionary back to Character dictionary
    private func stringDictToCharacterDict(_ dict: [String: String]) -> [Character: Character] {
        var result: [Character: Character] = [:]
        for (key, value) in dict {
            if let keyChar = key.first, let valueChar = value.first {
                result[keyChar] = valueChar
            }
        }
        return result
    }
}

extension DatabaseManager {
    /// Save a game to the database
    func saveGame(_ game: Game) throws {
        try dbQueue.write { db in
            // Convert Character dictionaries to String dictionaries for serialization
            let mappingStringDict = characterDictToStringDict(game.mapping)
            let reverseMappingStringDict = characterDictToStringDict(game.correctMappings)
            
            // Serialize the dictionaries and arrays
            let mappingData = try JSONEncoder().encode(mappingStringDict)
            let reverseMappingData = try JSONEncoder().encode(reverseMappingStringDict)
            let correctlyGuessedData = try JSONEncoder().encode(game.correctlyGuessed().map { String($0) })
            
            // Create a unique game ID if not present
            let gameId = game.gameId ?? UUID().uuidString
            
            // Execute with individual arguments
            try db.execute(
                sql: """
                    INSERT INTO games (
                        game_id, original_text, encrypted_text, current_display, solution,
                        mapping, reverse_mapping, correctly_guessed, mistakes, max_mistakes,
                        difficulty, has_won, has_lost, is_complete, created_at, last_updated
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    gameId,
                    game.solution,
                    game.encrypted,
                    game.currentDisplay,
                    game.solution,
                    mappingData,
                    reverseMappingData,
                    correctlyGuessedData,
                    game.mistakes,
                    game.maxMistakes,
                    "medium", // Default to medium
                    game.hasWon,
                    game.hasLost,
                    game.hasWon || game.hasLost,
                    Date(),
                    Date()
                ]
            )
        }
    }
    
    /// Update an existing game in the database
    func updateGame(_ game: Game, gameId: String) throws {
        try dbQueue.write { db in
            // Convert Character dictionaries to String dictionaries for serialization
            let mappingStringDict = characterDictToStringDict(game.mapping)
            let reverseMappingStringDict = characterDictToStringDict(game.correctMappings)
            
            // Serialize the dictionaries and arrays
            let mappingData = try JSONEncoder().encode(mappingStringDict)
            let reverseMappingData = try JSONEncoder().encode(reverseMappingStringDict)
            let correctlyGuessedData = try JSONEncoder().encode(game.correctlyGuessed().map { String($0) })
            
            // Execute with individual arguments
            try db.execute(
                sql: """
                    UPDATE games SET
                        current_display = ?,
                        mapping = ?,
                        reverse_mapping = ?,
                        correctly_guessed = ?,
                        mistakes = ?,
                        has_won = ?,
                        has_lost = ?,
                        is_complete = ?,
                        last_updated = ?
                    WHERE game_id = ?
                """,
                arguments: [
                    game.currentDisplay,
                    mappingData,
                    reverseMappingData,
                    correctlyGuessedData,
                    game.mistakes,
                    game.hasWon,
                    game.hasLost,
                    game.hasWon || game.hasLost,
                    Date(),
                    gameId
                ]
            )
        }
    }
    
    /// Load the most recent unfinished game, if any
    func loadLatestGame() throws -> Game? {
        try dbQueue.read { db in
            // Query for the most recent unfinished game
            let row = try Row.fetchOne(db, sql: """
                SELECT * FROM games 
                WHERE is_complete = 0
                ORDER BY created_at DESC
                LIMIT 1
            """)
            
            // Return nil if no game found
            guard let row = row else { return nil }
            
            // Extract values from the row
            guard let gameId = row["game_id"] as? String,
                  let encrypted = row["encrypted_text"] as? String,
                  let solution = row["solution"] as? String,
                  let currentDisplay = row["current_display"] as? String,
                  let mistakes = row["mistakes"] as? Int,
                  let maxMistakes = row["max_mistakes"] as? Int,
                  let hasWon = row["has_won"] as? Bool,
                  let hasLost = row["has_lost"] as? Bool,
                  let difficulty = row["difficulty"] as? String,
                  let startTime = row["created_at"] as? Date,
                  let lastUpdateTime = row["last_updated"] as? Date,
                  let mappingData = row["mapping"] as? Data,
                  let reverseMappingData = row["reverse_mapping"] as? Data,
                  let correctlyGuessedData = row["correctly_guessed"] as? Data
            else {
                print("Failed to extract required game data from database row")
                return nil
            }
            
            do {
                // Decode the mappings with error handling
                let mappingStringDict = try JSONDecoder().decode([String: String].self, from: mappingData)
                let reverseMappingStringDict = try JSONDecoder().decode([String: String].self, from: reverseMappingData)
                let correctlyGuessedStrings = try JSONDecoder().decode([String].self, from: correctlyGuessedData)
                
                // Convert String dictionaries back to Character dictionaries
                let mapping = stringDictToCharacterDict(mappingStringDict)
                let reverseMapping = stringDictToCharacterDict(reverseMappingStringDict)
                
                // Convert string array to character array for correctly guessed
                var guessedMappings: [Character: Character] = [:]
                for charStr in correctlyGuessedStrings {
                    if let char = charStr.first, let original = reverseMapping[char] {
                        guessedMappings[char] = original
                    }
                }
                
                // Create a game with loaded data
                return Game(
                    gameId: gameId,
                    encrypted: encrypted,
                    solution: solution,
                    currentDisplay: currentDisplay,
                    mapping: mapping,
                    correctMappings: reverseMapping,
                    guessedMappings: guessedMappings,
                    mistakes: mistakes,
                    maxMistakes: maxMistakes,
                    hasWon: hasWon,
                    hasLost: hasLost,
                    difficulty: difficulty,
                    startTime: startTime,
                    lastUpdateTime: lastUpdateTime
                )
            } catch {
                print("Error decoding game data: \(error)")
                return nil
            }
        }
    }
}

// MARK: - Quote Methods
extension DatabaseManager {
    /// Get a random quote with optional difficulty filter
    func getRandomQuote(difficulty: String? = nil) throws -> (text: String, author: String, attribution: String?) {
        try dbQueue.read { db in
            // Build the query
            var sql = "SELECT * FROM quotes WHERE is_active = 1"
            var arguments: StatementArguments = []
            
            // Add difficulty filter if specified
            if let difficulty = difficulty {
                sql += " AND difficulty = ?"
                arguments = [difficulty]
            }
            
            // Add random order and limit
            sql += " ORDER BY RANDOM() LIMIT 1"
            
            // Execute the query
            guard let row = try Row.fetchOne(db, sql: sql, arguments: arguments) else {
                throw NSError(domain: "DatabaseManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No quotes found"])
            }
            
            // Extract the quote data
            let text = row["text"] as! String
            let author = row["author"] as? String ?? "Unknown"
            let attribution = row["attribution"] as? String
            
            return (text, author, attribution)
        }
    }
    
    /// Add a new quote to the database
    func addQuote(text: String, author: String, attribution: String? = nil, difficulty: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT INTO quotes (text, author, attribution, difficulty, is_active) VALUES (?, ?, ?, ?, ?)",
                arguments: [text, author, attribution, difficulty, true]
            )
        }
    }
    
    /// Get all quotes
    func getAllQuotes() throws -> [(id: Int, text: String, author: String, difficulty: String)] {
        try dbQueue.read { db in
            var quotes: [(id: Int, text: String, author: String, difficulty: String)] = []
            
            let rows = try Row.fetchAll(db, sql: "SELECT id, text, author, difficulty FROM quotes ORDER BY difficulty, text")
            
            for row in rows {
                if let id = row["id"] as? Int,
                   let text = row["text"] as? String {
                    let author = row["author"] as? String ?? "Unknown"
                    let difficulty = row["difficulty"] as? String ?? "medium"
                    
                    quotes.append((id: id, text: text, author: author, difficulty: difficulty))
                }
            }
            
            return quotes
        }
    }
}

// MARK: - Statistics Methods
extension DatabaseManager {
    /// Update statistics after a game finishes
    func updateStatistics(userId: String, gameWon: Bool, mistakes: Int, timeTaken: Int, score: Int) throws {
        try dbQueue.write { db in
            // Get the current date
            let today = Date()
            
            // Check if the user already has statistics
            let hasStats = try Row.fetchOne(db, sql: "SELECT COUNT(*) FROM statistics WHERE user_id = ?", arguments: [userId])?[0] as? Int ?? 0 > 0
            
            if hasStats {
                // Update existing statistics
                try db.execute(
                    sql: """
                        UPDATE statistics SET
                            games_played = games_played + 1,
                            games_won = games_won + ?,
                            current_streak = CASE WHEN ? THEN current_streak + 1 ELSE 0 END,
                            best_streak = CASE WHEN ? AND current_streak + 1 > best_streak THEN current_streak + 1 ELSE best_streak END,
                            total_score = total_score + ?,
                            average_mistakes = (average_mistakes * games_played + ?) / (games_played + 1),
                            average_time = (average_time * games_played + ?) / (games_played + 1),
                            last_played_date = ?
                        WHERE user_id = ?
                    """,
                    arguments: [
                        gameWon ? 1 : 0,
                        gameWon,
                        gameWon,
                        score,
                        mistakes,
                        timeTaken,
                        today,
                        userId
                    ]
                )
            } else {
                // Create new statistics record
                try db.execute(
                    sql: """
                        INSERT INTO statistics (
                            user_id, games_played, games_won, current_streak, best_streak,
                            total_score, average_mistakes, average_time, last_played_date
                        ) VALUES (?, 1, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        userId,
                        gameWon ? 1 : 0,
                        gameWon ? 1 : 0,
                        gameWon ? 1 : 0,
                        score,
                        Double(mistakes),
                        Double(timeTaken),
                        today
                    ]
                )
            }
        }
    }
    
    /// Get user statistics
    func getStatistics(userId: String) throws -> [String: Any]? {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM statistics WHERE user_id = ?", arguments: [userId]) else {
                return nil
            }
            
            // Safely unwrap optional values
            guard let gamesPlayed = row["games_played"] as? Int,
                  let gamesWon = row["games_won"] as? Int,
                  let currentStreak = row["current_streak"] as? Int,
                  let bestStreak = row["best_streak"] as? Int,
                  let totalScore = row["total_score"] as? Int,
                  let averageMistakes = row["average_mistakes"] as? Double,
                  let averageTime = row["average_time"] as? Double else {
                print("Failed to extract required statistics from database row")
                return nil
            }
            
            let lastPlayedDate = row["last_played_date"] as? Date
            
            return [
                "games_played": gamesPlayed,
                "games_won": gamesWon,
                "win_percentage": calculatePercentage(gamesWon, outOf: gamesPlayed),
                "current_streak": currentStreak,
                "best_streak": bestStreak,
                "total_score": totalScore,
                "average_score": gamesPlayed > 0 ? totalScore / gamesPlayed : 0,
                "average_mistakes": averageMistakes,
                "average_time": averageTime,
                "last_played_date": lastPlayedDate as Any
            ]
        }
    }
    
    /// Calculate percentage helper
    private func calculatePercentage(_ value: Int, outOf total: Int) -> Double {
        guard total > 0 else { return 0.0 }
        return Double(value) / Double(total) * 100.0
    }
}

extension DatabaseManager {
    /// Sync all quotes from the server
    func syncQuotesFromServer(authService: AuthService, completion: @escaping (Bool, String?) -> Void) {
        guard let token = authService.getAccessToken() else {
            completion(false, "Authentication required")
            return
        }
        
        guard let url = URL(string: "\(authService.baseURL)/api/get_all_quotes") else {
            completion(false, "Invalid URL configuration")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                completion(false, "Self reference lost")
                return
            }
            
            if let error = error {
                print("DEBUG: Failed to sync quotes: \(error)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "Invalid response from server")
                return
            }
            
            if httpResponse.statusCode != 200 {
                completion(false, "Server returned status code \(httpResponse.statusCode)")
                return
            }
            
            guard let data = data else {
                completion(false, "No data received")
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let quotesResponse = try decoder.decode(QuotesResponse.self, from: data)
                
                // Save quotes to database
                try self.dbQueue.write { db in
                    // Clear existing quotes
                    try db.execute(sql: "DELETE FROM quotes")
                    
                    // Insert new quotes
                    for quote in quotesResponse.quotes {
                        try db.execute(
                            sql: """
                                INSERT INTO quotes (
                                    id, text, author, attribution, difficulty, 
                                    daily_date, is_active, times_used, unique_letters, 
                                    created_at, updated_at
                                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                            """,
                            arguments: [
                                quote.id,
                                quote.text,
                                quote.author,
                                quote.minorAttribution,
                                quote.difficulty,
                                quote.dailyDate,
                                true,
                                quote.timesUsed,
                                quote.uniqueLetters,
                                quote.createdAt,
                                quote.updatedAt
                            ]
                        )
                    }
                }
                
                print("DEBUG: Successfully synced \(quotesResponse.quotes.count) quotes")
                completion(true, nil)
            } catch {
                print("DEBUG: Failed to parse or save quotes: \(error)")
                completion(false, error.localizedDescription)
            }
        }.resume()
    }
    
    /// Check if quotes need to be synced (e.g., on app start)
    func checkAndSyncQuotesIfNeeded(authService: AuthService) {
        // Check if quotes table is empty or we haven't synced in a while
        do {
            let count = try dbQueue.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM quotes") ?? 0
            }
            
            let lastSync = UserDefaults.standard.object(forKey: "lastQuotesSync") as? Date
            let syncNeeded = count == 0 ||
                             lastSync == nil ||
                             Calendar.current.dateComponents([.day], from: lastSync!, to: Date()).day! > 7
            
            if syncNeeded {
                syncQuotesFromServer(authService: authService) { success, message in
                    if success {
                        // Update last sync date
                        UserDefaults.standard.set(Date(), forKey: "lastQuotesSync")
                    }
                }
            }
        } catch {
            print("Error checking quotes table: \(error)")
        }
    }
}
//
//  DatabaseManager.swift
//  decodey
//
//  Created by Daniel Horsley on 07/05/2025.
//

