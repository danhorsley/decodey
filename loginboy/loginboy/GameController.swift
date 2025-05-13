// GameController.swift - Refactored
import SwiftUI
import Combine

@MainActor
class GameController: ObservableObject {
    // Published game state
    @Published var game: Game
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var showWinMessage = false
    @Published var showLoseMessage = false
    
    // Quote metadata
    @Published var quoteAuthor: String = ""
    @Published var quoteAttribution: String? = nil
    @Published var quoteDate: String? = nil
    // Game state handling
    @Published var showContinueGameModal = false
    @Published var savedGame: Game? = nil
    
    // Configuration
    private(set) var isDailyChallenge: Bool = false
    private var dailyQuote: DailyQuote?
    
    // Services
    private let authService: AuthService
    private let quoteService = QuoteService.shared
    
    // Callbacks
    var onGameComplete: (() -> Void)?
    
    // Initialize with a placeholder game
    init(authService: AuthService) {
        self.authService = authService
        
        // Create a placeholder game with default quote
        let defaultQuote = Quote(
            text: "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG",
            author: "Anonymous",
            attribution: nil,
            difficulty: 2.0
        )
        self.game = Game(quote: defaultQuote)
    }
    
    // Setup a custom game
    func setupCustomGame() {
        self.isDailyChallenge = false
        self.dailyQuote = nil
        Task { await loadNewGame() }
    }
    
    // Setup daily challenge
    func setupDailyChallenge() {
        self.isDailyChallenge = true
        Task { await fetchDailyQuote() }
    }
    // Game state handling
    func checkForInProgressGame() {
            Task {
                do {
                    if let game = try DatabaseManager.shared.loadLatestGame() {
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
    // Fetch daily quote with async/await
    private func fetchDailyQuote() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let quote = try await quoteService.getDailyQuote(authService: authService)
            dailyQuote = quote
            
            // Update UI with quote data
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
            
            game = Game(quote: gameQuote)
            showWinMessage = false
            showLoseMessage = false
            
        } catch let error as QuoteService.QuoteError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to load daily challenge: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // Load a new random game
    private func loadNewGame() async {
            isLoading = true
            errorMessage = nil
            
            do {
                // Get random quote
                let quote = try quoteService.getRandomQuote()
                
                // Update UI data
                quoteAuthor = quote.author
                quoteAttribution = quote.attribution
                
                // Create game with quote and appropriate ID prefix
                var newGame = Game(quote: quote)
                newGame.gameId = "custom-\(UUID().uuidString)" // Mark as custom game
                game = newGame
                
                showWinMessage = false
                showLoseMessage = false
                
            } catch {
            errorMessage = "Failed to load a quote: \(error.localizedDescription)"
            
            // Use fallback quote
            let fallbackQuote = Quote(
                text: "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG",
                author: "Anonymous",
                attribution: nil,
                difficulty: 2.0
            )
            game = Game(quote: fallbackQuote)
        }
        
        isLoading = false
    }
    // Method to continue saved game
    func continueSavedGame() {
        if let savedGame = savedGame {
            game = savedGame
            self.showContinueGameModal = false
            self.savedGame = nil
        }
    }
    // Game control methods
    func resetGame() {
            // If there was a saved game, mark it as abandoned
            if let oldGameId = savedGame?.gameId {
                try? DatabaseManager.shared.markGameAsAbandoned(gameId: oldGameId)
            }
            
            if isDailyChallenge, let quote = dailyQuote {
            // Reuse the daily quote
            let gameQuote = Quote(
                text: quote.text,
                author: quote.author,
                attribution: quote.minor_attribution,
                difficulty: quote.difficulty
            )
            game = Game(quote: gameQuote)
            showWinMessage = false
            showLoseMessage = false
        } else {
            // Load a new random game
            Task { await loadNewGame() }
        }
        // Clear the saved game reference
        self.savedGame = nil
    }
    
    func handleGuessResult() {
        if game.hasWon {
            showWinMessage = true
        } else if game.hasLost {
            showLoseMessage = true
        }
    }
    
    func submitDailyScore() {
        guard authService.isAuthenticated else { return }
        
        let finalScore = game.calculateScore()
        let timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
        
        // Update local stats
        do {
            try DatabaseManager.shared.updateStatistics(
                userId: authService.userId,
                gameWon: true,
                mistakes: game.mistakes,
                timeTaken: timeTaken,
                score: finalScore
            )
        } catch {
            print("Error updating local stats: \(error)")
        }
    }
    
    // Helper for time formatting
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

//
//  GameController.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

