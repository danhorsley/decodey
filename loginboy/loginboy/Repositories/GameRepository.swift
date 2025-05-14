import Foundation
import GRDB

protocol GameRepositoryProtocol {
    func saveGame(_ game: Game) async throws -> Game
    func updateGame(_ game: Game, gameId: String) async throws
    func loadLatestGame() async throws -> Game?
    func loadGame(byId gameId: String) async throws -> Game?
    func markGameAsAbandoned(gameId: String) async throws
    func getGameStatistics(userId: String) async throws -> GameStatistics
    func updateStatistics(userId: String, gameWon: Bool, mistakes: Int, timeTaken: Int, score: Int) async throws
}

struct GameStatistics {
    let gamesPlayed: Int
    let gamesWon: Int
    let currentStreak: Int
    let bestStreak: Int
    let totalScore: Int
    let averageMistakes: Double
    let averageTime: Double
    let lastPlayedDate: Date?
}

/// Repository implementation for game data
class GameRepository: GameRepositoryProtocol {
    private let database: DatabaseQueue
    
    init(database: DatabaseQueue) {
        self.database = database
    }
    
    // MARK: - Game CRUD Operations
    
    /// Save a new game to the database
    func saveGame(_ game: Game) async throws -> Game {
        return try await Task {
            try database.write { db in
                var record = GameRecord(from: game)
                try record.insert(db)
                
                // Return updated game with ID if it was new
                if game.gameId == nil {
                    var updatedGame = game
                    updatedGame.gameId = record.game_id
                    return updatedGame
                }
                return game
            }
        }.value
    }
    
    /// Update an existing game
    func updateGame(_ game: Game, gameId: String) async throws {
        try await Task {
            try database.write { db in
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
                        current_display = ?, 
                        original_text = ?,
                        encrypted_text = ?,
                        solution = ?,
                        mapping = ?,
                        reverse_mapping = ?,
                        correctly_guessed = ?,
                        mistakes = ?,
                        max_mistakes = ?,
                        difficulty = ?,
                        has_won = ?,
                        has_lost = ?,
                        is_complete = ?,
                        score = ?,
                        time_taken = ?,
                        last_updated = ?
                        WHERE game_id = ?
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
        }.value
    }
    
    /// Load most recent unfinished game
    func loadLatestGame() async throws -> Game? {
        return try await Task {
            try database.read { db in
                let record = try GameRecord
                    .filter(Column("is_complete") == false)
                    .order(Column("created_at").desc)
                    .fetchOne(db)
                
                return record?.toGame()
            }
        }.value
    }
    
    /// Load a game by its ID
    func loadGame(byId gameId: String) async throws -> Game? {
        return try await Task {
            try database.read { db in
                let record = try GameRecord
                    .filter(Column("game_id") == gameId)
                    .fetchOne(db)
                
                return record?.toGame()
            }
        }.value
    }
    
    /// Mark a game as abandoned
    func markGameAsAbandoned(gameId: String) async throws {
        try await Task {
            try database.write { db in
                // Update the game
                try db.execute(
                    sql: "UPDATE games SET is_complete = TRUE, has_lost = TRUE WHERE game_id = ?",
                    arguments: [gameId]
                )
                
                // If we affected a row, reset the player's streak
                if let gameRecord = try GameRecord.filter(Column("game_id") == gameId).fetchOne(db),
                   let userId = gameRecord.user_id {
                    try db.execute(
                        sql: "UPDATE statistics SET current_streak = 0 WHERE user_id = ? AND current_streak > 0",
                        arguments: [userId]
                    )
                }
            }
        }.value
    }
    
    /// Get game statistics for a user
    func getGameStatistics(userId: String) async throws -> GameStatistics {
        return try await Task {
            try database.read { db in
                // Check if stats exist
                guard let stats = try StatsRecord.filter(Column("user_id") == userId).fetchOne(db) else {
                    // Return default stats if none exist
                    return GameStatistics(
                        gamesPlayed: 0,
                        gamesWon: 0,
                        currentStreak: 0,
                        bestStreak: 0,
                        totalScore: 0,
                        averageMistakes: 0,
                        averageTime: 0,
                        lastPlayedDate: nil
                    )
                }
                
                // Convert DB record to domain model
                return GameStatistics(
                    gamesPlayed: stats.games_played,
                    gamesWon: stats.games_won,
                    currentStreak: stats.current_streak,
                    bestStreak: stats.best_streak,
                    totalScore: stats.total_score,
                    averageMistakes: stats.average_mistakes,
                    averageTime: stats.average_time,
                    lastPlayedDate: stats.last_played_date
                )
            }
        }.value
    }
    
    // MARK: - Statistics Management
    
    /// Update statistics after game completion
    func updateStatistics(userId: String, gameWon: Bool, mistakes: Int, timeTaken: Int, score: Int) async throws {
        try await Task {
            try database.write { db in
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
                        user_id: userId,
                        games_played: 1,
                        games_won: gameWon ? 1 : 0,
                        current_streak: gameWon ? 1 : 0,
                        best_streak: gameWon ? 1 : 0,
                        total_score: score,
                        average_mistakes: Double(mistakes),
                        average_time: Double(timeTaken),
                        last_played_date: Date()
                    )
                    try stats.insert(db)
                }
            }
        }.value
    }
    
    /// Get leaderboard entries
    func getLeaderboard(period: String = "all-time", page: Int = 1, pageSize: Int = 10) async throws -> [LeaderboardEntry] {
        return try await Task {
            try database.read { db in
                // Create appropriate SQL based on the period
                let dateFilter: String
                if period == "weekly" {
                    // Get only entries from the last 7 days
                    dateFilter = "AND last_played_date >= date('now', '-7 days')"
                } else {
                    // All-time, no additional filter
                    dateFilter = ""
                }
                
                // Calculate offset for pagination
                let offset = (page - 1) * pageSize
                
                // Query for leaderboard entries
                let sql = """
                    SELECT 
                        user_id, 
                        username, 
                        total_score as score, 
                        games_played,
                        CASE WHEN games_played > 0 THEN total_score / games_played ELSE 0 END as avg_score,
                        ROW_NUMBER() OVER (ORDER BY total_score DESC) as rank
                    FROM statistics
                    JOIN users ON statistics.user_id = users.id
                    WHERE games_played > 0 \(dateFilter)
                    ORDER BY total_score DESC
                    LIMIT ? OFFSET ?
                """
                
                // Execute query and map to domain model
                let rows = try Row.fetchAll(db, sql: sql, arguments: [pageSize, offset])
                
                return rows.map { row in
                    LeaderboardEntry(
                        rank: row["rank"],
                        username: row["username"],
                        user_id: row["user_id"],
                        score: row["score"],
                        games_played: row["games_played"],
                        avg_score: row["avg_score"],
                        is_current_user: false // Will be set later
                    )
                }
            }
        }.value
    }
}

