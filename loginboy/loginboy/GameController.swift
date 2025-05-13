import SwiftUI
import Combine

// MARK: - GameController
class GameController: ObservableObject {
    // Published game state
    @Published var game = Game()
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var showWinMessage = false
    @Published var showLoseMessage = false
    
    // Quote metadata
    @Published var quoteAuthor: String = ""
    @Published var quoteAttribution: String? = nil
    @Published var quoteDate: String? = nil
    
    // Configuration
    private(set) var isDailyChallenge: Bool = false
    private var dailyQuote: DailyQuote?
    
    // Services
    private let authService: AuthService
    private var dailyQuoteService: DailyQuoteService?
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks
    var onGameComplete: (() -> Void)?
    
    // MARK: - Initialization
    
    init(authService: AuthService) {
        self.authService = authService
    }
    
    // MARK: - Game Setup Methods
    
    func setupCustomGame() {
        self.isDailyChallenge = false
        self.dailyQuote = nil
        loadNewGame()
    }
    
    func setupDailyChallenge() {
        self.isDailyChallenge = true
        fetchDailyQuote()
    }
    
    // MARK: - Loading Methods
    
    private func fetchDailyQuote() {
        isLoading = true
        errorMessage = nil
        
        // Create daily quote service if needed
        if dailyQuoteService == nil {
            dailyQuoteService = DailyQuoteService(authService: authService)
        }
        
        dailyQuoteService?.fetchDailyQuote()
        
        // Subscribe to the daily quote service's published properties
        dailyQuoteService?.$dailyQuote
            .receive(on: RunLoop.main)
            .sink { [weak self] quote in
                guard let self = self, let quote = quote else { return }
                self.dailyQuote = quote
                self.loadDailyGame(quote: quote)
            }
            .store(in: &cancellables)
        
        dailyQuoteService?.$errorMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                guard let self = self, let error = error else { return }
                self.errorMessage = error
                self.isLoading = false
            }
            .store(in: &cancellables)
    }
    
    private func loadNewGame() {
        isLoading = true
        errorMessage = nil
        
        // Use a background thread for database operations
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Try to get a random quote from the database
                let (quoteText, author, attribution) = try DatabaseManager.shared.getRandomQuote()
                
                // Create a new game on the main thread
                DispatchQueue.main.async {
                    // Store quote metadata for win screen
                    self.quoteAuthor = author
                    self.quoteAttribution = attribution
                    
                    // Create a new game with the retrieved quote
                    var newGame = Game()
                    
                    // Ensure solution is properly set
                    newGame.solution = quoteText.uppercased()
                    newGame.setupGameWithSolution(quoteText.uppercased())
                    
                    // Update state
                    self.game = newGame
                    self.showWinMessage = false
                    self.showLoseMessage = false
                    self.isLoading = false
                }
            } catch {
                // Handle error on the main thread
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load a quote: \(error.localizedDescription)"
                    self.isLoading = false
                    
                    // Create a fallback game with a predefined quote if database fails
                    var fallbackGame = Game()
                    self.quoteAuthor = "Anonymous"
                    self.quoteAttribution = nil
                    fallbackGame.setupGameWithSolution("THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG")
                    self.game = fallbackGame
                }
            }
        }
    }
    
    private func loadDailyGame(quote: DailyQuote) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Store quote metadata
            self.quoteAuthor = quote.author
            self.quoteAttribution = quote.minor_attribution
            self.quoteDate = quote.formattedDate
            
            // Create a new game with the daily quote
            var newGame = Game()
            newGame.solution = quote.text.uppercased()
            newGame.setupGameWithSolution(quote.text.uppercased())
            
            // Set difficulty based on quote's difficulty value
            let difficultyString = getDifficultyString(from: quote.difficulty)
            newGame.difficulty = difficultyString
            newGame.maxMistakes = difficultyToMaxMistakes(difficultyString)
            
            // Update state
            self.game = newGame
            self.showWinMessage = false
            self.showLoseMessage = false
            self.isLoading = false
        }
    }
    
    // MARK: - Game Control Methods
    
    func resetGame() {
        if isDailyChallenge, let quote = dailyQuote {
            loadDailyGame(quote: quote)
        } else {
            loadNewGame()
        }
    }
    
    func handleGuessResult() {
        // Check game status after a guess
        if game.hasWon {
            showWinMessage = true
        } else if game.hasLost {
            showLoseMessage = true
        }
    }
    
    func submitDailyScore() {
        guard authService.isAuthenticated,
              let token = authService.getAccessToken(),
              let quote = dailyQuote else {
            return
        }
        
        // Calculate final score
        let finalScore = game.calculateScore()
        let timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
        
        // For now, just update local stats in the database
        do {
            try DatabaseManager.shared.updateStatistics(
                userId: authService.userId,
                gameWon: true,
                mistakes: game.mistakes,
                timeTaken: timeTaken,
                score: finalScore
            )
            print("Updated local statistics for daily challenge")
        } catch {
            print("Error updating local stats: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Helper functions
private func getDifficultyString(from value: Double) -> String {
    switch value {
    case 0..<1:
        return "easy"
    case 1..<3:
        return "medium"
    default:
        return "hard"
    }
}

private func difficultyToMaxMistakes(_ difficulty: String) -> Int {
    switch difficulty {
    case "easy":
        return 8
    case "medium":
        return 5
    case "hard":
        return 3
    default:
        return 5
    }
}

//
//  GameController.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

