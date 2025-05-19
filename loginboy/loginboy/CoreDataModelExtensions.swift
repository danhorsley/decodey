import Foundation
import CoreData
import SwiftUI

// MARK: - Core Data Extensions for GameScoreModel
extension GameCD {
    
    // MARK: - Computed properties for mappings
    
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
    var gameId: String? {
        get {
            return value(forKey: "gameId") as? String
        }
        set {
            setValue(newValue, forKey: "gameId")
        }
    }
    
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
    
    /// Converts to a GameData struct for use in business logic
    func toData() -> GameData {
        // Deserialize mappings
        var mapping: [Character: Character] = [:]
        var correctMappings: [Character: Character] = [:]
        var guessedMappings: [Character: Character] = [:]
        
        if let mappingData = self.mappingData,
           let mappingDict = try? JSONDecoder().decode([String: String].self, from: mappingData) {
            mapping = mappingDict.convertToCharacterDictionary()
        }
        
        if let correctMappingsData = self.correctMappingsData,
           let correctDict = try? JSONDecoder().decode([String: String].self, from: correctMappingsData) {
            correctMappings = correctDict.convertToCharacterDictionary()
        }
        
        if let guessedMappingsData = self.guessedMappingsData,
           let guessedDict = try? JSONDecoder().decode([String: String].self, from: guessedMappingsData) {
            guessedMappings = guessedDict.convertToCharacterDictionary()
        }
        
        return GameData(
            gameId: self.gameId,
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
}

// MARK: - QuoteModel Extensions
extension QuoteCD {
    /// Converts to a QuoteData struct for use in business logic
    func toData() -> QuoteData {
        return QuoteData(
            text: text ?? "",
            author: author ?? "",
            attribution: attribution,
            difficulty: difficulty
        )
    }
}

// MARK: - Helper Extensions

extension Dictionary where Key == Character, Value == Character {
    func mapToDictionary() -> [String: String] {
        var result = [String: String]()
        for (key, value) in self {
            result[String(key)] = String(value)
        }
        return result
    }
}

extension Dictionary where Key == String, Value == String {
    func convertToCharacterDictionary() -> [Character: Character] {
        var result = [Character: Character]()
        for (key, value) in self {
            if let keyChar = key.first, let valueChar = value.first {
                result[keyChar] = valueChar
            }
        }
        return result
    }
}

// MARK: - NSFetchRequest Extensions
extension NSFetchRequest where ResultType == GameScoreModel {
    static func fetchRequest() -> NSFetchRequest<GameScoreModel> {
        return NSFetchRequest<GameScoreModel>(entityName: "GameScoreModel")
    }
}

extension NSFetchRequest where ResultType == QuoteModel {
    static func fetchRequest() -> NSFetchRequest<QuoteModel> {
        return NSFetchRequest<QuoteModel>(entityName: "QuoteModel")
    }
}

extension NSFetchRequest where ResultType == UserModel {
    static func fetchRequest() -> NSFetchRequest<UserModel> {
        return NSFetchRequest<UserModel>(entityName: "UserModel")
    }
}

extension NSFetchRequest where ResultType == UserStatsModel {
    static func fetchRequest() -> NSFetchRequest<UserStatsModel> {
        return NSFetchRequest<UserStatsModel>(entityName: "UserStatsModel")
    }
}

extension NSFetchRequest where ResultType == UserPreferencesModel {
    static func fetchRequest() -> NSFetchRequest<UserPreferencesModel> {
        return NSFetchRequest<UserPreferencesModel>(entityName: "UserPreferencesModel")
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
