import Foundation
import CoreData

// MARK: - Local Data Models (Simplified)
struct SimpleUserStats {
    let gamesPlayed: Int
    let gamesWon: Int
    let totalScore: Int
    let currentStreak: Int
    let bestStreak: Int
    let averageTime: Double
    let averageMistakes: Double
    let lastPlayedDate: Date?
}

// MARK: - GameStore
class GameStore {
    static let shared = GameStore()
    
    private let coreData = CoreDataStack.shared
    
    private init() {}
    
    // Save game to Core Data
    func saveGame(_ game: GameModel) -> Bool {
        let context = coreData.mainContext
        
        // Create new GameCD
        let gameCD = GameCD(context: context)
        // Note: gameCD.id is auto-managed by Core Data, don't set it manually
        
        // Convert gameId string back to UUID if needed
        if let gameIdString = game.gameId {
            gameCD.gameId = UUID(uuidString: gameIdString)
        } else {
            gameCD.gameId = UUID()
        }
        
        // Set properties that exist in GameCD
        gameCD.encrypted = game.encrypted
        gameCD.solution = game.solution
        gameCD.currentDisplay = game.currentDisplay
        gameCD.mistakes = Int16(game.mistakes)  // Core Data uses Int16
        gameCD.maxMistakes = Int16(game.maxMistakes)  // Core Data uses Int16
        gameCD.hasWon = game.hasWon
        gameCD.hasLost = game.hasLost
        gameCD.difficulty = game.difficulty
        gameCD.startTime = game.startTime
        gameCD.lastUpdateTime = game.lastUpdateTime
        
        // Save mappings using the correct property names
        gameCD.mapping = try? JSONEncoder().encode(game.mapping.mapToStringDict())
        gameCD.correctMappings = try? JSONEncoder().encode(game.correctMappings.mapToStringDict())
        gameCD.guessedMappings = try? JSONEncoder().encode(game.guessedMappings.mapToStringDict())
        
        return context.safeSave()
    }
    
    // Load saved game by ID
    func loadGame(gameId: String) -> GameModel? {
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        
        // Convert string ID to UUID for search
        guard let gameUUID = UUID(uuidString: gameId) else { return nil }
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameUUID as CVarArg)
        fetchRequest.fetchLimit = 1
        
        let games = context.safeFetch(fetchRequest)
        return games.first?.toModel()
    }
    
    // Get all saved games
    func getAllGames() -> [GameModel] {
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastUpdateTime", ascending: false)]
        
        let games = context.safeFetch(fetchRequest)
        return games.compactMap { $0.toModel() }
    }
    
    // Delete game
    func deleteGame(gameId: String) -> Bool {
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        
        guard let gameUUID = UUID(uuidString: gameId) else { return false }
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameUUID as CVarArg)
        
        let games = context.safeFetch(fetchRequest)
        games.forEach { context.delete($0) }
        
        return context.safeSave()
    }
    
    // Update user stats after game completion
    func updateStats(playerName: String, gameWon: Bool, mistakes: Int, timeTaken: Int, score: Int) {
        let context = coreData.mainContext
        
        // Since we're local-only, we'll use playerName as the identifier
        let fetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        fetchRequest.predicate = NSPredicate(format: "username == %@", playerName)
        
        var users = context.safeFetch(fetchRequest)
        let user: UserCD
        
        if let existingUser = users.first {
            user = existingUser
        } else {
            // Create new local user
            user = UserCD(context: context)
            user.id = UUID()  // ADD THIS LINE - Core Data needs the id field set
            user.primaryIdentifier = playerName.lowercased()  // ADD THIS LINE - Critical!
            user.userId = UUID().uuidString // Generate local ID
            user.username = playerName
            user.displayName = playerName
            user.isActive = true
            user.registrationDate = Date()
        }
        
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
        
        // Save changes
        _ = context.safeSave()
    }
}

// MARK: - QuoteStore
class QuoteStore {
    static let shared = QuoteStore()
    
    private let coreData = CoreDataStack.shared
    
    private init() {}
    
    // Save quotes from LocalQuoteManager
    func saveQuotes(_ quotes: [QuoteModel]) -> Bool {
        let context = coreData.mainContext
        
        for quote in quotes {
            let quoteCD = QuoteCD(context: context)
            // Note: quoteCD.id is auto-managed by Core Data
            quoteCD.text = quote.text
            quoteCD.author = quote.author
            quoteCD.attribution = quote.attribution
            quoteCD.difficulty = quote.difficulty ?? 2.0  // Provide default value
        }
        
        return context.safeSave()
    }
    
