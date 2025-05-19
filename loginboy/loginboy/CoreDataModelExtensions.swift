import Foundation
import CoreData
import SwiftUI

// MARK: - Core Data Extensions for GameCD
extension GameCD {
    
    // MARK: - Computed properties for mappings
    var gameIdString: String? {
            get {
                return gameId?.uuidString
            }
        }
    /// Mapping data stored as binary
    var mappingData: Data? {
        get { return mapping }
        set { mapping = newValue }
    }
    
    /// Correct mappings data stored as binary
    var correctMappingsData: Data? {
        get { return correctMappings }
        set { correctMappings = newValue }
    }
    
    /// Guessed mappings data stored as binary
    var guessedMappingsData: Data? {
        get { return guessedMappings }
        set { guessedMappings = newValue }
    }
    
    /// Gets the game ID (safe unwrapping)
//    var gameId: String? {
//        get {
//            // You need to define a "gameId" attribute in your Core Data model
//            return value(forKey: "gameId") as? String
//        }
//        set {
//            setValue(newValue, forKey: "gameId")
//        }
//    }
    
    /// Convenience function to calculate letter frequency
    func calculateLetterFrequency() -> [Character: Int] {
        guard let encrypted = self.encrypted else { return [:] }
        
        var frequency: [Character: Int] = [:]
        for char in encrypted where char.isLetter {
            frequency[char, default: 0] += 1
        }
        return frequency
    }
    
    /// Calculate score based on game state
    func calculateScore() -> Int {
        guard let startTime = self.startTime, let lastUpdateTime = self.lastUpdateTime else { return 0 }
        
        let timeInSeconds = Int(lastUpdateTime.timeIntervalSince(startTime))
        
        // Base score by difficulty
        let baseScore: Int
        switch difficulty?.lowercased() ?? "medium" {
        case "easy": baseScore = 100
        case "hard": baseScore = 300
        default: baseScore = 200
        }
        
        // Time bonus/penalty
        let timeScore: Int
        if timeInSeconds < 60 { timeScore = 50 }
        else if timeInSeconds < 180 { timeScore = 30 }
        else if timeInSeconds < 300 { timeScore = 10 }
        else if timeInSeconds > 600 { timeScore = -20 }
        else { timeScore = 0 }
        
        // Mistake penalty
        let mistakePenalty = Int(mistakes) * 20
        
        // Total (never negative)
        return max(0, baseScore - mistakePenalty + timeScore)
    }
    
    // MARK: - Helper methods
    
    /// Converts to a GameModel struct for use in business logic
    func toModel() -> GameModel {
        // Deserialize mappings
        var mapping: [Character: Character] = [:]
        var correctMappings: [Character: Character] = [:]
        var guessedMappings: [Character: Character] = [:]
        
        if let mappingData = self.mappingData,
           let mappingDict = try? JSONDecoder().decode([String: String].self, from: mappingData) {
            mapping = dictionaryToCharacterMapping(mappingDict)
        }
        
        if let correctMappingsData = self.correctMappingsData,
           let correctDict = try? JSONDecoder().decode([String: String].self, from: correctMappingsData) {
            correctMappings = dictionaryToCharacterMapping(correctDict)
        }
        
        if let guessedMappingsData = self.guessedMappingsData,
           let guessedDict = try? JSONDecoder().decode([String: String].self, from: guessedMappingsData) {
            guessedMappings = dictionaryToCharacterMapping(guessedDict)
        }
        
        return GameModel(
            gameId: self.gameId?.uuidString ?? "", // Convert UUID to string
            encrypted: self.encrypted ?? "",
            solution: self.solution ?? "",
            currentDisplay: self.currentDisplay ?? "",
            mapping: mapping,
            correctMappings: correctMappings,
            guessedMappings: guessedMappings,
            mistakes: Int(self.mistakes),
            maxMistakes: Int(self.maxMistakes),
            hasWon: self.hasWon,
            hasLost: self.hasLost,
            difficulty: self.difficulty ?? "medium",
            startTime: self.startTime ?? Date(),
            lastUpdateTime: self.lastUpdateTime ?? Date()
        )
    }
    
    // Helper to convert dictionary to character mapping
    private func dictionaryToCharacterMapping(_ dict: [String: String]) -> [Character: Character] {
        var result = [Character: Character]()
        for (key, value) in dict {
            if let keyChar = key.first, let valueChar = value.first {
                result[keyChar] = valueChar
            }
        }
        return result
    }
}

// MARK: - QuoteCD Extensions
extension QuoteCD {
    /// Converts to a QuoteModel struct for use in business logic
    func toModel() -> QuoteModel {
        return QuoteModel(
            text: text ?? "",
            author: author ?? "",
            attribution: attribution,
            difficulty: difficulty
        )
    }
}

// MARK: - NSFetchRequest Extensions
extension NSFetchRequest where ResultType == GameCD {
    static func fetchRequest() -> NSFetchRequest<GameCD> {
        return NSFetchRequest<GameCD>(entityName: "GameCD")
    }
}

extension NSFetchRequest where ResultType == QuoteCD {
    static func fetchRequest() -> NSFetchRequest<QuoteCD> {
        return NSFetchRequest<QuoteCD>(entityName: "QuoteCD")
    }
}

extension NSFetchRequest where ResultType == UserCD {
    static func fetchRequest() -> NSFetchRequest<UserCD> {
        return NSFetchRequest<UserCD>(entityName: "UserCD")
    }
}

extension NSFetchRequest where ResultType == UserStatsCD {
    static func fetchRequest() -> NSFetchRequest<UserStatsCD> {
        return NSFetchRequest<UserStatsCD>(entityName: "UserStatsCD")
    }
}

extension NSFetchRequest where ResultType == UserPreferencesCD {
    static func fetchRequest() -> NSFetchRequest<UserPreferencesCD> {
        return NSFetchRequest<UserPreferencesCD>(entityName: "UserPreferencesCD")
    }
}

extension NSManagedObjectContext {
    /// Safely fetch with error handling
    func safeFetch<T>(_ request: NSFetchRequest<T>) -> [T] {
        do {
            return try fetch(request)
        } catch {
            print("❌ Error fetching \(T.self): \(error)")
            return []
        }
    }
    
    /// Safely save with error handling
    func safeSave() -> Bool {
        do {
            if hasChanges {
                try save()
                return true
            }
            return true
        } catch {
            print("❌ Error saving context: \(error)")
            return false
        }
    }
}
