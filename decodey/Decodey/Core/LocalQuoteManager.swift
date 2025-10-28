// LocalQuoteManager.swift
// Complete implementation with package integration

import Foundation
import CoreData
import SwiftUI

@MainActor
class LocalQuoteManager: ObservableObject {
    static let shared = LocalQuoteManager()
    
    @Published var isLoaded = false
    @Published var loadingError: String?
    @Published var quotesCount: Int = 0
    
    private let coreData = CoreDataStack.shared
    private let quotesLoadedKey = "quotes_loaded_v3.0"
    
    private init() {}
    
    // MARK: - Initialization & Loading
    
    /// Main loading function called on app startup
    func loadQuotesIfNeeded() async {
        // Check BOTH UserDefaults AND actual database count
        let hasQuotesInDB = getQuoteCount() > 0
        let hasLoadedFlag = UserDefaults.standard.bool(forKey: quotesLoadedKey)
        
        if hasLoadedFlag && hasQuotesInDB {
            print("✅ Quotes already loaded (Count: \(getQuoteCount()))")
            self.isLoaded = true
            self.quotesCount = getQuoteCount()
            
            // Still load purchased quotes in case of new purchases
            await loadPurchasedQuotes()
            return
        }
        
        // If we have the flag but no quotes, clear the flag
        if hasLoadedFlag && !hasQuotesInDB {
            print("⚠️ UserDefaults says quotes loaded but database is empty. Clearing flag.")
            UserDefaults.standard.removeObject(forKey: quotesLoadedKey)
        }
        
        print("📚 Loading quotes from bundle...")
        await loadQuotesFromBundle()
        
        // Load purchased quotes after free quotes
        await loadPurchasedQuotes()
    }
    
