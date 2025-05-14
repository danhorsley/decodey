import Foundation
import Combine

// Define protocols for all services to enable mocking in tests

protocol AuthServiceProtocol {
    var isAuthenticated: Bool { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var username: String { get }
    var userId: String { get }
    var isSubadmin: Bool { get }
    
    func login(username: String, password: String, rememberMe: Bool, completion: @escaping (Bool, String?) -> Void)
    func logout()
    func getAccessToken() -> String?
    func refreshToken(completion: @escaping (Bool) -> Void)
}

protocol QuoteServiceProtocol {
    func getRandomQuote() throws -> Quote
    func getDailyQuote(auth: AuthenticationCoordinator) async throws -> DailyQuote
    func getAllQuotes(token: String) async throws -> QuotesResponse
}

protocol GameServiceProtocol {
    var currentGame: Game? { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    
    func setupCustomGame()
    func setupDailyChallenge()
    func continueSavedGame()
    func resetGame()
    func makeGuess(_ letter: Character)
    func selectLetter(_ letter: Character)
    func getHint()
}

protocol DatabaseServiceProtocol {
    func getRandomQuote(difficulty: String?) throws -> (text: String, author: String, attribution: String?)
    func loadLatestGame() throws -> Game?
    func saveGame(_ game: Game) throws -> Game
    func updateGame(_ game: Game, gameId: String) throws
    func updateStatistics(userId: String, gameWon: Bool, mistakes: Int, timeTaken: Int, score: Int) throws
    func checkAndSyncQuotesIfNeeded(auth: AuthenticationCoordinator)
}

protocol UserStatisticsServiceProtocol {
    func fetchUserStats(userId: String) async throws -> UserStats
    func fetchLeaderboard(period: String, page: Int) async throws -> LeaderboardResponse
    func updateStats(userId: String, gameWon: Bool, score: Int, timeTaken: Int, mistakes: Int) async throws
}

// Example of a mock service for testing
class MockQuoteService: QuoteServiceProtocol {
    // Mock data
    var mockQuotes: [Quote] = [
        Quote(text: "TEST QUOTE ONE", author: "Test Author", attribution: nil, difficulty: 1.0),
        Quote(text: "TEST QUOTE TWO", author: "Test Author 2", attribution: "Test Book", difficulty: 2.0)
    ]
    
    var mockDailyQuote = DailyQuote(
        id: 1,
        text: "DAILY TEST QUOTE",
        author: "Daily Author",
        minor_attribution: nil,
        difficulty: 1.5,
        date: "2025-05-13",
        unique_letters: 10
    )
    
    var shouldThrowError = false
    
    func getRandomQuote() throws -> Quote {
        if shouldThrowError {
            throw NSError(domain: "MockQuoteService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return mockQuotes.randomElement() ?? mockQuotes[0]
    }
    
    func getDailyQuote(auth: AuthenticationCoordinator) async throws -> DailyQuote {
        if shouldThrowError {
            throw NSError(domain: "MockQuoteService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return mockDailyQuote
    }
    
    func getAllQuotes(token: String) async throws -> QuotesResponse {
        if shouldThrowError {
            throw NSError(domain: "MockQuoteService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        
        return QuotesResponse(
            success: true,
            quotesCount: mockQuotes.count,
            quotes: mockQuotes.map { quote in
                QuoteModel(
                    id: 1,
                    text: quote.text,
                    author: quote.author,
                    minorAttribution: quote.attribution,
                    difficulty: quote.difficulty,
                    dailyDate: nil,
                    timesUsed: 0,
                    uniqueLetters: Set(quote.text.filter { $0.isLetter }).count,
                    createdAt: nil,
                    updatedAt: nil
                )
            }
        )
    }
}

//
//  ServiceProtocols.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

