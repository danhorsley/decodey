import SwiftUI
import CoreData
import Foundation
import Combine

class GameState: ObservableObject {
    // Game state properties
    @Published var currentGame: GameModel?
    @Published var savedGame: GameModel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showContinueGameModal = false
    @Published var isInfiniteMode = false
    
    // NEW: Track which mode the win/loss modal is for
    @Published var winModalIsDaily = false
    @Published var loseModalIsDaily = false
    @Published var showWinMessage = false
    @Published var showLoseMessage = false
    
    // NEW: Store last completed game stats for re-display
    @Published var lastDailyGameStats: CompletedGameStats? = nil
    @Published var lastCustomGameStats: CompletedGameStats? = nil
    
    // NEW: Structure to hold completed game info
     struct CompletedGameStats {
         let solution: String
         let author: String
         let attribution: String?
         let score: Int
         let mistakes: Int
         let maxMistakes: Int
         let timeElapsed: Int
         let hasWon: Bool
         let currentDisplay: String  // For showing their attempt in loss modal
     }
    
    // Game metadata
    @Published var quoteAuthor: String = ""
    @Published var quoteAttribution: String? = nil
    @Published var quoteDate: String? = nil
    
    // Configuration
    @Published var isDailyChallenge = false
    @Published var defaultDifficulty = "medium"
    
    // Private properties
    private var dailyQuote: DailyQuoteModel?
    private let userManager = SimpleUserManager.shared
    
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
    
    /// Generate a simple substitution cipher
    private func generateCryptogramMapping(for text: String) -> [Character: Character] {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let shuffled = alphabet.shuffled()
        var mapping: [Character: Character] = [:]
        
        for (original, encrypted) in zip(alphabet, shuffled) {
            mapping[encrypted] = original
        }
        return mapping
    }
    
    /// Create encrypted version of text
    private func encryptText(_ text: String, with mapping: [Character: Character]) -> String {
        let reversedMapping = Dictionary(uniqueKeysWithValues: mapping.map { ($1, $0) })
        return text.map { char in
            if char.isLetter {
                let upperChar = char.uppercased().first!
                return reversedMapping[upperChar] ?? char
            } else {
                return char
            }
        }.map(String.init).joined()
    }
    
    private func setupDefaultGame() {
        let defaultText = "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG"
        let correctMappings = generateCryptogramMapping(for: defaultText)
        let encrypted = encryptText(defaultText, with: correctMappings)
        
        let game = GameModel(
            gameId: UUID().uuidString,
            encrypted: encrypted,
            solution: defaultText,
            currentDisplay: encrypted, // Start with encrypted version
            mapping: [:],
            correctMappings: correctMappings,
            guessedMappings: [:],
            incorrectGuesses: [:],
            mistakes: 0,
            maxMistakes: getMaxMistakesForDifficulty(SettingsState.shared.gameDifficulty),
            hasWon: false,
            hasLost: false,
            difficulty: SettingsState.shared.gameDifficulty,
            startTime: Date(),
            lastUpdateTime: Date()
        )
        
        self.currentGame = game
        self.quoteAuthor = "Anonymous"
        self.quoteAttribution = nil
    }
    
    // MARK: - Game Setup
    
    /// Set up daily challenge
    func setupDailyChallenge() {
        // Clear any custom game modals when switching to daily
        if !winModalIsDaily && showWinMessage {
            showWinMessage = false
        }
        if !loseModalIsDaily && showLoseMessage {
            showLoseMessage = false
        }
        
        self.isDailyChallenge = true
        
        // Check if we should show the stored daily modal
        if let dailyStats = lastDailyGameStats {
            // Check if it's still today's daily
            let today = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayString = formatter.string(from: today)
            
            // If we have a completed daily for today, show the appropriate modal
            if let savedGameId = savedGame?.gameId, savedGameId.contains(todayString) {
                quoteAuthor = dailyStats.author
                quoteAttribution = dailyStats.attribution
                
                if dailyStats.hasWon {
                    winModalIsDaily = true
                    showWinMessage = true
                } else {
                    loseModalIsDaily = true
                    showLoseMessage = true
                }
                return  // Don't setup a new game
            }
        }
        
        // Continue with normal daily setup...
        isLoading = true
        errorMessage = nil
        
        // Get today's date for deterministic daily quote
        let today = Date()
        let daysSinceEpoch = Int(today.timeIntervalSince1970 / 86400)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: today)
        
