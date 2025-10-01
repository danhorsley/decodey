import SwiftUI
import CoreData
import Combine

// MARK: - Simplified GameState with isActive Management
class GameState: ObservableObject {
    static let shared = GameState()
    
    // MARK: - Published Properties (keep existing ones)
    @Published var currentGame: GameModel?
    @Published var isDailyChallenge = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var defaultDifficulty = "medium"
    
    // Quote information (keep existing)
    @Published var quoteAuthor = ""
    @Published var quoteAttribution: String?
    @Published var quoteDate: String?
    
    // Modal states (keep existing)
    @Published var showWinMessage = false
    @Published var showLoseMessage = false
    @Published var winModalIsDaily = false
    @Published var loseModalIsDaily = false
    @Published var isInfiniteMode = false
    
    //Turorial
    @Published var showTutorial = true
    
    // Game display states (keep existing)
    @Published var selectedEncryptedLetter: Character?
    @Published var selectedGuessLetter: Character?
    @Published var userGuessedLetter: Character?
    @Published var showMessage = false
    @Published var messageTitle = ""
    @Published var messageText = ""
    
    // Store completed game stats (keep existing)
    public var lastDailyGameStats: CompletedGameStats?
    public var lastCustomGameStats: CompletedGameStats?
    
    // For completed games (keep existing)
    struct CompletedGameStats {
        let solution: String
        let author: String
        let attribution: String?
        let score: Int
        let mistakes: Int
        let maxMistakes: Int
        let timeElapsed: Int
        let hasWon: Bool
        let currentDisplay: String
    }
    
    // MARK: - Private Properties
    private let coreData = CoreDataStack.shared
    private var cancellables = Set<AnyCancellable>()
    private var isSettingUpGame = false
    private var playTimer: Timer?
    
    private init() {}
    
    // MARK: - NEW: Simplified Game Loading with isActive
    
    /// Load or create game based on tab selection
    func loadOrCreateGame(isDaily: Bool) {
        if isDaily {
            loadOrCreateDailyGame()
        } else {
            loadOrCreateRandomGame()
        }
    }
    
