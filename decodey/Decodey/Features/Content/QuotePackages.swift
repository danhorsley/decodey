import Foundation

// MARK: - Quote Model
struct Quote: Codable, Identifiable {
    let id: Int
    let text: String
    let author: String
    let category: String
}

// MARK: - Quote Package System
struct QuotePackage {
    let id: StoreManager.ProductID
    let quotes: [Quote]
    
    static func loadPackage(_ id: StoreManager.ProductID) -> QuotePackage? {
        let filename: String
        switch id {
        case .classical:
            // Use the classical.json file for classical philosophy quotes
            filename = "classical"
        case .literature:
            // Use the literature_19th.json file for 19th century literature
            filename = "literature_19th"
        case .shakespeare:
            // Use the shakespeare.json file for Shakespeare quotes
            filename = "shakespeare"
        case .zingers:
            // Use the zingers.json file for witty comebacks
            filename = "zingers"
        }
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let quotes = try? JSONDecoder().decode([Quote].self, from: data) else {
            print("❌ Failed to load package: \(filename)")
            return nil
        }
        
        print("✅ Successfully loaded package: \(filename) with \(quotes.count) quotes")
        return QuotePackage(id: id, quotes: quotes)
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
                    category: "general"
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
