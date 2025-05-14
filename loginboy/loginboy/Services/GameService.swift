import Foundation
import Combine

class GameService: ObservableObject {
    // Published properties
    @Published var currentGame: Game?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showWinMessage = false
    @Published var showLoseMessage = false
    @Published var showContinueGameModal = false
    @Published var savedGame: Game?
    
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
    
    // Dependencies
    private let gameRepository: GameRepositoryProtocol
    private let quoteRepository: QuoteRepositoryProtocol
    private let quoteService: QuoteServiceProtocol
    private let authCoordinator: AuthenticationCoordinator
    
    init(
        gameRepository: GameRepositoryProtocol,
        quoteRepository: QuoteRepositoryProtocol,
        quoteService: QuoteServiceProtocol,
        authCoordinator: AuthenticationCoordinator
    ) {
        self.gameRepository = gameRepository
        self.quoteRepository = quoteRepository
        self.quoteService = quoteService
        self.authCoordinator = authCoordinator
        
        setupDefaultGame()
    }
    
    // Convenience initializer using repository provider
    convenience init(authCoordinator: AuthenticationCoordinator) {
        let provider = RepositoryProvider.shared
        self.init(
            gameRepository: provider.gameRepository,
            quoteRepository: provider.quoteRepository,
            quoteService: QuoteService.shared,
            authCoordinator: authCoordinator
        )
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
    
    // MARK: - Game Setup
    
    func setupCustomGame() {
        self.isDailyChallenge = false
        self.dailyQuote = nil
        Task { await loadNewGame() }
    }
    
    func setupDailyChallenge() {
        self.isDailyChallenge = true
        Task { await fetchDailyQuote() }
    }
    
    // MARK: - Game State Management
    
    func checkForInProgressGame() {
        Task {
            do {
                isLoading = true
                
                if let game = try await gameRepository.loadLatestGame() {
                    // Check if it's the right type (daily vs custom)
                    let isDaily = isDailyChallenge
                    
                    // If we want to show daily but the saved game isn't daily, don't show modal
                    if isDaily && game.gameId?.starts(with: "custom-") == true {
                        isLoading = false
                        return
                    }
                    
                    // If we want to show custom but the saved game is daily, don't show modal
                    if !isDaily && game.gameId?.starts(with: "daily-") == true {
                        isLoading = false
                        return
                    }
                    
                    // We have a matching in-progress game
                    await MainActor.run {
                        self.savedGame = game
                        self.showContinueGameModal = true
                        self.isLoading = false
                    }
                } else {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error loading saved game: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func continueSavedGame() {
        if let savedGame = savedGame {
            currentGame = savedGame
            self.showContinueGameModal = false
            self.savedGame = nil
        }
    }
    
    func resetGame() {
        // If there was a saved game, mark it as abandoned
        Task {
            if let oldGameId = savedGame?.gameId {
                do {
                    try await gameRepository.markGameAsAbandoned(gameId: oldGameId)
                } catch {
                    print("Error marking game as abandoned: \(error.localizedDescription)")
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
    
    // MARK: - Game Actions
    
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
    
    func selectLetter(_ letter: Character) {
        guard var game = currentGame else { return }
        game.selectLetter(letter)
        self.currentGame = game
    }
    
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
    
    func submitDailyScore(userId: String) {
        guard let game = currentGame, game.hasWon else { return }
        
        let finalScore = game.calculateScore()
        let timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
        
        // Update statistics
        Task {
            do {
                try await gameRepository.updateStatistics(
                    userId: userId,
                    gameWon: true,
                    mistakes: game.mistakes,
                    timeTaken: timeTaken,
                    score: finalScore
                )
            } catch {
                print("Error updating statistics: \(error.localizedDescription)")
            }
        }
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
            // Try to get daily quote from local DB first
            if let localDailyQuote = try await Task { try quoteRepository.getDailyQuote() }.value {
                await handleDailyQuote(localDailyQuote)
                return
            }
            
            // If not found locally, fetch from API
            let quote = try await quoteService.getDailyQuote(auth: authCoordinator)
            dailyQuote = quote
            
            await handleDailyQuote(quote)
            
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
    
    private func handleDailyQuote(_ quote: DailyQuote) async {
        await MainActor.run {
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
            
            currentGame = Game(quote: gameQuote)
            currentGame?.gameId = "daily-\(quote.date)" // Mark as daily game with date
            
            showWinMessage = false
            showLoseMessage = false
            isLoading = false
        }
    }
    
    private func loadNewGame() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Get random quote
            let quote = try await Task {
                try quoteRepository.getRandomQuote(difficulty: defaultDifficulty)
            }.value
            
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

//
//  GameService.swift
//  loginboy
//
//  Created by Daniel Horsley on 15/05/2025.
//