    // Get random quote by difficulty
    nonisolated func getRandomQuote() -> LocalQuoteModel? {
        let context = CoreDataStack.shared.mainContext
        let request = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        
        // Get enabled packs from settings - this is the tricky part
        // We need to access SettingsState.shared.enabledPacksForRandom
        // Since SettingsState isn't MainActor, this should work
        let enabledPacks = SettingsState.shared.enabledPacksForRandom
        
        // Build predicate to only include quotes from enabled packs
        var predicates: [NSPredicate] = [NSPredicate(format: "isActive == YES")]
        var packPredicates: [NSPredicate] = []
        
        // Check if free pack is enabled
        if enabledPacks.contains("free") {
            packPredicates.append(NSPredicate(format: "isFromPack == NO"))
        }
        
        // Check for purchased packs
        for packID in enabledPacks {
            if packID != "free" {
                packPredicates.append(NSPredicate(format: "packID == %@", packID))
            }
        }
        
        // Combine with OR
        if !packPredicates.isEmpty {
            let orPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: packPredicates)
            predicates.append(orPredicate)
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        do {
            let quotes = try context.fetch(request)
            guard !quotes.isEmpty else {
                print("❌ No quotes available from enabled packs")
                return nil
            }
            
            let randomQuote = quotes.randomElement()!
            return LocalQuoteModel(
                text: randomQuote.text ?? "",
                author: randomQuote.author ?? "Unknown",
                attribution: randomQuote.attribution,
                difficulty: randomQuote.difficulty,
                category: "general"
            )
        } catch {
            print("❌ Fetch failed: \(error)")
            return nil
        }
    }
    
    // Get daily quote (deterministic based on date)
    func getDailyQuote() -> QuoteModel? {
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        
        let quotes = context.safeFetch(fetchRequest)
        guard !quotes.isEmpty else { return nil }
        
        // Use date as seed for consistent daily quote
        let calendar = Calendar.current
        let today = Date()
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: today) ?? 1
        let year = calendar.component(.year, from: today)
        let seed = dayOfYear + (year * 1000) // Simple seed calculation
        
        let index = seed % quotes.count
        return quotes[index].toModel()
    }
    
    // Get quote count
    func getQuoteCount() -> Int {
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        
        do {
            return try context.count(for: fetchRequest)
        } catch {
            print("❌ Error counting quotes: \(error)")
            return 0
        }
    }
    
    // Check if quotes are already loaded
    func hasQuotes() -> Bool {
        return getQuoteCount() > 0
    }
}

// MARK: - UserStore (Simplified)
class UserStore {
    static let shared = UserStore()
    
    private let coreData = CoreDataStack.shared
    
    private init() {}
    
    // Get user stats
    func getUserStats(playerName: String) -> SimpleUserStats? {
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        fetchRequest.predicate = NSPredicate(format: "username == %@", playerName)
        
        let users = context.safeFetch(fetchRequest)
        guard let user = users.first, let stats = user.stats else { return nil }
        
        return SimpleUserStats(
            gamesPlayed: Int(stats.gamesPlayed),
            gamesWon: Int(stats.gamesWon),
            totalScore: Int(stats.totalScore),
            currentStreak: Int(stats.currentStreak),
            bestStreak: Int(stats.bestStreak),
            averageTime: stats.averageTime ?? 0.0,  // Unwrap optional Double
            averageMistakes: stats.averageMistakes ?? 0.0,  // Unwrap optional Double
            lastPlayedDate: stats.lastPlayedDate
        )
    }
    
    // Reset all user data
    func resetAllUserData() -> Bool {
        let context = coreData.mainContext
        
        // Delete all users
        let userRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "UserCD")
        let deleteUsersRequest = NSBatchDeleteRequest(fetchRequest: userRequest)
        
        // Delete all user stats
        let statsRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "UserStatsCD")
        let deleteStatsRequest = NSBatchDeleteRequest(fetchRequest: statsRequest)
        
        // Delete all games
        let gameRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "GameCD")
        let deleteGamesRequest = NSBatchDeleteRequest(fetchRequest: gameRequest)
        
        do {
            try context.execute(deleteUsersRequest)
            try context.execute(deleteStatsRequest)
            try context.execute(deleteGamesRequest)
            try context.save()
            
            // Refresh context
            context.refreshAllObjects()
            
            return true
        } catch {
            print("❌ Error resetting user data: \(error)")
            return false
        }
    }
}

// MARK: - Helper Extensions
extension Dictionary where Key == Character, Value == Character {
    func mapToStringDict() -> [String: String] {
        var result = [String: String]()
        for (key, value) in self {
            result[String(key)] = String(value)
        }
        return result
    }
}

extension Dictionary where Key == String, Value == String {
    func mapToCharacterDict() -> [Character: Character] {
        var result = [Character: Character]()
        for (key, value) in self {
            if let keyChar = key.first, let valueChar = value.first {
                result[keyChar] = valueChar
            }
        }
        return result
    }
}


