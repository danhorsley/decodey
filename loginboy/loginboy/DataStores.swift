import Foundation
import CoreData
import SwiftUI

// MARK: - QuoteStore
class QuoteStore {
    static let shared = QuoteStore()
    
    private let coreData = CoreDataStack.shared
    
    // Get random quote
    func getRandomQuote(difficulty: String? = nil) -> QuoteCD? {
        let context = coreData.mainContext
        
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
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
                    let backgroundQuote = context.object(with: objectID) as! QuoteCD
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
    func getDailyQuote() -> QuoteCD? {
        let context = coreData.mainContext
        
        // Create a date formatter to check for daily quotes
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Find quote for today
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
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
                let quote = QuoteCD(context: context)
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
        guard let url = URL(string: "\(auth.baseURL)/api/quotes") else {
            print("Cannot sync quotes: Invalid URL")
            completion(false)
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Execute request
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Check for errors
            if let error = error {
                print("Network error during quote sync: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response during quote sync")
                completion(false)
                return
            }
            
            // Check for HTTP errors
            if httpResponse.statusCode != 200 {
                print("Server error during quote sync: Status \(httpResponse.statusCode)")
                completion(false)
                return
            }
            
            // Parse response data
            guard let data = data else {
                print("No data received during quote sync")
                completion(false)
                return
            }
            
            do {
                // Parse JSON response
                let decoder = JSONDecoder()
                let response = try decoder.decode(QuoteSyncResponse.self, from: data)
                
                guard response.success, let quotes = response.quotes else {
                    print("Server response indicated failure during quote sync")
                    completion(false)
                    return
                }
                
                // Process quotes on a background thread
                self?.processServerQuotes(quotes) { success in
                    completion(success)
                }
            } catch {
                print("Error parsing response during quote sync: \(error.localizedDescription)")
                completion(false)
            }
        }.resume()
    }
    
    // Helper method to process server quotes and update Core Data
    private func processServerQuotes(_ serverQuotes: [ServerQuote], completion: @escaping (Bool) -> Void) {
        // Use a background context for better performance
        coreData.performBackgroundTask { context in
            print("Processing \(serverQuotes.count) quotes from server...")
            
            // Get all existing quotes from Core Data
            let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
            
            do {
                let existingQuotes = try context.fetch(fetchRequest)
                print("Found \(existingQuotes.count) existing quotes in database")
                
                // Create a dictionary of existing quotes by server ID for faster lookup
                var existingQuotesByServerId = [Int32: QuoteCD]()
                for quote in existingQuotes where quote.serverId > 0 {
                    existingQuotesByServerId[quote.serverId] = quote
                }
                
                // Track which quote IDs are received from the server
                var serverQuoteIds = Set<Int32>()
                var updatedCount = 0
                var createdCount = 0
                
                // Process each quote from the server
                for serverQuote in serverQuotes {
                    let serverId = Int32(serverQuote.id)
                    
                    // Track this ID as seen
                    serverQuoteIds.insert(serverId)
                    
                    // Check if this quote exists in Core Data
                    if let existingQuote = existingQuotesByServerId[serverId] {
                        // Quote exists - update it if needed
                        self.updateExistingQuote(existingQuote, with: serverQuote)
                        updatedCount += 1
                    } else {
                        // Quote doesn't exist - create it
                        self.createNewQuote(from: serverQuote, in: context)
                        createdCount += 1
                    }
                }
                
                // Set quotes that no longer exist on the server to inactive
                var deactivatedCount = 0
                for existingQuote in existingQuotes {
                    if existingQuote.serverId > 0 && !serverQuoteIds.contains(existingQuote.serverId) {
                        existingQuote.isActive = false
                        deactivatedCount += 1
                    }
                }
                
                // Save the changes
                if context.hasChanges {
                    try context.save()
                    print("✅ Quote sync complete: Updated \(updatedCount), Created \(createdCount), Deactivated \(deactivatedCount)")
                    
                    // Update last sync timestamp in UserDefaults
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(Date(), forKey: "lastQuoteSyncDate")
                    }
                    
                    completion(true)
                } else {
                    print("No changes needed during quote sync")
                    completion(true)
                }
            } catch {
                print("Error updating Core Data during quote sync: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // Helper to update an existing quote
    private func updateExistingQuote(_ quote: QuoteCD, with serverQuote: ServerQuote) {
        // Only update if there are actual changes to avoid unnecessary Core Data changes
        let needsUpdate = quote.text != serverQuote.text ||
        quote.author != serverQuote.author ||
        quote.attribution != serverQuote.minor_attribution ||
        abs(quote.difficulty - serverQuote.difficulty) > 0.001 ||
        Int(quote.uniqueLetters) != serverQuote.unique_letters ||
        !quote.isActive
        
        if needsUpdate {
            // Update quote properties
            quote.text = serverQuote.text
            quote.author = serverQuote.author
            quote.attribution = serverQuote.minor_attribution
            quote.difficulty = serverQuote.difficulty
            quote.uniqueLetters = Int16(serverQuote.unique_letters)
            quote.isActive = true
        }
        
        // Set daily date if available
        if let dailyDateString = serverQuote.daily_date,
           let dailyDate = ISO8601DateFormatter().date(from: dailyDateString) {
            quote.isDaily = true
            quote.dailyDate = dailyDate
        } else if quote.isDaily && quote.dailyDate != nil {
            // Only update if there's a change
            quote.isDaily = false
            quote.dailyDate = nil
        }
        
        // Don't override timesUsed, as that's specific to this device
    }
    
    // Helper to create a new quote
    private func createNewQuote(from serverQuote: ServerQuote, in context: NSManagedObjectContext) {
        let quote = QuoteCD(context: context)
        
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
        } else {
            quote.isDaily = false
        }
    }
    
    // Add a method to check daily challenge availability
    func hasDailyChallenge(forDate date: Date = Date()) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        fetchRequest.predicate = NSPredicate(format: "isDaily == YES AND dailyDate >= %@ AND dailyDate < %@",
                                             startOfDay as NSDate, endOfDay as NSDate)
        fetchRequest.fetchLimit = 1
        
        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            print("Error checking for daily challenge: \(error)")
            return false
        }
    }
    
    // Models for server response
    struct QuoteSyncResponse: Codable {
        let success: Bool
        let quotes_count: Int?
        let quotes: [ServerQuote]?
        let error: String?
        let message: String?
        
        // Add a computed property to get a user-friendly error message
        var errorMessage: String {
            if let error = error {
                return error
            } else if let message = message, !success {
                return message
            } else {
                return "Unknown error occurred"
            }
        }
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
        
        // Add validation and conversion methods
        func isValid() -> Bool {
            // Basic validation to avoid completely broken quotes
            return !text.isEmpty &&
            !author.isEmpty &&
            unique_letters > 0 &&
            difficulty >= 0
        }
        
        // Helper to get daily date as a Date object
        func getDailyDate() -> Date? {
            guard let dateString = daily_date else { return nil }
            
            // Try ISO8601 format first
            let isoFormatter = ISO8601DateFormatter()
            if let date = isoFormatter.date(from: dateString) {
                return date
            }
            
            // Try alternative formats
            let dateFormatter = DateFormatter()
            let formats = ["yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss"]
            
            for format in formats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: dateString) {
                    return date
                }
            }
            
            return nil
        }
    }
    
}

