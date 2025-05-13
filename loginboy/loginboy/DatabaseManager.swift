// DatabaseManager.swift - Completely refactored
import Foundation
import GRDB

// MARK: - Database Manager
class DatabaseManager {
    // Singleton
    static let shared = DatabaseManager()
    
    // Database connection
    private var dbQueue: DatabaseQueue!
    
    // Private initializer
    private init() {
        setupDatabase()
    }
    
    // MARK: - Setup
    
    private func setupDatabase() {
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
            
            dbQueue = try DatabaseQueue(path: dbPath, configuration: config)
            
            // Run migrations
            try migrator.migrate(dbQueue)
            
        } catch {
            print("Database initialization error: \(error)")
        }
    }
    
    // Database migrations
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        // Initial schema - use camelCase column names to match our Swift properties
        migrator.registerMigration("createTables") { db in
            // Create quotes table with camelCase column names
            try db.create(table: "quotes") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("text", .text).notNull()
                t.column("author", .text).notNull()
                t.column("attribution", .text)
                t.column("difficulty", .double).notNull()
                t.column("isDaily", .boolean).defaults(to: false)      // camelCase
                t.column("dailyDate", .date)                          // camelCase
                t.column("isActive", .boolean).defaults(to: true)     // camelCase
                t.column("timesUsed", .integer).defaults(to: 0)       // camelCase
                t.column("uniqueLetters", .integer)                   // camelCase
                t.column("createdAt", .datetime)                      // camelCase
                t.column("updatedAt", .datetime)                      // camelCase
            }
            
            // Create games table with camelCase column names
            try db.create(table: "games") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("gameId", .text).notNull().unique()          // camelCase
                t.column("userId", .text)                             // camelCase
                t.column("quoteId", .integer).references("quotes")    // camelCase
                t.column("originalText", .text).notNull()             // camelCase
                t.column("encryptedText", .text).notNull()            // camelCase
                t.column("currentDisplay", .text).notNull()           // camelCase
                t.column("solution", .text).notNull()
                t.column("mapping", .blob).notNull()
                t.column("reverseMapping", .blob).notNull()           // camelCase
                t.column("correctlyGuessed", .blob)                   // camelCase
                t.column("mistakes", .integer).notNull().defaults(to: 0)
                t.column("maxMistakes", .integer).notNull().defaults(to: 5) // camelCase
                t.column("difficulty", .text).notNull()
                t.column("hasWon", .boolean).notNull().defaults(to: false)  // camelCase
                t.column("hasLost", .boolean).notNull().defaults(to: false) // camelCase
                t.column("isComplete", .boolean).notNull().defaults(to: false) // camelCase
                t.column("score", .integer)
                t.column("timeTaken", .integer)                      // camelCase
                t.column("createdAt", .datetime).notNull()           // camelCase
                t.column("lastUpdated", .datetime).notNull()         // camelCase
            }
            
            // Create stats table with camelCase column names
            try db.create(table: "statistics") { t in
                t.column("userId", .text).notNull().primaryKey()     // camelCase
                t.column("gamesPlayed", .integer).notNull().defaults(to: 0) // camelCase
                t.column("gamesWon", .integer).notNull().defaults(to: 0)    // camelCase
                t.column("currentStreak", .integer).notNull().defaults(to: 0) // camelCase
                t.column("bestStreak", .integer).notNull().defaults(to: 0)    // camelCase
                t.column("totalScore", .integer).notNull().defaults(to: 0)    // camelCase
                t.column("averageMistakes", .double).notNull().defaults(to: 0) // camelCase
                t.column("averageTime", .double).notNull().defaults(to: 0)     // camelCase
                t.column("lastPlayedDate", .date)                            // camelCase
            }
        }
        
        // Seed data migration remains the same
        migrator.registerMigration("seedData") { db in
            try self.seedInitialQuotes(db)
        }
        
        return migrator
    }
    
    // Seed quotes
    private func seedInitialQuotes(_ db: Database) throws {
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
    }
    
    // MARK: - Game Methods
    
    /// Save a game to the database
    func saveGame(_ game: Game) throws -> Game {
        try dbQueue.write { db in
            var record = GameRecord(from: game)
            try record.save(db)
            
            // Return updated game with ID if it was new
            if game.gameId == nil {
                var updatedGame = game
                updatedGame.gameId = record.gameId
                return updatedGame
            }
            return game
        }
    }
    
    /// Update an existing game
    func updateGame(_ game: Game, gameId: String) throws {
        try dbQueue.write { db in
            // Since gameId is a 'let' constant, we can't modify it after creation
            // Instead of modifying the record, we'll directly use SQL to update the database
            
            // First, serialize the data
            let encoder = JSONEncoder()
            let mappingData = try encoder.encode(game.mapping.mapToStringDict())
            let reverseMappingData = try encoder.encode(game.correctMappings.mapToStringDict())
            let correctlyGuessedData = try encoder.encode(game.correctlyGuessed().map { String($0) })
            
            // Calculate derived values
            let isComplete = game.hasWon || game.hasLost
            let score = game.hasWon ? game.calculateScore() : nil
            let timeTaken = game.hasWon || game.hasLost ?
                Int(game.lastUpdateTime.timeIntervalSince(game.startTime)) : nil
            
            // Execute the update directly
            try db.execute(
                sql: """
                    UPDATE games SET 
                    currentDisplay = ?, 
                    originalText = ?,
                    encryptedText = ?,
                    solution = ?,
                    mapping = ?,
                    reverseMapping = ?,
                    correctlyGuessed = ?,
                    mistakes = ?,
                    maxMistakes = ?,
                    difficulty = ?,
                    hasWon = ?,
                    hasLost = ?,
                    isComplete = ?,
                    score = ?,
                    timeTaken = ?,
                    lastUpdated = ?
                    WHERE gameId = ?
                """,
                arguments: [
                    game.currentDisplay,
                    game.solution,
                    game.encrypted,
                    game.solution,
                    mappingData,
                    reverseMappingData,
                    correctlyGuessedData,
                    game.mistakes,
                    game.maxMistakes,
                    game.difficulty,
                    game.hasWon,
                    game.hasLost,
                    isComplete,
                    score,
                    timeTaken,
                    game.lastUpdateTime,
                    gameId
                ]
            )
        }
    }
    
    /// Load most recent unfinished game
    func loadLatestGame() throws -> Game? {
        try dbQueue.read { db in
            let record = try GameRecord
                .filter(Column("isComplete") == false)
                .order(Column("createdAt").desc)
                .fetchOne(db)
            
            return record?.toGame()
        }
    }
    
    // MARK: - Quote Methods
    
    /// Get a random quote
    func getRandomQuote(difficulty: String? = nil) throws -> (text: String, author: String, attribution: String?) {
        try dbQueue.read { db in
            var request = QuoteRecord.filter(Column("isActive") == true)
            
            // Apply difficulty filter if provided
            if let difficulty = difficulty {
                let difficultyRange: ClosedRange<Double>
                switch difficulty {
                case "easy": difficultyRange = 0.0...1.0
                case "hard": difficultyRange = 2.0...3.0
                default: difficultyRange = 1.0...2.0
                }
                
                request = request.filter(difficultyRange.contains(Column("difficulty")))
            }
            
            // Get a random quote
            let count = try request.fetchCount(db)
            guard count > 0 else {
                throw NSError(domain: "DatabaseManager", code: 404,
                             userInfo: [NSLocalizedDescriptionKey: "No quotes found"])
            }
            
            let randomIndex = Int.random(in: 0..<count)
            request = request.limit(1, offset: randomIndex)
            
            guard let quote = try request.fetchOne(db) else {
                throw NSError(domain: "DatabaseManager", code: 404,
                             userInfo: [NSLocalizedDescriptionKey: "Quote not found"])
            }
            
            // Return a tuple to match expected return type
            return (text: quote.text, author: quote.author, attribution: quote.attribution)
        }
    }
    
    // MARK: - Statistics Methods
    
    /// Update statistics after game
    func updateStatistics(userId: String, gameWon: Bool, mistakes: Int, timeTaken: Int, score: Int) throws {
        try dbQueue.write { db in
            // Check if stats exist
            let exists = try StatsRecord.filter(Column("user_id") == userId).fetchCount(db) > 0
            
            if exists {
                // Update existing stats
                try db.execute(sql: """
                    UPDATE statistics SET
                        games_played = games_played + 1,
                        games_won = games_won + ?,
                        current_streak = CASE WHEN ? THEN current_streak + 1 ELSE 0 END,
                        best_streak = CASE WHEN ? AND current_streak + 1 > best_streak 
                                      THEN current_streak + 1 ELSE best_streak END,
                        total_score = total_score + ?,
                        average_mistakes = (average_mistakes * games_played + ?) / (games_played + 1),
                        average_time = (average_time * games_played + ?) / (games_played + 1),
                        last_played_date = ?
                    WHERE user_id = ?
                """, arguments: [
                    gameWon ? 1 : 0,
                    gameWon,
                    gameWon,
                    score,
                    mistakes,
                    timeTaken,
                    Date(),
                    userId
                ])
            } else {
                // Insert new stats
                let stats = StatsRecord(
                    userId: userId,
                    gamesPlayed: 1,
                    gamesWon: gameWon ? 1 : 0,
                    currentStreak: gameWon ? 1 : 0,
                    bestStreak: gameWon ? 1 : 0,
                    totalScore: score,
                    averageMistakes: Double(mistakes),
                    averageTime: Double(timeTaken),
                    lastPlayedDate: Date()
                )
                try stats.insert(db)
            }
        }
    }
}

