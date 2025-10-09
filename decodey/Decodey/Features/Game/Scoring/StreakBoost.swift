import Foundation
import CoreData

/// Manages daily streak bonuses for scoring
class StreakBoost {
    static let shared = StreakBoost()
    
    private let coreData = CoreDataStack.shared
    private let maxStreakDays = 20
    private let boostPerDay: Double = 0.05 // 5% per day
    private let maxBoostMultiplier: Double = 2.0 // 100% boost (2x multiplier)
    
    private init() {}
    
    /// Calculate the current daily streak by checking consecutive daily wins
    func calculateDailyStreak() -> Int {
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
        
        // Get all completed daily games, sorted by date descending
        fetchRequest.predicate = NSPredicate(format: "isDaily == YES AND hasWon == YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastUpdateTime", ascending: false)]
        
        do {
            let dailyWins = try context.fetch(fetchRequest)
            guard !dailyWins.isEmpty else { return 0 }
            
            var streak = 0
            let calendar = Calendar.current
            var expectedDate = Date() // Start from today
            
            for game in dailyWins {
                guard let completedDate = game.lastUpdateTime else { continue }
                
                // Check if this game was completed on the expected date
                if calendar.isDate(completedDate, inSameDayAs: expectedDate) {
                    streak += 1
                    // Move to previous day
                    expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? Date()
                } else if calendar.compare(completedDate, to: expectedDate, toGranularity: .day) == .orderedAscending {
                    // This game is from an earlier date, streak is broken
                    break
                }
                // If game is from a future date (shouldn't happen), skip it
            }
            
            return streak
            
        } catch {
            print("❌ Error calculating daily streak: \(error)")
            return 0
        }
    }
    
    /// Get the current boost multiplier (1.0 = no boost, 2.0 = 100% boost)
    func getCurrentBoostMultiplier() -> Double {
        let streak = calculateDailyStreak()
        let multiplier = 1.0 + (Double(min(streak, maxStreakDays)) * boostPerDay)
        return min(multiplier, maxBoostMultiplier)
    }
    
    /// Get the boost percentage for display (0-100)
    func getCurrentBoostPercentage() -> Int {
        let multiplier = getCurrentBoostMultiplier()
        return Int((multiplier - 1.0) * 100)
    }
    
    /// Apply streak boost to a base score
    func applyBoost(to baseScore: Int) -> Int {
        let multiplier = getCurrentBoostMultiplier()
        return Int(Double(baseScore) * multiplier)
    }
    
    /// Get formatted boost text for display
    func getBoostDisplayText() -> String? {
        let streak = calculateDailyStreak()
        guard streak > 0 else { return nil }
        
        let percentage = getCurrentBoostPercentage()
        if streak >= maxStreakDays {
            return "+\(percentage)% MAX STREAK!"
        } else {
            return "+\(percentage)% (\(streak) day streak)"
        }
    }
    
    /// Quick check using UserDefaults (faster but less reliable)
    func quickStreakCheck() -> Int {
        var streak = 0
        let calendar = Calendar.current
        var checkDate = Date()
        
        for _ in 0..<30 { // Check up to 30 days back
            let dateString = DateFormatter.yyyyMMdd.string(from: checkDate)
            let key = "daily_completed_\(dateString)"
            
            if UserDefaults.standard.bool(forKey: key) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? Date()
            } else {
                break
            }
        }
        
        return streak
    }
}
