import Foundation
import CoreData

// MARK: - QuoteStore
class QuoteStore {
    static let shared = QuoteStore()
    
    private let coreData = CoreDataStack.shared
    
    // Get random quote
    func getRandomQuote(difficulty: String? = nil) -> Quote? {
        let context = coreData.mainContext
        
        let fetchRequest = NSFetchRequest<Quote>(entityName: "Quote")
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            let quotes = try context.fetch(fetchRequest)
            
            // Get count and pick random
            let count = quotes.count
            guard count > 0 else { return nil }
            
            // Use a truly random index
            let randomIndex = Int.random(in: 0..<count)
            let quote = quotes[randomIndex]
            
            // Update usage count
            coreData.performBackgroundTask { context in
                if let quoteID = quote.id {
                    // Get the object in this background context
                    let objectID = quote.objectID
                    let backgroundQuote = context.object(with: objectID) as! Quote
                    backgroundQuote.timesUsed += 1
                    
                    do {
                        try context.save()
                    } catch {
                        print("Failed to update quote usage count: \(error.localizedDescription)")
                    }
                }
            }
            
            return quote
        } catch {
            print("Error fetching random quote: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Get daily quote
    func getDailyQuote() -> Quote? {
        let context = coreData.mainContext
        
        // Create a date formatter to check for daily quotes
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Find quote for today
        let fetchRequest = NSFetchRequest<Quote>(entityName: "Quote")
        fetchRequest.predicate = NSPredicate(format: "isDaily == YES AND dailyDate >= %@ AND dailyDate < %@", today as NSDate, tomorrow as NSDate)
        
        do {
            let quotes = try context.fetch(fetchRequest)
            return quotes.first
        } catch {
            print("Error fetching daily quote: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Add quotes
    func addQuotes(_ quotes: [QuoteModel]) {
        coreData.performBackgroundTask { context in
            for quoteModel in quotes {
                let quote = Quote(context: context)
                quote.id = UUID()
                quote.text = quoteModel.text
                quote.author = quoteModel.author
                quote.attribution = quoteModel.attribution
                quote.difficulty = quoteModel.difficulty ?? 1.0
                quote.uniqueLetters = Int16(Set(quoteModel.text.filter { $0.isLetter }).count)
                quote.isActive = true
                quote.timesUsed = 0
            }
            
            do {
                try context.save()
            } catch {
                print("Error adding quotes: \(error.localizedDescription)")
            }
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
                    self?.processServerQuotes(quotes) { success in
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
    
    // Helper method to process server quotes and update Core Data
    private func processServerQuotes(_ serverQuotes: [ServerQuote], completion: @escaping (Bool) -> Void) {
        coreData.performBackgroundTask { context in
            // Get all existing quotes from Core Data
            let fetchRequest = NSFetchRequest<Quote>(entityName: "Quote")
            
            do {
                let existingQuotes = try context.fetch(fetchRequest)
                
                // Track which quote IDs are received from the server
                var serverQuoteIds = Set<Int32>()
                
                // Process each quote from the server
                for serverQuote in serverQuotes {
                    // Track this ID as seen
                    serverQuoteIds.insert(Int32(serverQuote.id))
                    
                    // Check if this quote exists in Core Data
                    let existingQuote = existingQuotes.first(where: { $0.serverId == Int32(serverQuote.id) })
                    
                    if let existingQuote = existingQuote {
                        // Quote exists - update it if needed
                        self.updateExistingQuote(existingQuote, with: serverQuote)
                    } else {
                        // Quote doesn't exist - create it
                        self.createNewQuote(from: serverQuote, in: context)
                    }
                }
                
                // Set quotes that no longer exist on the server to inactive
                for existingQuote in existingQuotes {
                    if existingQuote.serverId > 0 && !serverQuoteIds.contains(existingQuote.serverId) {
                        existingQuote.isActive = false
                    }
                }
                
                // Save the changes
                try context.save()
                print("Successfully synchronized \(serverQuotes.count) quotes")
                completion(true)
            } catch {
                print("Error updating Core Data during quote sync: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // Helper to update an existing quote
    private func updateExistingQuote(_ quote: Quote, with serverQuote: ServerQuote) {
        // Update quote properties
        quote.text = serverQuote.text
        quote.author = serverQuote.author
        quote.attribution = serverQuote.minor_attribution
        quote.difficulty = serverQuote.difficulty
        quote.uniqueLetters = Int16(serverQuote.unique_letters)
        quote.isActive = true
        
        // Set daily date if available
        if let dailyDateString = serverQuote.daily_date,
           let dailyDate = ISO8601DateFormatter().date(from: dailyDateString) {
            quote.isDaily = true
            quote.dailyDate = dailyDate
        } else {
            quote.isDaily = false
            quote.dailyDate = nil
        }
        
        // Don't override timesUsed, as that's specific to this device
    }
    
    // Helper to create a new quote
    private func createNewQuote(from serverQuote: ServerQuote, in context: NSManagedObjectContext) {
        let quote = Quote(context: context)
        
        // Set properties
        quote.id = UUID()
        quote.serverId = Int32(serverQuote.id)
        quote.text = serverQuote.text
        quote.author = serverQuote.author
        quote.attribution = serverQuote.minor_attribution
        quote.difficulty = serverQuote.difficulty
        quote.uniqueLetters = Int16(serverQuote.unique_letters)
        quote.isActive = true
        quote.timesUsed = 0
        
        // Set daily date if available
        if let dailyDateString = serverQuote.daily_date,
           let dailyDate = ISO8601DateFormatter().date(from: dailyDateString) {
            quote.isDaily = true
            quote.dailyDate = dailyDate
        }
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

// MARK: - GameStore
class GameStore {
    static let shared = GameStore()
    
    private let coreData = CoreDataStack.shared
    
    // Save game
    func saveGame(_ game: GameModel) -> GameModel? {
        let context = coreData.mainContext
        
        let newGame = Game(context: context)
        newGame.id = UUID()
        newGame.setValue(game.gameId ?? UUID().uuidString, forKey: "gameId")
        newGame.encrypted = game.encrypted
        newGame.solution = game.solution
        newGame.currentDisplay = game.currentDisplay
        newGame.mistakes = Int16(game.mistakes)
        newGame.maxMistakes = Int16(game.maxMistakes)
        newGame.hasWon = game.hasWon
        newGame.hasLost = game.hasLost
        newGame.difficulty = game.difficulty
        newGame.startTime = game.startTime
        newGame.lastUpdateTime = game.lastUpdateTime
        newGame.isDaily = game.gameId?.starts(with: "daily-") ?? false
        
        // Calculate and store score and time taken
        if game.hasWon || game.hasLost {
            newGame.score = Int32(game.calculateScore())
            newGame.timeTaken = Int32(game.lastUpdateTime.timeIntervalSince(game.startTime))
        }
        
        // Store mappings as serialized data
        do {
            newGame.mappingData = try JSONEncoder().encode(game.mapping.mapToDictionary())
            newGame.correctMappingsData = try JSONEncoder().encode(game.correctMappings.mapToDictionary())
            newGame.guessedMappingsData = try JSONEncoder().encode(game.guessedMappings.mapToDictionary())
        } catch {
            print("Error encoding mappings: \(error.localizedDescription)")
        }
        
        // Save to Core Data
        do {
            try context.save()
            
            // Return updated game with gameId
            var updatedGame = game
            updatedGame.gameId = newGame.gameId
            return updatedGame
        } catch {
            print("Error saving game: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Update game
    func updateGame(_ game: GameModel) -> Bool {
        let context = coreData.mainContext
        
        // Find existing game
        guard let gameId = game.gameId else { return false }
        
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameId)
        
        do {
            let results = try context.fetch(fetchRequest)
            guard let existingGame = results.first else { return false }
            
            // Update game properties
            existingGame.encrypted = game.encrypted
            existingGame.solution = game.solution
            existingGame.currentDisplay = game.currentDisplay
            existingGame.mistakes = Int16(game.mistakes)
            existingGame.maxMistakes = Int16(game.maxMistakes)
            existingGame.hasWon = game.hasWon
            existingGame.hasLost = game.hasLost
            existingGame.difficulty = game.difficulty
            existingGame.lastUpdateTime = game.lastUpdateTime
            
            // Update score and time taken if game is completed
            if game.hasWon || game.hasLost {
                existingGame.score = Int32(game.calculateScore())
                existingGame.timeTaken = Int32(game.lastUpdateTime.timeIntervalSince(game.startTime))
            }
            
            // Update mappings
            do {
                existingGame.mappingData = try JSONEncoder().encode(game.mapping.mapToDictionary())
                existingGame.correctMappingsData = try JSONEncoder().encode(game.correctMappings.mapToDictionary())
                existingGame.guessedMappingsData = try JSONEncoder().encode(game.guessedMappings.mapToDictionary())
            } catch {
                print("Error encoding mappings: \(error.localizedDescription)")
            }
            
            // Save changes
            try context.save()
            return true
        } catch {
            print("Error updating game: \(error.localizedDescription)")
            return false
        }
    }
    
    // Load latest unfinished game
    func loadLatestGame() -> GameModel? {
        let context = coreData.mainContext
        
        // Query for unfinished games
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "hasWon == NO AND hasLost == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastUpdateTime", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let games = try context.fetch(fetchRequest)
            guard let latestGame = games.first else { return nil }
            return convertToGameModel(latestGame)
        } catch {
            print("Error loading latest game: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Helper method to convert Core Data object to Game model
    private func convertToGameModel(_ game: Game) -> GameModel {
        var mapping: [Character: Character] = [:]
        var correctMappings: [Character: Character] = [:]
        var guessedMappings: [Character: Character] = [:]
        
        // Deserialize mappings
        if let mappingData = game.mappingData,
           let mappingDict = try? JSONDecoder().decode([String: String].self, from: mappingData) {
            mapping = mappingDict.convertToCharacterDictionary()
        }
        
        if let correctMappingsData = game.correctMappingsData,
           let correctDict = try? JSONDecoder().decode([String: String].self, from: correctMappingsData) {
            correctMappings = correctDict.convertToCharacterDictionary()
        }
        
        if let guessedMappingsData = game.guessedMappingsData,
           let guessedDict = try? JSONDecoder().decode([String: String].self, from: guessedMappingsData) {
            guessedMappings = guessedDict.convertToCharacterDictionary()
        }
        
        return GameModel(
            gameId: game.value(forKey: "gameId") as? String,
            encrypted: game.encrypted ?? "",
            solution: game.solution ?? "",
            currentDisplay: game.currentDisplay ?? "",
            mapping: mapping,
            correctMappings: correctMappings,
            guessedMappings: guessedMappings,
            mistakes: Int(game.mistakes),
            maxMistakes: Int(game.maxMistakes),
            hasWon: game.hasWon,
            hasLost: game.hasLost,
            difficulty: game.difficulty ?? "medium",
            startTime: game.startTime ?? Date(),
            lastUpdateTime: game.lastUpdateTime ?? Date()
        )
    }
    
    // Update user stats after game
    func updateStats(userId: String, gameWon: Bool, mistakes: Int, timeTaken: Int, score: Int) {
        let context = coreData.mainContext
        
        // Find user
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first else { return }
            
            // Get or create stats
            let stats: UserStats
            if let existingStats = user.stats {
                stats = existingStats
            } else {
                stats = UserStats(context: context)
                user.stats = stats
                stats.user = user
            }
            
            // Update stats
            stats.gamesPlayed += 1
            if gameWon {
                stats.gamesWon += 1
                stats.currentStreak += 1
                stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
            } else {
                stats.currentStreak = 0
            }
            
            stats.totalScore += Int32(score)
            
            // Update averages
            let oldMistakesTotal = stats.averageMistakes * Double(stats.gamesPlayed - 1)
            stats.averageMistakes = (oldMistakesTotal + Double(mistakes)) / Double(stats.gamesPlayed)
            
            let oldTimeTotal = stats.averageTime * Double(stats.gamesPlayed - 1)
            stats.averageTime = (oldTimeTotal + Double(timeTaken)) / Double(stats.gamesPlayed)
            
            stats.lastPlayedDate = Date()
            
            // Save the changes
            try context.save()
        } catch {
            print("Error updating stats: \(error.localizedDescription)")
        }
    }
}
// MARK: - UserStore
class UserStore {
    static let shared = UserStore()
    
    private let coreData = CoreDataStack.shared
    
    // Get user
    func getUser(userId: String) -> User? {
        let context = coreData.mainContext
        
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            return users.first
        } catch {
            print("Error fetching user: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Save user
    func saveUser(_ userModel: UserModel) -> Bool {
        let context = coreData.mainContext
        
        // Check if user already exists
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userModel.userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            
            let user: User
            if let existingUser = users.first {
                // Update existing user
                user = existingUser
            } else {
                // Create new user
                user = User(context: context)
                user.id = UUID()
                user.userId = userModel.userId
            }
            
            // Update properties
            user.username = userModel.username
            user.email = userModel.email
            user.displayName = userModel.displayName
            user.avatarUrl = userModel.avatarUrl
            user.bio = userModel.bio
            user.registrationDate = userModel.registrationDate
            user.lastLoginDate = userModel.lastLoginDate
            user.isActive = userModel.isActive
            user.isVerified = userModel.isVerified
            user.isSubadmin = userModel.isSubadmin
            
            // Save changes
            try context.save()
            return true
        } catch {
            print("Error saving user: \(error.localizedDescription)")
            return false
        }
    }
    
    // Update user preferences
    func updatePreferences(userId: String, preferences: UserPreferencesModel) -> Bool {
        let context = coreData.mainContext
        
        // Find user
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first else { return false }
            
            // Get or create preferences
            let userPrefs: UserPreferences
            if let existingPrefs = user.preferences {
                userPrefs = existingPrefs
            } else {
                userPrefs = UserPreferences(context: context)
                user.preferences = userPrefs
                userPrefs.user = user
            }
            
            // Update properties
            userPrefs.darkMode = preferences.darkMode
            userPrefs.showTextHelpers = preferences.showTextHelpers
            userPrefs.accessibilityTextSize = preferences.accessibilityTextSize
            userPrefs.gameDifficulty = preferences.gameDifficulty
            userPrefs.soundEnabled = preferences.soundEnabled
            userPrefs.soundVolume = preferences.soundVolume
            userPrefs.useBiometricAuth = preferences.useBiometricAuth
            userPrefs.notificationsEnabled = preferences.notificationsEnabled
            userPrefs.lastSyncDate = preferences.lastSyncDate
            
            // Save changes
            try context.save()
            return true
        } catch {
            print("Error updating preferences: \(error.localizedDescription)")
            return false
        }
    }
    
    // Get user stats
    func getUserStats(userId: String) -> UserStatsModel? {
        let context = coreData.mainContext
        
        // Find user
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first, let stats = user.stats else { return nil }
            
            return UserStatsModel(
                userId: user.userId,
                gamesPlayed: Int(stats.gamesPlayed),
                gamesWon: Int(stats.gamesWon),
                currentStreak: Int(stats.currentStreak),
                bestStreak: Int(stats.bestStreak),
                totalScore: Int(stats.totalScore),
                averageScore: stats.gamesPlayed > 0 ? Double(stats.totalScore) / Double(stats.gamesPlayed) : 0,
                averageTime: stats.averageTime,
                lastPlayedDate: stats.lastPlayedDate
            )
        } catch {
            print("Error fetching user stats: \(error.localizedDescription)")
            return nil
        }
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

//
//  DataStores.swift
//  loginboy
//
//  Created by Daniel Horsley on 19/05/2025.
//

