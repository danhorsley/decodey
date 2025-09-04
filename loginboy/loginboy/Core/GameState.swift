//
//  GameState.swift - Local Game State Management
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
    private let localQuotes = LocalQuoteManager.shared
    private let userManager = SimpleUserManager.shared
    
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
        let defaultText = "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG"
        let difficulty = SettingsState.shared.gameDifficulty
        
        // Create a fully initialized GameModel
        var game = GameModel(
            gameId: UUID().uuidString,
            encrypted: createEncryptedVersion(of: defaultText),
            solution: defaultText,
            currentDisplay: createCurrentDisplay(for: defaultText),
            mapping: [:],
            correctMappings: createCryptogramMapping(for: defaultText),
            guessedMappings: [:],
            incorrectGuesses: [:],
            mistakes: 0,
            maxMistakes: getMaxMistakesForDifficulty(difficulty),
            hasWon: false,
            hasLost: false,
            difficulty: difficulty,
            startTime: Date(),
            lastUpdateTime: Date()
        )
        
        self.currentGame = game
        self.quoteAuthor = "Anonymous"
        self.quoteAttribution = nil
    }
    
    // MARK: - Game Setup Methods
    
    /// Set up a random local game
    func setupRandomGame() {
        self.isDailyChallenge = false
        isLoading = true
        errorMessage = nil
        
        // Get random quote from LocalQuoteManager
        let difficulty = SettingsState.shared.gameDifficulty
        guard let localQuote = localQuotes.getQuoteByDifficulty(difficulty) else {
            useFallbackQuote()
            return
        }
        
        setupGameWithLocalQuote(localQuote)
    }
    
    /// Set up the daily challenge
    func setupDailyChallenge() {
        self.isDailyChallenge = true
        isLoading = true
        errorMessage = nil
        
        // Get deterministic daily quote
        let daysSinceEpoch = Calendar.current.dateComponents([.day], from: Date(timeIntervalSince1970: 0), to: Date()).day ?? 0
        
        guard let dailyQuote = localQuotes.getDailyQuote(for: daysSinceEpoch) else {
            useFallbackQuote()
            return
        }
        
        setupGameWithLocalQuote(dailyQuote)
    }
    
    /// Set up custom game with specific difficulty
    func setupCustomGame(difficulty: String? = nil) {
        self.isDailyChallenge = false
        isLoading = true
        errorMessage = nil
        
        let targetDifficulty = difficulty ?? SettingsState.shared.gameDifficulty
        
        guard let quote = localQuotes.getQuoteByDifficulty(targetDifficulty) else {
            useFallbackQuote()
            return
        }
        
        setupGameWithLocalQuote(quote)
    }
    
    // MARK: - Private Game Setup
    
    private func setupGameWithLocalQuote(_ localQuote: LocalQuoteModel) {
        // Create cryptogram from the quote
        let encrypted = createEncryptedVersion(of: localQuote.text)
        let currentDisplay = createCurrentDisplay(for: localQuote.text)
        let correctMappings = createCryptogramMapping(for: localQuote.text)
        
        let gameId: String
        if isDailyChallenge {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: Date())
            gameId = "daily-\(dateString)"
        } else {
            gameId = UUID().uuidString
        }
        
        var game = GameModel(
            gameId: gameId,
            encrypted: encrypted,
            solution: localQuote.text,
            currentDisplay: currentDisplay,
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
        
        // Update UI metadata
        quoteAuthor = localQuote.author
        quoteAttribution = localQuote.attribution
        quoteDate = isDailyChallenge ? DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none) : nil
        
        currentGame = game
        showWinMessage = false
        showLoseMessage = false
        isLoading = false
        
        print("✅ Game setup complete: \(localQuote.author)")
    }
    
    private func useFallbackQuote() {
        // Use fallback quote
        let fallbackText = "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG"
        let difficulty = SettingsState.shared.gameDifficulty
        
        var game = GameModel(
            gameId: UUID().uuidString,
            encrypted: createEncryptedVersion(of: fallbackText),
            solution: fallbackText,
            currentDisplay: createCurrentDisplay(for: fallbackText),
            mapping: [:],
            correctMappings: createCryptogramMapping(for: fallbackText),
            guessedMappings: [:],
            incorrectGuesses: [:],
            mistakes: 0,
            maxMistakes: getMaxMistakesForDifficulty(difficulty),
            hasWon: false,
            hasLost: false,
            difficulty: difficulty,
            startTime: Date(),
            lastUpdateTime: Date()
        )
        
        currentGame = game
        quoteAuthor = "Anonymous"
        quoteAttribution = nil
        quoteDate = nil
        isLoading = false
        
        print("⚠️ Using fallback quote")
    }
    
    // MARK: - Game Persistence
    
    /// Check for an in-progress game
    func checkForInProgressGame() {
        let context = coreData.mainContext
        
        // Query for unfinished games
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        
        // Add isDaily filter based on current mode
        let dailyPredicate = NSPredicate(format: "isDaily == %@", NSNumber(value: isDailyChallenge))
        let incompletePredicate = NSPredicate(format: "hasWon == NO AND hasLost == NO")
        
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [dailyPredicate, incompletePredicate])
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastUpdateTime", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let games = try context.fetch(fetchRequest)
            if let gameCD = games.first {
                savedGame = gameCD.toModel()
                showContinueGameModal = true
                print("📁 Found saved game to continue")
            }
        } catch {
            print("❌ Error checking for saved games: \(error)")
        }
    }
    
    /// Save current game state
    func saveGameState() {
        guard let game = currentGame else { return }
        
        let context = coreData.newBackgroundContext()
        
        context.perform {
            // Check if game already exists
            let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
            fetchRequest.predicate = NSPredicate(format: "gameId == %@", game.gameId ?? "")
            
            do {
                let existingGames = try context.fetch(fetchRequest)
                let gameCD: GameCD
                
                if let existing = existingGames.first {
                    gameCD = existing
                } else {
                    gameCD = GameCD(context: context)
                    // Note: gameCD.id is auto-generated by Core Data, don't set it manually
                    if let gameIdString = game.gameId, let gameUUID = UUID(uuidString: gameIdString) {
                        gameCD.gameId = gameUUID
                    } else {
                        gameCD.gameId = UUID()
                    }
                }
                
                // Update game data
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
                gameCD.isDaily = self.isDailyChallenge
                
                // Serialize mappings
                if let mappingData = try? JSONEncoder().encode(self.characterMappingToDictionary(game.mapping)) {
                    gameCD.mappingData = mappingData
                }
                
                if let correctData = try? JSONEncoder().encode(self.characterMappingToDictionary(game.correctMappings)) {
                    gameCD.correctMappingsData = correctData
                }
                
                if let guessedData = try? JSONEncoder().encode(self.characterMappingToDictionary(game.guessedMappings)) {
                    gameCD.guessedMappingsData = guessedData
                }
                
                try context.save()
                print("💾 Game state saved")
            } catch {
                print("❌ Error saving game state: \(error)")
            }
        }
    }
    
    /// Load saved game
    func loadSavedGame() {
        guard let saved = savedGame else { return }
        currentGame = saved
        savedGame = nil
        showContinueGameModal = false
        print("📁 Loaded saved game")
    }
    
    /// Discard saved game
    func discardSavedGame() {
        guard let saved = savedGame else { return }
        
        let context = coreData.newBackgroundContext()
        
        context.perform {
            let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
            fetchRequest.predicate = NSPredicate(format: "gameId == %@", saved.gameId ?? "")
            
            do {
                let games = try context.fetch(fetchRequest)
                for game in games {
                    context.delete(game)
                }
                try context.save()
                print("🗑️ Discarded saved game")
            } catch {
                print("❌ Error discarding saved game: \(error)")
            }
        }
        
        savedGame = nil
        showContinueGameModal = false
    }
    
    // MARK: - Game Completion
    
    /// Handle game completion (win/loss)
    func completeGame() {
        guard let game = currentGame else { return }
        guard game.hasWon || game.hasLost else { return }
        
        // Update local stats
        updateLocalStats(game: game)
        
        // Remove from saved games
        clearSavedGame(gameId: game.gameId ?? "")
        
        print("🎯 Game completed - Score: \(game.calculateScore())")
    }
    
    private func updateLocalStats(game: GameModel) {
        guard userManager.isSignedIn else { return }
        
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<UserStatsCD> = UserStatsCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "user.username == %@", userManager.playerName)
        
        do {
            let statsArray = try context.fetch(fetchRequest)
            guard let stats = statsArray.first else { return }
            
            // Update stats
            stats.gamesPlayed += 1
            let timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
            let finalScore = game.calculateScore()
            
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
            
            // Refresh user manager stats
            userManager.refreshStats()
            
        } catch {
            print("Error updating user stats: \(error.localizedDescription)")
        }
    }
    
    private func clearSavedGame(gameId: String) {
        let context = coreData.newBackgroundContext()
        
        context.perform {
            let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
            fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameId)
            
            do {
                let games = try context.fetch(fetchRequest)
                for game in games {
                    context.delete(game)
                }
                try context.save()
            } catch {
                print("❌ Error clearing saved game: \(error)")
            }
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
    
    // MARK: - Utility Methods
    
    // Helper for time formatting
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func characterMappingToDictionary(_ mapping: [Character: Character]) -> [String: String] {
        var result = [String: String]()
        for (key, value) in mapping {
            result[String(key)] = String(value)
        }
        return result
    }
    
    // MARK: - Cryptogram Creation
    
    private func createEncryptedVersion(of text: String) -> String {
        // Create a simple substitution cipher
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let shuffled = String(alphabet.shuffled())
        
        var encrypted = ""
        for char in text.uppercased() {
            if char.isLetter, let index = alphabet.firstIndex(of: char) {
                let shuffledIndex = alphabet.distance(from: alphabet.startIndex, to: index)
                let shuffledChar = shuffled[shuffled.index(shuffled.startIndex, offsetBy: shuffledIndex)]
                encrypted.append(shuffledChar)
            } else {
                encrypted.append(char)
            }
        }
        return encrypted
    }
    
    private func createCurrentDisplay(for text: String) -> String {
        // Initially show only spaces, punctuation, and numbers
        var display = ""
        for char in text.uppercased() {
            if char.isLetter {
                display.append("_")
            } else {
                display.append(char)
            }
        }
        return display
    }
    
    private func createCryptogramMapping(for text: String) -> [Character: Character] {
        // Create the correct mapping from encrypted to solution
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let shuffled = String(alphabet.shuffled())
        
        var mapping: [Character: Character] = [:]
        
        for (index, char) in alphabet.enumerated() {
            let shuffledChar = shuffled[shuffled.index(shuffled.startIndex, offsetBy: index)]
            mapping[shuffledChar] = char
        }
        
        return mapping
    }
}
