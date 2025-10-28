import Foundation

// MARK: - Quote Model
struct Quote: Codable, Identifiable {
    let id: Int
    let text: String
    let author: String
    let category: String
    let attribution: String?  // Add attribution field
}

// MARK: - JSON Structure that matches your files
struct QuotePackageData: Codable {
    let quotes: [QuoteData]
}

struct QuoteData: Codable {
    let text: String
    let author: String
    let attribution: String?
    let difficulty: Double?
    let category: String
    let unique_letters: Int?
}

// MARK: - Quote Package System
struct QuotePackage {
    let id: StoreManager.ProductID
    let quotes: [Quote]
    
    static func loadPackage(_ id: StoreManager.ProductID) -> QuotePackage? {
        let filename: String
        switch id {
        case .classical:
            filename = "classical"
        case .literature:
            filename = "literature_19th"
        case .shakespeare:
            filename = "shakespeare"
        case .zingers:
            filename = "zingers"
        }
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("❌ Failed to load file: \(filename).json")
            return nil
        }
        
        do {
            // Parse the JSON with the structure that matches your files
            let packageData = try JSONDecoder().decode(QuotePackageData.self, from: data)
            
            // Convert QuoteData to Quote format - NOW PROPERLY MAPPING ATTRIBUTION
            let quotes = packageData.quotes.enumerated().map { index, quoteData in
                Quote(
                    id: index,
                    text: quoteData.text.uppercased(), // Convert to uppercase for the game
                    author: quoteData.author,
                    category: quoteData.category,
                    attribution: quoteData.attribution  // Use the actual attribution field!
                )
            }
            
            print("✅ Successfully loaded package: \(filename) with \(quotes.count) quotes")
            return QuotePackage(id: id, quotes: quotes)
            
        } catch {
            print("❌ Failed to decode package: \(filename) - Error: \(error)")
            return nil
        }
    }
}

// MARK: - Quote Package Manager
@MainActor
class QuotePackageManager: ObservableObject {
    static let shared = QuotePackageManager()
    
    @Published var availablePackages: [QuotePackage] = []
    private var loadedPackages: [StoreManager.ProductID: QuotePackage] = [:]
    
    private init() {
        loadAvailablePackages()
    }
    
    func loadAvailablePackages() {
        availablePackages.removeAll()
        
        // Load purchased packages
        for productID in StoreManager.ProductID.allCases {
            if StoreManager.shared.isPackPurchased(productID) {
                if let package = loadedPackages[productID] ?? QuotePackage.loadPackage(productID) {
                    loadedPackages[productID] = package
                    availablePackages.append(package)
                }
            }
        }
    }
    
    func getAllAvailableQuotes(includesFree: Bool = true) -> [Quote] {
        var allQuotes: [Quote] = []
        
        // Add free quotes if requested
        if includesFree {
            // Get free quotes from LocalQuoteManager and convert to Quote format
            let freeQuotes = LocalQuoteManager.shared.getFreeQuotes()
            let convertedQuotes = freeQuotes.enumerated().map { index, localQuote in
                Quote(
                    id: index,
                    text: localQuote.text,
                    author: localQuote.author,
                    category: "general",
                    attribution: nil  // Free quotes might not have attribution
                )
            }
            allQuotes.append(contentsOf: convertedQuotes)
        }
        
        // Add quotes from purchased packages
        for package in availablePackages {
            allQuotes.append(contentsOf: package.quotes)
        }
        
        return allQuotes
    }
    
    func getQuotes(for category: String, includesFree: Bool = true) -> [Quote] {
        getAllAvailableQuotes(includesFree: includesFree)
            .filter { $0.category.lowercased() == category.lowercased() }
    }
    
    func isPackageAvailable(_ productID: StoreManager.ProductID) -> Bool {
        StoreManager.shared.isPackPurchased(productID)
    }
    
    func refreshPackages() {
        loadAvailablePackages()
    }
}
