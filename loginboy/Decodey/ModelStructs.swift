//
//  ModelStructs.swift - CONSOLIDATED CLEAN VERSION
//  loginboy
//
//  All model structs in one place for clean architecture
//

import Foundation

// MARK: - Quote Models

/// Local quote model for offline gameplay
struct LocalQuoteModel {
    let text: String
    let author: String
    let attribution: String?
    let difficulty: Double
    let category: String
    
    init(text: String, author: String, attribution: String? = nil, difficulty: Double = 2.0, category: String = "classic") {
        self.text = text
        self.author = author
        self.attribution = attribution
        self.difficulty = difficulty
        self.category = category
    }
}

/// Legacy quote model (for backward compatibility)
struct QuoteModel {
    let text: String
    let author: String
    let attribution: String?
    let difficulty: Double?
    
    init(text: String, author: String, attribution: String? = nil, difficulty: Double? = nil) {
        self.text = text
        self.author = author
        self.attribution = attribution
        self.difficulty = difficulty
    }
}

/// Daily quote model for JSON parsing
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

// MARK: - Game Model

/// Main game model containing all game state
struct GameModel {
    // Basic game state
    var encrypted: String = ""
    var solution: String = ""
    var currentDisplay: String = ""
    var selectedLetter: Character? = nil
    var mistakes: Int = 0
    var maxMistakes: Int = 5
    var hasWon: Bool = false
    var hasLost: Bool = false
    
    // Game ID for database reference
    var gameId: String?
    
    // Mapping dictionaries
    var mapping: [Character:Character] = [:]
    var correctMappings: [Character:Character] = [:]
    var letterFrequency: [Character:Int] = [:]
    var guessedMappings: [Character:Character] = [:]
    var incorrectGuesses: [Character: Set<Character>] = [:]
    
    // Timestamp tracking
    var startTime: Date = Date()
    var lastUpdateTime: Date = Date()
    
    // Difficulty level
    var difficulty: String = "medium"
    
    // MARK: - Initializers
    
    /// Full initializer (used by Core Data conversion)
    init(gameId: String?, encrypted: String, solution: String, currentDisplay: String,
         mapping: [Character:Character], correctMappings: [Character:Character],
         guessedMappings: [Character:Character], incorrectGuesses: [Character: Set<Character>] = [:],
         mistakes: Int, maxMistakes: Int,
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
        self.incorrectGuesses = incorrectGuesses
        self.startTime = startTime
        self.lastUpdateTime = lastUpdateTime
        self.difficulty = difficulty
        
        // Calculate letter frequency from encrypted text
        self.letterFrequency = [:]
        for char in encrypted where char.isLetter {
            letterFrequency[char, default: 0] += 1
        }
    }
    
    // MARK: - Game Setup
    
