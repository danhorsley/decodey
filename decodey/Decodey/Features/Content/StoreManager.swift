import StoreKit
import SwiftUI

// MARK: - Store Manager
@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Product IDs - match these exactly in App Store Connect
    enum ProductID: String, CaseIterable {
        case classical = "com.freeform.decodey.classical"
        case literature = "com.freeform.decodey.literature"
        case shakespeare = "com.freeform.decodey.shakespeare"
        case zingers = "com.freeform.decodey.zingers"
        
        var displayName: String {
            switch self {
            case .classical: return "Classical Wisdom"
            case .literature: return "19th Century Literature"
            case .shakespeare: return "Shakespeare"
            case .zingers: return "Zingers & Wit"
            }
        }
        
        var description: String {
            switch self {
            case .classical: return "500 quotes from ancient philosophers"
            case .literature: return "500 quotes from Dickens, Austen & more"
            case .shakespeare: return "500 quotes from the Bard"
            case .zingers: return "100 witty comebacks & clever retorts"
            }
        }
        
        var icon: String {
            switch self {
            case .classical: return "building.columns"
            case .literature: return "books.vertical"
            case .shakespeare: return "theatermasks"
            case .zingers: return "bolt.fill"
            }
        }
        
        var quoteCount: Int {
            switch self {
            case .zingers: return 100
            default: return 500
            }
        }
    }
    
    private init() {
        Task {
            await loadProducts()
            await updatePurchasedProducts()
            observeTransactionUpdates()
        }
    }
    
    // Load products from App Store
    func loadProducts() async {
        isLoading = true
        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)
            isLoading = false
        } catch {
            errorMessage = "Failed to load products"
            isLoading = false
        }
    }
    
    // Check what user has already purchased
    func updatePurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchasedProductIDs.insert(transaction.productID)
            }
        }
    }
    
    // Observe transaction updates
    private func observeTransactionUpdates() {
        Task {
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    purchasedProductIDs.insert(transaction.productID)
                    await transaction.finish()
                }
            }
        }
    }
    
    // Purchase a product
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                purchasedProductIDs.insert(transaction.productID)
                if let productID = ProductID(rawValue: transaction.productID) {
                    print("🎯 Starting to load pack: \(productID.displayName)")
                    await LocalQuoteManager.shared.loadQuotePack(productID)
                    print("✅ Finished loading pack: \(productID.displayName)")
                }
                await transaction.finish()
                
                // Trigger package loading after purchase
                if let productID = ProductID(rawValue: transaction.productID) {
                    await LocalQuoteManager.shared.loadQuotePack(productID)
                }
                
                return true
            }
            return false
            
        case .userCancelled:
            return false
            
        case .pending:
            return false
            
        @unknown default:
            return false
        }
    }
    
    // Restore purchases
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            
            // Reload packages after restore
            for productID in ProductID.allCases {
                if isPackPurchased(productID) {
                    await LocalQuoteManager.shared.loadQuotePack(productID)
                }
            }
        } catch {
            errorMessage = "Failed to restore purchases"
        }
    }
    
    // Check if a pack is purchased
    func isPackPurchased(_ productID: ProductID) -> Bool {
        purchasedProductIDs.contains(productID.rawValue)
    }
    
    // Get product by ID
    func product(for productID: ProductID) -> Product? {
        products.first { $0.id == productID.rawValue }
    }
}
