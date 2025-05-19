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
    
    // Store - direct access to Core Data store
    private let gameStore = GameStore.shared
    private let quoteStore = QuoteStore.shared
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
        
        // Get random quote from store
        if let quote = quoteStore.getRandomQuote() {
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
            
            // Create game with quote and appropriate ID prefix
            var newGame = GameModel(quote: quoteModel)
            // Get difficulty from settings instead of quote
            newGame.difficulty = SettingsState.shared.gameDifficulty
            // Set max mistakes based on difficulty settings
            newGame.maxMistakes = getMaxMistakesForDifficulty(newGame.difficulty)
            newGame.gameId = "custom-\(UUID().uuidString)" // Mark as custom game
            currentGame = newGame
            
            showWinMessage = false
            showLoseMessage = false
        } else {
            errorMessage = "Failed to load a quote"
            
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
        
        isLoading = false
    }
    
    /// Set up the daily challenge
    func setupDailyChallenge() {
        self.isDailyChallenge = true
        
        isLoading = true
        errorMessage = nil
        
        // Try to get daily challenge locally
        if let quote = quoteStore.getDailyQuote() {
            setupFromDailyQuote(quote)
        } else {
            // If not available locally, fetch from API
            fetchDailyQuoteFromAPI()
        }
    }
    
    // Helper to set up game from daily quote
    private func setupFromDailyQuote(_ quote: Quote) {
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
        game.gameId = "daily-\(ISO8601DateFormatter().string(from: quote.dailyDate ?? Date()))" // Mark as daily game with date
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
            
            // Create new Quote entity
            let quote = Quote(context: context)
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
        // Look for unfinished games in Core Data
        if let game = gameStore.loadLatestGame() {
            // Check if it's the right type (daily vs custom)
            let isDaily = isDailyChallenge
            
            // If we want to show daily but the saved game isn't daily, don't show modal
            if isDaily && game.gameId?.starts(with: "custom-") == true {
                return
            }
            
            // If we want to show custom but the saved game is daily, don't show modal
            if !isDaily && game.gameId?.starts(with: "daily-") == true {
                return
            }
            
            // We have a matching in-progress game
            self.savedGame = game
            self.showContinueGameModal = true
        }
    }
    
    /// Continue a saved game
    func continueSavedGame() {
        if let savedGame = savedGame {
            currentGame = savedGame
            
            // Get quote info if available - can be expanded as needed
            let context = CoreDataStack.shared.mainContext
            let fetchRequest: NSFetchRequest<Quote> = Quote.fetchRequest()
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
        let context = CoreDataStack.shared.mainContext
        
        // Find the game
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
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
            saveGameState(game)
            
            // Check game status after hint
            if game.hasWon {
                showWinMessage = true
            } else if game.hasLost {
                showLoseMessage = true
            }
        }
    }
    
    // Save current game state to Core Data
    private func saveGameState(_ game: GameModel) {
        guard let userId = UserState.shared.userId, !userId.isEmpty else {
            // Just save the game model
            if let _ = game.gameId {
                // Update existing game
                _ = gameStore.updateGame(game)
            } else {
                // Save new game
                if let updatedGame = gameStore.saveGame(game) {
                    currentGame = updatedGame
                }
            }
            return
        }
        
        // Get user entity
        let context = CoreDataStack.shared.mainContext
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            let user: User
            
            if let existingUser = users.first {
                user = existingUser
            } else {
                // Create a new user if needed
                user = User(context: context)
                user.id = UUID()
                user.userId = userId
                user.username = UserState.shared.username
                user.email = "\(UserState.shared.username)@example.com" // Placeholder
                user.registrationDate = Date()
                user.lastLoginDate = Date()
                user.isActive = true
            }
            
            // Get or create game
            let gameEntity: Game
            let gameFetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
            if let gameId = game.gameId {
                gameFetchRequest.predicate = NSPredicate(format: "gameId == %@", gameId)
                let games = try context.fetch(gameFetchRequest)
                
                if let existingGame = games.first {
                    gameEntity = existingGame
                } else {
                    gameEntity = Game(context: context)
                    gameEntity.id = UUID()
                    gameEntity.setValue(gameId, forKey: "gameId")
                    gameEntity.startTime = game.startTime
                }
            } else {
                gameEntity = Game(context: context)
                gameEntity.id = UUID()
                gameEntity.setValue(UUID().uuidString, forKey: "gameId")
                gameEntity.startTime = game.startTime
            }
            
            // Update game properties
            gameEntity.encrypted = game.encrypted
            gameEntity.solution = game.solution
            gameEntity.currentDisplay = game.currentDisplay
            gameEntity.mistakes = Int16(game.mistakes)
            gameEntity.maxMistakes = Int16(game.maxMistakes)
            gameEntity.hasWon = game.hasWon
            gameEntity.hasLost = game.hasLost
            gameEntity.difficulty = game.difficulty
            gameEntity.lastUpdateTime = game.lastUpdateTime
            gameEntity.isDaily = game.gameId?.starts(with: "daily-") ?? false
            
            // Set the user relationship
            gameEntity.user = user
            
            // Calculate and store score and time taken
            if game.hasWon || game.hasLost {
                gameEntity.score = Int32(game.calculateScore())
                gameEntity.timeTaken = Int32(game.lastUpdateTime.timeIntervalSince(game.startTime))
            }
            
            // Store mappings as serialized data
            do {
                gameEntity.mappingData = try JSONEncoder().encode(game.mapping.mapToDictionary())
                gameEntity.correctMappingsData = try JSONEncoder().encode(game.correctMappings.mapToDictionary())
                gameEntity.guessedMappingsData = try JSONEncoder().encode(game.guessedMappings.mapToDictionary())
            } catch {
                print("Error encoding mappings: \(error)")
            }
            
            // Save changes
            try context.save()
            
            // Update the current game model with the ID if it was new
            if game.gameId == nil {
                var updatedGame = game
                updatedGame.gameId = gameEntity.value(forKey: "gameId") as? String
                currentGame = updatedGame
            }
        } catch {
            print("Error saving game state: \(error.localizedDescription)")
        }
    }
    
    /// Submit score for daily challenge
    func submitDailyScore(userId: String) {
        guard let game = currentGame, game.hasWon || game.hasLost else { return }
        
        let finalScore = game.calculateScore()
        let timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
        
        // Update user stats in Core Data
        gameStore.updateStats(
            userId: userId,
            gameWon: game.hasWon,
            mistakes: game.mistakes,
            timeTaken: timeTaken,
            score: finalScore
        )
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