        // Check if we already have a saved game for today
        checkForInProgressGame(isDailyChallenge: true)
        
        // Use LocalQuoteManager to get deterministic daily quote
        if let localQuoteManager = LocalQuoteManager.shared.getDailyQuote(for: daysSinceEpoch) {
            createGameFromLocalQuote(localQuoteManager, gameId: "daily-\(dateString)")
        } else {
            // Fallback to Core Data
            loadQuoteFromCoreData(isDaily: true)
        }
    }
    
    /// Set up a custom/random game
    func setupCustomGame() {
        // Clear any daily game modals when switching to custom
        if winModalIsDaily && showWinMessage {
            showWinMessage = false
        }
        if loseModalIsDaily && showLoseMessage {
            showLoseMessage = false
        }
        
        self.isDailyChallenge = false
        self.dailyQuote = nil
        
        // Check if we should show a stored custom game modal
        if let customStats = lastCustomGameStats,
           let currentGame = currentGame,
           currentGame.hasWon || currentGame.hasLost {
            // Restore the modal for the last custom game
            quoteAuthor = customStats.author
            quoteAttribution = customStats.attribution
            
            if customStats.hasWon {
                winModalIsDaily = false
                showWinMessage = true
            } else {
                loseModalIsDaily = false
                showLoseMessage = true
            }
            return  // Don't setup a new game
        }
        
        // Continue with normal custom setup...
        isLoading = true
        errorMessage = nil
        
        // Get random quote from LocalQuoteManager or Core Data
        if let randomQuote = LocalQuoteManager.shared.getRandomQuote() {
            createGameFromLocalQuote(randomQuote, gameId: UUID().uuidString)
        } else {
            // Fallback to Core Data
            loadQuoteFromCoreData(isDaily: false)
        }
    }
    
    private func createGameFromLocalQuote(_ quote: LocalQuoteModel, gameId: String) {
        // Update UI data
        quoteAuthor = quote.author
        quoteAttribution = quote.attribution
        
        let text = quote.text.uppercased()
        let correctMappings = generateCryptogramMapping(for: text)
        let encrypted = encryptText(text, with: correctMappings)
        
        // Create game model
        let game = GameModel(
            gameId: gameId,
            encrypted: encrypted,
            solution: text,
            currentDisplay: encrypted,
            mapping: [:],
            correctMappings: correctMappings,
            guessedMappings: [:],
            incorrectGuesses: [:],
            mistakes: 0,
            maxMistakes: getMaxMistakesForDifficulty(SettingsState.shared.gameDifficulty),
            hasWon: false,
            hasLost: false,
            difficulty: SettingsState.shared.gameDifficulty,
            startTime: Date(),
            lastUpdateTime: Date()
        )
        
        currentGame = game
        isLoading = false
        
        // Save initial game state
        saveGameState(game)
    }
    
    private func loadQuoteFromCoreData(isDaily: Bool) {
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            let quotes = try context.fetch(fetchRequest)
            
            if !quotes.isEmpty {
                let randomIndex = isDaily ?
                    abs(Calendar.current.dateComponents([.day], from: Date()).day ?? 0) % quotes.count :
                    Int.random(in: 0..<quotes.count)
                
                let quote = quotes[randomIndex]
                
                // Update UI data
                quoteAuthor = quote.author ?? ""
                quoteAttribution = quote.attribution
                
                let text = (quote.text ?? "").uppercased()
                let correctMappings = generateCryptogramMapping(for: text)
                let encrypted = encryptText(text, with: correctMappings)
                
                let gameId = isDaily ? "daily-\(Date().formatted(.iso8601.year().month().day()))" : UUID().uuidString
                
                let game = GameModel(
                    gameId: gameId,
                    encrypted: encrypted,
                    solution: text,
                    currentDisplay: encrypted,
                    mapping: [:],
                    correctMappings: correctMappings,
                    guessedMappings: [:],
                    incorrectGuesses: [:],
                    mistakes: 0,
                    maxMistakes: getMaxMistakesForDifficulty(SettingsState.shared.gameDifficulty),
                    hasWon: false,
                    hasLost: false,
                    difficulty: SettingsState.shared.gameDifficulty,
                    startTime: Date(),
                    lastUpdateTime: Date()
                )
                
                currentGame = game
                saveGameState(game)
            } else {
                errorMessage = "No quotes available"
                useFallbackQuote()
            }
        } catch {
            errorMessage = "Failed to load quote: \(error.localizedDescription)"
            useFallbackQuote()
        }
        
        isLoading = false
    }
    
    private func useFallbackQuote() {
        setupDefaultGame()
        isLoading = false
    }
    
    // MARK: - Game Actions
    
    /// Handle a player's guess
    func makeGuess(_ guessedLetter: Character) {
        guard var game = currentGame else { return }
        
        // Only proceed if a letter is selected
        if game.selectedLetter != nil {
            let wasCorrect = game.makeGuess(guessedLetter)
            self.currentGame = game
            
            // Play appropriate sound
            if wasCorrect {
                SoundManager.shared.play(.correctGuess)
            } else {
                SoundManager.shared.play(.incorrectGuess)
            }
            
            // Save game state after each guess
            printGameDetails() // Debug
            saveGameState(game)
            
            // Check if the game is complete
            if game.hasWon {
                // Submit score BEFORE showing modal
                submitScore()
                
                // Store the completed game stats for display
                saveCompletedGameStats(game, won: true)
                winModalIsDaily = isDailyChallenge
                showWinMessage = true
                
                // Play win sound
                SoundManager.shared.play(.win)
            } else if game.hasLost {
                // Submit score BEFORE showing modal
                submitScore()
                
                // Store the completed game stats for display
                saveCompletedGameStats(game, won: false)
                loseModalIsDaily = isDailyChallenge
                showLoseMessage = true
                
                // Play lose sound
                SoundManager.shared.play(.lose)
            }
        }
    }

    
    //helper to temp stoore data between states
    private func saveCompletedGameStats(_ game: GameModel, won: Bool) {
        let elapsed = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
        let stats = CompletedGameStats(
            solution: game.solution,
            author: quoteAuthor,
            attribution: quoteAttribution,
            score: won ? game.calculateScore() : 0,
            mistakes: game.mistakes,
            maxMistakes: game.maxMistakes,
            timeElapsed: elapsed,
            hasWon: won,
            currentDisplay: game.currentDisplay
        )
        
        if isDailyChallenge {
            lastDailyGameStats = stats
        } else {
            lastCustomGameStats = stats
        }
    }
    /// Select a letter to decode
    func selectLetter(_ letter: Character) {
        guard var game = currentGame else { return }
        game.selectLetter(letter)
        self.currentGame = game
    }
    
    /// Get a hint - RESTORED METHOD
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
                // Submit score BEFORE showing modal
                submitScore()
                
                // Store the completed game stats for display
                saveCompletedGameStats(game, won: true)
                winModalIsDaily = isDailyChallenge
                showWinMessage = true
            } else if game.hasLost {
                // Submit score BEFORE showing modal
                submitScore()
                
                // Store the completed game stats for display
                saveCompletedGameStats(game, won: false)
                loseModalIsDaily = isDailyChallenge
                showLoseMessage = true
            }
        }
    }
    
    // UPDATED: Reset game method
    func resetGame() {
        isInfiniteMode = false
        
        // Clear the appropriate saved stats
        if isDailyChallenge {
            lastDailyGameStats = nil
        } else {
            lastCustomGameStats = nil
        }
        
        // If there was a saved game, mark it as abandoned
        if let oldGameId = savedGame?.gameId {
            markGameAsAbandoned(gameId: oldGameId)
        }
        
        if isDailyChallenge {
            // For daily challenge, restart with same quote
            setupDailyChallenge()
        } else {
            // For random games, load a new random game
            setupCustomGame()
        }
        
        // Clear the saved game reference
        self.savedGame = nil
        
        // Reset UI state
        showWinMessage = false
        showLoseMessage = false
    }
    func validateModalState() {
            // If showing a win modal for the wrong mode, hide it
            if showWinMessage && (winModalIsDaily != isDailyChallenge) {
                showWinMessage = false
            }
            
            // If showing a loss modal for the wrong mode, hide it
            if showLoseMessage && (loseModalIsDaily != isDailyChallenge) {
                showLoseMessage = false
            }
        }
    
    // Mark a game as abandoned
    private func markGameAsAbandoned(gameId: String) {
        let context = coreData.mainContext
        
        // Handle different game ID formats
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        
        if gameId.hasPrefix("daily-") {
            // For daily games, search by gameId string representation
            fetchRequest.predicate = NSPredicate(format: "gameId.description CONTAINS %@", gameId)
        } else if let gameUUID = UUID(uuidString: gameId) {
            // For regular games with UUID
            fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameUUID as CVarArg)
        } else {
            return
        }
        
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
    
    //debug tool for game state
    func printGameDetails() {
        if let game = currentGame {
            print("Current Game ID: \(game.gameId ?? "nil")")
            print("Game Status - Won: \(game.hasWon), Lost: \(game.hasLost)")
            print("Mistakes: \(game.mistakes)/\(game.maxMistakes)")
            print("Current Display: \(game.currentDisplay)")
        }
    }
    
    // MARK: - Game Persistence
    
    private func saveGameState(_ game: GameModel) {
        // Don't save if we're in infinite mode (post-loss practice)
        guard !isInfiniteMode else { return }
        
        guard let gameId = game.gameId else {
            print("Error: Trying to save game state with no game ID")
            return
        }
        
        let context = coreData.mainContext
        
        // Handle UUID conversion
        let gameUUID: UUID
        if gameId.hasPrefix("daily-") {
            // Create a deterministic UUID for daily games
            let hash = abs(gameId.hashValue)
            let uuidString = String(format: "00000000-0000-0000-0000-%012d", hash % 1000000000000)
            gameUUID = UUID(uuidString: uuidString) ?? UUID()
        } else {
            gameUUID = UUID(uuidString: gameId) ?? UUID()
        }
        
        // Try to find existing game
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameUUID as CVarArg)
        
        do {
            let games = try context.fetch(fetchRequest)
            let entity: GameCD
            
            if let existingGame = games.first {
                entity = existingGame
            } else {
                entity = GameCD(context: context)
                entity.gameId = gameUUID
            }
            
            // Update game data
            updateGameEntity(entity, from: game)
            
            // IMPORTANT: Calculate and save the score
            entity.score = Int32(game.calculateScore())
            
            // Associate with current user if signed in
            if userManager.isSignedIn && !userManager.playerName.isEmpty {
                let primaryId = UserState.shared.userId.isEmpty ? userManager.playerName.lowercased() : UserState.shared.userId
                let userFetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
                userFetchRequest.predicate = NSPredicate(format: "primaryIdentifier == %@", primaryId)
                
                if let users = try? context.fetch(userFetchRequest),
                   let user = users.first {
                    entity.user = user
                }
            } else {
                // Associate with anonymous user
                entity.user = userManager.getOrCreateAnonymousUser()
            }
            
            // Save the saved game reference
            self.savedGame = game
            
            try context.save()
            print("✅ Game state saved with score: \(entity.score)")
            
        } catch {
            print("Error saving game state: \(error.localizedDescription)")
        }
    }
    
    private func updateGameEntity(_ entity: GameCD, from game: GameModel) {
        entity.encrypted = game.encrypted
        entity.solution = game.solution
        entity.currentDisplay = game.currentDisplay
        entity.mistakes = Int16(game.mistakes)
        entity.maxMistakes = Int16(game.maxMistakes)
        entity.hasWon = game.hasWon
        entity.hasLost = game.hasLost
        entity.lastUpdateTime = game.lastUpdateTime
        entity.isDaily = isDailyChallenge
        entity.difficulty = game.difficulty
        entity.startTime = game.startTime
        
        // IMPORTANT: Always calculate and save the current score
        entity.score = Int32(game.calculateScore())
        
        // Convert character mappings to JSON data for Core Data
        do {
            entity.mapping = try JSONEncoder().encode(characterDictionaryToStringDictionary(game.mapping))
            entity.correctMappings = try JSONEncoder().encode(characterDictionaryToStringDictionary(game.correctMappings))
            entity.guessedMappings = try JSONEncoder().encode(characterDictionaryToStringDictionary(game.guessedMappings))
            
            // Handle incorrect guesses
            var incorrectGuessesDict = [String: [String]]()
            for (key, value) in game.incorrectGuesses {
                incorrectGuessesDict[String(key)] = Array(value).map { String($0) }
            }
            entity.incorrectGuesses = try JSONEncoder().encode(incorrectGuessesDict)
        } catch {
            print("Error encoding game mappings: \(error)")
        }
    }
    
    
    // Helper functions for character dictionary conversions
    private func characterDictionaryToStringDictionary(_ dict: [Character: Character]) -> [String: String] {
        var result = [String: String]()
        for (key, value) in dict {
            result[String(key)] = String(value)
        }
        return result
    }
    
    // MARK: - Game Continuation
    
    /// Check for in-progress games
    public func checkForInProgressGame(isDailyChallenge: Bool) {
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        
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
    
    /// Skip the saved game and start fresh
    func skipSavedGame() {
        // Mark the saved game as abandoned
        if let oldGameId = savedGame?.gameId {
            markGameAsAbandoned(gameId: oldGameId)
        }
        
        self.showContinueGameModal = false
        self.savedGame = nil
        
        // Continue with fresh game setup
        if isDailyChallenge {
            setupDailyChallenge()
        } else {
            setupCustomGame()
        }
    }
    
    // MARK: - Enable inifnite mode
    func enableInfiniteMode() {
        isInfiniteMode = true
        
        // Remove the loss state but keep the game going
        if var game = currentGame {
            game.hasLost = false
            game.maxMistakes = 999  // Effectively unlimited
            self.currentGame = game
        }
        
        print("🎮 Infinite mode enabled - unlimited mistakes!")
    }
    
    // MARK: - Score Submission & Stats
    
    /// Submit score for completed game
    func submitScore() {
        guard let game = currentGame, game.hasWon || game.hasLost else {
            print("⚠️ Cannot submit score - no valid completed game")
            return
        }
        
        // Use UserIdentityManager if it exists, otherwise use the old approach
        let identityManager = UserIdentityManager.shared
        let context = coreData.mainContext
        
        // Calculate the score once
        let finalScore = game.calculateScore()
        let timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
        
        print("📊 Submitting score - Score: \(finalScore), Time: \(timeTaken)s, Won: \(game.hasWon)")
        print("   User: \(identityManager.displayName) [\(identityManager.primaryIdentifier)]")
        
        // Update stats using UserIdentityManager
        identityManager.updateStatsAfterGame(
            won: game.hasWon,
            score: finalScore,
            mistakes: game.mistakes,
            timeTaken: timeTaken
        )
        
        // Also save the game record
        do {
            let user = identityManager.getCurrentUser()
            
            if let gameId = game.gameId {
                let gameUUID: UUID
                if gameId.hasPrefix("daily-") {
                    let hash = abs(gameId.hashValue)
                    let uuidString = String(format: "00000000-0000-0000-0000-%012d", hash % 1000000000000)
                    gameUUID = UUID(uuidString: uuidString) ?? UUID()
                } else {
                    gameUUID = UUID(uuidString: gameId) ?? UUID()
                }
                
                let gameFetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
                gameFetchRequest.predicate = NSPredicate(format: "gameId == %@", gameUUID as CVarArg)
                
                if let games = try? context.fetch(gameFetchRequest),
                   let gameEntity = games.first {
                    // Update existing game
                    gameEntity.score = Int32(finalScore)
                    gameEntity.user = user
                    gameEntity.hasWon = game.hasWon
                    gameEntity.hasLost = game.hasLost
                    gameEntity.timeTaken = Int32(timeTaken)
                    print("✅ Updated existing game record")
                } else if let user = user {
                    // Create new game record
                    let gameEntity = GameCD(context: context)
                    gameEntity.gameId = gameUUID
                    gameEntity.encrypted = game.encrypted
                    gameEntity.solution = game.solution
                    gameEntity.currentDisplay = game.currentDisplay
                    gameEntity.mistakes = Int16(game.mistakes)
                    gameEntity.maxMistakes = Int16(game.maxMistakes)
                    gameEntity.hasWon = game.hasWon
                    gameEntity.hasLost = game.hasLost
                    gameEntity.difficulty = game.difficulty
                    gameEntity.startTime = game.startTime
                    gameEntity.lastUpdateTime = game.lastUpdateTime
                    gameEntity.score = Int32(finalScore)
                    gameEntity.timeTaken = Int32(timeTaken)
                    gameEntity.isDaily = isDailyChallenge
                    gameEntity.user = user
                    print("✅ Created new game record")
                }
                
                try context.save()
            }
            
            // Submit to Game Center if available
            if game.hasWon {
                Task {
                    if let stats = identityManager.getUserStats() {
                        await GameCenterManager.shared.submitTotalScore(Int(stats.totalScore))
                    }
                }
            }
            
            print("✅ Score submission complete")
            
        } catch {
            print("❌ Error saving game record: \(error)")
        }
    }

    
    // MARK: - State Management
    
    /// Reset the entire state
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
    
    // MARK: - Utility Methods
    
    // Helper for time formatting
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

