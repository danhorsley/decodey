// Create Stores.swift
import RealmSwift
import Foundation

// MARK: - Realm Manager
class RealmManager {
    static let shared = RealmManager()
    
    private var realm: Realm?
    
    private init() {
        do {
            // Get and print the default Realm path before we even try to open it
            let defaultRealmPath = Realm.Configuration.defaultConfiguration.fileURL?.path ?? "unknown"
            print("📂 Default Realm path: \(defaultRealmPath)")
            
            // Configure the default Realm
            let config = Realm.Configuration(
                schemaVersion: 2,
                migrationBlock: { migration, oldSchemaVersion in
                    if oldSchemaVersion < 1 {
                        // Nothing to migrate for the first version
                    }
                    
                    if oldSchemaVersion < 2 {
                        // Migration for adding serverId to QuoteRealm
                        migration.enumerateObjects(ofType: "QuoteRealm") { oldObject, newObject in
                            // New properties are automatically initialized with default values
                        }
                    }
                }
            )
            
            // Set default configuration
            Realm.Configuration.defaultConfiguration = config
            
            // Initialize realm
            realm = try Realm()
            
            // Print database details with emoji for visibility in console
            print("✅ Realm successfully initialized!")
            print("📊 Realm database location: \(config.fileURL?.path ?? "unknown")")
            print("🔢 Current schema version: \(config.schemaVersion)")
            
            // Create initial data if needed
            createInitialData()
            
        } catch {
            print("❌ Failed to initialize Realm: \(error.localizedDescription)")
            
            // Print additional information to help with debugging
            if let fileURL = Realm.Configuration.defaultConfiguration.fileURL {
                let fileExists = FileManager.default.fileExists(atPath: fileURL.path)
                print("📂 Realm file exists: \(fileExists)")
                
                if fileExists {
                    // Try to get file attributes for more info
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                        let fileSize = attributes[FileAttributeKey.size] as? UInt64 ?? 0
                        let modificationDate = attributes[FileAttributeKey.modificationDate] as? Date
                        
                        print("📊 Realm file size: \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))")
                        if let modDate = modificationDate {
                            print("🕒 Last modified: \(modDate)")
                        }
                    } catch {
                        print("⚠️ Could not read file attributes: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // Public method to print database info anytime
    func printDatabaseInfo() {
        guard let realm = realm else {
            print("❌ Realm not initialized")
            return
        }
        
        print("📊 Database Information:")
        print("📂 Path: \(realm.configuration.fileURL?.path ?? "unknown")")
        print("🔢 Schema Version: \(realm.configuration.schemaVersion)")
        
        // Print counts of objects
        let quotes = realm.objects(QuoteRealm.self)
        let activeQuotes = quotes.filter("isActive == true")
        let games = realm.objects(GameRealm.self)
        let users = realm.objects(UserRealm.self)
        
        print("📚 Total Quotes: \(quotes.count) (Active: \(activeQuotes.count))")
        print("🎮 Total Games: \(games.count)")
        print("👤 Total Users: \(users.count)")
        
        // Print file size
        if let fileURL = realm.configuration.fileURL {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[FileAttributeKey.size] as? UInt64 ?? 0
                print("💾 Database Size: \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))")
            } catch {
                print("⚠️ Could not get file size: \(error.localizedDescription)")
            }
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
        
        // Calculate and store score and time taken
        if game.hasWon || game.hasLost {
            gameRealm.score = game.calculateScore()
            gameRealm.timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
        }
        
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
                
                // Update score and time taken if game is completed
                if game.hasWon || game.hasLost {
                    gameRealm.score = game.calculateScore()
                    gameRealm.timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
                }
                
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
    

    
    // Helper method to convert Realm object to Game model
    private func convertToGame(_ gameRealm: GameRealm) -> Game {
        var mapping: [Character: Character] = [:]
        var correctMappings: [Character: Character] = [:]
        var guessedMappings: [Character: Character] = [:]
        
        // Convert mappings - using the correct way to iterate through Realm Map objects
        for entry in gameRealm.mapping {
            if let keyChar = entry.key.first, let valueChar = entry.value.first {
                mapping[keyChar] = valueChar
            }
        }
        
        for entry in gameRealm.correctMappings {
            if let keyChar = entry.key.first, let valueChar = entry.value.first {
                correctMappings[keyChar] = valueChar
            }
        }
        
        for entry in gameRealm.guessedMappings {
            if let keyChar = entry.key.first, let valueChar = entry.value.first {
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
        //        if let difficulty = difficulty {
        //            switch difficulty {
        //            case "easy":
        //                quotesQuery = quotesQuery.filter("difficulty <= 1.0")
        //            case "hard":
        //                quotesQuery = quotesQuery.filter("difficulty >= 2.0")
        //            default: // medium
        //                quotesQuery = quotesQuery.filter("difficulty > 1.0 AND difficulty < 2.0")
        //            }
        //        }
        
        // Get count and pick random
        let count = quotesQuery.count
        guard count > 0 else { return nil }
        
        // Use a truly random index - the previous implementation might have been using
        // a deterministic source for randomness or had a bug in the index calculation
        let randomIndex = Int.random(in: 0..<count)
        
        // Convert to array to ensure we can access elements by index properly
        let quotesArray = Array(quotesQuery)
        guard randomIndex < quotesArray.count else { return nil }
        
        // Access the quote safely
        let quote = quotesArray[randomIndex]
        
        // Update usage count
        do {
            try realm.write {
                quote.timesUsed += 1
            }
        } catch {
            print("Failed to update quote usage count: \(error.localizedDescription)")
        }
        
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
        // Ensure we have a valid auth token
        guard let token = auth.getAccessToken() else {
            print("Cannot sync quotes: No authentication token")
            completion(false)
            return
        }
        
        // Ensure we have access to Realm
        guard let realm = realm else {
            print("Cannot sync quotes: Realm not available")
            completion(false)
            return
        }
        
        // Build URL
        guard let url = URL(string: "\(auth.baseURL)/get_all_quotes") else {
            print("Cannot sync quotes: Invalid URL")
            completion(false)
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Execute request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Check for errors
            if let error = error {
                print("Network error during quote sync: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response during quote sync")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            // Check for HTTP errors
            if httpResponse.statusCode != 200 {
                print("Server error during quote sync: Status \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            // Parse response data
            guard let data = data else {
                print("No data received during quote sync")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            do {
                // Parse JSON response
                let decoder = JSONDecoder()
                let response = try decoder.decode(QuoteSyncResponse.self, from: data)
                
                guard response.success, let quotes = response.quotes else {
                    print("Server response indicated failure during quote sync")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
                
                // Process quotes on a background thread
                DispatchQueue.global(qos: .userInitiated).async {
                    self?.processServerQuotes(quotes, realm: realm) { success in
                        DispatchQueue.main.async {
                            completion(success)
                        }
                    }
                }
            } catch {
                print("Error parsing response during quote sync: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // Helper method to process server quotes and update Realm
    private func processServerQuotes(_ serverQuotes: [ServerQuote], realm: Realm, completion: @escaping (Bool) -> Void) {
        do {
            // Get all existing quotes from Realm
            let existingQuotes = realm.objects(QuoteRealm.self)
            
            // Track which quote IDs are received from the server
            var serverQuoteIds = Set<Int>()
            
            try realm.write {
                // Process each quote from the server
                for serverQuote in serverQuotes {
                    // Track this ID as seen
                    serverQuoteIds.insert(serverQuote.id)
                    
                    // Check if this quote exists in Realm
                    let existingQuote = existingQuotes.filter("id == %@", serverQuote.id).first
                    
                    if let existingQuote = existingQuote {
                        // Quote exists - update it if needed
                        updateExistingQuote(existingQuote, with: serverQuote)
                    } else {
                        // Quote doesn't exist - create it
                        createNewQuote(from: serverQuote, in: realm)
                    }
                }
                
                // Set quotes that no longer exist on the server to inactive
                for existingQuote in existingQuotes {
                    // Skip quotes that don't have a server ID yet
                    guard let quoteId = existingQuote.serverId else { continue }
                    
                    if !serverQuoteIds.contains(quoteId) {
                        existingQuote.isActive = false
                    }
                }
            }
            
            print("Successfully synchronized \(serverQuotes.count) quotes")
            completion(true)
        } catch {
            print("Error updating Realm during quote sync: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    // Helper to update an existing quote
    private func updateExistingQuote(_ quoteRealm: QuoteRealm, with serverQuote: ServerQuote) {
        // Add server ID if not set
        if quoteRealm.serverId == nil {
            quoteRealm.serverId = serverQuote.id
        }
        
        // Update quote properties
        quoteRealm.text = serverQuote.text
        quoteRealm.author = serverQuote.author
        quoteRealm.attribution = serverQuote.minor_attribution
        quoteRealm.difficulty = serverQuote.difficulty
        quoteRealm.uniqueLetters = serverQuote.unique_letters
        quoteRealm.isActive = true
        
        // Set daily date if available
        if let dailyDateString = serverQuote.daily_date,
           let dailyDate = ISO8601DateFormatter().date(from: dailyDateString) {
            quoteRealm.isDaily = true
            quoteRealm.dailyDate = dailyDate
        } else {
            quoteRealm.isDaily = false
            quoteRealm.dailyDate = nil
        }
        
        // Don't override timesUsed, as that's specific to this device
    }
    
    // Helper to create a new quote
    private func createNewQuote(from serverQuote: ServerQuote, in realm: Realm) {
        let quoteRealm = QuoteRealm()
        
        // Set primary key (generates automatically)
        
        // Set properties
        quoteRealm.serverId = serverQuote.id
        quoteRealm.text = serverQuote.text
        quoteRealm.author = serverQuote.author
        quoteRealm.attribution = serverQuote.minor_attribution
        quoteRealm.difficulty = serverQuote.difficulty
        quoteRealm.uniqueLetters = serverQuote.unique_letters
        quoteRealm.isActive = true
        quoteRealm.timesUsed = 0
        
        // Set daily date if available
        if let dailyDateString = serverQuote.daily_date,
           let dailyDate = ISO8601DateFormatter().date(from: dailyDateString) {
            quoteRealm.isDaily = true
            quoteRealm.dailyDate = dailyDate
        }
        
        // Add to Realm
        realm.add(quoteRealm)
    }
    
    // Models for server response
    struct QuoteSyncResponse: Codable {
        let success: Bool
        let quotes_count: Int?
        let quotes: [ServerQuote]?
        let error: String?
        let message: String?
    }
    
    struct ServerQuote: Codable {
        let id: Int
        let text: String
        let author: String
        let minor_attribution: String?
        let difficulty: Double
        let daily_date: String?
        let times_used: Int?
        let unique_letters: Int
        let created_at: String?
        let updated_at: String?
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

