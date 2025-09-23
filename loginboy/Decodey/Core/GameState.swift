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
    @Published var isInfiniteMode = false
    
    // Track which mode the win/loss modal is for
    @Published var winModalIsDaily = false
    @Published var loseModalIsDaily = false
    @Published var showWinMessage = false
    @Published var showLoseMessage = false
    
    // Store last completed game stats for re-display
    @Published var lastDailyGameStats: CompletedGameStats? = nil
    @Published var lastCustomGameStats: CompletedGameStats? = nil
    
    // Structure to hold completed game info
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
    
    // Add flag to prevent multiple encryption setups
    private var isSettingUpGame = false
    
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
        guard !isSettingUpGame else { return }
        isSettingUpGame = true
        defer { isSettingUpGame = false }
        
        let defaultText = "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG"
        let correctMappings = generateCryptogramMapping(for: defaultText)
        let encrypted = encryptText(defaultText, with: correctMappings)
        
        let game = GameModel(
            gameId: UUID().uuidString,
            encrypted: encrypted,
            solution: defaultText,
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
        
        self.currentGame = game
        self.quoteAuthor = "Anonymous"
        self.quoteAttribution = nil
    }
    
    // MARK: - Game Setup
    
    /// Set up daily challenge
    func setupDailyChallenge() {
        guard !isSettingUpGame else { return }
        
        // Clear any custom game modals when switching to daily
        if !winModalIsDaily && showWinMessage {
            showWinMessage = false
        }
        if !loseModalIsDaily && showLoseMessage {
            showLoseMessage = false
        }
        
        self.isDailyChallenge = true
        
        // Check if we should show the stored daily modal
        if let dailyStats = lastDailyGameStats,
           let currentGame = currentGame,
           currentGame.hasWon || currentGame.hasLost {
            // Restore the modal for the last daily game
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
        
        // Continue with normal daily setup...
        isLoading = true
        errorMessage = nil
        
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: today)
        
        self.quoteDate = dateString
        
        // Try LocalQuoteManager first
        let daysSinceEpoch = Int(today.timeIntervalSince1970 / 86400)
        if let quote = LocalQuoteManager.shared.getDailyQuote(for: daysSinceEpoch) {
            createGameFromLocalQuote(quote, gameId: "daily-\(dateString)")
        } else {
            // Fallback to Core Data
            loadQuoteFromCoreData(isDaily: true)
        }
    }
    
    /// Set up a custom/random game
    func setupCustomGame() {
        guard !isSettingUpGame else { return }
        
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
    
    // MARK: - Game Creation
    
    /// Create game from local quote
    private func createGameFromLocalQuote(_ quote: LocalQuoteModel, gameId: String) {
        isSettingUpGame = true
        defer { isSettingUpGame = false }
        
        let solutionText = quote.text.uppercased()
        
        // Generate mapping once - DO NOT call setupEncryption
        let correctMappings = generateCryptogramMapping(for: solutionText)
        let encrypted = encryptText(solutionText, with: correctMappings)
        
        let game = GameModel(
            gameId: gameId,
            encrypted: encrypted,
            solution: solutionText,
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
        
        self.currentGame = game
        self.quoteAuthor = quote.author
        self.quoteAttribution = quote.attribution
        self.isLoading = false
        
        // Save to Core Data
        saveQuoteIfNeeded(quote)
        saveGameState(game)
        
        print("✅ Created game from local quote: \(quote.text.prefix(30))...")
    }
    
    /// Load quote from Core Data
    private func loadQuoteFromCoreData(isDaily: Bool) {
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        
        do {
            let quotes = try context.fetch(fetchRequest)
            
            guard !quotes.isEmpty else {
                errorMessage = "No quotes available"
                isLoading = false
                return
            }
            
            let selectedQuote: QuoteCD
            if isDaily {
                // For daily, use date-based selection
                let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
                let index = (dayOfYear - 1) % quotes.count
                selectedQuote = quotes[index]
            } else {
                // For custom, random selection
                selectedQuote = quotes.randomElement()!
            }
            
            createGameFromCoreDataQuote(selectedQuote)
            
        } catch {
            errorMessage = "Failed to load quotes: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Create game from Core Data quote
    private func createGameFromCoreDataQuote(_ quote: QuoteCD) {
        guard let text = quote.text else { return }
        
        isSettingUpGame = true
        defer { isSettingUpGame = false }
        
        let solutionText = text.uppercased()
        
        // Generate mapping once - DO NOT call setupEncryption
        let correctMappings = generateCryptogramMapping(for: solutionText)
        let encrypted = encryptText(solutionText, with: correctMappings)
        
        let gameId = isDailyChallenge ? "daily-\(Date())" : UUID().uuidString
        
        let game = GameModel(
            gameId: gameId,
            encrypted: encrypted,
            solution: solutionText,
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
        
        self.currentGame = game
        self.quoteAuthor = quote.author ?? "Unknown"
        self.quoteAttribution = quote.attribution
        self.isLoading = false
        
        // Save game state
        saveGameState(game)
    }
    
    // MARK: - Game Actions
    
    /// Make a guess for the selected letter
    func makeGuess(for encryptedLetter: Character, with guessedLetter: Character) {
        guard var game = currentGame else { return }
        
        // First select the encrypted letter, then make the guess
        game.selectLetter(encryptedLetter)
        let wasCorrect = game.makeGuess(guessedLetter)
        self.currentGame = game
        
        // Play appropriate sound
        if wasCorrect {
            SoundManager.shared.play(.correctGuess)
        } else {
            SoundManager.shared.play(.incorrectGuess)
        }
        
        // Save game state
        saveGameState(game)
        
        // Check game status
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
    
    /// Reset game method
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
    
    /// Enable infinite mode
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
    
    // MARK: - Private Helper Methods
    
    /// Save completed game stats for display
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
    
    /// Save quote if needed
    private func saveQuoteIfNeeded(_ quote: LocalQuoteModel) {
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        fetchRequest.predicate = NSPredicate(format: "text == %@", quote.text)
        
        do {
            let existingQuotes = try context.fetch(fetchRequest)
            if existingQuotes.isEmpty {
                let quoteEntity = QuoteCD(context: context)
                quoteEntity.text = quote.text
                quoteEntity.author = quote.author
                quoteEntity.attribution = quote.attribution
                quoteEntity.difficulty = quote.difficulty
                quoteEntity.uniqueLetters = Int16(Set(quote.text.filter { $0.isLetter }).count)
                
                try context.save()
                print("✅ Saved new quote to Core Data")
            }
        } catch {
            print("Error saving quote: \(error)")
        }
    }
    
    /// Save game state to Core Data
    private func saveGameState(_ game: GameModel) {
        let context = coreData.mainContext
        
        // Convert gameId string to UUID
        let gameUUID: UUID
        if let gameId = game.gameId {
            if gameId.hasPrefix("daily-") {
                // Create deterministic UUID for daily challenges
                let hash = abs(gameId.hashValue)
                let uuidString = String(format: "00000000-0000-0000-0000-%012d", hash % 1000000000000)
                gameUUID = UUID(uuidString: uuidString) ?? UUID()
            } else {
                gameUUID = UUID(uuidString: gameId) ?? UUID()
            }
        } else {
            gameUUID = UUID()
        }
        
        // Check if game already exists
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameUUID as CVarArg)
        
        do {
            let existingGames = try context.fetch(fetchRequest)
            let gameEntity: GameCD
            
            if let existing = existingGames.first {
                gameEntity = existing
            } else {
                gameEntity = GameCD(context: context)
                gameEntity.gameId = gameUUID
            }
            
            // Update game entity
            updateGameEntity(gameEntity, from: game)
            
            try context.save()
            
        } catch {
            print("Error saving game state: \(error)")
        }
    }
    
    /// Update game entity from model
    private func updateGameEntity(_ entity: GameCD, from game: GameModel) {
        entity.encrypted = game.encrypted
        entity.solution = game.solution
        entity.currentDisplay = game.currentDisplay
        entity.mistakes = Int16(game.mistakes)
        entity.maxMistakes = Int16(game.maxMistakes)
        entity.hasWon = game.hasWon
        entity.hasLost = game.hasLost
        entity.difficulty = game.difficulty
        entity.startTime = game.startTime
        entity.lastUpdateTime = game.lastUpdateTime
        entity.isDaily = isDailyChallenge
        
        // Encode mappings
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
    
    /// Helper function for character dictionary conversions
    private func characterDictionaryToStringDictionary(_ dict: [Character: Character]) -> [String: String] {
        var result = [String: String]()
        for (key, value) in dict {
            result[String(key)] = String(value)
        }
        return result
    }
    
    /// Mark game as abandoned
    private func markGameAsAbandoned(gameId: String) {
        let context = coreData.mainContext
        
        let gameUUID: UUID
        if gameId.hasPrefix("daily-") {
            let hash = abs(gameId.hashValue)
            let uuidString = String(format: "00000000-0000-0000-0000-%012d", hash % 1000000000000)
            gameUUID = UUID(uuidString: uuidString) ?? UUID()
        } else {
            gameUUID = UUID(uuidString: gameId) ?? UUID()
        }
        
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameUUID as CVarArg)
        
        do {
            let games = try context.fetch(fetchRequest)
            if let game = games.first {
                game.hasLost = true
                try context.save()
                print("✅ Marked game as abandoned")
            }
        } catch {
            print("Error marking game as abandoned: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    
    /// Format time for display
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
