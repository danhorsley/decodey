//
//  GameState.swift - NUCLEAR STRIPPED VERSION
//  loginboy
//

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
    @Published var showWinMessage = false
    @Published var showLoseMessage = false
    @Published var showContinueGameModal = false
    @Published var isInfiniteMode = false
    
    // Game metadata
    @Published var quoteAuthor: String = ""
    @Published var quoteAttribution: String? = nil
    @Published var quoteDate: String? = nil
    
    // Configuration
    @Published var isDailyChallenge = false
    @Published var defaultDifficulty = "medium"
    
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
        let defaultQuote = LocalQuoteModel(
            text: "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG",
            author: "Anonymous",
            attribution: nil,
            difficulty: 2.0
        )
        
        var game = GameModel(
            gameId: UUID().uuidString,
            encrypted: "",
            solution: defaultQuote.text.uppercased(),
            currentDisplay: "",
            mapping: [:],
            correctMappings: [:],
            guessedMappings: [:],
            mistakes: 0,
            maxMistakes: getMaxMistakesForDifficulty(SettingsState.shared.gameDifficulty),
            hasWon: false,
            hasLost: false,
            difficulty: SettingsState.shared.gameDifficulty,
            startTime: Date(),
            lastUpdateTime: Date()
        )
        
        // Setup encryption
        game.setupEncryption()
        
        self.currentGame = game
    }
    
    // MARK: - Game Setup (LOCAL ONLY)
    
    /// Set up daily challenge - LOCAL ONLY
    func setupDailyChallenge() {
        self.isDailyChallenge = true
        
        isLoading = true
        errorMessage = nil
        
        // Get today's deterministic quote
        let today = Calendar.current.startOfDay(for: Date())
        let daysSinceEpoch = Int(today.timeIntervalSince1970 / 86400)
        
        // Get quote from LocalQuoteManager
        if let dailyQuote = LocalQuoteManager.shared.getDailyQuote(for: daysSinceEpoch) {
            // Update UI data
            quoteAuthor = dailyQuote.author
            quoteAttribution = dailyQuote.attribution
            quoteDate = DateFormatter.shortDate.string(from: today)
            
            // Create game with LOCAL quote
            var game = GameModel(
                gameId: "daily-\(daysSinceEpoch)",
                encrypted: "",
                solution: dailyQuote.text.uppercased(),
                currentDisplay: "",
                mapping: [:],
                correctMappings: [:],
                guessedMappings: [:],
                mistakes: 0,
                maxMistakes: getMaxMistakesForDifficulty(SettingsState.shared.gameDifficulty),
                hasWon: false,
                hasLost: false,
                difficulty: SettingsState.shared.gameDifficulty,
                startTime: Date(),
                lastUpdateTime: Date()
            )
            
            // Setup encryption
            game.setupEncryption()
            
            currentGame = game
            showWinMessage = false
            showLoseMessage = false
            isLoading = false
        } else {
            errorMessage = "No daily quote available"
            isLoading = false
        }
    }
    
    /// Set up a random game - LOCAL ONLY
    func setupRandomGame() {
        self.isDailyChallenge = false
        
        isLoading = true
        errorMessage = nil
        
        // Get random quote from LocalQuoteManager
        if let randomQuote = LocalQuoteManager.shared.getRandomQuote() {
            // Update UI data
            quoteAuthor = randomQuote.author
            quoteAttribution = randomQuote.attribution
            
            // Create game with LOCAL quote
            var game = GameModel(
                gameId: UUID().uuidString,
                encrypted: "",
                solution: randomQuote.text.uppercased(),
                currentDisplay: "",
                mapping: [:],
                correctMappings: [:],
                guessedMappings: [:],
                mistakes: 0,
                maxMistakes: getMaxMistakesForDifficulty(SettingsState.shared.gameDifficulty),
                hasWon: false,
                hasLost: false,
                difficulty: SettingsState.shared.gameDifficulty,
                startTime: Date(),
                lastUpdateTime: Date()
            )
            
            // Setup encryption
            game.setupEncryption()
            
            currentGame = game
            showWinMessage = false
            showLoseMessage = false
            isLoading = false
        } else {
            errorMessage = "No quotes available"
            isLoading = false
        }
    }
    
    /// Set up a custom game - LOCAL ONLY
    func setupCustomGame() {
        setupRandomGame() // Same as random for now
    }
    
    // MARK: - Game Actions
    
    /// Make a guess for a letter
    func makeGuess(encrypted: Character, decrypted: Character) {
        guard var game = currentGame else { return }
        
        let upperEncrypted = Character(encrypted.uppercased())
        let upperDecrypted = Character(decrypted.uppercased())
        
        // Use GameModel's makeGuess method
        let wasCorrect = game.makeGuess(upperDecrypted)
        
        // Update current game
        currentGame = game
        
        // Save game and check win/lose conditions
        saveCurrentGame()
        
        if game.hasWon {
            showWinMessage = true
        } else if game.hasLost {
            showLoseMessage = true
        }
    }
    
    /// Make a guess for a letter (simplified version for GameGridsView)
    func makeGuess(_ decryptedLetter: Character) {
        guard var game = currentGame else { return }
        
        // Use GameModel's makeGuess method
        _ = game.makeGuess(decryptedLetter)
        
        // Update current game
        currentGame = game
        
        // Save game and check win/lose conditions
        saveCurrentGame()
        
        if game.hasWon {
            showWinMessage = true
        } else if game.hasLost {
            showLoseMessage = true
        }
    }
    
    /// Remove a mapping
    func removeMapping(encrypted: Character) {
        guard var game = currentGame else { return }
        
        let upperEncrypted = Character(encrypted.uppercased())
        
        // Remove from guessed mappings
        game.guessedMappings.removeValue(forKey: upperEncrypted)
        
        // Update current display
        game.updateCurrentDisplay()
        
        // Update timestamp
        game.lastUpdateTime = Date()
        
        // Save updated game
        currentGame = game
        saveCurrentGame()
    }
    
    /// Select a letter for guessing
    func selectLetter(_ letter: Character) {
        guard var game = currentGame else { return }
        
        // Use GameModel's selectLetter method
        game.selectLetter(letter)
        
        // Update current game
        currentGame = game
    }
    
    /// Get a hint
    func getHint() {
        guard var game = currentGame else { return }
        
        // Only allow getting hints if we haven't reached the maximum mistakes
        if game.mistakes < game.maxMistakes {
            // Use GameModel's getHint method
            _ = game.getHint()
            
            // Update current game
            currentGame = game
            
            // Save game state
            saveCurrentGame()
            
            // Check game status after hint
            if game.hasWon {
                showWinMessage = true
            } else if game.hasLost {
                showLoseMessage = true
            }
        }
    }
    
    /// Reset the current game
    func resetGame() {
        isInfiniteMode = false
        
        // Mark old game as abandoned if exists
        if let oldGameId = savedGame?.gameId {
            markGameAsAbandoned(gameId: oldGameId)
        }
        
        if isDailyChallenge {
            setupDailyChallenge()
        } else {
            setupRandomGame()
        }
    }
    
    // MARK: - Core Data Operations
    
    /// Save current game state to Core Data
    func saveCurrentGame() {
        guard let game = currentGame else { return }
        
        let context = coreData.mainContext
        
        // Find existing game or create new one
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        if let gameId = game.gameId, let uuid = UUID(uuidString: gameId) {
            fetchRequest.predicate = NSPredicate(format: "gameId == %@", uuid as CVarArg)
        } else {
            // Create new UUID if gameId is invalid
            let newUUID = UUID()
            var updatedGame = game
            updatedGame.gameId = newUUID.uuidString
            currentGame = updatedGame
            fetchRequest.predicate = NSPredicate(format: "gameId == %@", newUUID as CVarArg)
        }
        
        do {
            let games = try context.fetch(fetchRequest)
            let gameEntity: GameCD
            
            if let existingGame = games.first {
                gameEntity = existingGame
            } else {
                gameEntity = createGameEntity(from: game)
            }
            
            updateGameEntity(gameEntity, from: game)
            
            try context.save()
        } catch {
            print("Error saving game: \(error)")
            errorMessage = "Failed to save game"
        }
    }
    
    /// Convert Core Data entity to GameModel
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
            gameId: game.gameId?.uuidString ?? UUID().uuidString,
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
    
    /// Create a new game entity from model
    private func createGameEntity(from model: GameModel) -> GameCD {
        let context = coreData.mainContext
        let gameEntity = GameCD(context: context)
        
        if let gameIdString = model.gameId, let uuid = UUID(uuidString: gameIdString) {
            gameEntity.gameId = uuid
        } else {
            gameEntity.gameId = UUID()
        }
        gameEntity.startTime = model.startTime
        
        updateGameEntity(gameEntity, from: model)
        return gameEntity
    }
    
    /// Update game entity from model
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
            print("Error serializing mappings: \(error)")
        }
    }
    
    /// Mark a game as abandoned
    private func markGameAsAbandoned(gameId: String) {
        guard let uuid = UUID(uuidString: gameId) else { return }
        
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", uuid as CVarArg)
        
        do {
            let games = try context.fetch(fetchRequest)
            for game in games {
                context.delete(game)
            }
            try context.save()
        } catch {
            print("Error marking game as abandoned: \(error)")
        }
    }
    
    // MARK: - Utility Functions
    
    /// Convert character dictionary to string dictionary for JSON serialization
    private func characterDictionaryToStringDictionary(_ dict: [Character: Character]) -> [String: String] {
        return Dictionary(uniqueKeysWithValues: dict.map { (String($0.key), String($0.value)) })
    }
    
    /// Convert string dictionary to character dictionary
    private func stringDictionaryToCharacterDictionary(_ dict: [String: String]) -> [Character: Character] {
        return Dictionary(uniqueKeysWithValues: dict.compactMap { key, value in
            guard let keyChar = key.first, let valueChar = value.first else { return nil }
            return (keyChar, valueChar)
        })
    }
    
    // MARK: - Debug
    
    func debugPrintGameState() {
        if let game = currentGame {
            print("=== GAME STATE DEBUG ===")
            print("Game ID: \(game.gameId ?? "nil")")
            print("Is Daily Challenge: \(isDailyChallenge)")
            print("Current mistakes: \(game.mistakes)/\(game.maxMistakes)")
            print("Encrypted: \(game.encrypted)")
            print("Solution: \(game.solution)")
            print("Current Display: \(game.currentDisplay)")
        } else {
            print("No current game")
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}
