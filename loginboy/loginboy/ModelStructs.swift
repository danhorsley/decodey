import Foundation

// MARK: - Model Structs
// Plain Swift structs used for business logic and UI

// Quote model
struct QuoteModel {
    let text: String
    let author: String
    let attribution: String?
    let difficulty: Double? // Optional - just for future analytics
}

// Daily quote model
struct DailyQuoteModel: Codable {
    let id: Int
    let text: String
    let author: String
    let minor_attribution: String?
    let difficulty: Double
    let date: String
    let unique_letters: Int
    
    // Computed property for formatted date
    var formattedDate: String {
        if let date = ISO8601DateFormatter().date(from: date) {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            return formatter.string(from: date)
        }
        return date
    }
}

// Game model
struct GameModel {
    // Game state
    var encrypted: String = ""
    var solution: String = ""
    var currentDisplay: String = ""
    var selectedLetter: Character? = nil
    var mistakes: Int = 0
    var maxMistakes: Int = 5
    var hasWon: Bool = false
    var hasLost: Bool = false
    
    // Game ID for db ref
    var gameId: String? = nil
    
    // Mapping dictionaries
    var mapping: [Character:Character] = [:]
    var correctMappings: [Character:Character] = [:]
    var letterFrequency: [Character:Int] = [:]
    var guessedMappings: [Character:Character] = [:]
    
    // Timestamp tracking
    var startTime: Date = Date()
    var lastUpdateTime: Date = Date()
    
    // Difficulty level
    var difficulty: String = "medium"
    
    // Clean initializer that takes a quote
    init(quote: QuoteModel) {
        self.solution = quote.text.uppercased()
        // Default difficulty to medium - will be overridden by settings
        self.difficulty = "medium"
        // Default max mistakes - will be overridden by settings
        self.maxMistakes = 5
        setupEncryption()
    }
    
    // For loading from Core Data
    init(gameId: String, encrypted: String, solution: String, currentDisplay: String,
         mapping: [Character:Character], correctMappings: [Character:Character],
         guessedMappings: [Character:Character], mistakes: Int, maxMistakes: Int,
         hasWon: Bool, hasLost: Bool, difficulty: String, startTime: Date, lastUpdateTime: Date) {
        
        self.gameId = gameId
        self.encrypted = encrypted
        self.solution = solution
        self.currentDisplay = currentDisplay
        self.mistakes = mistakes
        self.maxMistakes = maxMistakes
        self.hasWon = hasWon
        self.hasLost = hasLost
        self.mapping = mapping
        self.correctMappings = correctMappings
        self.guessedMappings = guessedMappings
        self.startTime = startTime
        self.lastUpdateTime = lastUpdateTime
        self.difficulty = difficulty
        
        // Calculate letter frequency from encrypted text
        for char in encrypted where char.isLetter {
            letterFrequency[char, default: 0] += 1
        }
    }
    
    // Setup encryption for current solution (unchanged)
    private mutating func setupEncryption() {
        // Create mapping
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let shuffled = alphabet.shuffled()
        
        // Create mappings
        for i in 0..<alphabet.count {
            mapping[alphabet[i]] = shuffled[i]
        }
        correctMappings = Dictionary(uniqueKeysWithValues: mapping.map { ($1, $0) })
        
        // Encrypt solution
        encrypted = solution.map { char in
            if char.isLetter {
                return String(mapping[char] ?? char)
            }
            return String(char)
        }.joined()
        
        // Initialize display with blocks
        currentDisplay = solution.map { char in
            if char.isLetter {
                return "█"
            }
            return String(char)
        }.joined()
        
        // Calculate letter frequency
        letterFrequency = [:]
        for char in encrypted where char.isLetter {
            letterFrequency[char, default: 0] += 1
        }
    }
    
    // Game logic methods - basic functionality unchanged
    mutating func selectLetter(_ letter: Character) {
        if correctlyGuessed().contains(letter) {
            selectedLetter = nil
            return
        }
        selectedLetter = letter
    }
    