    /// Setup encryption for the solution
    mutating func setupEncryption() {
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
            } else {
                return String(char)
            }
        }.joined()
        
        // Calculate letter frequencies
        letterFrequency = [:]
        for char in encrypted where char.isLetter {
            letterFrequency[char, default: 0] += 1
        }
        
        // Initialize current display
        updateCurrentDisplay()
    }
    
    /// Update the current display based on guessed mappings
    mutating func updateCurrentDisplay() {
        currentDisplay = encrypted.map { char in
            if char.isLetter {
                if let decrypted = guessedMappings[char] {
                    return String(decrypted)
                } else {
                    return String(char)
                }
            } else {
                return String(char)
            }
        }.joined()
    }
    
    // MARK: - Game Logic Methods
    
    /// Select a letter for guessing
    mutating func selectLetter(_ letter: Character) {
        if isLetterGuessed(letter) {
            selectedLetter = nil
            return
        }
        selectedLetter = letter
    }
    
    /// Make a guess for the selected letter
    mutating func makeGuess(_ guessedLetter: Character) -> Bool {
        guard let selected = selectedLetter else { return false }
        
        let isCorrect = correctMappings[selected] == guessedLetter
        if isCorrect {
            guessedMappings[selected] = guessedLetter
            updateCurrentDisplay()
            checkWinCondition()
        } else {
            // Track incorrect guess
            if incorrectGuesses[selected] == nil {
                incorrectGuesses[selected] = Set<Character>()
            }
            incorrectGuesses[selected]?.insert(guessedLetter)
            
            mistakes += 1
            if mistakes >= maxMistakes {
                hasLost = true
            }
        }
        
        selectedLetter = nil
        lastUpdateTime = Date()
        return isCorrect
    }
    
    /// Get a hint by revealing a random unguessed letter
    mutating func getHint() -> Bool {
        let unguessedLetters = Set(encrypted.filter { $0.isLetter && !isLetterGuessed($0) })
        guard !unguessedLetters.isEmpty else { return false }
        
        if let hintLetter = unguessedLetters.randomElement(),
           let originalLetter = correctMappings[hintLetter] {
            // Add hint to guessed mappings
            guessedMappings[hintLetter] = originalLetter
            
            // Update display and check win condition
            updateCurrentDisplay()
            checkWinCondition()
            
            // This counts as a mistake (hints have a cost)
            mistakes += 1
            if mistakes >= maxMistakes {
                hasLost = true
            }
            
            lastUpdateTime = Date()
            return true
        }
        
        return false
    }
    
    /// Check if the game is won (all letters guessed)
    private mutating func checkWinCondition() {
        let uniqueEncryptedLetters = Set(encrypted.filter { $0.isLetter })
        let guessedLetters = Set(guessedMappings.keys)
        hasWon = uniqueEncryptedLetters == guessedLetters
    }
    
    // MARK: - Helper Methods for UI
    
    /// Check if a letter has been revealed
    func isLetterGuessed(_ encryptedLetter: Character) -> Bool {
        return guessedMappings[encryptedLetter] != nil
    }
    
    /// Get the frequency of an encrypted letter
    func getLetterFrequency(_ letter: Character) -> Int {
        return letterFrequency[letter] ?? 0
    }
    
    /// Get array of unique encrypted letters in order of appearance
    func getUniqueEncryptedLetters() -> [Character] {
        var seen = Set<Character>()
        var result: [Character] = []
        
        for char in encrypted {
            if char.isLetter && !seen.contains(char) {
                seen.insert(char)
                result.append(char)
            }
        }
        
        return result
    }
    
    /// Get array of unique solution letters sorted alphabetically
    func getUniqueSolutionLetters() -> [Character] {
        return Array(Set(solution.filter { $0.isLetter })).sorted()
    }
    
    /// Get array of correctly guessed encrypted letters
    func getCorrectlyGuessed() -> [Character] {
        return Array(guessedMappings.keys)
    }
    
    /// Get completion percentage
    func getCompletionPercentage() -> Double {
        let totalLetters = Set(encrypted.filter { $0.isLetter }).count
        let solvedLetters = guessedMappings.count
        
        return totalLetters > 0 ? Double(solvedLetters) / Double(totalLetters) : 0.0
    }
    
    /// Calculate time spent in seconds
    func getTimeSpentSeconds() -> Int {
        return max(1, Int(lastUpdateTime.timeIntervalSince(startTime)))
    }
    
    /// Calculate score
    func calculateScore() -> Int {
        guard hasWon else { return 0 }
        
        let timeInSeconds = getTimeSpentSeconds()
        
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

// MARK: - Quote Bundle Models (for JSON loading)

/// Quote pack data structure for JSON
struct QuotePackData: Codable {
    let quotes: [QuoteBundleItem]
    let version: String
    let description: String
}

/// Individual quote item from JSON bundle
struct QuoteBundleItem: Codable {
    let text: String
    let author: String
    let attribution: String?
    let difficulty: String
    let category: String
}
