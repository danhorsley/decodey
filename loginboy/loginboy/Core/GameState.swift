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
    
    // Core Data references
    private let cdStack = CoreDataStack.shared
    
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
        if let quoteCD = getRandomQuoteCD() {
            // Update UI data
            quoteAuthor = quoteCD.author ?? ""
            quoteAttribution = quoteCD.attribution
            
            // Create quote model
            let quoteModel = QuoteModel(
                text: quoteCD.text ?? "",
                author: quoteCD.author ?? "",
                attribution: quoteCD.attribution,
                difficulty: quoteCD.difficulty
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
        
        // Try to get daily challenge locally from Core Data
        if let quoteCD = getDailyQuoteCD() {
            setupFromDailyQuoteCD(quoteCD)
        } else {
            // If not available locally, fetch from API
            fetchDailyQuoteFromAPI()
        }
    }
    
    // Helper to set up game from daily quote CD entity
    private func setupFromDailyQuoteCD(_ quoteCD: Quote) {
        // Create a daily quote model
        let dailyQuoteModel = DailyQuoteModel(
            id: Int(quoteCD.serverId),
            text: quoteCD.text ?? "",
            author: quoteCD.author ?? "",
            minor_attribution: quoteCD.attribution,
            difficulty: quoteCD.difficulty,
            date: ISO8601DateFormatter().string(from: quoteCD.dailyDate ?? Date()),
            unique_letters: Int(quoteCD.uniqueLetters)
        )
        
        self.dailyQuote = dailyQuoteModel
        
        // Update UI data
        quoteAuthor = quoteCD.author ?? ""
        quoteAttribution = quoteCD.attribution
        
        if let dailyDate = quoteCD.dailyDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            quoteDate = formatter.string(from: dailyDate)
        }
        
        // Create game from quote
        let gameQuote = QuoteModel(
            text: quoteCD.text ?? "",
            author: quoteCD.author ?? "",
            attribution: quoteCD.attribution,
            difficulty: quoteCD.difficulty
        )
        
        var game = GameModel(quote: gameQuote)
        // Set difficulty from settings, not from quote
        game.difficulty = SettingsState.shared.gameDifficulty
        // Set max mistakes based on difficulty settings
        game.maxMistakes = getMaxMistakesForDifficulty(game.difficulty)
        game.gameId = "daily-\(ISO8601DateFormatter().string(from: quoteCD.dailyDate ?? Date()))" // Mark as daily game with date
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
                    saveDailyQuoteToCD(dailyQuote)
                    
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
    
    // MARK: - Core Data Operations
    
    // Get random quote from Core Data
    private func getRandomQuoteCD() -> Quote? {
        let context = cdStack.mainContext
        
        let fetchRequest = NSFetchRequest<Quote>(entityName: "Quote")
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            let quotesCD = try context.fetch(fetchRequest)
            
            // Get count and pick random
            let count = quotesCD.count
            guard count > 0 else { return nil }
            
            // Use a truly random index
            let randomIndex = Int.random(in: 0..<count)
            let quoteCD = quotesCD[randomIndex]
            
            // Update usage count
            cdStack.performBackgroundTask { context in
                if let quoteID = quoteCD.id {
                    // Get the object in this background context
                    let objectID = quoteCD.objectID
                    if let backgroundQuote = context.object(with: objectID) as? Quote {
                        backgroundQuote.timesUsed += 1
                        
                        do {
                            try context.save()
                        } catch {
                            print("Failed to update quote usage count: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            return quoteCD
        } catch {
            print("Error fetching random quote: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Get daily quote from Core Data
    private func getDailyQuoteCD() -> Quote? {
        let context = cdStack.mainContext
        
        // Create a date formatter to check for daily quotes
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        // Find quote for today
        let fetchRequest = NSFetchRequest<Quote>(entityName: "Quote")
        fetchRequest.predicate = NSPredicate(format: "isDaily == YES AND dailyDate >= %@ AND dailyDate < %@", today as NSDate, tomorrow as NSDate)
        
        do {
            let quotesCD = try context.fetch(fetchRequest)
            return quotesCD.first
        } catch {
            print("Error fetching daily quote: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Save daily quote to Core Data for offline use
    private func saveDailyQuoteToCD(_ dailyQuote: DailyQuoteModel) {
        let context = cdStack.newBackgroundContext()
        
        context.perform {
            // Create date object from ISO string
            let dateFormatter = ISO8601DateFormatter()
            guard let quoteDate = dateFormatter.date(from: dailyQuote.date) else { return }
            
            // Create new Quote entity
            let quoteCD = Quote(context: context)
            quoteCD.id = UUID()
            quoteCD.serverId = Int32(dailyQuote.id)
            quoteCD.text = dailyQuote.text
            quoteCD.author = dailyQuote.author
            quoteCD.attribution = dailyQuote.minor_attribution
            quoteCD.difficulty = dailyQuote.difficulty
            quoteCD.isDaily = true
            quoteCD.dailyDate = quoteDate
            quoteCD.uniqueLetters = Int16(dailyQuote.unique_letters)
            quoteCD.isActive = true
            quoteCD.timesUsed = 0
            
            do {
                try context.save()
            } catch {
                print("Error saving daily quote: \(error.localizedDescription)")
            }
        }
    }
    
    // Load latest unfinished game from Core Data
    private func loadLatestGameCD() -> GameModel? {
        let context = cdStack.mainContext
        
        // Query for unfinished games
        let fetchRequest = NSFetchRequest<Game>(entityName: "Game")
        fetchRequest.predicate = NSPredicate(format: "hasWon == NO AND hasLost == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastUpdateTime", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let gamesCD = try context.fetch(fetchRequest)
            guard let latestGameCD = gamesCD.first else { return nil }
            return convertCDGameToModel(latestGameCD)
        } catch {
            print("Error loading latest game: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Convert Core Data Game Entity to GameModel
    private func convertCDGameToModel(_ gameCD: Game) -> GameModel {
        var mapping: [Character: Character] = [:]
        var correctMappings: [Character: Character] = [:]
        var guessedMappings: [Character: Character] = [:]
        
        // Deserialize mappings
        if let mappingData = gameCD.mappingData,
           let mappingDict = try? JSONDecoder().decode([String: String].self, from: mappingData) {
            mapping = mappingDict.convertToCharacterDictionary()
        }
        
        if let correctMappingsData = gameCD.correctMappingsData,
           let correctDict = try? JSONDecoder().decode([String: String].self, from: correctMappingsData) {
            correctMappings = correctDict.convertToCharacterDictionary()
        }
        
        if let guessedMappingsData = gameCD.guessedMappingsData,
           let guessedDict = try? JSONDecoder().decode([String: String].self, from: guessedMappingsData) {
            guessedMappings = guessedDict.convertToCharacterDictionary()
        }
        
        return GameModel(
            gameId: gameCD.gameId,
            encrypted: gameCD.encrypted ?? "",
            solution: gameCD.solution ?? "",
            currentDisplay: gameCD.currentDisplay ?? "",
            mapping: mapping,
            correctMappings: correctMappings,
            guessedMappings: guessedMappings,
            mistakes: Int(gameCD.mistakes),
            maxMistakes: Int(gameCD.maxMistakes),
            hasWon: gameCD.hasWon,
            hasLost: gameCD.hasLost,
            difficulty: gameCD.difficulty ?? "medium",
            startTime: gameCD.startTime ?? Date(),
            lastUpdateTime: gameCD.lastUpdateTime ?? Date()
        )
    }
    
    // Save game to Core Data
    private func saveGameToCD(_ game: GameModel) -> GameModel? {
        let context = cdStack.mainContext
        
        let gameCD = Game(context: context)
        gameCD.id = UUID()
        gameCD.gameId = game.gameId ?? UUID().uuidString
        gameCD.encrypted = game.encrypted
        gameCD.solution = game.solution
        gameCD.currentDisplay = game.currentDisplay
        gameCD.mistakes = Int16(game.mistakes)
        gameCD.maxMistakes = Int16(game.maxMistakes)
        gameCD.hasWon = game.hasWon
        gameCD.hasLost = game.hasLost
        gameCD.difficulty = game.difficulty
        gameCD.startTime = game.startTime
        gameCD.lastUpdateTime = game.lastUpdateTime
        gameCD.isDaily = game.gameId?.starts(with: "daily-") ?? false
        
        // Calculate and store score and time taken
        if game.hasWon || game.hasLost {
            gameCD.score = Int32(game.calculateScore())
            gameCD.timeTaken = Int32(game.lastUpdateTime.timeIntervalSince(game.startTime))
        }
        
        // Store mappings as serialized data
        do {
            gameCD.mappingData = try JSONEncoder().encode(game.mapping.mapToDictionary())
            gameCD.correctMappingsData = try JSONEncoder().encode(game.correctMappings.mapToDictionary())
            gameCD.guessedMappingsData = try JSONEncoder().encode(game.guessedMappings.mapToDictionary())
        } catch {
            print("Error encoding mappings: \(error.localizedDescription)")
        }
        
        // Save to Core Data
        do {
            try context.save()
            
            // Return updated game with gameId
            var updatedGame = game
            updatedGame.gameId = gameCD.gameId
            return updatedGame
        } catch {
            print("Error saving game: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Update existing game in Core Data
    private func updateGameInCD(_ game: GameModel) -> Bool {
        let context = cdStack.mainContext
        
        // Find existing game
        guard let gameId = game.gameId else { return false }
        
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameId)
        
        do {
            let results = try context.fetch(fetchRequest)
            guard let existingGameCD = results.first else { return false }
            
            // Update game properties
            existingGameCD.encrypted = game.encrypted
            existingGameCD.solution = game.solution
            existingGameCD.currentDisplay = game.currentDisplay
            existingGameCD.mistakes = Int16(game.mistakes)
            existingGameCD.maxMistakes = Int16(game.maxMistakes)
            existingGameCD.hasWon = game.hasWon
            existingGameCD.hasLost = game.hasLost
            existingGameCD.difficulty = game.difficulty
            existingGameCD.lastUpdateTime = game.lastUpdateTime
            
            // Update score and time taken if game is completed
            if game.hasWon || game.hasLost {
                existingGameCD.score = Int32(game.calculateScore())
                existingGameCD.timeTaken = Int32(game.lastUpdateTime.timeIntervalSince(game.startTime))
            }
            
            // Update mappings
            do {
                existingGameCD.mappingData = try JSONEncoder().encode(game.mapping.mapToDictionary())
                existingGameCD.correctMappingsData = try JSONEncoder().encode(game.correctMappings.mapToDictionary())
                existingGameCD.guessedMappingsData = try JSONEncoder().encode(game.guessedMappings.mapToDictionary())
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
    
    // Update user stats in Core Data
    private func updateUserStatsInCD(userId: String, gameWon: Bool, mistakes: Int, timeTaken: Int, score: Int) {
        let context = cdStack.mainContext
        
        // Find user
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let usersCD = try context.fetch(fetchRequest)
            guard let userCD = usersCD.first else { return }
            
            // Get or create stats
            let statsCD: UserStats
            if let existingStats = userCD.stats {
                statsCD = existingStats
            } else {
                statsCD = UserStats(context: context)
                userCD.stats = statsCD
                statsCD.user = userCD
            }
            
            // Update stats
            statsCD.gamesPlayed += 1
            if gameWon {
                statsCD.gamesWon += 1
                statsCD.currentStreak += 1
                statsCD.bestStreak = max(statsCD.bestStreak, statsCD.currentStreak)
            } else {
                statsCD.currentStreak = 0
            }
            
            statsCD.totalScore += Int32(score)
            
            // Update averages
            let oldMistakesTotal = statsCD.averageMistakes * Double(statsCD.gamesPlayed - 1)
            statsCD.averageMistakes = (oldMistakesTotal + Double(mistakes)) / Double(statsCD.gamesPlayed)
            
            let oldTimeTotal = statsCD.averageTime * Double(statsCD.gamesPlayed - 1)
            statsCD.averageTime = (oldTimeTotal + Double(timeTaken)) / Double(statsCD.gamesPlayed)
            
            statsCD.lastPlayedDate = Date()
            
            // Save the changes
            try context.save()
        } catch {
            print("Error updating stats: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Game State Management
    
    /// Check for an in-progress game
    func checkForInProgressGame() {
        // Look for unfinished games in Core Data
        if let game = loadLatestGameCD() {
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
            
            // Get quote info if available
            let context = cdStack.mainContext
            let fetchRequest: NSFetchRequest<Quote> = Quote.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "text == %@", savedGame.solution)
            
            do {
                let quotesCD = try context.fetch(fetchRequest)
                if let quoteCD = quotesCD.first {
                    quoteAuthor = quoteCD.author ?? ""
                    quoteAttribution = quoteCD.attribution
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
            markGameAsAbandonedInCD(gameId: oldGameId)
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
    
    // Mark a game as abandoned in Core Data
    private func markGameAsAbandonedInCD(gameId: String) {
        let context = cdStack.mainContext
        
        // Find the game
        let fetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameId)
        
        do {
            let gamesCD = try context.fetch(fetchRequest)
            if let gameCD = gamesCD.first {
                gameCD.hasLost = true
                
                // Reset streak if player had one
                if let userCD = gameCD.user, let statsCD = userCD.stats, statsCD.currentStreak > 0 {
                    statsCD.currentStreak = 0
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
                _ = updateGameInCD(game)
            } else {
                // Save new game
                if let updatedGame = saveGameToCD(game) {
                    currentGame = updatedGame
                }
            }
            return
        }
        
        // Get user entity from Core Data
        let context = cdStack.mainContext
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let usersCD = try context.fetch(fetchRequest)
            let userCD: User
            
            if let existingUser = usersCD.first {
                userCD = existingUser
            } else {
                // Create a new user if needed
                userCD = User(context: context)
                userCD.id = UUID()
                userCD.userId = userId
                userCD.username = UserState.shared.username
                userCD.email = "\(UserState.shared.username)@example.com" // Placeholder
                userCD.registrationDate = Date()
                userCD.lastLoginDate = Date()
                userCD.isActive = true
            }
            
            // Get or create game in Core Data
            let gameCD: Game
            let gameFetchRequest: NSFetchRequest<Game> = Game.fetchRequest()
            if let gameId = game.gameId {
                gameFetchRequest.predicate = NSPredicate(format: "gameId == %@", gameId)
                let gamesCD = try context.fetch(gameFetchRequest)
                
                if let existingGame = gamesCD.first {
                    gameCD = existingGame
                } else {
                    gameCD = Game(context: context)
                    gameCD.id = UUID()
                    gameCD.gameId = gameId
                    gameCD.startTime = game.startTime
                }
            } else {
                gameCD = Game(context: context)
                gameCD.id = UUID()
                gameCD.gameId = UUID().uuidString
                gameCD.startTime = game.startTime
            }
            
            // Update game properties
            gameCD.encrypted = game.encrypted
            gameCD.solution = game.solution
            gameCD.currentDisplay = game.currentDisplay
            gameCD.mistakes = Int16(game.mistakes)
            gameCD.maxMistakes = Int16(game.maxMistakes)
            gameCD.hasWon = game.hasWon
            gameCD.hasLost = game.hasLost
            gameCD.difficulty = game.difficulty
            gameCD.lastUpdateTime = game.lastUpdateTime
            gameCD.isDaily = game.gameId?.starts(with: "daily-") ?? false
            
            // Set the user relationship
            gameCD.user = userCD
            
            // Calculate and store score and time taken
            if game.hasWon || game.hasLost {
                gameCD.score = Int32(game.calculateScore())
                gameCD.timeTaken = Int32(game.lastUpdateTime.timeIntervalSince(game.startTime))
            }
            
            // Store mappings as serialized data
            do {
                gameCD.mappingData = try JSONEncoder().encode(game.mapping.mapToDictionary())
                gameCD.correctMappingsData = try JSONEncoder().encode(game.correctMappings.mapToDictionary())
                gameCD.guessedMappingsData = try JSONEncoder().encode(game.guessedMappings.mapToDictionary())
            } catch {
                print("Error encoding mappings: \(error)")
            }
            
            // Save changes
            try context.save()
            
            // Update the current game model with the ID if it was new
            if game.gameId == nil {
                var updatedGame = game
                updatedGame.gameId = gameCD.gameId
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
        updateUserStatsInCD(
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