// MARK: - Database Records

// Quote Record
struct QuoteRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "quotes"
    
    var id: Int64?
    let text: String
    let author: String
    let attribution: String?
    let difficulty: Double
    let isDaily: Bool
    let dailyDate: Date?
    let isActive: Bool
    let timesUsed: Int
    let uniqueLetters: Int?
    let createdAt: Date
    let updatedAt: Date
    
    init(text: String, author: String, attribution: String? = nil,
         difficulty: Double, isDaily: Bool = false, dailyDate: Date? = nil,
         isActive: Bool = true, timesUsed: Int = 0, uniqueLetters: Int? = nil) {
        self.id = nil
        self.text = text
        self.author = author
        self.attribution = attribution
        self.difficulty = difficulty
        self.isDaily = isDaily
        self.dailyDate = dailyDate
        self.isActive = isActive
        self.timesUsed = timesUsed
        self.uniqueLetters = uniqueLetters ?? Set(text.uppercased().filter { $0.isLetter }).count
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    
}

// Game Record
struct GameRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "games"
    
    var id: Int64?
    let gameId: String
    let userId: String?
    let quoteId: Int64?
    let originalText: String
    let encryptedText: String
    let currentDisplay: String
    let solution: String
    let mapping: Data
    let reverseMapping: Data
    let correctlyGuessed: Data?
    let mistakes: Int
    let maxMistakes: Int
    let difficulty: String
    let hasWon: Bool
    let hasLost: Bool
    let isComplete: Bool
    let score: Int?
    let timeTaken: Int?
    let createdAt: Date
    let lastUpdated: Date
    
    // Create from Game model
    init(from game: Game) {
        self.id = nil
        self.gameId = game.gameId ?? UUID().uuidString
        self.userId = nil // This would come from your auth service
        self.quoteId = nil // Would be set if coming from a specific quote
        self.originalText = game.solution
        self.encryptedText = game.encrypted
        self.currentDisplay = game.currentDisplay
        self.solution = game.solution
        
        // Serialize mappings
        let encoder = JSONEncoder()
        self.mapping = try! encoder.encode(game.mapping.mapToStringDict())
        self.reverseMapping = try! encoder.encode(game.correctMappings.mapToStringDict())
        self.correctlyGuessed = try! encoder.encode(game.correctlyGuessed().map { String($0) })
        
        self.mistakes = game.mistakes
        self.maxMistakes = game.maxMistakes
        self.difficulty = game.difficulty
        self.hasWon = game.hasWon
        self.hasLost = game.hasLost
        self.isComplete = game.hasWon || game.hasLost
        self.score = game.hasWon ? game.calculateScore() : nil
        self.timeTaken = game.hasWon || game.hasLost ?
            Int(game.lastUpdateTime.timeIntervalSince(game.startTime)) : nil
        self.createdAt = game.startTime
        self.lastUpdated = game.lastUpdateTime
    }
    
    // Convert to Game model
    func toGame() -> Game? {
        do {
            let decoder = JSONDecoder()
            
            // Deserialize mappings
            let mappingDict = try decoder.decode([String: String].self, from: mapping)
            let reverseDict = try decoder.decode([String: String].self, from: reverseMapping)
            let guessedArray = try decoder.decode([String].self, from: correctlyGuessed ?? Data())
            
            // Convert string dictionaries to character dictionaries
            let mappingChars = mappingDict.mapToCharDict()
            let reverseChars = reverseDict.mapToCharDict()
            
            // Build guessed mappings
            var guessedMappings: [Character: Character] = [:]
            for charStr in guessedArray {
                if let char = charStr.first, let original = reverseChars[char] {
                    guessedMappings[char] = original
                }
            }
            
            // Create Game - fix parameter name to match expected initializer
            return Game(
                gameId: gameId,
                encrypted: encryptedText,
                solution: originalText, // Use originalText to avoid the mismatch issue
                currentDisplay: currentDisplay,
                mapping: mappingChars,
                correctMappings: reverseChars,
                guessedMappings: guessedMappings,
                mistakes: mistakes,
                maxMistakes: maxMistakes,
                hasWon: hasWon,
                hasLost: hasLost,
                difficulty: difficulty,
                startTime: createdAt,
                lastUpdateTime: lastUpdated  // Changed from lastUpdated to lastUpdateTime
            )
        } catch {
            print("Error converting GameRecord to Game: \(error)")
            return nil
        }
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

// Helper extensions
extension Dictionary where Key == Character, Value == Character {
    func mapToStringDict() -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in self {
            result[String(key)] = String(value)
        }
        return result
    }
}

