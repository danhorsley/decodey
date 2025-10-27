import SwiftUI
import StoreKit

struct PurchaseView: View {
    @StateObject private var store = StoreManager.shared
    @StateObject private var packageManager = QuotePackageManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var purchaseInProgress: StoreManager.ProductID?
    @State private var showError = false
    @State private var showSuccessAlert = false
    @State private var purchasedPackageName = ""
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header with close button
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Expand Your Library")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("Unlock timeless wisdom and wit")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    // Free quotes indicator
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("200 Free Quotes Included")
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Category description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Collections")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text("Each collection adds hundreds of carefully curated quotes to your game, making daily puzzles more diverse and enjoyable.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    // Products
                    ForEach(StoreManager.ProductID.allCases, id: \.self) { productID in
                        ProductRow(
                            productID: productID,
                            product: store.product(for: productID),
                            isPurchased: store.isPackPurchased(productID),
                            isPurchasing: purchaseInProgress == productID,
                            onPurchase: { await purchaseProduct(productID) }
                        )
                        .padding(.horizontal)
                    }
                    
                    // Bundle offer (optional)
                    if !areAllPacksPurchased() {
                        VStack(spacing: 8) {
                            Text("💎 Complete Collection")
                                .font(.headline)
                            Text("Get all remaining packs at a discount!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(colors: [.purple.opacity(0.1), .blue.opacity(0.1)],
                                         startPoint: .leading,
                                         endPoint: .trailing)
                        )
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Restore purchases button
                    Button(action: {
                        Task {
                            await store.restorePurchases()
                            packageManager.refreshPackages()
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.footnote)
                            .foregroundColor(.blue)
                    }
                    .padding(.top)
                    
                    // Legal text
                    Text("All quotes are from public domain sources. Purchases are non-consumable and sync across your devices.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        }
        .alert("Purchase Failed", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(store.errorMessage ?? "Unable to complete purchase")
        }
        .alert("Success!", isPresented: $showSuccessAlert) {
            Button("Great!") { }
        } message: {
            Text("\(purchasedPackageName) has been added to your library. New quotes will appear in your daily games!")
        }
        .onAppear {
            Task {
                await store.loadProducts()
            }
        }
    }
    
    private func areAllPacksPurchased() -> Bool {
        StoreManager.ProductID.allCases.allSatisfy { store.isPackPurchased($0) }
    }
    
    private func purchaseProduct(_ productID: StoreManager.ProductID) async {
        guard let product = store.product(for: productID) else { return }
        
        purchaseInProgress = productID
        
        do {
            let success = try await store.purchase(product)
            if success {
                // Refresh packages after successful purchase
                packageManager.refreshPackages()
                
                // Show success alert
                purchasedPackageName = productID.displayName
                showSuccessAlert = true
                
                // Trigger game state refresh to include new quotes
                await GameState.shared.refreshAvailableQuotes()
            }
        } catch {
            store.errorMessage = error.localizedDescription
            showError = true
        }
        
        purchaseInProgress = nil
    }
}

// MARK: - Product Row
struct ProductRow: View {
    let productID: StoreManager.ProductID
    let product: Product?
    let isPurchased: Bool
    let isPurchasing: Bool
    let onPurchase: () async -> Void
    
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: productID.icon)
                    .font(.title2)
                    .foregroundColor(isPurchased ? .green : iconColor)
                    .frame(width: 40)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(productID.displayName)
                            .fontWeight(.semibold)
                        
                        if productID == .zingers {
                            Text("POPULAR")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(productID.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("\(productID.quoteCount) quotes")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if !isPurchased {
                            Text("•")
                                .foregroundColor(.secondary)
                                .font(.caption2)
                            
                            Button(action: { showDetails.toggle() }) {
                                Text(showDetails ? "Hide details" : "View details")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Purchase button or status
                if isPurchased {
                    VStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        Text("Owned")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                } else if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else if let product = product {
                    Button(action: {
                        Task {
                            await onPurchase()
                        }
                    }) {
                        Text(product.displayPrice)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(buttonBackground)
                            .cornerRadius(20)
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                }
            }
            .padding()
            
            // Expandable details section
            if showDetails && !isPurchased {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    detailContent
                        .padding()
                }
                .transition(.opacity)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)  // SwiftUI's semantic background color
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }
    
    private var iconColor: Color {
        switch productID {
        case .classical: return .purple
        case .literature: return .brown
        case .shakespeare: return .red
        case .zingers: return .orange
        }
    }
    
    private var buttonBackground: LinearGradient {
        switch productID {
        case .classical:
            return LinearGradient(colors: [.purple, .purple.opacity(0.8)],
                                startPoint: .leading, endPoint: .trailing)
        case .literature:
            return LinearGradient(colors: [.brown, .brown.opacity(0.8)],
                                startPoint: .leading, endPoint: .trailing)
        case .shakespeare:
            return LinearGradient(colors: [.red, .red.opacity(0.8)],
                                startPoint: .leading, endPoint: .trailing)
        case .zingers:
            return LinearGradient(colors: [.orange, .orange.opacity(0.8)],
                                startPoint: .leading, endPoint: .trailing)
        }
    }
    
    @ViewBuilder
    private var detailContent: some View {
        switch productID {
        case .classical:
            VStack(alignment: .leading, spacing: 4) {
                Text("Includes quotes from:")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("• Plato, Aristotle, Socrates")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("• Marcus Aurelius, Seneca, Epictetus")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("• Cicero, Confucius, and more")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
        case .literature:
            VStack(alignment: .leading, spacing: 4) {
                Text("Includes quotes from:")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("• Jane Austen, Charles Dickens")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("• Oscar Wilde, Mark Twain")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("• Emily Dickinson, and more")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
        case .shakespeare:
            VStack(alignment: .leading, spacing: 4) {
                Text("Includes quotes from:")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("• Hamlet, Romeo and Juliet")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("• Macbeth, A Midsummer Night's Dream")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("• King Lear, Othello, and more")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
        case .zingers:
            VStack(alignment: .leading, spacing: 4) {
                Text("Perfect for:")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("• Quick wit and clever comebacks")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("• Humorous observations")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("• Memorable one-liners")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview
struct PurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        PurchaseView()
    }
}
