import SwiftUI
import CoreData

import Foundation
import CoreData
import Combine

class GameState: ObservableObject {
    // Game state properties
    @Published var currentGame: GameModel?
    @Published var savedGame: GameModel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showWinMessage = false
    @Published var showLoseMessage = false
    @Published var showContinueGameModal = false
    
    // Game metadata
    @Published var quoteAuthor: String = ""
    @Published var quoteAttribution: String? = nil
    @Published var quoteDate: String? = nil
    
    // Configuration
    @Published var isDailyChallenge = false
    @Published var defaultDifficulty = "medium"
    
    // Private properties
    private var dailyQuote: DailyQuoteModel?
    private let authCoordinator = UserState.shared.authCoordinator
    
    // Core Data access
    private let coreData = CoreDataStack.shared
    
    // Singleton instance
    static let shared = GameState()
    
    private init() {
        setupDefaultGame()
    }
    
    /// Get max mistakes based on difficulty settings
    private func getMaxMistakesForDifficulty(_ difficulty: String) -> Int {
        switch difficulty.lowercased() {
        case "easy": return 8
        case "hard": return 3
        default: return 5  // Medium difficulty
        }
    }
    
    private func setupDefaultGame() {
        // Create a placeholder game with default quote
        let defaultQuote = QuoteModel(
            text: "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG",
            author: "Anonymous",
            attribution: nil,
            difficulty: 2.0
        )
        
        var game = GameModel(quote: defaultQuote)
        // Difficulty and max mistakes from settings, not from quote
        game.difficulty = SettingsState.shared.gameDifficulty
        game.maxMistakes = getMaxMistakesForDifficulty(game.difficulty)
        
        self.currentGame = game
    }
    
    // MARK: - Game Setup
    
