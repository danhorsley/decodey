// QuoteService.swift - New file
import Foundation

struct Quote {
    let text: String
    let author: String
    let attribution: String?
    let difficulty: Double
    
    // Convert difficulty value to string representation
    var difficultyLevel: String {
        switch difficulty {
        case 0..<1: return "easy"
        case 1..<3: return "medium"
        default: return "hard"
        }
    }
    
    // Convert difficulty to max mistakes
    var maxMistakes: Int {
        switch difficultyLevel {
        case "easy": return 8
        case "hard": return 3
        default: return 5
        }
    }
}

class QuoteService {
    static let shared = QuoteService()
    private let databaseManager = DatabaseManager.shared
    
    // Get a random quote - simplified with no completion handler
    func getRandomQuote() throws -> Quote {
        let (text, author, attribution) = try databaseManager.getRandomQuote()
        return Quote(
            text: text,
            author: author,
            attribution: attribution,
            difficulty: 2.0 // Default to medium difficulty
        )
    }
    
    // Get daily quote
    func getDailyQuote(authService: AuthService) async throws -> DailyQuote {
        guard let token = authService.getAccessToken() else {
            throw QuoteError.authRequired
        }
        
        guard let url = URL(string: "\(authService.baseURL)/api/get_daily") else {
            throw QuoteError.invalidConfiguration
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QuoteError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(DailyQuote.self, from: data)
        case 401:
            throw QuoteError.authRequired
        case 404:
            throw QuoteError.notAvailable
        default:
            throw QuoteError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    enum QuoteError: Error, LocalizedError {
        case authRequired
        case invalidConfiguration
        case invalidResponse
        case notAvailable
        case serverError(statusCode: Int)
        
        var errorDescription: String? {
            switch self {
            case .authRequired: return "Authentication required"
            case .invalidConfiguration: return "Invalid URL configuration"
            case .invalidResponse: return "Invalid response from server"
            case .notAvailable: return "No daily challenge available today"
            case .serverError(let code): return "Server error (\(code))"
            }
        }
    }
}
//
//  QuoteService.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

