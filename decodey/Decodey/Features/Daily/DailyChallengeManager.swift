// DailyChallengeManager.swift
// Manages daily challenges with consistent seeding for all players

import Foundation
import CoreData

class DailyChallengeManager {
    static let shared = DailyChallengeManager()
    
    // MARK: - App Launch Configuration
    // 🚨 CHANGE THIS TO YOUR ACTUAL LAUNCH DATE BEFORE RELEASE
    // This ensures everyone gets the same sequence of dailies starting from launch
    private let APP_LAUNCH_DATE = "2024-12-17"  // Today's date for testing
    // private let APP_LAUNCH_DATE = "2025-02-01"  // Example: Change to your actual launch date
    
    // MARK: - Properties
    private let coreData = CoreDataStack.shared
    private var cachedDailyQuote: (date: String, quote: LocalQuoteModel)?
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Get today's daily challenge quote
    func getTodaysDailyQuote() -> LocalQuoteModel? {
        let todayString = getCurrentDateString()
        
        // Check cache first
        if let cached = cachedDailyQuote, cached.date == todayString {
            print("📅 Using cached daily for \(todayString)")
            return cached.quote
        }
        
        // Calculate the day index
        let dayIndex = getDayIndex()
        print("📅 Daily Challenge - Date: \(todayString), Day Index: \(dayIndex)")
        
        // Get the quote for this day
        if let quote = getQuoteForDayIndex(dayIndex) {
            // Cache it
            cachedDailyQuote = (todayString, quote)
            return quote
        }
        
        return nil
    }
    
    /// Get the daily challenge for a specific date (for history/archive feature)
    func getDailyQuote(for date: Date) -> LocalQuoteModel? {
        let dayIndex = getDayIndex(for: date)
        return getQuoteForDayIndex(dayIndex)
    }
    
    /// Check if user has completed today's daily
    func hasCompletedToday() -> Bool {
        let todayString = getCurrentDateString()
        return UserDefaults.standard.bool(forKey: "daily_completed_\(todayString)")
    }
    
    /// Mark today's daily as completed
    func markTodayCompleted() {
        let todayString = getCurrentDateString()
        UserDefaults.standard.set(true, forKey: "daily_completed_\(todayString)")
        
        // Also track streak
        updateStreak()
    }
    
    /// Get current daily streak
    func getCurrentStreak() -> Int {
        return UserDefaults.standard.integer(forKey: "daily_streak")
    }
    
    // MARK: - Private Methods
    
    /// Calculate days since launch (this determines which quote to use)
    private func getDayIndex(for date: Date = Date()) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let launchDate = formatter.date(from: APP_LAUNCH_DATE) else {
            print("❌ Invalid launch date format")
            return 0
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: launchDate, to: date)
        
        // Return absolute value to handle pre-launch testing
        return abs(components.day ?? 0)
    }
    
    /// Get quote for a specific day index
    private func getQuoteForDayIndex(_ dayIndex: Int) -> LocalQuoteModel? {
        let context = coreData.mainContext
        let request = NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
        
        // Only use active quotes for daily challenges
        request.predicate = NSPredicate(format: "isActive == YES")
        
        // Sort consistently so everyone gets the same order
        request.sortDescriptors = [
            NSSortDescriptor(key: "text", ascending: true)  // Alphabetical by text
        ]
        
        do {
            let quotes = try context.fetch(request)
            guard !quotes.isEmpty else {
                print("❌ No quotes available for daily challenge")
                return nil
            }
            
            // Use modulo to cycle through quotes
            let quoteIndex = dayIndex % quotes.count
            let selectedQuote = quotes[quoteIndex]
            
            print("📅 Selected daily quote \(quoteIndex + 1) of \(quotes.count)")
            
            return LocalQuoteModel(
                text: selectedQuote.text ?? "",
                author: selectedQuote.author ?? "Unknown",
                attribution: selectedQuote.attribution,
                difficulty: selectedQuote.difficulty,
                category: "daily"
            )
            
        } catch {
            print("❌ Error fetching daily quote: \(error)")
            return nil
        }
    }
    
    /// Get current date as string
    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    /// Update daily streak
    private func updateStreak() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayString = DateFormatter.yyyyMMdd.string(from: yesterday)
        
        if UserDefaults.standard.bool(forKey: "daily_completed_\(yesterdayString)") {
            // Continuing streak
            let currentStreak = UserDefaults.standard.integer(forKey: "daily_streak")
            UserDefaults.standard.set(currentStreak + 1, forKey: "daily_streak")
        } else {
            // Starting new streak
            UserDefaults.standard.set(1, forKey: "daily_streak")
        }
        
        // Update best streak
        let currentStreak = UserDefaults.standard.integer(forKey: "daily_streak")
        let bestStreak = UserDefaults.standard.integer(forKey: "daily_best_streak")
        if currentStreak > bestStreak {
            UserDefaults.standard.set(currentStreak, forKey: "daily_best_streak")
        }
    }
    
    // MARK: - Debug Helpers
    
    /// Preview the next N daily challenges (for testing)
    func previewUpcomingDailies(count: Int = 7) {
        #if DEBUG
        print("📅 Upcoming Daily Challenges:")
        for i in 0..<count {
            let date = Calendar.current.date(byAdding: .day, value: i, to: Date())!
            let dayIndex = getDayIndex(for: date)
            if let quote = getQuoteForDayIndex(dayIndex) {
                let dateString = DateFormatter.yyyyMMdd.string(from: date)
                print("  \(dateString) (Day \(dayIndex)): \"\(quote.text.prefix(30))...\" - \(quote.author)")
            }
        }
        #endif
    }
    
    /// Reset all daily progress (for testing)
    func resetDailyProgress() {
        #if DEBUG
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        cachedDailyQuote = nil
        print("🔄 Reset all daily progress")
        #endif
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}