    /// Set up a custom game
    func setupCustomGame() {
        self.isDailyChallenge = false
        self.dailyQuote = nil
        
        isLoading = true
        errorMessage = nil
        
        // Get random quote from Core Data
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            let quotes = try context.fetch(fetchRequest)
            
            // Get count and pick random
            let count = quotes.count
            if count > 0 {
                // Use a truly random index
                let randomIndex = Int.random(in: 0..<count)
                let quote = quotes[randomIndex]
                
                // Update UI data
                quoteAuthor = quote.author ?? ""
                quoteAttribution = quote.attribution
                
                // Create quote model
                let quoteModel = QuoteModel(
                    text: quote.text ?? "",
                    author: quote.author ?? "",
                    attribution: quote.attribution,
                    difficulty: quote.difficulty
                )
                
                // Create game with quote and appropriate ID
                var newGame = GameModel(quote: quoteModel)
                // Get difficulty from settings instead of quote
                newGame.difficulty = SettingsState.shared.gameDifficulty
                // Set max mistakes based on difficulty settings
                newGame.maxMistakes = getMaxMistakesForDifficulty(newGame.difficulty)
                
                // Create a UUID for the game - store just the UUID in the model
                let gameUUID = UUID()
                newGame.gameId = gameUUID.uuidString // Store as a string for compatibility
                
                currentGame = newGame
                
                showWinMessage = false
                showLoseMessage = false
                
                // Update quote usage count in background
                coreData.performBackgroundTask { bgContext in
                    if let quoteID = quote.id {
                        // Get the object in this background context
                        let objectID = quote.objectID
                        let backgroundQuote = bgContext.object(with: objectID) as! QuoteCD
                        backgroundQuote.timesUsed += 1
                        
                        do {
                            try bgContext.save()
                        } catch {
                            print("Failed to update quote usage count: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                // No quotes found, use fallback
                errorMessage = "No quotes available"
                useFallbackQuote()
            }
        } catch {
            errorMessage = "Failed to load a quote: \(error.localizedDescription)"
            useFallbackQuote()
        }
        
        isLoading = false
    }
    
    private func useFallbackQuote() {
        // Use fallback quote
        let fallbackQuote = QuoteModel(
            text: "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG",
            author: "Anonymous",
            attribution: nil,
            difficulty: nil
        )
        var game = GameModel(quote: fallbackQuote)
        // Get difficulty from settings
        game.difficulty = SettingsState.shared.gameDifficulty
        // Set max mistakes based on difficulty settings
        game.maxMistakes = getMaxMistakesForDifficulty(game.difficulty)
        currentGame = game
    }
    
    /// Set up the daily challenge
    func setupDailyChallenge() {
        self.isDailyChallenge = true
        
        isLoading = true
        errorMessage = nil
        
        // Try to get daily challenge locally from Core Data
        let context = coreData.mainContext
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Find quote for today
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        fetchRequest.predicate = NSPredicate(format: "isDaily == YES AND dailyDate >= %@ AND dailyDate < %@", today as NSDate, tomorrow as NSDate)
        
        do {
            let quotes = try context.fetch(fetchRequest)
            
            if let dailyQuote = quotes.first {
                setupFromDailyQuote(dailyQuote)
            } else {
                // If not available locally, fetch from API
                fetchDailyQuoteFromAPI()
            }
        } catch {
            errorMessage = "Failed to load daily challenge: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // Helper to set up game from daily quote
    private func setupFromDailyQuote(_ quote: QuoteCD) {
        // Create a daily quote model
        let dailyQuoteModel = DailyQuoteModel(
            id: Int(quote.serverId),
            text: quote.text ?? "",
            author: quote.author ?? "",
            minor_attribution: quote.attribution,
            difficulty: quote.difficulty,
            date: ISO8601DateFormatter().string(from: quote.dailyDate ?? Date()),
            unique_letters: Int(quote.uniqueLetters)
        )
        
        self.dailyQuote = dailyQuoteModel
        
        // Update UI data
        quoteAuthor = quote.author ?? ""
        quoteAttribution = quote.attribution
        
        if let dailyDate = quote.dailyDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            quoteDate = formatter.string(from: dailyDate)
        }
        
        // Create game from quote
        let gameQuote = QuoteModel(
            text: quote.text ?? "",
            author: quote.author ?? "",
            attribution: quote.attribution,
            difficulty: quote.difficulty
        )
        
        var game = GameModel(quote: gameQuote)
        // Set difficulty from settings, not from quote
        game.difficulty = SettingsState.shared.gameDifficulty
        // Set max mistakes based on difficulty settings
        game.maxMistakes = getMaxMistakesForDifficulty(game.difficulty)
        let gameUUID = UUID()
        game.gameId = gameUUID.uuidString // Store as a string
        currentGame = game
        
        showWinMessage = false
        showLoseMessage = false
        isLoading = false
    }
    
    // Fetch daily quote from API if not available locally
    private func fetchDailyQuoteFromAPI() {
        Task {
            do {
                // Get networking service from the auth coordinator
                guard let token = authCoordinator.getAccessToken() else {
                    await MainActor.run {
                        errorMessage = "Authentication required"
                        isLoading = false
                    }
                    return
                }
                
                // Build URL request
                guard let url = URL(string: "\(authCoordinator.baseURL)/api/get_daily") else {
                    await MainActor.run {
                        errorMessage = "Invalid URL configuration"
                        isLoading = false
                    }
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
                // Perform network request
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    await MainActor.run {
                        errorMessage = "Invalid response from server"
                        isLoading = false
                    }
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    // Parse response
                    let decoder = JSONDecoder()
                    let dailyQuote = try decoder.decode(DailyQuoteModel.self, from: data)
                    
                    // Save to Core Data for future use
                    saveQuoteToCoreData(dailyQuote)
                    
                    // Update UI on main thread
                    await MainActor.run {
                        self.dailyQuote = dailyQuote
                        quoteAuthor = dailyQuote.author
                        quoteAttribution = dailyQuote.minor_attribution
                        quoteDate = dailyQuote.formattedDate
                        
                        // Create game
                        let quoteModel = QuoteModel(
                            text: dailyQuote.text,
                            author: dailyQuote.author,
                            attribution: dailyQuote.minor_attribution,
                            difficulty: dailyQuote.difficulty
                        )
                        
                        var game = GameModel(quote: quoteModel)
                        // Set difficulty and max mistakes from settings
                        game.difficulty = SettingsState.shared.gameDifficulty
                        game.maxMistakes = getMaxMistakesForDifficulty(game.difficulty)
                        game.gameId = "daily-\(dailyQuote.date)" // Mark as daily game with date
                        currentGame = game
                        
                        showWinMessage = false
                        showLoseMessage = false
                        isLoading = false
                    }
                } else {
                    // Handle error responses
                    await MainActor.run {
                        if httpResponse.statusCode == 401 {
                            errorMessage = "Authentication required"
                        } else if httpResponse.statusCode == 404 {
                            errorMessage = "No daily challenge available today"
                        } else {
                            errorMessage = "Server error (\(httpResponse.statusCode))"
                        }
                        isLoading = false
                    }
                }
            } catch {
                // Handle network or parsing errors
                await MainActor.run {
                    errorMessage = "Failed to load daily challenge: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    // Save daily quote to Core Data for offline use
    private func saveQuoteToCoreData(_ dailyQuote: DailyQuoteModel) {
        let context = CoreDataStack.shared.newBackgroundContext()
        
        context.perform {
            // Create date object from ISO string
            let dateFormatter = ISO8601DateFormatter()
            guard let quoteDate = dateFormatter.date(from: dailyQuote.date) else { return }
            
            // Create new QuoteCD entity
            let quote = QuoteCD(context: context)
            quote.id = UUID()
            quote.serverId = Int32(dailyQuote.id)
            quote.text = dailyQuote.text
            quote.author = dailyQuote.author
            quote.attribution = dailyQuote.minor_attribution
            quote.difficulty = dailyQuote.difficulty
            quote.isDaily = true
            quote.dailyDate = quoteDate
            quote.uniqueLetters = Int16(dailyQuote.unique_letters)
            quote.isActive = true
            quote.timesUsed = 0
            
            do {
                try context.save()
            } catch {
                print("Error saving daily quote: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Game State Management
    
    /// Check for an in-progress game
    func checkForInProgressGame() {
        let context = coreData.mainContext
        
        // Query for unfinished games
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        
        // Add isDaily filter based on current mode
        let dailyPredicate = NSPredicate(format: "isDaily == %@", NSNumber(value: isDailyChallenge))
        let unfinishedPredicate = NSPredicate(format: "hasWon == NO AND hasLost == NO")
        
        // Combine predicates
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            dailyPredicate, unfinishedPredicate
        ])
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastUpdateTime", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let games = try context.fetch(fetchRequest)
            if let latestGame = games.first {
                // Convert to model
                let gameModel = latestGame.toModel()
                self.savedGame = gameModel
                self.showContinueGameModal = true
            }
        } catch {
            print("Error checking for in-progress game: \(error)")
        }
    }
    
    /// Continue a saved game
    func continueSavedGame() {
        if let savedGame = savedGame {
            currentGame = savedGame
            
            // Get quote info if available
            let context = coreData.mainContext
            let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
            fetchRequest.predicate = NSPredicate(format: "text == %@", savedGame.solution)
            
            do {
                let quotes = try context.fetch(fetchRequest)
                if let quote = quotes.first {
                    quoteAuthor = quote.author ?? ""
                    quoteAttribution = quote.attribution
                }
            } catch {
                print("Error fetching quote for game: \(error.localizedDescription)")
            }
            
            self.showContinueGameModal = false
            self.savedGame = nil
        }
    }
    
    /// Reset the current game
    func resetGame() {
        // If there was a saved game, mark it as abandoned
        if let oldGameId = savedGame?.gameId {
            markGameAsAbandoned(gameId: oldGameId)
        }
        
        if isDailyChallenge, let dailyQuote = dailyQuote {
            // Reuse the daily quote
            let gameQuote = QuoteModel(
                text: dailyQuote.text,
                author: dailyQuote.author,
                attribution: dailyQuote.minor_attribution,
                difficulty: dailyQuote.difficulty
            )
            var game = GameModel(quote: gameQuote)
            // Set difficulty from settings
            game.difficulty = SettingsState.shared.gameDifficulty
            // Set max mistakes based on difficulty settings
            game.maxMistakes = getMaxMistakesForDifficulty(game.difficulty)
            game.gameId = "daily-\(dailyQuote.date)" // Mark as daily game with date
            currentGame = game
            showWinMessage = false
            showLoseMessage = false
        } else {
            // Load a new random game
            setupCustomGame()
        }
        
        // Clear the saved game reference
        self.savedGame = nil
    }
    
    // Mark a game as abandoned
    private func markGameAsAbandoned(gameId: String) {
        let context = coreData.mainContext
        
        // Find the game
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameId)
        
        do {
            let games = try context.fetch(fetchRequest)
            if let game = games.first {
                game.hasLost = true
                
                // Reset streak if player had one
                if let user = game.user, let stats = user.stats, stats.currentStreak > 0 {
                    stats.currentStreak = 0
                }
                
                try context.save()
            }
        } catch {
            print("Error marking game as abandoned: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Game Actions
    
    /// Handle a player's guess
    func makeGuess(_ guessedLetter: Character) {
        guard var game = currentGame else { return }
        
        // Only proceed if a letter is selected
        if game.selectedLetter != nil {
            let _ = game.makeGuess(guessedLetter)
            self.currentGame = game
            
            // Save game state
            printGameDetails() // Debug
            saveGameState(game)
            
            // Check game status
            if game.hasWon {
                showWinMessage = true
            } else if game.hasLost {
                showLoseMessage = true
            }
        }
    }
    
    /// Select a letter to decode
    func selectLetter(_ letter: Character) {
        guard var game = currentGame else { return }
        game.selectLetter(letter)
        self.currentGame = game
    }
    
    /// Get a hint
    func getHint() {
        guard var game = currentGame else { return }
        
        // Only allow getting hints if we haven't reached the maximum mistakes
        if game.mistakes < game.maxMistakes {
            let _ = game.getHint()
            self.currentGame = game
            
            // Play hint sound
            SoundManager.shared.play(.hint)
            
            // Save game state
            printGameDetails() // Debug
            saveGameState(game)
            
            // Check game status after hint
            if game.hasWon {
                showWinMessage = true
            } else if game.hasLost {
                showLoseMessage = true
            }
        }
    }
    //debug tool for game state
    func printGameDetails() {
        if let game = currentGame {
            print("Current Game ID: \(game.gameId ?? "nil")")
            if let gameId = game.gameId, let uuid = UUID(uuidString: gameId) {
                print("Valid UUID format: \(uuid.uuidString)")
            } else {
                print("Not a valid UUID format")
            }
            print("Is Daily Challenge: \(isDailyChallenge)")
            print("Current mistakes: \(game.mistakes)/\(game.maxMistakes)")
        } else {
            print("No current game")
        }
    }
    // Save current game state to Core Data
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
    
    // Create a new game entity from model
    private func createGameEntity(from model: GameModel) -> GameCD {
        let context = coreData.mainContext
        let gameEntity = GameCD(context: context)
        
        gameEntity.gameId = UUID() 
        gameEntity.startTime = model.startTime
        
        updateGameEntity(gameEntity, from: model)
        return gameEntity
    }
    
    // Update game entity from model
    private func updateGameEntity(_ entity: GameCD, from model: GameModel) {
        entity.encrypted = model.encrypted
        entity.solution = model.solution
        entity.currentDisplay = model.currentDisplay
        entity.mistakes = Int16(model.mistakes)
        entity.maxMistakes = Int16(model.maxMistakes)
        entity.hasWon = model.hasWon
        entity.hasLost = model.hasLost
        entity.difficulty = model.difficulty
        entity.lastUpdateTime = model.lastUpdateTime
        entity.isDaily = isDailyChallenge
        
        // Serialize mappings
        do {
            entity.mapping = try JSONEncoder().encode(characterDictionaryToStringDictionary(model.mapping))
            entity.correctMappings = try JSONEncoder().encode(characterDictionaryToStringDictionary(model.correctMappings))
            entity.guessedMappings = try JSONEncoder().encode(characterDictionaryToStringDictionary(model.guessedMappings))
        } catch {
            print("Error encoding mappings: \(error.localizedDescription)")
        }
    }
    //tidy DB in case of error
    func cleanupDuplicateGames() {
        let context = coreData.mainContext
        
        // Get all games
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        
        do {
            let allGames = try context.fetch(fetchRequest)
            print("Found \(allGames.count) total game records")
            
            // Dictionary to count occurrences of each game ID
            var gameIDCounts: [UUID: Int] = [:]
            var gameIDObjects: [UUID: [GameCD]] = [:]
            
            // Count occurrences of each game ID
            for game in allGames {
                if let id = game.gameId {
                    print("Game ID: \(id)")
                    gameIDCounts[id, default: 0] += 1
                    
                    if gameIDObjects[id] == nil {
                        gameIDObjects[id] = [game]
                    } else {
                        gameIDObjects[id]?.append(game)
                    }
                } else {
                    print("Warning: Found game record with nil gameId")
                }
            }
            
            // Find IDs with multiple occurrences
            let duplicateIDs = gameIDCounts.filter { $0.value > 1 }.keys
            print("Found \(gameIDCounts.count) unique game IDs")
            print("Found \(duplicateIDs.count) IDs with duplicates")
            
            // Clean up duplicates
            var deletedCount = 0
            
            for id in duplicateIDs {
                guard let games = gameIDObjects[id], games.count > 1 else { continue }
                
                print("Game ID \(id.uuidString) has \(games.count) duplicates")
                
                // Sort by last update time (newest first)
                let sortedGames = games.sorted {
                    ($0.lastUpdateTime ?? Date.distantPast) > ($1.lastUpdateTime ?? Date.distantPast)
                }
                
                // Keep the newest, delete the rest
                for i in 1..<sortedGames.count {
                    let game = sortedGames[i]
                    context.delete(game)
                    deletedCount += 1
                    print("  Deleted duplicate updated at: \(game.lastUpdateTime ?? Date.distantPast)")
                }
                
                print("  Kept newest updated at: \(sortedGames[0].lastUpdateTime ?? Date.distantPast)")
            }
            
            if duplicateIDs.isEmpty {
                print("✅ No duplicates found - database is clean!")
            } else {
                print("🧹 Cleanup complete. Deleted \(deletedCount) duplicate records")
            }
            
            // Save changes
            if context.hasChanges {
                try context.save()
            }
        } catch {
            print("❌ Error during cleanup: \(error.localizedDescription)")
        }
    }
    /// Submit score for daily challenge
    func submitDailyScore(userId: String) {
        guard let game = currentGame, game.hasWon || game.hasLost else { return }
        
        let context = coreData.mainContext
        let userFetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        userFetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(userFetchRequest)
            
            if let user = users.first {
                // Get or create stats
                let stats: UserStatsCD
                if let existingStats = user.stats {
                    stats = existingStats
                } else {
                    stats = UserStatsCD(context: context)
                    user.stats = stats
                    stats.user = user
                }
                
                // Calculate final values
                let finalScore = game.calculateScore()
                let timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
                
                // Update stats
                stats.gamesPlayed += 1
                if game.hasWon {
                    stats.gamesWon += 1
                    stats.currentStreak += 1
                    stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
                } else {
                    stats.currentStreak = 0
                }
                
                stats.totalScore += Int32(finalScore)
                
                // Update averages
                let oldMistakesTotal = stats.averageMistakes * Double(stats.gamesPlayed - 1)
                stats.averageMistakes = (oldMistakesTotal + Double(game.mistakes)) / Double(stats.gamesPlayed)
                
                let oldTimeTotal = stats.averageTime * Double(stats.gamesPlayed - 1)
                stats.averageTime = (oldTimeTotal + Double(timeTaken)) / Double(stats.gamesPlayed)
                
                stats.lastPlayedDate = Date()
                
                // Save changes
                try context.save()
            }
        } catch {
            print("Error updating user stats: \(error.localizedDescription)")
        }
    }
    
    /// Reset the state
    func reset() {
        currentGame = nil
        savedGame = nil
        isLoading = false
        errorMessage = nil
        showWinMessage = false
        showLoseMessage = false
        showContinueGameModal = false
        quoteAuthor = ""
        quoteAttribution = nil
        quoteDate = nil
        isDailyChallenge = false
        setupDefaultGame()
    }
    
    // Helper for time formatting
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Helper functions for character dictionary conversions
    private func characterDictionaryToStringDictionary(_ dict: [Character: Character]) -> [String: String] {
        var result = [String: String]()
        for (key, value) in dict {
            result[String(key)] = String(value)
        }
        return result
    }
    
    private func saveGameState(_ game: GameModel) {
        guard let gameId = game.gameId else {
            print("Error: Trying to save game state with no game ID")
            return
        }
        
        let context = coreData.mainContext
        
        // Try to convert to UUID
        guard let gameUUID = UUID(uuidString: gameId) else {
            print("Error: Invalid UUID format in game ID: \(gameId)")
            return
        }
        
        // Try to find the existing game
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameUUID as CVarArg)
        
        do {
            let existingGames = try context.fetch(fetchRequest)
            
            // Check if we have multiple matches - this shouldn't happen, but let's handle it
            if existingGames.count > 1 {
                print("Warning: Found \(existingGames.count) games with the same ID \(gameId). Using the most recent one.")
                
                // Sort by last update time, descending
                let sortedGames = existingGames.sorted {
                    ($0.lastUpdateTime ?? Date.distantPast) > ($1.lastUpdateTime ?? Date.distantPast)
                }
                
                // Keep the most recent one, delete others
                for i in 1..<sortedGames.count {
                    context.delete(sortedGames[i])
                    print("Deleted duplicate game with ID: \(sortedGames[i].gameId?.uuidString ?? "nil")")
                }
                
                // Update the most recent one
                updateGameEntity(sortedGames[0], from: game)
            } else if let existingGame = existingGames.first {
                // Normal case - just update the existing game
                updateGameEntity(existingGame, from: game)
            } else {
                // No existing game - create a new one
                let gameEntity = GameCD(context: context)
                gameEntity.gameId = gameUUID
                gameEntity.startTime = game.startTime
                
                // Set user relationship if available
                if !UserState.shared.userId.isEmpty {
                    let userFetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
                    userFetchRequest.predicate = NSPredicate(format: "userId == %@", UserState.shared.userId)
                    let users = try context.fetch(userFetchRequest)
                    
                    if let user = users.first {
                        gameEntity.user = user
                    }
                }
                
                // Update with game data
                updateGameEntity(gameEntity, from: game)
            }
            
            try context.save()
        } catch {
            print("Error saving game state: \(error.localizedDescription)")
        }
    }
    private func stringDictionaryToCharacterDictionary(_ dict: [String: String]) -> [Character: Character] {
        var result = [Character: Character]()
        for (key, value) in dict {
            if let keyChar = key.first, let valueChar = value.first {
                result[keyChar] = valueChar
            }
        }
        return result
    }
}

// MARK: game rec integration

extension GameState {
    
    /// Manually trigger game sync
    func manualSync(completion: @escaping (Bool, String?) -> Void) {
        guard UserState.shared.isAuthenticated else {
            completion(false, "Not authenticated")
            return
        }
        
        GameReconciliationManager.shared.reconcileGames { success, error in
            completion(success, error)
        }
    }
    
    /// Force upload current game to server
    func uploadCurrentGame() {
        guard let game = currentGame,
              game.hasWon || game.hasLost,
              let gameId = game.gameId,
              let token = UserState.shared.authCoordinator.getAccessToken() else {
            return
        }
        
        let reconciliationManager = GameReconciliationManager.shared
        // Use the private method through a public wrapper
        uploadGameToServer(gameId: gameId, token: token) { success, error in
            if success {
                print("✅ Current game uploaded to server")
            } else {
                print("❌ Failed to upload current game: \(error ?? "Unknown error")")
            }
        }
    }
    
    // Make the upload method accessible
    func uploadGameToServer(gameId: String, token: String, completion: @escaping (Bool, String?) -> Void) {
        // Get local game
        guard let localGame = getLocalGameForUpload(gameId: gameId) else {
            completion(false, "Local game not found")
            return
        }
        
        guard let url = URL(string: "\(UserState.shared.authCoordinator.baseURL)/api/games") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(localGame)
        } catch {
            completion(false, "Failed to encode game: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                    completion(false, "Server error")
                    return
                }
                
                completion(true, nil)
            }
        }.resume()
    }
    
    private func getLocalGameForUpload(gameId: String) -> ServerGameData? {
        let context = coreData.mainContext
        
        guard let gameUUID = UUID(uuidString: gameId) else { return nil }
        
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        fetchRequest.predicate = NSPredicate(format: "gameId == %@ AND user.userId == %@",
                                           gameUUID as CVarArg, UserState.shared.userId)
        
        do {
            let games = try context.fetch(fetchRequest)
            guard let game = games.first else { return nil }
            
            return ServerGameData(
                gameId: game.gameId?.uuidString ?? "",
                userId: UserState.shared.userId,
                encrypted: game.encrypted ?? "",
                solution: game.solution ?? "",
                currentDisplay: game.currentDisplay ?? "",
                mistakes: Int(game.mistakes),
                maxMistakes: Int(game.maxMistakes),
                hasWon: game.hasWon,
                hasLost: game.hasLost,
                difficulty: game.difficulty ?? "medium",
                isDaily: game.isDaily,
                score: Int(game.score),
                timeTaken: Int(game.timeTaken),
                startTime: game.startTime ?? Date(),
                lastUpdateTime: game.lastUpdateTime ?? Date(),
                mapping: decodeMapping(game.mapping) ?? [:],
                correctMappings: decodeMapping(game.correctMappings) ?? [:],
                guessedMappings: decodeMapping(game.guessedMappings) ?? [:]
            )
        } catch {
            print("Error fetching local game: \(error)")
            return nil
        }
    }
    
    private func decodeMapping(_ data: Data?) -> [String: String]? {
        guard let data = data else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }
}

// Add sync status UI component

struct GameSyncStatusView: View {
    @StateObject private var syncManager = GameSyncStatusManager()
    @State private var showingSyncDetails = false
    
    var body: some View {
        HStack {
            Image(systemName: syncManager.isOnline ? "wifi" : "wifi.slash")
                .foregroundColor(syncManager.isOnline ? .green : .gray)
            
            if syncManager.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Syncing...")
                    .font(.caption)
            } else {
                Text("Last sync: \(syncManager.lastSyncText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                showingSyncDetails = true
            }) {
                Image(systemName: "info.circle")
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingSyncDetails) {
            GameSyncDetailsView(syncManager: syncManager)
        }
        .onAppear {
            syncManager.checkStatus()
        }
    }
}

struct GameSyncDetailsView: View {
    @ObservedObject var syncManager: GameSyncStatusManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack {
                    Text("Sync Status")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Circle()
                            .fill(syncManager.isOnline ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        Text(syncManager.isOnline ? "Online" : "Offline")
                    }
                }
                
                if let stats = syncManager.syncStats {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Game Statistics")
                            .font(.headline)
                        
                        InfoRow(title: "Total Games", value: "\(stats.totalGames)")
                        InfoRow(title: "Completed Games", value: "\(stats.completedGames)")
                        InfoRow(title: "Active Games", value: "\(stats.activeGames)")
                        
                        if let lastActivity = stats.lastActivity {
                            InfoRow(title: "Last Activity", value: formatDate(lastActivity))
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                VStack(spacing: 12) {
                    Button(action: {
                        syncManager.manualSync()
                    }) {
                        HStack {
                            if syncManager.isSyncing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Sync Now")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(syncManager.isSyncing || !syncManager.isOnline)
                    
                    if let lastError = syncManager.lastError {
                        Text("Last error: \(lastError)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Game Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Sync status manager
class GameSyncStatusManager: ObservableObject {
    @Published var isOnline = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncStats: SyncStats?
    @Published var lastError: String?
    
    var lastSyncText: String {
        guard let lastSyncDate = lastSyncDate else {
            return "Never"
        }
        
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: lastSyncDate, relativeTo: Date())
    }
    
    struct SyncStats {
        let totalGames: Int
        let completedGames: Int
        let activeGames: Int
        let lastActivity: Date?
    }
    
    init() {
        checkOnlineStatus()
        loadLastSyncDate()
    }
    
    func checkStatus() {
        checkOnlineStatus()
        fetchSyncStats()
    }
    
    func manualSync() {
        guard !isSyncing else { return }
        
        isSyncing = true
        lastError = nil
        
        GameState.shared.manualSync { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isSyncing = false
                
                if success {
                    self?.lastSyncDate = Date()
                    self?.saveLastSyncDate()
                    self?.fetchSyncStats()
                } else {
                    self?.lastError = error
                }
            }
        }
    }
    
    private func checkOnlineStatus() {
        // Simple connectivity check
        guard let url = URL(string: UserState.shared.authCoordinator.baseURL) else {
            isOnline = false
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    self?.isOnline = httpResponse.statusCode < 500
                } else {
                    self?.isOnline = false
                }
            }
        }.resume()
    }
    
    private func fetchSyncStats() {
        guard let token = UserState.shared.authCoordinator.getAccessToken(),
              let url = URL(string: "\(UserState.shared.authCoordinator.baseURL)/api/games/sync-status") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }
            
            do {
                let response = try JSONDecoder().decode(SyncStatusResponse.self, from: data)
                
                DispatchQueue.main.async {
                    self?.syncStats = SyncStats(
                        totalGames: response.stats.totalGames,
                        completedGames: response.stats.completedGames,
                        activeGames: response.stats.activeGames,
                        lastActivity: response.stats.lastActivity.flatMap { ISO8601DateFormatter().date(from: $0) }
                    )
                }
            } catch {
                print("Error parsing sync stats: \(error)")
            }
        }.resume()
    }
    
    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastGameSyncTimestamp") as? Date
    }
    
    private func saveLastSyncDate() {
        if let date = lastSyncDate {
            UserDefaults.standard.set(date, forKey: "lastGameSyncTimestamp")
        }
    }
}

struct SyncStatusResponse: Codable {
    let success: Bool
    let stats: SyncStatsResponse
    
    struct SyncStatsResponse: Codable {
        let totalGames: Int
        let completedGames: Int
        let activeGames: Int
        let lastActivity: String?
    }
}