extension Dictionary where Key == String, Value == String {
    func mapToCharDict() -> [Character: Character] {
        var result: [Character: Character] = [:]
        for (key, value) in self {
            if let keyChar = key.first, let valueChar = value.first {
                result[keyChar] = valueChar
            }
        }
        return result
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
                
                // Save quotes to database using Records
                try self.dbQueue.write { db in
                    // Clear existing quotes
                    try QuoteRecord.deleteAll(db)
                    
                    // Insert new quotes
                    for quote in quotesResponse.quotes {
                        // Create a QuoteRecord from the API quote
                        let record = QuoteRecord(
                            text: quote.text,
                            author: quote.author,
                            attribution: quote.minorAttribution,
                            difficulty: quote.difficulty,
                            isDaily: quote.dailyDate != nil,
                            dailyDate: ISO8601DateFormatter().date(from: quote.dailyDate ?? ""),
                            isActive: true,
                            timesUsed: quote.timesUsed,
                            uniqueLetters: quote.uniqueLetters
                        )
                        
                        // Save to database
                        try record.insert(db)
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
                try QuoteRecord.fetchCount(db)
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
                        print("DEBUG: Quotes synced successfully")
                    } else {
                        print("DEBUG: Failed to sync quotes: \(message ?? "Unknown error")")
                    }
                }
            }
        } catch {
            print("DEBUG: Error checking quotes table: \(error)")
        }
    }
    
}

extension DatabaseManager {
    /// Mark a specific game as abandoned
    func markGameAsAbandoned(gameId: String) throws {
        try dbQueue.write { db in
            // Update the game
            try db.execute(
                sql: "UPDATE games SET isComplete = TRUE, hasLost = TRUE WHERE gameId = ?",
                arguments: [gameId]
            )
            
            // If we affected a row, reset the player's streak
            if let gameRecord = try GameRecord.filter(Column("gameId") == gameId).fetchOne(db),
               let userId = gameRecord.userId {
                try db.execute(
                    sql: "UPDATE statistics SET current_streak = 0 WHERE user_id = ? AND current_streak > 0",
                    arguments: [userId]
                )
                print("DEBUG: Reset streak for user \(userId) due to abandoned game")
            }
        }
    }
}
//
//  DatabaseManager.swift
//  decodey
//
//  Created by Daniel Horsley on 07/05/2025.
//

