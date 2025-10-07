// LocalQuoteManager.swift - Updated loadQuotesIfNeeded function

import Foundation
import CoreData
import SwiftUI

class LocalQuoteManager: ObservableObject {
    static let shared = LocalQuoteManager()
    
    @Published var isLoaded = false
    @Published var loadingError: String?
    
    private let coreData = CoreDataStack.shared
    private let quotesLoadedKey = "quotes_loaded_v3.0"
    
    private init() {}
    
    // MARK: - Simple Loading
    
    func loadQuotesIfNeeded() async {
        // Check BOTH UserDefaults AND actual database count
        let hasQuotesInDB = getQuoteCount() > 0
        let hasLoadedFlag = UserDefaults.standard.bool(forKey: quotesLoadedKey)
        
        if hasLoadedFlag && hasQuotesInDB {
            print("✅ Quotes already loaded (Count: \(getQuoteCount()))")
            await MainActor.run {
                self.isLoaded = true
            }
            return
        }
        
        // If we have the flag but no quotes, clear the flag
        if hasLoadedFlag && !hasQuotesInDB {
            print("⚠️ UserDefaults says quotes loaded but database is empty. Clearing flag.")
            UserDefaults.standard.removeObject(forKey: quotesLoadedKey)
        }
        
        print("📚 Loading quotes from bundle...")
        await loadQuotesFromBundle()
    }
    
    // Alternative: Add a force reload function for debugging
    func forceReloadQuotes() async {
        print("🔄 Force reloading quotes...")
        
        // Clear the flag
        UserDefaults.standard.removeObject(forKey: quotesLoadedKey)
        
        // Clear existing quotes
        await resetData()
        
        // Reload from bundle
        await loadQuotesFromBundle()
    }
    
    // Keep the rest of the implementation the same...
    private func loadQuotesFromBundle() async {
        // Find the file
        guard let url = Bundle.main.url(forResource: "quotes_classic", withExtension: "json") else {
            await MainActor.run {
                self.loadingError = "quotes_classic.json not found in bundle"
            }
            print("❌ File not found")
            return
        }
        
        print("✅ Found file: \(url.path)")
        
        do {
            let data = try Data(contentsOf: url)
            print("📄 Read \(data.count) bytes")
            
            // Parse JSON - only support simple format
            let decoder = JSONDecoder()
            let quoteData = try decoder.decode(SimpleQuoteData.self, from: data)
            
            print("✅ Parsed \(quoteData.quotes.count) quotes")
            await saveQuotesToCoreData(quoteData.quotes)
            
        } catch {
            await MainActor.run {
                self.loadingError = "Failed to load: \(error.localizedDescription)"
            }
            print("❌ Error: \(error)")
        }
    }
    
    private func saveQuotesToCoreData(_ quotes: [SimpleQuote]) async {
        return await withCheckedContinuation { continuation in
            let context = coreData.newBackgroundContext()
            
            context.perform {
                for quote in quotes {
                    let entity = QuoteCD(context: context)
                    entity.id = UUID()
                    entity.text = quote.text.uppercased()
                    entity.author = quote.author
                    entity.attribution = quote.attribution
                    entity.difficulty = 0.0  // Always 0 for now
                    entity.timesUsed = 0
                    entity.uniqueLetters = Int16(Set(quote.text.filter { $0.isLetter }).count)
                    entity.isActive = true
                    entity.isDaily = false
                    entity.serverId = 0
                    entity.dailyDate = nil
                }
                
                do {
                    try context.save()
                    print("✅ Saved \(quotes.count) quotes")
                    
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(true, forKey: self.quotesLoadedKey)
                        self.isLoaded = true
                        self.loadingError = nil
                    }
                } catch {
                    print("❌ Save failed: \(error)")
                    DispatchQueue.main.async {
                        self.loadingError = "Save failed: \(error.localizedDescription)"
                    }
                }
                
                continuation.resume()
            }
        }
    }
    
    // MARK: - Quote Access
    
    func getRandomQuote() -> LocalQuoteModel? {
        let context = coreData.mainContext
        let request = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        request.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            let quotes = try context.fetch(request)
            guard !quotes.isEmpty else {
                print("❌ No quotes in database")
                return nil
            }
            
            let randomQuote = quotes.randomElement()!
            return LocalQuoteModel(
                text: randomQuote.text ?? "",
                author: randomQuote.author ?? "Unknown"
            )
        } catch {
            print("❌ Fetch failed: \(error)")
            return nil
        }
    }
    
    func getDailyQuote(for dayNumber: Int) -> LocalQuoteModel? {
        let context = coreData.mainContext
        let request = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "text", ascending: true)]
        
        do {
            let quotes = try context.fetch(request)
            guard !quotes.isEmpty else { return nil }
            
            let index = dayNumber % quotes.count
            let quote = quotes[index]
            
            return LocalQuoteModel(
                text: quote.text ?? "",
                author: quote.author ?? "Unknown"
            )
        } catch {
            print("❌ Daily fetch failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Debug
    
    func getQuoteCount() -> Int {
        let context = coreData.mainContext
        let request = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        request.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            return try context.count(for: request)
        } catch {
            print("❌ Count failed: \(error)")
            return 0
        }
    }
    
    func debugPrint() {
        print("📊 Quotes loaded: \(isLoaded)")
        print("📊 Quote count: \(getQuoteCount())")
        print("📊 Error: \(loadingError ?? "none")")
        
        if let quote = getRandomQuote() {
            print("📊 Sample: \"\(quote.text)\" - \(quote.author)")
        }
    }
    
    func resetData() async {
        UserDefaults.standard.removeObject(forKey: quotesLoadedKey)
        
        return await withCheckedContinuation { continuation in
            let context = coreData.newBackgroundContext()
            context.perform {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: "QuoteCD")
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                
                do {
                    try context.execute(deleteRequest)
                    try context.save()
                    
                    DispatchQueue.main.async {
                        self.isLoaded = false
                        self.loadingError = nil
                    }
                    
                    print("✅ Reset complete")
                } catch {
                    print("❌ Reset failed: \(error)")
                }
                
                continuation.resume()
            }
        }
    }
}

// MARK: - Simple Data Structures

private struct SimpleQuoteData: Codable {
    let quotes: [SimpleQuote]
}

private struct SimpleQuote: Codable {
    let text: String
    let author: String
    let attribution: String?
}

//struct LocalQuoteModel {
//    let text: String
//    let author: String
//}
