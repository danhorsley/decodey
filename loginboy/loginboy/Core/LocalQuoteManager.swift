//
//  LocalQuoteManager.swift - WORKS WITH ACTUAL CORE DATA MODEL
//  loginboy
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
            
            // Try the simple structure first (from our artifact)
            if let simpleQuoteData = try? decoder.decode(SimpleQuotePackData.self, from: data) {
                print("📖 Loaded \(simpleQuoteData.quotes.count) quotes from bundle (simple format)")
                saveQuotesToCoreData(simpleQuoteData.quotes)
            }
            // Fallback to complex structure if that fails
            else if let complexQuoteData = try? decoder.decode(ComplexQuotePackData.self, from: data) {
                print("📖 Loaded \(complexQuoteData.quotes.count) quotes from bundle (complex format)")
                // Convert QuoteData to QuoteBundleItem
                let bundleItems = complexQuoteData.quotes.map { quoteData in
                    QuoteBundleItem(
                        text: quoteData.text,
                        author: quoteData.author,
                        attribution: nil, // QuoteData doesn't have attribution
                        difficulty: quoteData.difficulty,
                        category: quoteData.category
                    )
                }
                saveQuotesToCoreData(bundleItems)
            }
            else {
                throw NSError(domain: "QuoteParsingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown JSON format"])
            }
            
            // Mark as loaded
            UserDefaults.standard.set(true, forKey: quotesLoadedKey)
            
            DispatchQueue.main.async {
                self.isLoaded = true
                print("✅ Quotes ready for gameplay!")
            }
        } catch {
            loadingError = "Failed to load quotes: \(error.localizedDescription)"
            print("❌ Error loading quotes: \(error)")
        }
    }
    
    // MARK: - Supporting Structures for JSON Parsing
    
    private struct SimpleQuotePackData: Codable {
        let quotes: [QuoteBundleItem]
        let version: String
        let description: String
    }
    
    private struct ComplexQuotePackData: Codable {
        let metadata: PackMetadata
        let quotes: [QuoteData]
    }
    
    private struct PackMetadata: Codable {
        let name: String
        let description: String
        let version: String
        let quoteCount: Int
        let isBase: Bool?
    }
    
    private struct QuoteData: Codable {
        let text: String
        let author: String
        let difficulty: String
        let category: String
        let id: String
    }
    
    private func saveQuotesToCoreData(_ quotes: [QuoteBundleItem]) {
        let context = coreData.newBackgroundContext()
        
        context.perform {
            for quoteItem in quotes {
                let quoteEntity = QuoteCD(context: context)
                
                // Set properties that actually exist in QuoteCD
                quoteEntity.id = UUID()
                quoteEntity.text = quoteItem.text
                quoteEntity.author = quoteItem.author
                quoteEntity.attribution = quoteItem.attribution
                
                // Convert string difficulty to double
                let difficultyDouble = self.parseDifficulty(quoteItem.difficulty)
                quoteEntity.difficulty = difficultyDouble
                
                // Set properties from actual Core Data model
                quoteEntity.timesUsed = 0
                quoteEntity.uniqueLetters = Int16(Set(quoteItem.text.filter { $0.isLetter }).count)
                quoteEntity.isActive = true
                quoteEntity.isDaily = false
                quoteEntity.serverId = 0
                quoteEntity.dailyDate = nil
            }
            
            do {
                try context.save()
                print("✅ Saved \(quotes.count) quotes to Core Data")
            } catch {
                print("❌ Error saving quotes to Core Data: \(error)")
                DispatchQueue.main.async {
                    self.loadingError = "Failed to save quotes to database"
                }
            }
        }
    }
    
    private func parseDifficulty(_ difficultyString: String) -> Double {
        switch difficultyString.lowercased() {
        case "easy", "1":
            return 1.0
        case "medium", "2":
            return 2.0
        case "hard", "3":
            return 3.0
        default:
            return 2.0 // Default to medium
        }
    }
    
    // MARK: - Quote Access Methods
    
    /// Get a deterministic daily quote based on day number
    func getDailyQuote(for dayNumber: Int) -> LocalQuoteModel? {
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "text", ascending: true)] // Consistent sorting
        
        do {
            let quotes = try context.fetch(fetchRequest)
            guard !quotes.isEmpty else {
                print("❌ No quotes available for daily challenge")
                return nil
            }
            
            // Use modulo to get consistent daily quote
            let index = dayNumber % quotes.count
            let quote = quotes[index]
            
            return LocalQuoteModel(
                text: quote.text ?? "",
                author: quote.author ?? "Unknown",
                attribution: quote.attribution,
                difficulty: quote.difficulty,
                category: "classic" // Default category since Core Data doesn't have it
            )
        } catch {
            print("❌ Error fetching daily quote: \(error)")
            return nil
        }
    }
    
    /// Get a random quote
    func getRandomQuote() -> LocalQuoteModel? {
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            let quotes = try context.fetch(fetchRequest)
            guard !quotes.isEmpty else {
                print("❌ No quotes available")
                return nil
            }
            
            // Get truly random quote
            let randomIndex = Int.random(in: 0..<quotes.count)
            let quote = quotes[randomIndex]
            
            // Update usage tracking in background
            updateQuoteUsage(quote)
            
            return LocalQuoteModel(
                text: quote.text ?? "",
                author: quote.author ?? "Unknown",
                attribution: quote.attribution,
                difficulty: quote.difficulty,
                category: "classic" // Default category since Core Data doesn't have it
            )
        } catch {
            print("❌ Error fetching random quote: \(error)")
            return nil
        }
    }
    
    /// Get quote by difficulty
    func getQuoteByDifficulty(_ difficulty: Double) -> LocalQuoteModel? {
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        fetchRequest.predicate = NSPredicate(format: "isActive == YES AND difficulty == %@", NSNumber(value: difficulty))
        
        do {
            let quotes = try context.fetch(fetchRequest)
            guard !quotes.isEmpty else {
                print("❌ No quotes available for difficulty \(difficulty)")
                return getRandomQuote() // Fallback to any quote
            }
            
            let randomIndex = Int.random(in: 0..<quotes.count)
            let quote = quotes[randomIndex]
            
            updateQuoteUsage(quote)
            
            return LocalQuoteModel(
                text: quote.text ?? "",
                author: quote.author ?? "Unknown",
                attribution: quote.attribution,
                difficulty: quote.difficulty,
                category: "classic" // Default category since Core Data doesn't have it
            )
        } catch {
            print("❌ Error fetching quote by difficulty: \(error)")
            return getRandomQuote()
        }
    }
    
    private func updateQuoteUsage(_ quote: QuoteCD) {
        coreData.performBackgroundTask { context in
            let objectID = quote.objectID
            let backgroundQuote = context.object(with: objectID) as! QuoteCD
            
            // Use the actual Core Data property name
            backgroundQuote.timesUsed += 1
            
            do {
                try context.save()
            } catch {
                print("❌ Error updating quote usage: \(error)")
            }
        }
    }
    
    // MARK: - Stats
    
    func getQuoteCount() -> Int {
        let context = coreData.mainContext
        let fetchRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        fetchRequest.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            return try context.count(for: fetchRequest)
        } catch {
            print("❌ Error getting quote count: \(error)")
            return 0
        }
    }
    
    func resetQuoteData() {
        // Clear the loaded flag to force reload
        UserDefaults.standard.removeObject(forKey: quotesLoadedKey)
        
        // Delete all quotes from Core Data
        let context = coreData.newBackgroundContext()
        context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "QuoteCD")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                try context.save()
                
                DispatchQueue.main.async {
                    self.isLoaded = false
                    self.loadQuotesIfNeeded()
                }
            } catch {
                print("❌ Error resetting quote data: \(error)")
            }
        }
    }
}

// MARK: - Extensions for Core Data

extension QuoteCD {
    func toLocalQuoteModel() -> LocalQuoteModel {
        return LocalQuoteModel(
            text: self.text ?? "",
            author: self.author ?? "Unknown",
            attribution: self.attribution,
            difficulty: self.difficulty,
            category: "classic" // Default category since Core Data doesn't store this
        )
    }
}