// MARK: - GameStore
class GameStore {
    static let shared = GameStore()
    
    private let coreData = CoreDataStack.shared
    
    // Save game
    func saveGame(_ game: GameModel) -> GameModel? {
        let context = coreData.mainContext
        
        let newGame = GameCD(context: context)
        
        // Convert String to UUID for gameId
        if let gameIdString = game.gameId, let uuid = UUID(uuidString: gameIdString) {
            newGame.gameId = uuid
        } else {
            // If no valid UUID, create a new one
            newGame.gameId = UUID()
        }
        
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
            newGame.mapping = try JSONEncoder().encode(characterDictionaryToStringDictionary(game.mapping))
            newGame.correctMappings = try JSONEncoder().encode(characterDictionaryToStringDictionary(game.correctMappings))
            newGame.guessedMappings = try JSONEncoder().encode(characterDictionaryToStringDictionary(game.guessedMappings))
        } catch {
            print("Error encoding mappings: \(error.localizedDescription)")
        }
        
        // Save to Core Data
        do {
            try context.save()
            
            // Return updated game with gameId
            var updatedGame = game
            updatedGame.gameId = newGame.gameId?.uuidString // Convert UUID back to String
            return updatedGame
        } catch {
            print("Error saving game: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Update game
    func updateGame(_ game: GameModel) -> Bool {
        let context = coreData.mainContext
        
        // Find existing game - convert String to UUID
        guard let gameIdString = game.gameId,
              let gameIdUUID = UUID(uuidString: gameIdString) else {
            return false
        }
        
        let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameIdUUID as CVarArg)
        
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
                existingGame.mapping = try JSONEncoder().encode(characterDictionaryToStringDictionary(game.mapping))
                existingGame.correctMappings = try JSONEncoder().encode(characterDictionaryToStringDictionary(game.correctMappings))
                existingGame.guessedMappings = try JSONEncoder().encode(characterDictionaryToStringDictionary(game.guessedMappings))
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
        let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
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
    private func convertToGameModel(_ game: GameCD) -> GameModel {
        var mapping: [Character: Character] = [:]
        var correctMappings: [Character: Character] = [:]
        var guessedMappings: [Character: Character] = [:]
        
        // Deserialize mappings
        if let mappingData = game.mapping,
           let mappingDict = try? JSONDecoder().decode([String: String].self, from: mappingData) {
            mapping = stringDictionaryToCharacterDictionary(mappingDict)
        }
        
        if let correctMappingsData = game.correctMappings,
           let correctDict = try? JSONDecoder().decode([String: String].self, from: correctMappingsData) {
            correctMappings = stringDictionaryToCharacterDictionary(correctDict)
        }
        
        if let guessedMappingsData = game.guessedMappings,
           let guessedDict = try? JSONDecoder().decode([String: String].self, from: guessedMappingsData) {
            guessedMappings = stringDictionaryToCharacterDictionary(guessedDict)
        }
        
        return GameModel(
            gameId: game.gameId?.uuidString ?? "", // Convert UUID to String
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
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first else { return }
            
            // Get or create stats
            let stats: UserStatsCD
            if let existingStats = user.stats {
                stats = existingStats
            } else {
                stats = UserStatsCD(context: context)
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
    func getUser(userId: String) -> UserCD? {
        let context = coreData.mainContext
        
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
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
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userModel.userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            
            let user: UserCD
            if let existingUser = users.first {
                // Update existing user
                user = existingUser
            } else {
                // Create new user
                user = UserCD(context: context)
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
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first else { return false }
            
            // Get or create preferences
            let userPrefs: UserPreferencesCD
            if let existingPrefs = user.preferences {
                userPrefs = existingPrefs
            } else {
                userPrefs = UserPreferencesCD(context: context)
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
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first, let stats = user.stats else { return nil }
            
            return UserStatsModel(
                userId: user.userId ?? "",
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

// MARK: - Helper Functions

// Convert character dictionary to string dictionary
func characterDictionaryToStringDictionary(_ dict: [Character: Character]) -> [String: String] {
    var result = [String: String]()
    for (key, value) in dict {
        result[String(key)] = String(value)
    }
    return result
}

// Convert string dictionary to character dictionary
func stringDictionaryToCharacterDictionary(_ dict: [String: String]) -> [Character: Character] {
    var result = [Character: Character]()
    for (key, value) in dict {
        if let keyChar = key.first, let valueChar = value.first {
            result[keyChar] = valueChar
        }
    }
    return result
}

extension ISO8601DateFormatter {
    static func dateWithFallbacks(from string: String) -> Date? {
        // Try standard ISO formatter
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: string) {
            return date
        }
        
        // Add extended options if needed
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) {
            return date
        }
        
        // Fall back to DateFormatter with various formats
        let dateFormatter = DateFormatter()
        let formats = ["yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss"]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: string) {
                return date
            }
        }
        
        return nil
    }
}
