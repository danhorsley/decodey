import SwiftUI
import StoreKit

struct PurchaseView: View {
    @StateObject private var store = StoreManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var purchaseInProgress: StoreManager.ProductID?
    @State private var showError = false
    
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
                    
                    // Restore purchases button
                    Button(action: {
                        Task {
                            await store.restorePurchases()
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
    }
    
    private func purchaseProduct(_ productID: StoreManager.ProductID) async {
        guard let product = store.product(for: productID) else { return }
        
        purchaseInProgress = productID
        
        do {
            let success = try await store.purchase(product)
            if success {
                // Refresh packages after successful purchase
                QuotePackageManager.shared.refreshPackages()
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
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: productID.icon)
                .font(.title2)
                .foregroundColor(isPurchased ? .green : .blue)
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
                
                Text("\(productID.quoteCount) quotes")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Purchase button or status
            if isPurchased {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
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
                        .background(Color.blue)
                        .cornerRadius(20)
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background {
            #if os(iOS)
            Color(.systemBackground)
            #else
            Color(NSColor.controlBackgroundColor)
            #endif
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Preview
struct PurchaseView_Previews: PreviewProvider {
    static var previews: some View {
        PurchaseView()
    }
}