    /// Load active daily or create new one
    private func loadOrCreateDailyGame() {
        let context = coreData.mainContext
        let todayString = DateFormatter.yyyyMMdd.string(from: Date())
        let dailyUUID = dailyStringToUUID("daily-\(todayString)")
        
        // Check if today's daily exists
        let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", dailyUUID as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            if let dailyGame = try context.fetch(fetchRequest).first {
                // Daily exists
                if dailyGame.hasWon || dailyGame.hasLost {
                    // Completed - just load for display
                    loadGameFromEntity(dailyGame)
                    if dailyGame.hasWon {
                        showWinMessage = true
                        winModalIsDaily = true
                    } else {
                        showLoseMessage = true
                        loseModalIsDaily = true
                    }
                } else {
                    // In progress - make active and load
                    deactivateOtherGames(ofType: true)
                    dailyGame.isActive = true
                    try? context.save()
                    loadGameFromEntity(dailyGame)
                }
            } else {
                // No daily exists - create new
                createNewDailyGame()
            }
        } catch {
            errorMessage = "Failed to load daily: \(error.localizedDescription)"
        }
    }
    
    /// Load active random or create new one
    private func loadOrCreateRandomGame() {
        let context = coreData.mainContext
        
        // If there's a current game that's completed, clear it
        if let current = currentGame, (current.hasWon || current.hasLost) {
            currentGame = nil
            showWinMessage = false
            showLoseMessage = false
        }
        
        // Look for active random game
        let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isActive == YES AND isDaily == NO")
        fetchRequest.fetchLimit = 1
        
        do {
            if let activeGame = try context.fetch(fetchRequest).first {
                if activeGame.hasWon || activeGame.hasLost {
                    // Completed but still marked active - deactivate and create new
                    activeGame.isActive = false
                    try? context.save()
                    createNewRandomGame()
                } else {
                    // Resume active game only if not completed
                    loadGameFromEntity(activeGame)
                }
            } else {
                // No active game - create new
                createNewRandomGame()
            }
        } catch {
            errorMessage = "Failed to load game: \(error.localizedDescription)"
        }
    }
    
    // MARK: Time recording
    func startTrackingTime() {
            playTimer?.invalidate()
            playTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if var game = self.currentGame, !game.hasWon && !game.hasLost {
                    game.activeSeconds += 1
                    game.lastUpdateTime = Date()  // Already exists!
                    self.currentGame = game
                }
            }
        }
        
    func stopTrackingTime() {
        playTimer?.invalidate()
        playTimer = nil
        if let game = currentGame {
            saveGameState(game)  // Save accumulated time
        }
    }
    
    // MARK: - Game Creation (Updated with isActive)
    
    private func createNewDailyGame() {
        guard let quote = DailyChallengeManager.shared.getTodaysDailyQuote() else {
            errorMessage = "No daily quote available"
            return
        }
        
        let context = coreData.mainContext
        let todayString = DateFormatter.yyyyMMdd.string(from: Date())
        let gameId = "daily-\(todayString)"
        
        // Deactivate other dailies
        deactivateOtherGames(ofType: true)
        
        // Create new game
        let gameEntity = GameCD(context: context)
        gameEntity.gameId = dailyStringToUUID(gameId)
        gameEntity.isDaily = true
        gameEntity.isActive = true
        
        // Setup game from quote
        let localQuote = LocalQuoteModel(
            text: quote.text,
            author: quote.author,
            attribution: quote.attribution,
            difficulty: quote.difficulty,
            category: quote.category
        )
        setupGameEntity(gameEntity, from: localQuote)
        
        do {
            try context.save()
            loadGameFromEntity(gameEntity)
            isDailyChallenge = true
        } catch {
            errorMessage = "Failed to create daily: \(error.localizedDescription)"
        }
    }
    
    private func createNewRandomGame() {
        let context = coreData.mainContext
        
        // Get random quote
        let quoteFetch: NSFetchRequest<QuoteCD> = QuoteCD.fetchRequest()
        quoteFetch.predicate = NSPredicate(format: "isActive == YES")
        
        guard let quotes = try? context.fetch(quoteFetch),
              let randomQuote = quotes.randomElement() else {
            errorMessage = "No quotes available"
            return
        }
        
        // Deactivate other random games
        deactivateOtherGames(ofType: false)
        
        // Create new game
        let gameEntity = GameCD(context: context)
        gameEntity.gameId = UUID()
        gameEntity.isDaily = false
        gameEntity.isActive = true
        
        let quote = LocalQuoteModel(
            text: randomQuote.text ?? "",
            author: randomQuote.author ?? "Unknown",
            attribution: randomQuote.attribution,
            difficulty: randomQuote.difficulty,
        )
        setupGameEntity(gameEntity, from: quote)
        
        do {
            try context.save()
            loadGameFromEntity(gameEntity)
            isDailyChallenge = false
        } catch {
            errorMessage = "Failed to create game: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Methods (Keep Existing)
    
    /// Get max mistakes based on difficulty
    private func getMaxMistakesForDifficulty(_ difficulty: String) -> Int {
        switch difficulty.lowercased() {
        case "easy": return 8
        case "hard": return 3
        default: return 5  // Medium
        }
    }
    
    /// Generate cryptogram mapping (keep existing)
    private func generateCryptogramMapping(for text: String) -> [Character: Character] {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let shuffled = alphabet.shuffled()
        var mapping: [Character: Character] = [:]
        
        for (original, encrypted) in zip(alphabet, shuffled) {
            mapping[encrypted] = original
        }
        return mapping
    }
    
    /// Encrypt text (keep existing)
    private func encryptText(_ text: String, with mapping: [Character: Character]) -> String {
        let reversedMapping = Dictionary(uniqueKeysWithValues: mapping.map { ($1, $0) })
        
        return text.map { char in
            if char.isLetter {
                guard let upperChar = char.uppercased().first else {
                    return String(char)
                }
                
                if let mappedChar = reversedMapping[upperChar] {
                    return String(mappedChar)
                } else {
                    return String(char)
                }
            } else {
                return String(char)
            }
        }.joined()
    }
    
    /// Setup game entity with cryptogram
    private func setupGameEntity(_ entity: GameCD, from quote: LocalQuoteModel) {
        let text = quote.text.uppercased()
        let correctMappings = generateCryptogramMapping(for: text)
        let encrypted = encryptText(text, with: correctMappings)
        
        entity.encrypted = encrypted
        entity.solution = text
        entity.currentDisplay = encrypted
        entity.mistakes = 0
        entity.maxMistakes = entity.isDaily ? 5 : Int16(getMaxMistakesForDifficulty(SettingsState.shared.gameDifficulty))
        entity.hasWon = false
        entity.hasLost = false
        entity.difficulty = entity.isDaily ? "medium" : SettingsState.shared.gameDifficulty
        entity.startTime = Date()
        entity.lastUpdateTime = Date()
        
        // Store quote info
        self.quoteAuthor = quote.author
        self.quoteAttribution = quote.attribution
        
        // Encode mappings
        if let mappingData = try? JSONEncoder().encode(correctMappings.mapToStringDict()) {
            entity.correctMappings = mappingData
        }
        entity.mapping = try? JSONEncoder().encode([String: String]())
        entity.guessedMappings = try? JSONEncoder().encode([String: String]())
        entity.incorrectGuesses = try? JSONEncoder().encode([String: [String]]())
    }
    
    /// Load game from entity
    private func loadGameFromEntity(_ entity: GameCD) {
        // Convert to game model
        let gameIdString: String
        if entity.isDaily {
            let dateString = DateFormatter.yyyyMMdd.string(from: entity.startTime ?? Date())
            gameIdString = "daily-\(dateString)"
        } else {
            gameIdString = entity.gameId?.uuidString ?? UUID().uuidString
        }
        
        // Decode mappings
        var correctMappings: [Character: Character] = [:]
        var guessedMappings: [Character: Character] = [:]
        var mapping: [Character: Character] = [:]
        var incorrectGuesses: [Character: Set<Character>] = [:]
        
        if let data = entity.correctMappings,
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            correctMappings = decoded.stringDictToCharDict()
        }
        
        if let data = entity.guessedMappings,
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            guessedMappings = decoded.stringDictToCharDict()
        }
        
        if let data = entity.mapping,
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            mapping = decoded.stringDictToCharDict()
        }
        
        if let data = entity.incorrectGuesses,
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            for (key, values) in decoded {
                if let keyChar = key.first {
                    incorrectGuesses[keyChar] = Set(values.compactMap { $0.first })
                }
            }
        }
        
        self.currentGame = GameModel(
            gameId: gameIdString,
            encrypted: entity.encrypted ?? "",
            solution: entity.solution ?? "",
            currentDisplay: entity.currentDisplay ?? "",
            mapping: mapping,
            correctMappings: correctMappings,
            guessedMappings: guessedMappings,
            incorrectGuesses: incorrectGuesses,
            mistakes: Int(entity.mistakes),
            maxMistakes: Int(entity.maxMistakes),
            hasWon: entity.hasWon,
            hasLost: entity.hasLost,
            difficulty: entity.difficulty ?? "medium",
            startTime: entity.startTime ?? Date(),
            lastUpdateTime: entity.lastUpdateTime ?? Date()
        )
        
        self.isDailyChallenge = entity.isDaily
        
        // Load quote info if available
        let quoteFetch: NSFetchRequest<QuoteCD> = QuoteCD.fetchRequest()
        quoteFetch.predicate = NSPredicate(format: "text == %@", entity.solution ?? "")
        quoteFetch.fetchLimit = 1
        
        if let quote = try? coreData.mainContext.fetch(quoteFetch).first {
            self.quoteAuthor = quote.author ?? "Unknown"
            self.quoteAttribution = quote.attribution
        }
    }
    
    /// Deactivate other games of same type
    private func deactivateOtherGames(ofType isDaily: Bool) {
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isActive == YES AND isDaily == %@", NSNumber(value: isDaily))
        
        if let games = try? context.fetch(fetchRequest) {
            games.forEach { $0.isActive = false }
        }
    }
    
    /// Convert daily string to UUID
    private func dailyStringToUUID(_ dailyId: String) -> UUID {
        let hash = abs(dailyId.hashValue)
        let uuidString = String(format: "00000000-0000-0000-0000-%012d", hash % 1000000000000)
        return UUID(uuidString: uuidString) ?? UUID()
    }
    
    // MARK: - Game Actions (Keep Existing)
    
    /// Make a guess (keep existing implementation)
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
            submitScore()
            saveCompletedGameStats(game, won: true)
            winModalIsDaily = isDailyChallenge
            showWinMessage = true
            SoundManager.shared.play(.win)
        } else if game.hasLost {
            submitScore()
            saveCompletedGameStats(game, won: false)
            loseModalIsDaily = isDailyChallenge
            showLoseMessage = true
            SoundManager.shared.play(.lose)
        }
    }
    //select first letter
    func selectLetter(_ letter: Character) {
        guard var game = currentGame else { return }
        game.selectLetter(letter)
        self.currentGame = game
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
    /// Save current game state to Core Data
    func saveGameState(_ game: GameModel) {
        guard let gameId = game.gameId else { return }
        
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
        
        let gameUUID: UUID
        if gameId.hasPrefix("daily-") {
            gameUUID = dailyStringToUUID(gameId)
        } else {
            gameUUID = UUID(uuidString: gameId) ?? UUID()
        }
        
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameUUID as CVarArg)
        fetchRequest.fetchLimit = 1
        
        guard let entity = try? context.fetch(fetchRequest).first else { return }
        
        // Update entity
        entity.currentDisplay = game.currentDisplay
        entity.mistakes = Int16(game.mistakes)
        entity.hasWon = game.hasWon
        entity.hasLost = game.hasLost
        entity.lastUpdateTime = Date()
        
        // Deactivate if completed
        if game.hasWon || game.hasLost {
            entity.isActive = false
        }
        
        // Update mappings
        entity.mapping = try? JSONEncoder().encode(game.mapping.mapToStringDict())
        entity.guessedMappings = try? JSONEncoder().encode(game.guessedMappings.mapToStringDict())
        
        var incorrectDict = [String: [String]]()
        for (key, values) in game.incorrectGuesses {
            incorrectDict[String(key)] = Array(values).map { String($0) }
        }
        entity.incorrectGuesses = try? JSONEncoder().encode(incorrectDict)
        
        try? context.save()
    }
    
    /// Submit score (keep existing implementation)
    func submitScore() {
        guard let game = currentGame, game.hasWon || game.hasLost else {
            print("⚠️ Cannot submit score - no valid completed game")
            return
        }
        
        let identityManager = UserIdentityManager.shared
        let context = coreData.mainContext
        
        let finalScore = game.calculateScore()
        let timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
        
        print("📊 Submitting score - Score: \(finalScore), Time: \(timeTaken)s, Won: \(game.hasWon)")
        
        // Update stats
        identityManager.updateStatsAfterGame(
            won: game.hasWon,
            score: finalScore,
            mistakes: game.mistakes,
            timeTaken: timeTaken
        )
        
        // Save game record
        do {
            let user = identityManager.getCurrentUser()
            
            if let gameId = game.gameId {
                let gameUUID: UUID
                if gameId.hasPrefix("daily-") {
                    gameUUID = dailyStringToUUID(gameId)
                } else {
                    gameUUID = UUID(uuidString: gameId) ?? UUID()
                }
                
                let gameFetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
                gameFetchRequest.predicate = NSPredicate(format: "gameId == %@", gameUUID as CVarArg)
                
                if let games = try? context.fetch(gameFetchRequest),
                   let gameEntity = games.first {
                    gameEntity.score = Int32(finalScore)
                    gameEntity.user = user
                    gameEntity.hasWon = game.hasWon
                    gameEntity.hasLost = game.hasLost
                    gameEntity.timeTaken = Int32(timeTaken)
                    gameEntity.isActive = false  // Ensure it's deactivated
                }
                
                try context.save()
            }
            
            // Submit to Game Center if won
            if game.hasWon {
                Task {
                    if let stats = identityManager.getUserStats() {
                        await GameCenterManager.shared.submitTotalScore(Int(stats.totalScore))
                    }
                }
            }
        } catch {
            print("❌ Error saving game record: \(error)")
        }
    }
    
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
    
    // MARK: - Other Game Actions (Keep Existing)
    
    /// Use a hint
    func getHint() {
        guard var game = currentGame else { return }
        
        // CHANGED: Only allow hint if we have hints remaining
        let remainingHints = game.maxMistakes - game.mistakes
        guard remainingHints > 0 else { return }
        
        let _ = game.getHint()  // This calls the GameModel's getHint which increments mistakes
        self.currentGame = game
        
        // ADDED: Check if game is lost after using hint
        if game.mistakes >= game.maxMistakes {
            game.hasLost = true
            self.currentGame = game
            submitScore()
            saveCompletedGameStats(game, won: false)
            loseModalIsDaily = isDailyChallenge
            showLoseMessage = true
            SoundManager.shared.play(.lose)
        } else if game.hasWon {
            submitScore()
            saveCompletedGameStats(game, won: true)
            winModalIsDaily = isDailyChallenge
            showWinMessage = true
            SoundManager.shared.play(.win)
        }
    }
    /// Reset current game
    func resetGame() {
        guard let game = currentGame else { return }
        
        // Mark current game as abandoned
        if let gameId = game.gameId {
            let context = coreData.mainContext
            let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
            
            let gameUUID = gameId.hasPrefix("daily-") ?
                dailyStringToUUID(gameId) :
                (UUID(uuidString: gameId) ?? UUID())
            
            fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameUUID as CVarArg)
            
            if let entity = try? context.fetch(fetchRequest).first {
                entity.isActive = false
                entity.hasLost = true
                try? context.save()
            }
        }
        
        // Start new game of same type
        if isDailyChallenge {
            setupDailyChallenge()
        } else {
            setupCustomGame()
        }
    }
    
    // MARK: - Public Methods for Backwards Compatibility
    
    /// Setup daily challenge (for existing code)
    func setupDailyChallenge() {
        loadOrCreateGame(isDaily: true)
    }
    
    /// Setup custom game (for existing code)
    func setupCustomGame() {
        loadOrCreateGame(isDaily: false)
    }
}

// MARK: - Helper Extensions
extension Dictionary where Key == String, Value == String {
    func stringDictToCharDict() -> [Character: Character] {
        var result: [Character: Character] = [:]
        for (key, value) in self {
            if let keyChar = key.first, let valueChar = value.first {
                result[keyChar] = valueChar
            }
        }
        return result
    }
}


