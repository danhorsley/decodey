// GameState.swift - Updated with fixes

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
    private let databaseManager = DatabaseManager.shared
    private let quoteService = QuoteService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
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
                if let game = try databaseManager.loadLatestGame() {
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
        if let oldGameId = savedGame?.gameId {
            try? databaseManager.markGameAsAbandoned(gameId: oldGameId)
        }
        
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
    
    /// Handle a player's guess
    func makeGuess(_ guessedLetter: Character) {
        guard var game = currentGame else { return }
        
        // Fixed: Removed unused selectedLetter variable
        // Simply check if there is a selected letter and proceed
        if game.selectedLetter != nil {
            let _ = game.makeGuess(guessedLetter)
            self.currentGame = game
            
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
        
        // Check game status after hint
        if game.hasWon {
            showWinMessage = true
        } else if game.hasLost {
            showLoseMessage = true
        }
    }
    
    /// Submit score for daily challenge
    func submitDailyScore(userId: String) {
        guard let game = currentGame, game.hasWon else { return }
        
        let finalScore = game.calculateScore()
        let timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
        
        // Update local stats
        do {
            // Fixed: Added the missing mistakes parameter
            try databaseManager.updateStatistics(
                userId: userId,
                gameWon: true,
                mistakes: game.mistakes,
                timeTaken: timeTaken,
                score: finalScore,
                
            )
        } catch {
            print("Error updating local stats: \(error)")
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
    
    private func fetchDailyQuote() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let authCoordinator = UserState.shared.authCoordinator
            // Fixed: Removed argument in call that takes no arguments
            // Use the proper method signature
            let quote = try await quoteService.getDailyQuote(auth: authCoordinator)
            dailyQuote = quote
            
            // Update UI with quote data
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
            // Get random quote
            let quote = try quoteService.getRandomQuote()
            
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

extension GameState {
    // Singleton for shared access
    static let shared = GameState()
}
