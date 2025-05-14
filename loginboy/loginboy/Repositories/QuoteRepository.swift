import Foundation
import GRDB

protocol QuoteRepositoryProtocol {
    func getRandomQuote(difficulty: String?) throws -> Quote
    func getDailyQuote() throws -> DailyQuote?
    func syncQuotes(from api: QuoteServiceProtocol, auth: AuthenticationCoordinator) async throws -> Bool
}

class QuoteRepository: QuoteRepositoryProtocol {
    private let database: DatabaseQueue
    
    init(database: DatabaseQueue) {
        self.database = database
    }
    
    func getRandomQuote(difficulty: String? = nil) throws -> Quote {
        try database.read { db in
            var request = QuoteRecord.filter(Column("isActive") == true)
            
            // Apply difficulty filter if provided
            if let difficulty = difficulty {
                let difficultyRange: ClosedRange<Double>
                switch difficulty {
                case "easy": difficultyRange = 0.0...1.0
                case "hard": difficultyRange = 2.0...3.0
                default: difficultyRange = 1.0...2.0
                }
                
                request = request.filter(difficultyRange.contains(Column("difficulty")))
            }
            
            // Get a random quote
            let count = try request.fetchCount(db)
            guard count > 0 else {
                throw RepositoryError.notFound("No quotes found")
            }
            
            let randomIndex = Int.random(in: 0..<count)
            request = request.limit(1, offset: randomIndex)
            
            guard let quoteRecord = try request.fetchOne(db) else {
                throw RepositoryError.notFound("Quote not found")
            }
            
            // Convert to domain model
            return Quote(
                text: quoteRecord.text,
                author: quoteRecord.author,
                attribution: quoteRecord.attribution,
                difficulty: quoteRecord.difficulty
            )
        }
    }
    
    func getDailyQuote() throws -> DailyQuote? {
        // Implementation for getting daily quote from local DB
        try database.read { db in
            let today = Date()
            let formatter = ISO8601DateFormatter()
            
            // Try to find a quote marked as daily for today
            let request = QuoteRecord.filter(Column("isDaily") == true && Column("dailyDate") == today)
            
            if let quoteRecord = try request.fetchOne(db) {
                // Convert to DailyQuote domain model
                return DailyQuote(
                    id: Int(quoteRecord.id ?? 0),
                    text: quoteRecord.text,
                    author: quoteRecord.author,
                    minor_attribution: quoteRecord.attribution,
                    difficulty: quoteRecord.difficulty,
                    date: formatter.string(from: today),
                    unique_letters: quoteRecord.uniqueLetters ?? 0
                )
            }
            
            return nil
        }
    }
    
    func syncQuotes(from api: QuoteServiceProtocol, auth: AuthenticationCoordinator) async throws -> Bool {
        guard let token = auth.getAccessToken() else {
            throw RepositoryError.authRequired
        }
        
        do {
            // Fetch quotes from API - adding await here to fix the compilation error
            let quotesResponse = try await api.getAllQuotes(token: token)
            
            // Save to database using async wrapper
            // We need to use a Task to synchronously wait within an async context
            return try await Task {
                try database.write { db in
                    // Clear existing quotes
                    try QuoteRecord.deleteAll(db)
                    
                    // Insert new quotes
                    for quote in quotesResponse.quotes {
                        let record = QuoteRecord(
                            text: quote.text,
                            author: quote.author,
                            attribution: quote.minorAttribution,
                            difficulty: quote.difficulty,
                            isDaily: quote.dailyDate != nil,
                            dailyDate: ISO8601DateFormatter().date(from: quote.dailyDate ?? ""),
                            isActive: true,
                            timesUsed: quote.timesUsed,
                            uniqueLetters: quote.uniqueLetters
                        )
                        
                        try record.insert(db)
                    }
                }
                return true
            }.value
            
            return true
        } catch {
            throw RepositoryError.syncFailed(error.localizedDescription)
        }
    }
}

// Common errors for repositories
enum RepositoryError: Error, LocalizedError {
    case notFound(String)
    case authRequired
    case syncFailed(String)
    case saveFailed(String)
    case databaseError(String)
    
    var errorDescription: String? {
        switch self {
        case .notFound(let entity): return "\(entity) not found"
        case .authRequired: return "Authentication required"
        case .syncFailed(let reason): return "Sync failed: \(reason)"
        case .saveFailed(let reason): return "Save failed: \(reason)"
        case .databaseError(let message): return "Database error: \(message)"
        }
    }
}

// Quote Record
struct QuoteRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "quotes"
    
    var id: Int64?
    let text: String
    let author: String
    let attribution: String?
    let difficulty: Double
    let isDaily: Bool
    let dailyDate: Date?
    let isActive: Bool
    let timesUsed: Int
    let uniqueLetters: Int?
    let createdAt: Date
    let updatedAt: Date
    
    init(text: String, author: String, attribution: String? = nil,
         difficulty: Double, isDaily: Bool = false, dailyDate: Date? = nil,
         isActive: Bool = true, timesUsed: Int = 0, uniqueLetters: Int? = nil) {
        self.id = nil
        self.text = text
        self.author = author
        self.attribution = attribution
        self.difficulty = difficulty
        self.isDaily = isDaily
        self.dailyDate = dailyDate
        self.isActive = isActive
        self.timesUsed = timesUsed
        self.uniqueLetters = uniqueLetters ?? Set(text.uppercased().filter { $0.isLetter }).count
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    
}
//
//  QuoteRepository.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//