    mutating func makeGuess(_ guessedLetter: Character) -> Bool {
        guard let selected = selectedLetter else { return false }
        
        let isCorrect = correctMappings[selected] == guessedLetter
        if isCorrect {
            guessedMappings[selected] = guessedLetter
            updateDisplay()
            checkWinCondition()
        } else {
            mistakes += 1
            if mistakes >= maxMistakes {
                hasLost = true
            }
        }
        
        selectedLetter = nil
        lastUpdateTime = Date()
        return isCorrect
    }
    
    // Helper methods
    mutating func updateDisplay() {
        var displayChars = Array(currentDisplay)
        
        for i in 0..<encrypted.count {
            let encryptedChar = Array(encrypted)[i]
            if let guessedChar = guessedMappings[encryptedChar] {
                displayChars[i] = guessedChar
            }
        }
        currentDisplay = String(displayChars)
    }
    
    mutating func checkWinCondition() {
        let uniqueEncryptedLetters = Set(encrypted.filter { $0.isLetter })
        let guessedLetters = Set(guessedMappings.keys)
        hasWon = uniqueEncryptedLetters == guessedLetters
    }
    
    func correctlyGuessed() -> [Character] {
        return Array(guessedMappings.keys)
    }
    
    func uniqueEncryptedLetters() -> [Character] {
        return Array(Set(encrypted.filter { $0.isLetter })).sorted()
    }
    
    func uniqueSolutionLetters() -> [Character] {
        return Array(Set(solution.filter { $0.isLetter })).sorted()
    }
    
    mutating func getHint() -> Bool {
        let unguessedLetters = Set(encrypted.filter { $0.isLetter && !correctlyGuessed().contains($0) })
        if unguessedLetters.isEmpty { return false }
        
        if let hintLetter = unguessedLetters.randomElement(),
           let originalLetter = correctMappings[hintLetter] {
            // Add hint to guessed mappings
            guessedMappings[hintLetter] = originalLetter
            
            // Update the display to show the letter
            updateDisplay()
            
            // Increment the mistakes counter to track hint usage
            mistakes += 1
            
            // Check if the game is won after this hint
            checkWinCondition()
            
            // Check if we've reached the maximum mistakes
            if mistakes >= maxMistakes {
                hasLost = true
            }
            
            // Track last update time
            lastUpdateTime = Date()
            
            return true
        }
        return false
    }
    
    func calculateScore() -> Int {
        let timeInSeconds = Int(lastUpdateTime.timeIntervalSince(startTime))
        
        // Base score by difficulty
        let baseScore: Int
        switch difficulty.lowercased() {
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
        let mistakePenalty = mistakes * 20
        
        // Total (never negative)
        return max(0, baseScore - mistakePenalty + timeScore)
    }
}

// User profile model
struct UserModel {
    let userId: String
    let username: String
    let email: String
    let displayName: String?
    let avatarUrl: String?
    let bio: String?
    let registrationDate: Date
    let lastLoginDate: Date
    let isActive: Bool
    let isVerified: Bool
    let isSubadmin: Bool
}

// User preferences model
struct UserPreferencesModel {
    var darkMode: Bool = true
    var showTextHelpers: Bool = true
    var accessibilityTextSize: Bool = false
    var gameDifficulty: String = "medium"
    var soundEnabled: Bool = true
    var soundVolume: Float = 0.5
    var useBiometricAuth: Bool = false
    var notificationsEnabled: Bool = true
    var lastSyncDate: Date? = nil
}

// User stats model
struct UserStatsModel {
    let userId: String
    let gamesPlayed: Int
    let gamesWon: Int
    let currentStreak: Int
    let bestStreak: Int
    let totalScore: Int
    let averageScore: Double
    let averageTime: Double // in seconds
    let lastPlayedDate: Date?
    
    var winPercentage: Double {
        return gamesPlayed > 0 ? Double(gamesWon) / Double(gamesPlayed) * 100 : 0
    }
}

// Leaderboard entry model
struct LeaderboardEntryModel: Identifiable {
    let rank: Int
    let username: String
    let userId: String
    let score: Int
    let gamesPlayed: Int
    let avgScore: Double
    let isCurrentUser: Bool
    
    var id: String { userId }
}

//
//  ModelStructs.swift
//  loginboy
//
//  Created by Daniel Horsley on 19/05/2025.
//

