//
//  QuoteCheck.swift
//  Decodey
//
//  Quote Database Reconciliation System
//  Ensures purchased packs are always properly loaded in the database
//

import Foundation
import CoreData
import SwiftUI

/// QuoteCheck performs reconciliation between purchased packs and database content
/// This ensures users always have access to their purchased content, even after:
/// - Database resets
/// - Device switches
/// - App reinstalls
/// - Partial load failures
@MainActor
class QuoteCheck: ObservableObject {
    static let shared = QuoteCheck()
    
    @Published var isChecking = false
    @Published var checkComplete = false
    @Published var packsNeedingLoad: Set<StoreManager.ProductID> = []
    
    private let coreData = CoreDataStack.shared
    
    private init() {}
    
    // MARK: - Expected Quote Counts
    private let expectedQuoteCounts: [StoreManager.ProductID: Int] = [
        .shakespeare: 550,
        .zingers: 110,
        .classical: 300,  // Update with actual count
        .literature: 400   // Update with actual count
    ]
    
    private let expectedFreeQuoteCount = 218
    
    // MARK: - Main Reconciliation Method
    
    /// Perform complete reconciliation check on app launch
    /// This should be called from AppDelegate or main App struct
    func performLaunchCheck() async {
        print("\n🔍 ========== QUOTE DATABASE RECONCILIATION ==========")
        isChecking = true
        
        // Step 1: Check free quotes
        let freeQuotesOK = await checkFreeQuotes()
        
        // Step 2: Check purchased packs
        let purchasedPacksOK = await checkPurchasedPacks()
        
        // Step 3: Load any missing content
        if !packsNeedingLoad.isEmpty {
            await loadMissingPacks()
        }
        
        // Step 4: Clean up orphaned flags
        cleanupOrphanedFlags()
        
        // Step 5: Final verification
        let finalCheck = await verifyFinalState()
        
        isChecking = false
        checkComplete = true
        
        print("✅ Reconciliation complete. Database is \(finalCheck ? "healthy" : "needs attention")")
        print("====================================================\n")
    }
    
    // MARK: - Check Free Quotes
    
    private func checkFreeQuotes() async -> Bool {
        let context = coreData.mainContext
        let request = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        request.predicate = NSPredicate(format: "isFromPack == NO OR isFromPack == NULL")
        
        let freeQuoteCount = (try? context.count(for: request)) ?? 0
        
        print("📚 Free Quotes: \(freeQuoteCount)/\(expectedFreeQuoteCount)")
        
        if freeQuoteCount < expectedFreeQuoteCount {
            print("  ⚠️ Missing free quotes, reloading...")
            await LocalQuoteManager.shared.loadQuotesFromBundle()
            return false
        }
        
        print("  ✅ Free quotes loaded correctly")
        return true
    }
    
    // MARK: - Check Purchased Packs
    
    private func checkPurchasedPacks() async -> Bool {
        var allPacksOK = true
        packsNeedingLoad.removeAll()
        
        for productID in StoreManager.ProductID.allCases {
            if StoreManager.shared.isPackPurchased(productID) {
                let packStatus = await checkPack(productID)
                if !packStatus {
                    packsNeedingLoad.insert(productID)
                    allPacksOK = false
                }
            }
        }
        
        return allPacksOK
    }
    
    private func checkPack(_ productID: StoreManager.ProductID) async -> Bool {
        let context = coreData.mainContext
        let request = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        request.predicate = NSPredicate(format: "packID == %@", productID.rawValue)
        
        let actualCount = (try? context.count(for: request)) ?? 0
        let expectedCount = expectedQuoteCounts[productID] ?? 0
        
        print("📦 \(productID.displayName): \(actualCount)/\(expectedCount)")
        
        // Allow for some variance in case quotes are updated
        let tolerance = 5
        let isOK = actualCount >= (expectedCount - tolerance)
        
        if !isOK {
            print("  ⚠️ Pack needs reloading (missing \(expectedCount - actualCount) quotes)")
            
            // Clear the false "loaded" flag
            let key = "pack_loaded_\(productID.rawValue)"
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            print("  ✅ Pack loaded correctly")
        }
        
        return isOK
    }
    
    // MARK: - Load Missing Packs
    
    private func loadMissingPacks() async {
        print("\n🔄 Loading missing packs...")
        
        for productID in packsNeedingLoad {
            print("  Loading \(productID.displayName)...")
            
            // Clear any existing incomplete data for this pack
            await clearPackData(productID)
            
            // Load the pack fresh
            await LocalQuoteManager.shared.loadQuotePack(productID)
            
            // Verify it loaded correctly
            let packOK = await checkPack(productID)
            if packOK {
                print("  ✅ \(productID.displayName) loaded successfully")
            } else {
                print("  ❌ \(productID.displayName) failed to load properly")
            }
        }
    }
    
