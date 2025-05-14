// GameState.swift - Refactored for Realm
import SwiftUI
import Combine
import Foundation
import RealmSwift

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
    private let authCoordinator = UserState.shared.authCoordinator
    
    // Stores - direct access to data without repositories/services
    private let gameStore = GameStore.shared
    private let quoteStore = QuoteStore.shared
    
    // Singleton instance
    static let shared = GameState()
    
    private init() {
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
    
    // MARK: - Game Setup
    
    /// Set up a custom game
    func setupCustomGame() {
        self.isDailyChallenge = false
        self.dailyQuote = nil
        
        isLoading = true
        errorMessage = nil
        
        // Get random quote from store
        if let quote = quoteStore.getRandomQuote(difficulty: defaultDifficulty) {
            // Update UI data
            quoteAuthor = quote.author
            quoteAttribution = quote.attribution
            
            // Create game with quote and appropriate ID prefix
            var newGame = Game(quote: quote)
            newGame.gameId = "custom-\(UUID().uuidString)" // Mark as custom game
            currentGame = newGame
            
            showWinMessage = false
            showLoseMessage = false
        } else {
            errorMessage = "Failed to load a quote"
            
            // Use fallback quote
            let fallbackQuote = Quote(
                text: "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG",
                author: "Anonymous",
                attribution: nil,
                difficulty: 2.0
            )
            currentGame = Game(quote: fallbackQuote)
        }
        
        isLoading = false
    }
    
    /// Set up the daily challenge
    func setupDailyChallenge() {
        self.isDailyChallenge = true
        
        isLoading = true
        errorMessage = nil
        
        // Try to get daily challenge locally
        if let quote = quoteStore.getDailyQuote() {
            setupFromDailyQuote(quote)
        } else {
            // If not available locally, fetch from API
            fetchDailyQuoteFromAPI()
        }
    }
    
    // Helper to set up game from daily quote
    private func setupFromDailyQuote(_ quote: DailyQuote) {
        self.dailyQuote = quote
        
        // Update UI data
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
        
        var game = Game(quote: gameQuote)
        game.gameId = "daily-\(quote.date)" // Mark as daily game with date
        currentGame = game
        
        showWinMessage = false
        showLoseMessage = false
        isLoading = false
    }
    
    // Fetch daily quote from API if not available locally
    private func fetchDailyQuoteFromAPI() {
        Task {
            do {
                // Get networking service from the auth coordinator
                guard let token = authCoordinator.getAccessToken() else {
                    await MainActor.run {
                        errorMessage = "Authentication required"
                        isLoading = false
                    }
                    return
                }
                
                // Build URL request
                guard let url = URL(string: "\(authCoordinator.baseURL)/api/get_daily") else {
                    await MainActor.run {
                        errorMessage = "Invalid URL configuration"
                        isLoading = false
                    }
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
                // Perform network request
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    await MainActor.run {
                        errorMessage = "Invalid response from server"
                        isLoading = false
                    }
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    // Parse response
                    let decoder = JSONDecoder()
                    let quote = try decoder.decode(DailyQuote.self, from: data)
                    
                    // Save to Realm for future use
                    saveQuoteToRealm(quote)
                    
                    // Update UI on main thread
                    await MainActor.run {
                        setupFromDailyQuote(quote)
                    }
                } else {
                    // Handle error responses
                    await MainActor.run {
                        if httpResponse.statusCode == 401 {
                            errorMessage = "Authentication required"
                        } else if httpResponse.statusCode == 404 {
                            errorMessage = "No daily challenge available today"
                        } else {
                            errorMessage = "Server error (\(httpResponse.statusCode))"
                        }
                        isLoading = false
                    }
                }
            } catch {
                // Handle network or parsing errors
                await MainActor.run {
                    errorMessage = "Failed to load daily challenge: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    // Save daily quote to Realm for offline use
    private func saveQuoteToRealm(_ quote: DailyQuote) {
        // Get realm instance
        guard let realm = RealmManager.shared.getRealm() else { return }
        
        // Create date object from ISO string
        let dateFormatter = ISO8601DateFormatter()
        guard let quoteDate = dateFormatter.date(from: quote.date) else { return }
        
        do {
            try realm.write {
                let quoteRealm = QuoteRealm()
                quoteRealm.text = quote.text
                quoteRealm.author = quote.author
                quoteRealm.attribution = quote.minor_attribution
                quoteRealm.difficulty = quote.difficulty
                quoteRealm.isDaily = true
                quoteRealm.dailyDate = quoteDate
                quoteRealm.uniqueLetters = quote.unique_letters
                
                realm.add(quoteRealm)
            }
        } catch {
            print("Error saving daily quote: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Game State Management
    
    /// Check for an in-progress game
    func checkForInProgressGame() {
        // Look for unfinished games in Realm
        if let game = gameStore.loadLatestGame() {
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
            self.savedGame = game
            self.showContinueGameModal = true
        }
    }
    
    /// Continue a saved game
    func continueSavedGame() {
        if let savedGame = savedGame {
            currentGame = savedGame
            
            // Get quote info if available
            if let quoteRealm = getQuoteForGame(savedGame) {
                quoteAuthor = quoteRealm.author
                quoteAttribution = quoteRealm.attribution
            }
            
            self.showContinueGameModal = false
            self.savedGame = nil
        }
    }
    
    // Helper to find quote for a game
    private func getQuoteForGame(_ game: Game) -> QuoteRealm? {
        guard let realm = RealmManager.shared.getRealm() else { return nil }
        
        // The solution text should match the quote text
        let quotes = realm.objects(QuoteRealm.self).filter("text == %@", game.solution)
        return quotes.first
    }
    
    /// Reset the current game
    func resetGame() {
        // If there was a saved game, mark it as abandoned
        if let oldGameId = savedGame?.gameId {
            markGameAsAbandoned(gameId: oldGameId)
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
            setupCustomGame()
        }
        
        // Clear the saved game reference
        self.savedGame = nil
    }
    
    // Mark a game as abandoned
    private func markGameAsAbandoned(gameId: String) {
        guard let realm = RealmManager.shared.getRealm() else { return }
        
        do {
            try realm.write {
                if let game = realm.object(ofType: GameRealm.self, forPrimaryKey: gameId) {
                    game.hasLost = true
                    
                    // Reset streak if player had one
                    if let userId = game.userId, let user = realm.object(ofType: UserRealm.self, forPrimaryKey: userId) {
                        if let stats = user.stats, stats.currentStreak > 0 {
                            stats.currentStreak = 0
                        }
                    }
                }
            }
        } catch {
            print("Error marking game as abandoned: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Game Actions
    
    /// Handle a player's guess
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
    
    // Save current game state to Realm
    private func saveGameState(_ game: Game) {
        if let _ = game.gameId {
            // Update existing game
            _ = gameStore.updateGame(game)
        } else {
            // Save new game
            if let updatedGame = gameStore.saveGame(game) {
                currentGame = updatedGame
            }
        }
    }
    
    /// Submit score for daily challenge
    func submitDailyScore(userId: String) {
        guard let game = currentGame, game.hasWon || game.hasLost else { return }
        
        let finalScore = game.calculateScore()
        let timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
        
        // Update user stats in Realm
        gameStore.updateStats(
            userId: userId,
            gameWon: game.hasWon,
            mistakes: game.mistakes,
            timeTaken: timeTaken,
            score: finalScore
        )
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
    
    // Helper for time formatting
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Extension to safely access array elements
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
