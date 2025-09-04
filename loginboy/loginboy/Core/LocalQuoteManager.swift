//
//  LocalQuoteManager.swift
//  loginboy
//
//  Created by Daniel Horsley on 04/09/2025.
//

import Foundation
import CoreData
import SwiftUI

class LocalQuoteManager: ObservableObject {
    static let shared = LocalQuoteManager()
    
    @Published var isLoaded = false
    @Published var loadingError: String?
    
    private let coreData = CoreDataStack.shared
    private let quotesLoadedKey = "quotes_loaded_v1.0"
    
    init() {
        loadQuotesIfNeeded()
    }
    
    // MARK: - Auto-Loading System
    
    func loadQuotesIfNeeded() {
        // Check if we've already loaded quotes for this version
        if UserDefaults.standard.bool(forKey: quotesLoadedKey) {
            print("✅ Quotes already loaded")
            isLoaded = true
            return
        }
        
        print("📚 Loading quotes from bundle...")
        loadQuotesFromBundle()
    }
    
    private func loadQuotesFromBundle() {
        guard let path = Bundle.main.path(forResource: "quotes_classic", ofType: "json") else {
            loadingError = "Could not find quotes_classic.json in bundle"
            print("❌ Missing quotes_classic.json file")
            return
        }
        
        do {
            let data = Data(contentsOfFile: path)
            let decoder = JSONDecoder()
            let quotePackData = try decoder.decode(QuotePackData.self, from: data)
            
            print("📖 Loaded \(quotePackData.quotes.count) quotes from bundle")
            
            // Save to Core Data
            saveQuotesToCoreData(quotePackData.quotes)
            
            // Mark as loaded
            UserDefaults.standard.set(true, forKey: quotesLoadedKey)
            
            DispatchQueue.main.async {
                self.isLoaded = true
                print("✅ Quotes ready for gameplay!")
            }
            
        } catch {
            loadingError = "Failed to load quotes: \(error.localizedDescription)"
            print("❌ Quote loading error: \(error)")
        }
    }
    
    private func saveQuotesToCoreData(_ quotes: [QuoteData]) {
        let context = coreData.newBackgroundContext()
        
        context.performAndWait {
            do {
                // Clear existing quotes (in case of version update)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: QuoteCD.fetchRequest())
                try context.execute(deleteRequest)
                
                // Add new quotes
                for quote in quotes {
                    let quoteEntity = QuoteCD(context: context)
                    quoteEntity.id = UUID() // Generate new UUID
                    quoteEntity.text = quote.text
                    quoteEntity.author = quote.author
                    quoteEntity.difficulty = quote.difficulty
                    quoteEntity.category = quote.category
                    quoteEntity.usageCount = 0
                    quoteEntity.lastUsed = nil
                }
                
                try context.save()
                print("💾 Saved \(quotes.count) quotes to Core Data")
                
            } catch {
                print("❌ Core Data save error: \(error)")
                DispatchQueue.main.async {
                    self.loadingError = "Failed to save quotes to database"
                }
            }
        }
    }
    
    // MARK: - Quote Access Methods
    
    func getRandomQuote() -> QuoteModel? {
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<QuoteCD> = QuoteCD.fetchRequest()
        
        do {
            let quotes = try context.fetch(fetchRequest)
            guard !quotes.isEmpty else {
                print("⚠️ No quotes available")
                return nil
            }
            
            let randomQuote = quotes.randomElement()
            return randomQuote?.toQuoteModel()
            
        } catch {
            print("❌ Error fetching random quote: \(error)")
            return nil
        }
    }
    
    func getDailyQuote() -> QuoteModel? {
        // Deterministic daily quote based on date
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let daysSinceEpoch = Int(today.timeIntervalSince1970 / 86400)
        
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<QuoteCD> = QuoteCD.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "text", ascending: true)]
        
        do {
            let quotes = try context.fetch(fetchRequest)
            guard !quotes.isEmpty else { return nil }
            
            // Same quote for same day for all users
            let quoteIndex = daysSinceEpoch % quotes.count
            let dailyQuote = quotes[quoteIndex]
            
            print("📅 Daily quote for day \(daysSinceEpoch): \(dailyQuote.author ?? "Unknown")")
            return dailyQuote.toQuoteModel()
            
        } catch {
            print("❌ Error fetching daily quote: \(error)")
            return getRandomQuote() // Fallback to random
        }
    }
    
    func getQuotesByDifficulty(_ difficulty: String) -> [QuoteModel] {
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<QuoteCD> = QuoteCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "difficulty == %@", difficulty)
        
        do {
            let quotes = try context.fetch(fetchRequest)
            return quotes.compactMap { $0.toQuoteModel() }
        } catch {
            print("❌ Error fetching quotes by difficulty: \(error)")
            return []
        }
    }
    
    func getAvailableQuoteCount() -> Int {
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<QuoteCD> = QuoteCD.fetchRequest()
        
        do {
            return try context.count(for: fetchRequest)
        } catch {
            print("❌ Error counting quotes: \(error)")
            return 0
        }
    }
}

// MARK: - Data Models

struct QuotePackData: Codable {
    let metadata: PackMetadata
    let quotes: [QuoteData]
}

struct PackMetadata: Codable {
    let name: String
    let description: String
    let version: String
    let quoteCount: Int
    let isBase: Bool?
}

struct QuoteData: Codable {
    let text: String
    let author: String
    let difficulty: String
    let category: String
    let id: String
}

struct QuoteModel {
    let id: UUID
    let text: String
    let author: String
    let difficulty: String
    let category: String
    
    init(id: UUID = UUID(), text: String, author: String, difficulty: String = "medium", category: String = "classic") {
        self.id = id
        self.text = text
        self.author = author
        self.difficulty = difficulty
        self.category = category
    }
}

// Update your existing QuoteCD extension
extension QuoteCD {
    func toQuoteModel() -> QuoteModel {
        return QuoteModel(
            id: self.id ?? UUID(),
            text: self.text ?? "",
            author: self.author ?? "",
            difficulty: self.difficulty ?? "medium",
            category: self.category ?? "classic"
        )
    }
}