    // MARK: - Clear Pack Data
    
    private func clearPackData(_ productID: StoreManager.ProductID) async {
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
                        print("  Cleared \(quotes.count) incomplete quotes from \(productID.displayName)")
                    }
                } catch {
                    print("  ❌ Error clearing pack data: \(error)")
                }
                
                continuation.resume()
            }
        }
    }
    
    // MARK: - Cleanup Orphaned Flags
    
    private func cleanupOrphanedFlags() {
        print("\n🧹 Cleaning up orphaned flags...")
        
        // Remove "loaded" flags for unpurchased packs
        for productID in StoreManager.ProductID.allCases {
            let key = "pack_loaded_\(productID.rawValue)"
            
            if !StoreManager.shared.isPackPurchased(productID) {
                if UserDefaults.standard.bool(forKey: key) {
                    UserDefaults.standard.removeObject(forKey: key)
                    print("  Removed orphaned flag for \(productID.displayName)")
                }
            }
        }
    }
    
    // MARK: - Final Verification
    
    private func verifyFinalState() async -> Bool {
        let context = coreData.mainContext
        
        // Count total quotes
        let totalRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        let totalCount = (try? context.count(for: totalRequest)) ?? 0
        
        // Calculate expected total
        var expectedTotal = expectedFreeQuoteCount
        for productID in StoreManager.ProductID.allCases {
            if StoreManager.shared.isPackPurchased(productID) {
                expectedTotal += expectedQuoteCounts[productID] ?? 0
            }
        }
        
        print("\n📊 Final State:")
        print("  Total quotes in database: \(totalCount)")
        print("  Expected total: \(expectedTotal)")
        
        // Update LocalQuoteManager's count
        await MainActor.run {
            LocalQuoteManager.shared.quotesCount = totalCount
        }
        
        return totalCount >= (expectedTotal - 10) // Allow small tolerance
    }
    
    // MARK: - Quick Status Check
    
    /// Quick check without loading - just returns status
    func quickStatusCheck() -> (total: Int, missing: [StoreManager.ProductID]) {
        let context = coreData.mainContext
        var missingPacks: [StoreManager.ProductID] = []
        
        // Check each purchased pack
        for productID in StoreManager.ProductID.allCases {
            if StoreManager.shared.isPackPurchased(productID) {
                let request = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
                request.predicate = NSPredicate(format: "packID == %@", productID.rawValue)
                
                let count = (try? context.count(for: request)) ?? 0
                let expected = expectedQuoteCounts[productID] ?? 0
                
                if count < (expected - 5) {
                    missingPacks.append(productID)
                }
            }
        }
        
        // Total count
        let totalRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        let total = (try? context.count(for: totalRequest)) ?? 0
        
        return (total, missingPacks)
    }
}

// MARK: - Integration with App Lifecycle

extension QuoteCheck {
    
    /// Call this from AppDelegate or main App struct
    static func performStartupCheck() async {
        await QuoteCheck.shared.performLaunchCheck()
    }
    
    /// Call this after any purchase
    static func checkAfterPurchase(_ productID: StoreManager.ProductID) async {
        let packOK = await QuoteCheck.shared.checkPack(productID)
        if !packOK {
            await QuoteCheck.shared.loadMissingPacks()
        }
    }
    
    /// Call this if user reports missing content
    static func performManualCheck() async {
        await QuoteCheck.shared.performLaunchCheck()
    }
}

// MARK: - Debug Commands

#if DEBUG
extension QuoteCheck {
    
    /// Print detailed database state for debugging
    func printDatabaseState() {
        print("\n🔍 ========== DATABASE STATE ==========")
        
        let context = coreData.mainContext
        
        // Free quotes
        let freeRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        freeRequest.predicate = NSPredicate(format: "isFromPack == NO OR isFromPack == NULL")
        let freeCount = (try? context.count(for: freeRequest)) ?? 0
        print("Free Quotes: \(freeCount)")
        
        // Each pack
        for productID in StoreManager.ProductID.allCases {
            let packRequest = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
            packRequest.predicate = NSPredicate(format: "packID == %@", productID.rawValue)
            let packCount = (try? context.count(for: packRequest)) ?? 0
            
            let isPurchased = StoreManager.shared.isPackPurchased(productID)
            let key = "pack_loaded_\(productID.rawValue)"
            let hasFlag = UserDefaults.standard.bool(forKey: key)
            
            print("\n\(productID.displayName):")
            print("  Purchased: \(isPurchased)")
            print("  UserDefaults Flag: \(hasFlag)")
            print("  Quotes in DB: \(packCount)")
            print("  Expected: \(expectedQuoteCounts[productID] ?? 0)")
        }
        
        print("=====================================\n")
    }
}
#endif