    /// Force reload all quotes (for debugging or manual refresh)
    func forceReloadQuotes() async {
        print("🔄 Force reloading quotes...")
        
        // Clear the flag
        UserDefaults.standard.removeObject(forKey: quotesLoadedKey)
        
        // Clear purchased pack flags
        for productID in StoreManager.ProductID.allCases {
            let key = "pack_loaded_\(productID.rawValue)"
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Clear existing quotes
        await resetData()
        
        // Reload everything
        await loadQuotesFromBundle()
        await loadPurchasedQuotes()
    }

    // MARK: - Bundle Loading (Free Quotes)
    
    private func loadQuotesFromBundle() async {
        // Find the file - try both names for compatibility
        let fileNames = ["quotes_starter", "quotes"]
        var fileURL: URL?
        
        for fileName in fileNames {
            if let url = Bundle.main.url(forResource: fileName, withExtension: "json") {
                fileURL = url
                print("✅ Found file: \(fileName).json")
                break
            }
        }
        
        guard let url = fileURL else {
            self.loadingError = "No quotes file found in bundle"
            print("❌ No quotes file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            print("📄 Read \(data.count) bytes")
            
            // Parse JSON
            let decoder = JSONDecoder()
            let quoteData = try decoder.decode(SimpleQuoteData.self, from: data)
            
            print("✅ Parsed \(quoteData.quotes.count) free quotes")
            
            // Save to Core Data
            await saveQuotesToCoreData(quoteData.quotes, isFromPack: false)
            
        } catch {
            self.loadingError = "Failed to load: \(error.localizedDescription)"
            print("❌ Error loading bundle quotes: \(error)")
        }
    }
    
    // MARK: - Package Loading
    
    /// Load all purchased quote packages
    func loadPurchasedQuotes() async {
        for productID in StoreManager.ProductID.allCases {
            if StoreManager.shared.isPackPurchased(productID) && !isPackLoaded(productID) {
                await loadQuotePack(productID)
            }
        }
        
        // Update count after loading packages
        self.quotesCount = getQuoteCount()
    }
    
    /// Load a specific quote pack
    func loadQuotePack(_ productID: StoreManager.ProductID) async {
        // Check if already loaded
        if isPackLoaded(productID) {
            print("✅ Pack already loaded: \(productID.displayName)")
            return
        }
        
        // Load the package
        guard let package = QuotePackage.loadPackage(productID) else {
            print("❌ Failed to load package file: \(productID.displayName)")
            return
        }
        
        print("📦 Loading package: \(productID.displayName) with \(package.quotes.count) quotes")
        
        // Convert package quotes to SimpleQuote format
        // FIX: Use the actual attribution from the quote, not category!
        let simpleQuotes = package.quotes.map { quote in
            SimpleQuote(
                text: quote.text,
                author: quote.author,
                attribution: quote.attribution  // FIXED: was quote.category
            )
        }
        
        // Save to Core Data with pack info
        // IMPORTANT: packID should be the full rawValue (com.freeform.decodey.shakespeare)
        await saveQuotesToCoreData(simpleQuotes, isFromPack: true, packID: productID.rawValue)
        
        // Mark pack as loaded
        markPackAsLoaded(productID)
        
        print("✅ Successfully loaded \(productID.displayName) pack with packID: \(productID.rawValue)")
    }

    
    /// Check if a pack has been loaded
    private func isPackLoaded(_ productID: StoreManager.ProductID) -> Bool {
        let key = "pack_loaded_\(productID.rawValue)"
        return UserDefaults.standard.bool(forKey: key)
    }
    
    /// Mark a pack as loaded
    private func markPackAsLoaded(_ productID: StoreManager.ProductID) {
        let key = "pack_loaded_\(productID.rawValue)"
        UserDefaults.standard.set(true, forKey: key)
    }
    
    /// Remove a pack (for testing or management)
    func removeQuotePack(_ productID: StoreManager.ProductID) async {
        await withCheckedContinuation { continuation in
            let context = coreData.newBackgroundContext()
            
            context.perform {
                let fetchRequest: NSFetchRequest<QuoteCD> = QuoteCD.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "packID == %@", productID.rawValue)
                
                do {
                    let quotes = try context.fetch(fetchRequest)
                    
                    for quote in quotes {
                        context.delete(quote)
                    }
                    
                    if context.hasChanges {
                        try context.save()
                        print("✅ Removed \(quotes.count) quotes from \(productID.displayName)")
                        
                        // Clear loaded flag
                        let key = "pack_loaded_\(productID.rawValue)"
                        UserDefaults.standard.removeObject(forKey: key)
                        
                        // Update count on main thread
                        DispatchQueue.main.async {
                            self.quotesCount = self.getQuoteCount()
                        }
                    }
                } catch {
                    print("❌ Failed to remove pack: \(error)")
                }
                
                continuation.resume()
            }
        }
    }
    
    // MARK: - Core Data Operations
    
    private func saveQuotesToCoreData(_ quotes: [SimpleQuote], isFromPack: Bool = false, packID: String? = nil) async {
        await withCheckedContinuation { continuation in
            let context = coreData.newBackgroundContext()
            
            context.perform {
                var savedCount = 0
                
                for quote in quotes {
                    // Check for duplicates
                    let fetchRequest: NSFetchRequest<QuoteCD> = QuoteCD.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "text == %@", quote.text.uppercased())
                    
                    do {
                        let existingQuotes = try context.fetch(fetchRequest)
                        
                        if existingQuotes.isEmpty {
                            // Create new quote
                            let entity = QuoteCD(context: context)
                            entity.id = UUID()
                            entity.text = quote.text.uppercased()
                            entity.author = quote.author
                            entity.attribution = quote.attribution
                            entity.difficulty = self.calculateDifficulty(for: quote.text)
                            entity.timesUsed = 0
                            entity.uniqueLetters = Int16(Set(quote.text.filter { $0.isLetter }).count)
                            entity.isActive = true
                            entity.isDaily = false
                            entity.serverId = 0
                            entity.dailyDate = nil
                            entity.isFromPack = isFromPack
                            entity.packID = packID
                            
                            savedCount += 1
                        }
                    } catch {
                        print("❌ Error checking for duplicate: \(error)")
                    }
                }
                
                // Save context
                do {
                    if context.hasChanges {
                        try context.save()
                        print("✅ Saved \(savedCount) new quotes to Core Data")
                        
                        // Update state on main thread
                        DispatchQueue.main.async {
                            if !isFromPack {
                                // Only set the loaded flag for free quotes
                                UserDefaults.standard.set(true, forKey: self.quotesLoadedKey)
                            }
                            self.isLoaded = true
                            self.loadingError = nil
                            self.quotesCount = self.getQuoteCount()
                        }
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
    
    // MARK: - Quote Access Methods
    
    /// Get a random quote from all available quotes
    func getRandomQuote() -> LocalQuoteModel? {
        let context = coreData.mainContext
        let request = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        
        // Get enabled packs from settings
        let enabledPacks = SettingsState.shared.enabledPacksForRandom
        
        // Build predicate to only include quotes from enabled packs
        var predicates: [NSPredicate] = [NSPredicate(format: "isActive == YES")]
        var packPredicates: [NSPredicate] = []
        
        // Check if free pack is enabled
        if enabledPacks.contains("free") {
            packPredicates.append(NSPredicate(format: "isFromPack == NO"))
        }
        
        // Check for purchased packs
        for packID in enabledPacks {
            if packID != "free" {
                packPredicates.append(NSPredicate(format: "packID == %@", packID))
            }
        }
        
        // Combine with OR
        if !packPredicates.isEmpty {
            let orPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: packPredicates)
            predicates.append(orPredicate)
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        do {
            let quotes = try context.fetch(request)
            guard !quotes.isEmpty else {
                print("❌ No quotes available from enabled packs")
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
    
    /// Get daily quote based on day number
    func getDailyQuote(for dayNumber: Int) -> LocalQuoteModel? {
        let context = coreData.mainContext
        let request = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "text", ascending: true)]
        
        do {
            let quotes = try context.fetch(request)
            guard !quotes.isEmpty else { return nil }
            
            // Use modulo to cycle through quotes
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
    
    /// Get quotes by difficulty
    func getQuotesByDifficulty(_ difficulty: Double) -> [LocalQuoteModel] {
        let context = coreData.mainContext
        let request = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        
        // Allow for some range in difficulty
        let minDifficulty = max(0, difficulty - 0.5)
        let maxDifficulty = min(2, difficulty + 0.5)
        
        request.predicate = NSPredicate(format: "isActive == YES AND difficulty >= %f AND difficulty <= %f", minDifficulty, maxDifficulty)
        
        do {
            let quotes = try context.fetch(request)
            return quotes.map { quote in
                LocalQuoteModel(
                    text: quote.text ?? "",
                    author: quote.author ?? "Unknown"
                )
            }
        } catch {
            print("❌ Difficulty fetch failed: \(error)")
            return []
        }
    }
    
    /// Get quotes from a specific pack
    func getQuotesFromPack(_ productID: StoreManager.ProductID) -> [LocalQuoteModel] {
        let context = coreData.mainContext
        let request = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        request.predicate = NSPredicate(format: "packID == %@", productID.rawValue)
        
        do {
            let quotes = try context.fetch(request)
            return quotes.map { quote in
                LocalQuoteModel(
                    text: quote.text ?? "",
                    author: quote.author ?? "Unknown"
                )
            }
        } catch {
            print("❌ Pack fetch failed: \(error)")
            return []
        }
    }
    
    /// Get only free quotes (not from packs)
    func getFreeQuotes() -> [LocalQuoteModel] {
        let context = coreData.mainContext
        let request = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        request.predicate = NSPredicate(format: "isActive == YES AND isFromPack == NO")
        
        do {
            let quotes = try context.fetch(request)
            return quotes.map { quote in
                LocalQuoteModel(
                    text: quote.text ?? "",
                    author: quote.author ?? "Unknown"
                )
            }
        } catch {
            print("❌ Free quotes fetch failed: \(error)")
            return []
        }
    }
    
    // MARK: - Utility Methods
    
    /// Get total count of quotes
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
    
    /// Get count by pack
    func getQuoteCount(for productID: StoreManager.ProductID) -> Int {
        let context = coreData.mainContext
        let request = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        request.predicate = NSPredicate(format: "packID == %@", productID.rawValue)
        
        do {
            return try context.count(for: request)
        } catch {
            return 0
        }
    }
    
    /// Calculate difficulty based on text characteristics
    private func calculateDifficulty(for text: String) -> Double {
        let uniqueLetters = Set(text.lowercased().filter { $0.isLetter }).count
        let length = text.count
        
        // Simple difficulty calculation
        if uniqueLetters <= 12 && length <= 40 {
            return 0.0 // Easy
        } else if uniqueLetters <= 16 && length <= 60 {
            return 1.0 // Medium
        } else {
            return 2.0 // Hard
        }
    }
    
    /// Debug information
    func debugPrint() {
        print("📊 === LocalQuoteManager Debug ===")
        print("📊 Quotes loaded: \(isLoaded)")
        print("📊 Total quotes: \(getQuoteCount())")
        print("📊 Free quotes: \(getFreeQuotes().count)")
        print("📊 Error: \(loadingError ?? "none")")
        
        for productID in StoreManager.ProductID.allCases {
            if isPackLoaded(productID) {
                print("📊 \(productID.displayName): \(getQuoteCount(for: productID)) quotes")
            }
        }
        
        if let quote = getRandomQuote() {
            print("📊 Sample: \"\(quote.text)\" - \(quote.author)")
        }
    }
    
    /// Reset all data
    func resetData() async {
        UserDefaults.standard.removeObject(forKey: quotesLoadedKey)
        
        // Clear all pack flags
        for productID in StoreManager.ProductID.allCases {
            let key = "pack_loaded_\(productID.rawValue)"
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        await withCheckedContinuation { continuation in
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
                        self.quotesCount = 0
                    }
                    
                    print("✅ Reset complete")
                } catch {
                    print("❌ Reset failed: \(error)")
                }
                
                continuation.resume()
            }
        }
    }
    
    /// Refresh quotes after a purchase
    func refreshAfterPurchase() async {
        await loadPurchasedQuotes()
        
        // Notify game state to refresh
        await GameState.shared.refreshAvailableQuotes()
    }
}

// MARK: - Data Structures

private struct SimpleQuoteData: Codable {
    let quotes: [SimpleQuote]
}

private struct SimpleQuote: Codable {
    let text: String
    let author: String
    let attribution: String?
}





