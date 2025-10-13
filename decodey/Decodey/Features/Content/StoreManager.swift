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
        case zingers = "com.yourapp.quotes.zingers"
        case shakespeare = "com.yourapp.quotes.shakespeare"
        case bible = "com.yourapp.quotes.bible"
        case literature = "com.yourapp.quotes.literature"
        case philosophy = "com.yourapp.quotes.philosophy"
        case mixed = "com.yourapp.quotes.mixed"
        
        var displayName: String {
            switch self {
            case .zingers: return "Zingers & Wit"
            case .shakespeare: return "Shakespeare"
            case .bible: return "King James Bible"
            case .literature: return "19th Century Literature"
            case .philosophy: return "Classical Philosophy"
            case .mixed: return "Mixed Classics"
            }
        }
        
        var description: String {
            switch self {
            case .zingers: return "100 witty comebacks & clever retorts"
            case .shakespeare: return "500 quotes from the Bard"
            case .bible: return "500 verses from the King James Bible"
            case .literature: return "500 quotes from Dickens, Austen & more"
            case .philosophy: return "500 quotes from ancient philosophers"
            case .mixed: return "500 mixed classical quotes"
            }
        }
        
        var icon: String {
            switch self {
            case .zingers: return "bolt.fill"
            case .shakespeare: return "theatermasks"
            case .bible: return "book.closed.fill"
            case .literature: return "books.vertical"
            case .philosophy: return "building.columns"
            case .mixed: return "sparkles"
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
            guard case .verified(let transaction) = result else { continue }
            purchasedProductIDs.insert(transaction.productID)
        }
    }
    
    // Listen for purchase updates
    private func observeTransactionUpdates() {
        Task {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
            }
        }
    }
    
    // Purchase a product
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw StoreError.verificationFailed
            }
            purchasedProductIDs.insert(transaction.productID)
            await transaction.finish()
            return true
            
        case .userCancelled:
            return false
            
        case .pending:
            throw StoreError.purchasePending
            
        @unknown default:
            throw StoreError.unknown
        }
    }
    
    // Restore purchases
    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    // Check if a specific pack is purchased
    func isPackPurchased(_ productID: ProductID) -> Bool {
        purchasedProductIDs.contains(productID.rawValue)
    }
    
    // Get product for a specific ID
    func product(for productID: ProductID) -> Product? {
        products.first { $0.id == productID.rawValue }
    }
}

// MARK: - Store Errors
enum StoreError: LocalizedError {
    case verificationFailed
    case purchasePending
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Purchase verification failed"
        case .purchasePending:
            return "Purchase is pending approval"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