// Game Record
struct GameRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "games"
    
    var id: Int64?
    let game_id: String
    let user_id: String?
    let quote_id: Int64?
    let original_text: String
    let encrypted_text: String
    let current_display: String
    let solution: String
    let mapping: Data
    let reverse_mapping: Data
    let correctly_guessed: Data?
    let mistakes: Int
    let max_mistakes: Int
    let difficulty: String
    let has_won: Bool
    let has_lost: Bool
    let is_complete: Bool
    let score: Int?
    let time_taken: Int?
    let created_at: Date
    let last_updated: Date
    
    // Create from Game model
    init(from game: Game) {
        self.id = nil
        self.game_id = game.gameId ?? UUID().uuidString
        self.user_id = nil // This would come from your auth service
        self.quote_id = nil // Would be set if coming from a specific quote
        self.original_text = game.solution
        self.encrypted_text = game.encrypted
        self.current_display = game.currentDisplay
        self.solution = game.solution
        
        // Serialize mappings
        let encoder = JSONEncoder()
        self.mapping = try! encoder.encode(game.mapping.mapToStringDict())
        self.reverse_mapping = try! encoder.encode(game.correctMappings.mapToStringDict())
        self.correctly_guessed = try! encoder.encode(game.correctlyGuessed().map { String($0) })
        
        self.mistakes = game.mistakes
        self.max_mistakes = game.maxMistakes
        self.difficulty = game.difficulty
        self.has_won = game.hasWon
        self.has_lost = game.hasLost
        self.is_complete = game.hasWon || game.hasLost
        self.score = game.hasWon ? game.calculateScore() : nil
        self.time_taken = game.hasWon || game.hasLost ?
            Int(game.lastUpdateTime.timeIntervalSince(game.startTime)) : nil
        self.created_at = game.startTime
        self.last_updated = game.lastUpdateTime
    }
    
    // Convert to Game model
    func toGame() -> Game? {
        do {
            let decoder = JSONDecoder()
            
            // Deserialize mappings
            let mappingDict = try decoder.decode([String: String].self, from: mapping)
            let reverseDict = try decoder.decode([String: String].self, from: reverse_mapping)
            let guessedArray = try decoder.decode([String].self, from: correctly_guessed ?? Data())
            
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
            
            // Create Game
            return Game(
                gameId: game_id,
                encrypted: encrypted_text,
                solution: original_text,
                currentDisplay: current_display,
                mapping: mappingChars,
                correctMappings: reverseChars,
                guessedMappings: guessedMappings,
                mistakes: mistakes,
                maxMistakes: max_mistakes,
                hasWon: has_won,
                hasLost: has_lost,
                difficulty: difficulty,
                startTime: created_at,
                lastUpdateTime: last_updated
            )
        } catch {
            print("Error converting GameRecord to Game: \(error)")
            return nil
        }
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
