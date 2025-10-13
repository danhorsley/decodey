import Foundation

// MARK: - Quote Model (if not defined elsewhere)
// If you already have a Quote struct defined elsewhere,
// remove this and import that file instead
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
        case .zingers: filename = "zingers"
        case .shakespeare: filename = "shakespeare"
        case .bible: filename = "bible_kjv"
        case .literature: filename = "literature_19th"
        case .philosophy: filename = "philosophy_classical"
        case .mixed: filename = "mixed_classical"
        }
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let quotes = try? JSONDecoder().decode([Quote].self, from: data) else {
            return nil
        }
        
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
        
        // Always include free quotes (your existing quotes)
        // These come from your existing quotes.json
        
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
            // This would pull from your existing quote loading logic
            // Keep this part unchanged from your current implementation
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
