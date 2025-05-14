// GameState.swift - Updated for Repository Pattern

import Foundation
import Combine
import SwiftUI

/// GameState manages all game-related state and operations
class GameState: ObservableObject {
    // Game state properties
    @Published var currentGame: Game?
    @Published var savedGame: Game?
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
    private var dailyQuote: DailyQuote?
    private var cancellables = Set<AnyCancellable>()
    
    // Services
    private let gameRepository: GameRepositoryProtocol
    private let quoteRepository: QuoteRepositoryProtocol
    private let quoteService: QuoteServiceProtocol
    
    // Singleton instance
    static let shared = GameState()
    
    private init() {
        // Get repositories from provider
        let repositoryProvider = RepositoryProvider.shared
        self.gameRepository = repositoryProvider.gameRepository
        self.quoteRepository = repositoryProvider.quoteRepository
        self.quoteService = QuoteService.shared
        
        setupDefaultGame()
    }
    
    private func setupDefaultGame() {
        // Create a placeholder game with default quote
        let defaultQuote = Quote(
            text: "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG",
            author: "Anonymous",
            attribution: nil,
            difficulty: 2.0
        )
        self.currentGame = Game(quote: defaultQuote)
    }
    
    // MARK: - Public Methods
    
    /// Set up a custom game
    func setupCustomGame() {
        self.isDailyChallenge = false
        self.dailyQuote = nil
        Task { await loadNewGame() }
    }
    
    /// Set up the daily challenge
    func setupDailyChallenge() {
        self.isDailyChallenge = true
        Task { await fetchDailyQuote() }
    }
    
    /// Check for an in-progress game
    func checkForInProgressGame() {
        Task {
            do {
                if let game = try await gameRepository.loadLatestGame() {
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
                    await MainActor.run {
                        self.savedGame = game
                        self.showContinueGameModal = true
                    }
                }
            } catch {
                print("Error checking for in-progress game: \(error)")
            }
        }
    }
    
    /// Continue a saved game
    func continueSavedGame() {
        if let savedGame = savedGame {
            currentGame = savedGame
            self.showContinueGameModal = false
            self.savedGame = nil
        }
    }
    
    /// Reset the current game
    func resetGame() {
        // If there was a saved game, mark it as abandoned
        Task {
            if let oldGameId = savedGame?.gameId {
                do {
                    try await gameRepository.markGameAsAbandoned(gameId: oldGameId)
                } catch {
                    print("Error marking game as abandoned: \(error)")
                }
            }
            
            await MainActor.run {
                if isDailyChallenge, let quote = dailyQuote {
                    // Reuse the daily quote
                    let gameQuote = Quote(
                        text: quote.text,
                        author: quote.author,
                        attribution: quote.minor_attribution,
                        difficulty: quote.difficulty
                    )
                    currentGame = Game(quote: gameQuote)
                    currentGame?.gameId = "daily-\(quote.date)" // Mark as daily game with date
                    showWinMessage = false
                    showLoseMessage = false
                } else {
                    // Load a new random game
                    Task { await loadNewGame() }
                }
                // Clear the saved game reference
                self.savedGame = nil
            }
        }
    }
    
    /// Handle a player's guess
    func makeGuess(_ guessedLetter: Character) {
        guard var game = currentGame else { return }
        
        // Fixed: Removed unused selectedLetter variable
        // Simply check if there is a selected letter and proceed
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
        let _ = game.getHint()
        self.currentGame = game
        
        // Save game state
        saveGameState(game)
        
        // Check game status after hint
        if game.hasWon {
            showWinMessage = true
        } else if game.hasLost {
            showLoseMessage = true
        }
    }
    
    /// Submit score for daily challenge
    func submitDailyScore(userId: String) {
        guard let game = currentGame, game.hasWon || game.hasLost else { return }
        
        let finalScore = game.calculateScore()
        let timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
        
        // Update local stats
        Task {
            do {
                try await gameRepository.updateStatistics(
                    userId: userId,
                    gameWon: game.hasWon,
                    mistakes: game.mistakes,
                    timeTaken: timeTaken,
                    score: finalScore
                )
            } catch {
                print("Error updating stats: \(error.localizedDescription)")
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
    
    // MARK: - Private Methods
    
    private func saveGameState(_ game: Game) {
        Task {
            do {
                if let gameId = game.gameId {
                    try await gameRepository.updateGame(game, gameId: gameId)
                } else {
                    let updatedGame = try await gameRepository.saveGame(game)
                    await MainActor.run {
                        self.currentGame = updatedGame
                    }
                }
            } catch {
                print("Error saving game state: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchDailyQuote() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Try to get daily challenge from repository first
            let authCoordinator = ServiceProvider.shared.authCoordinator
                let quote = try await quoteService.getDailyQuote(auth: authCoordinator)
                dailyQuote = quote
                
                await MainActor.run {
                    quoteAuthor = quote.author
                    quoteAttribution = quote.minor_attribution
                    quoteDate = quote.formattedDate
                    
                    // Create game from quote
                    let gameQuote = Quote(
                        text: quote.text,
                        author: quote.author,
                        attribution: quote.minor_attribution,
                        difficulty: quote.difficulty
                    )
                    
                    currentGame = Game(quote: gameQuote)
                    currentGame?.gameId = "daily-\(quote.date)" // Mark as daily game with date
                    
                    showWinMessage = false
                    showLoseMessage = false
                    isLoading = false
                }
            
        } catch let error as QuoteService.QuoteError {
            await MainActor.run {
                errorMessage = error.errorDescription
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load daily challenge: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func loadNewGame() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Get random quote from repository
            let quote = try quoteRepository.getRandomQuote(difficulty: defaultDifficulty)
            
            await MainActor.run {
                // Update UI data
                quoteAuthor = quote.author
                quoteAttribution = quote.attribution
                
                // Create game with quote and appropriate ID prefix
                var newGame = Game(quote: quote)
                newGame.gameId = "custom-\(UUID().uuidString)" // Mark as custom game
                currentGame = newGame
                
                showWinMessage = false
                showLoseMessage = false
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load a quote: \(error.localizedDescription)"
                
                // Use fallback quote
                let fallbackQuote = Quote(
                    text: "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG",
                    author: "Anonymous",
                    attribution: nil,
                    difficulty: 2.0
                )
                currentGame = Game(quote: fallbackQuote)
                isLoading = false
            }
        }
    }
    
    // Helper for time formatting
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
