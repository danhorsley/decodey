// Create Stores.swift
import RealmSwift
import Foundation

// MARK: - Realm Manager
class RealmManager {
    static let shared = RealmManager()
    
    private var realm: Realm?
    
    private init() {
        do {
            // Configure the default Realm
            let config = Realm.Configuration(
                schemaVersion: 1,
                migrationBlock: { _, oldSchemaVersion in
                    // Handle schema migrations if needed
                    if oldSchemaVersion < 1 {
                        // Nothing to migrate for the first version
                    }
                }
            )
            
            // Set default configuration
            Realm.Configuration.defaultConfiguration = config
            
            // Initialize realm
            realm = try Realm()
            print("Realm initialized at: \(config.fileURL?.path ?? "unknown")")
            
            // Create initial data if needed
            createInitialData()
            
        } catch {
            print("Failed to initialize Realm: \(error.localizedDescription)")
        }
    }
    
    func getRealm() -> Realm? {
        return realm
    }
    
    // Create initial quotes if database is empty
    private func createInitialData() {
        guard let realm = realm else { return }
        
        // Only seed if no quotes exist
        if realm.objects(QuoteRealm.self).count == 0 {
            print("Adding initial quotes to Realm database...")
            
            // Default quotes
            let defaultQuotes = [
                (text: "THE EARLY BIRD CATCHES THE WORM.", author: "John Ray", difficulty: 1.0),
                (text: "KNOWLEDGE IS POWER.", author: "Francis Bacon", difficulty: 0.8),
                (text: "TIME WAITS FOR NO ONE.", author: "Geoffrey Chaucer", difficulty: 1.0),
                (text: "BE YOURSELF; EVERYONE ELSE IS ALREADY TAKEN.", author: "Oscar Wilde", difficulty: 1.5),
                (text: "THE JOURNEY OF A THOUSAND MILES BEGINS WITH A SINGLE STEP.", author: "Lao Tzu", difficulty: 2.0)
            ]
            
            do {
                try realm.write {
                    for quoteData in defaultQuotes {
                        let quote = QuoteRealm()
                        quote.text = quoteData.text
                        quote.author = quoteData.author
                        quote.difficulty = quoteData.difficulty
                        quote.uniqueLetters = Set(quoteData.text.filter { $0.isLetter }).count
                        quote.isActive = true
                        
                        realm.add(quote)
                    }
                }
                print("Added \(defaultQuotes.count) initial quotes")
            } catch {
                print("Error adding initial quotes: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Game Store
class GameStore {
    static let shared = GameStore()
    private let realm = RealmManager.shared.getRealm()
    
    // Save game
    func saveGame(_ game: Game) -> Game? {
        guard let realm = realm else { return nil }
        
        let gameRealm = GameRealm()
        gameRealm.gameId = game.gameId ?? UUID().uuidString
        gameRealm.encrypted = game.encrypted
        gameRealm.solution = game.solution
        gameRealm.currentDisplay = game.currentDisplay
        gameRealm.mistakes = game.mistakes
        gameRealm.maxMistakes = game.maxMistakes
        gameRealm.hasWon = game.hasWon
        gameRealm.hasLost = game.hasLost
        gameRealm.difficulty = game.difficulty
        gameRealm.startTime = game.startTime
        gameRealm.lastUpdateTime = game.lastUpdateTime
        gameRealm.isDaily = game.gameId?.starts(with: "daily-") ?? false
        
        // Store mappings
        for (key, value) in game.mapping {
            gameRealm.mapping[String(key)] = String(value)
        }
        
        for (key, value) in game.correctMappings {
            gameRealm.correctMappings[String(key)] = String(value)
        }
        
        for (key, value) in game.guessedMappings {
            gameRealm.guessedMappings[String(key)] = String(value)
        }
        
        do {
            try realm.write {
                realm.add(gameRealm, update: .modified)
            }
            
            // Return updated game with gameId
            var updatedGame = game
            updatedGame.gameId = gameRealm.gameId
            return updatedGame
        } catch {
            print("Error saving game: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Load latest unfinished game
    func loadLatestGame() -> Game? {
        guard let realm = realm else { return nil }
        
        // Query for unfinished games
        let games = realm.objects(GameRealm.self)
            .filter("hasWon == false AND hasLost == false")
            .sorted(byKeyPath: "lastUpdateTime", ascending: false)
        
        guard let latestGame = games.first else { return nil }
        return convertToGame(latestGame)
    }
    
    // Update game
    func updateGame(_ game: Game) -> Bool {
        guard let realm = realm, let gameId = game.gameId else { return false }
        
        guard let gameRealm = realm.object(ofType: GameRealm.self, forPrimaryKey: gameId) else {
            return false
        }
        
        do {
            try realm.write {
                gameRealm.encrypted = game.encrypted
                gameRealm.solution = game.solution
                gameRealm.currentDisplay = game.currentDisplay
                gameRealm.mistakes = game.mistakes
                gameRealm.maxMistakes = game.maxMistakes
                gameRealm.hasWon = game.hasWon
                gameRealm.hasLost = game.hasLost
                gameRealm.difficulty = game.difficulty
                gameRealm.lastUpdateTime = game.lastUpdateTime
                
                // Clear and update mappings
                gameRealm.mapping.removeAll()
                gameRealm.correctMappings.removeAll()
                gameRealm.guessedMappings.removeAll()
                
                for (key, value) in game.mapping {
                    gameRealm.mapping[String(key)] = String(value)
                }
                
                for (key, value) in game.correctMappings {
                    gameRealm.correctMappings[String(key)] = String(value)
                }
                
                for (key, value) in game.guessedMappings {
                    gameRealm.guessedMappings[String(key)] = String(value)
                }
            }
            return true
        } catch {
            print("Error updating game: \(error.localizedDescription)")
            return false
        }
    }
    
    // Helper method to convert Realm object to Game model
    private func convertToGame(_ gameRealm: GameRealm) -> Game {
        var mapping: [Character: Character] = [:]
        var correctMappings: [Character: Character] = [:]
        var guessedMappings: [Character: Character] = [:]
        
        // Convert mappings
        for (key, value) in gameRealm.mapping {
            if let keyChar = key.first, let valueChar = value.first {
                mapping[keyChar] = valueChar
            }
        }
        
        for (key, value) in gameRealm.correctMappings {
            if let keyChar = key.first, let valueChar = value.first {
                correctMappings[keyChar] = valueChar
            }
        }
        
        for (key, value) in gameRealm.guessedMappings {
            if let keyChar = key.first, let valueChar = value.first {
                guessedMappings[keyChar] = valueChar
            }
        }
        
        return Game(
            gameId: gameRealm.gameId,
            encrypted: gameRealm.encrypted,
            solution: gameRealm.solution,
            currentDisplay: gameRealm.currentDisplay,
            mapping: mapping,
            correctMappings: correctMappings,
            guessedMappings: guessedMappings,
            mistakes: gameRealm.mistakes,
            maxMistakes: gameRealm.maxMistakes,
            hasWon: gameRealm.hasWon,
            hasLost: gameRealm.hasLost,
            difficulty: gameRealm.difficulty,
            startTime: gameRealm.startTime,
            lastUpdateTime: gameRealm.lastUpdateTime
        )
    }
    
    // Update user stats after game
    func updateStats(userId: String, gameWon: Bool, mistakes: Int, timeTaken: Int, score: Int) {
        guard let realm = realm else { return }
        
        do {
            try realm.write {
                // Find or create user stats
                guard let user = realm.object(ofType: UserRealm.self, forPrimaryKey: userId) else {
                    return
                }
                
                if user.stats == nil {
                    user.stats = UserStatsRealm()
                }
                
                guard let stats = user.stats else { return }
                
                // Update stats
                stats.gamesPlayed += 1
                if gameWon {
                    stats.gamesWon += 1
                    stats.currentStreak += 1
                    stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
                } else {
                    stats.currentStreak = 0
                }
                
                stats.totalScore += score
                
                // Update averages
                let oldMistakesTotal = stats.averageMistakes * Double(stats.gamesPlayed - 1)
                stats.averageMistakes = (oldMistakesTotal + Double(mistakes)) / Double(stats.gamesPlayed)
                
                let oldTimeTotal = stats.averageTime * Double(stats.gamesPlayed - 1)
                stats.averageTime = (oldTimeTotal + Double(timeTaken)) / Double(stats.gamesPlayed)
                
                stats.lastPlayedDate = Date()
            }
        } catch {
            print("Error updating stats: \(error.localizedDescription)")
        }
    }
}

// MARK: - Quote Store
class QuoteStore {
    static let shared = QuoteStore()
    private let realm = RealmManager.shared.getRealm()
    
    // Get random quote
    func getRandomQuote(difficulty: String? = nil) -> Quote? {
        guard let realm = realm else { return nil }
        
        var quotesQuery = realm.objects(QuoteRealm.self).filter("isActive == true")
        
        // Apply difficulty filter if provided
        if let difficulty = difficulty {
            switch difficulty {
            case "easy":
                quotesQuery = quotesQuery.filter("difficulty <= 1.0")
            case "hard":
                quotesQuery = quotesQuery.filter("difficulty >= 2.0")
            default: // medium
                quotesQuery = quotesQuery.filter("difficulty > 1.0 AND difficulty < 2.0")
            }
        }
        
        // Get count and pick random
        let count = quotesQuery.count
        guard count > 0 else { return nil }
        
        let randomIndex = Int.random(in: 0..<count)
        guard let quote = quotesQuery[safe: randomIndex] else { return nil }
        
        return quote.toQuote()
    }
    
    // Get daily quote
    func getDailyQuote() -> DailyQuote? {
        guard let realm = realm else { return nil }
        
        // Create a date formatter to check for daily quotes
        let dateFormatter = ISO8601DateFormatter()
        let today = Calendar.current.startOfDay(for: Date())
        
        // Find quote for today
        let dailyQuotes = realm.objects(QuoteRealm.self)
            .filter("isDaily == true AND dailyDate >= %@ AND dailyDate < %@",
                    today, Calendar.current.date(byAdding: .day, value: 1, to: today)!)
        
        if let quote = dailyQuotes.first {
            return DailyQuote(
                id: 0, // We don't need this for Realm
                text: quote.text,
                author: quote.author,
                minor_attribution: quote.attribution,
                difficulty: quote.difficulty,
                date: dateFormatter.string(from: today),
                unique_letters: quote.uniqueLetters
            )
        }
        
        return nil
    }
    
    // Add quotes
    func addQuotes(_ quotes: [Quote]) {
        guard let realm = realm else { return }
        
        do {
            try realm.write {
                for quote in quotes {
                    let quoteRealm = QuoteRealm()
                    quoteRealm.text = quote.text
                    quoteRealm.author = quote.author
                    quoteRealm.attribution = quote.attribution
                    quoteRealm.difficulty = quote.difficulty
                    quoteRealm.uniqueLetters = Set(quote.text.filter { $0.isLetter }).count
                    
                    realm.add(quoteRealm)
                }
            }
        } catch {
            print("Error adding quotes: \(error.localizedDescription)")
        }
    }
    
    // Sync quotes from server
    func syncQuotesFromServer(auth: AuthenticationCoordinator, completion: @escaping (Bool) -> Void) {
        // Implementation for syncing quotes from server
        // This calls your API and updates the local Realm
    }
}

// MARK: - User Store
class UserStore {
    static let shared = UserStore()
    private let realm = RealmManager.shared.getRealm()
    
    // Get user
    func getUser(userId: String) -> UserRealm? {
        guard let realm = realm else { return nil }
        return realm.object(ofType: UserRealm.self, forPrimaryKey: userId)
    }
    
    // Save user
    func saveUser(_ user: UserRealm) -> Bool {
        guard let realm = realm else { return false }
        
        do {
            try realm.write {
                realm.add(user, update: .modified)
            }
            return true
        } catch {
            print("Error saving user: \(error.localizedDescription)")
            return false
        }
    }
    
    // Update user preferences
    func updatePreferences(userId: String, preferences: UserPreferencesRealm) -> Bool {
        guard let realm = realm else { return false }
        
        guard let user = realm.object(ofType: UserRealm.self, forPrimaryKey: userId) else {
            return false
        }
        
        do {
            try realm.write {
                user.preferences = preferences
            }
            return true
        } catch {
            print("Error updating preferences: \(error.localizedDescription)")
            return false
        }
    }
    
    // Get user stats
    func getUserStats(userId: String) -> UserStatsRealm? {
        guard let realm = realm, let user = realm.object(ofType: UserRealm.self, forPrimaryKey: userId) else {
            return nil
        }
        
        return user.stats
    }
}

//
//  Stores.swift
//  loginboy
//
//  Created by Daniel Horsley on 14/05/2025.
//

