// QuoteService.swift - Refactored for AuthenticationCoordinator
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

class QuoteService: QuoteServiceProtocol {
    static let shared = QuoteService()
    private let quoteRepository: QuoteRepositoryProtocol
    
    init(quoteRepository: QuoteRepositoryProtocol = RepositoryProvider.shared.quoteRepository) {
        self.quoteRepository = quoteRepository
    }
    
    // Get a random quote - use the repository
    func getRandomQuote() throws -> Quote {
        return try quoteRepository.getRandomQuote(difficulty: nil)
    }
    
    // Get daily quote
    func getDailyQuote(auth: AuthenticationCoordinator) async throws -> DailyQuote {
        guard let token = auth.getAccessToken() else {
            throw QuoteError.authRequired
        }
        
        guard let url = URL(string: "\(auth.baseURL)/api/get_daily") else {
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
    
    // Get all quotes
    func getAllQuotes(token: String) async throws -> QuotesResponse {
        guard let url = URL(string: "\(ServiceConstants.baseURL)/api/get_all_quotes") else {
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
            return try JSONDecoder().decode(QuotesResponse.self, from: data)
        case 401:
            throw QuoteError.authRequired
        case 404:
            throw QuoteError.notAvailable
        default:
            throw QuoteError.serverError(statusCode: httpResponse.statusCode)
        }
    }
    
    // Quote service errors
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

// Constants for service URLs
enum ServiceConstants {
    static let baseURL = "https://7264097a-b4a2-42c7-988c-db8c0c9b107a-00-1lx57x7wg68m5.janeway.replit.dev"
}
