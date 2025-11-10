// GameModelExtensions.swift
// Decodey
//
// Extensions to GameModel and GameState for Time Pressure Mode

import Foundation
import SwiftUI


// MARK: - Extended Game Model for Time Pressure
struct TimePressureGameModel {
    let baseGame: GameModel
    var gameMode: GameMode = .timePressure
    
    // Timer properties
    var timeRemaining: Double = 8.0
    var nextRevealLetter: Character?
    var revealOrder: [Character] = []
    var autoRevealedLetters: Set<Character> = []
    var gatewayBonuses: Int = 0
    
    // Stats
    var currentStreak: Int = 0
    var totalTimeBonus: Double = 0
    var lettersRevealedByTimer: Int = 0
    var lettersGuessedCorrectly: Int = 0
    
    // Difficulty settings
    var baseInterval: Double {
        switch difficulty {
        case .easy:
            return 10.0
        case .medium:
            return 8.0
        case .hard:
            return 5.0
        }
    }
    
    var difficulty: TimePressureDifficulty = .medium
    
    enum TimePressureDifficulty {
        case easy, medium, hard
    }
}

// MARK: - GameState Extensions for Time Pressure
extension GameState {
    
    // Add these published properties to GameState
    func setupTimePressureMode() {
        // This would be added to your actual GameState class
        // @Published var gameMode: GameMode = .classic
        // @Published var timePressureModel: TimePressureGameModel?
    }
    
    func startTimePressureGame(difficulty: TimePressureGameModel.TimePressureDifficulty = .medium) {
        guard let game = currentGame else { return }
        
        // Create time pressure model
        var tpModel = TimePressureGameModel(baseGame: game)
        tpModel.difficulty = difficulty
        tpModel.revealOrder = generateSmartRevealOrder(for: game)
        
        // Store and start
        // self.timePressureModel = tpModel
        // startTimePressureTimer()
    }
    
    func generateSmartRevealOrder(for game: GameModel) -> [Character] {
        let encrypted = game.encrypted
        var letterFrequency: [Character: Int] = [:]
        var letterPositions: [Character: [Int]] = [:]
        
        // Analyze letter frequencies and positions
        for (index, char) in encrypted.enumerated() where char.isLetter {
            letterFrequency[char, default: 0] += 1
            letterPositions[char, default: []].append(index)
        }
        
        // Categorize letters into tiers
        var tier1_doubles: [Character] = []     // Double letters, common trigrams
        var tier2_highFreq: [Character] = []    // High frequency (3+ occurrences)
        var tier3_singles: [Character] = []     // Potential A, I (singles)
        var tier4_rare: [Character] = []        // Everything else
        
        // Check for common patterns
        let commonPatterns = detectCommonPatterns(in: encrypted)
        
        for (letter, freq) in letterFrequency {
            // Check if letter is part of common pattern
            let isInPattern = commonPatterns.contains { $0.contains(letter) }
            
            switch freq {
            case 4...:
                // Very high frequency - likely E, T, A
                if isInPattern {
                    tier1_doubles.append(letter)
                } else {
                    tier2_highFreq.append(letter)
                }
                
            case 2...3:
                // Medium frequency
                if isDouble(letter, in: encrypted) {
                    tier1_doubles.append(letter)
                } else {
                    tier2_highFreq.append(letter)
                }
                
            case 1:
                // Single occurrence - could be A or I
                if isSingleLetterWord(letter, in: encrypted) {
                    tier3_singles.append(letter)
                } else {
                    tier4_rare.append(letter)
                }
                
            default:
                tier4_rare.append(letter)
            }
        }
        
        // Build smart reveal order
        var revealOrder: [Character] = []
        
        // Tier 1: Start with doubles and common patterns
        revealOrder.append(contentsOf: tier1_doubles.shuffled())
        
        // Tier 2: High frequency letters
        revealOrder.append(contentsOf: tier2_highFreq.shuffled())
        
        // Tier 3: Insert singles (A, I) at 40% position
        let insertPosition = max(1, Int(Double(revealOrder.count) * 0.4))
        for single in tier3_singles.shuffled() {
            revealOrder.insert(single, at: min(insertPosition, revealOrder.count))
        }
        
        // Tier 4: Rare letters last
        revealOrder.append(contentsOf: tier4_rare.shuffled())
        
        return revealOrder
    }
    
    private func detectCommonPatterns(in text: String) -> [Set<Character>] {
        var patterns: [Set<Character>] = []
        let words = text.split(separator: " ")
        
        for word in words {
            // Check for THE
            if word.count == 3 {
                let chars = Set(word)
                if chars.count == 3 {
                    patterns.append(chars)
                }
            }
            
            // Check for double letters
            var prev: Character?
            for char in word {
                if char == prev {
                    patterns.append([char])
                }
                prev = char
            }
        }
        
        return patterns
    }
    
    private func isDouble(_ letter: Character, in text: String) -> Bool {
        // Check if letter appears as a double (LL, EE, etc.)
        var prev: Character?
        for char in text {
            if char == letter && prev == letter {
                return true
            }
            prev = char
        }
        return false
    }
    
    private func isSingleLetterWord(_ letter: Character, in text: String) -> Bool {
        let words = text.split(separator: " ")
        return words.contains { $0.count == 1 && $0.first == letter }
    }
    
    // Timer management
    func handleTimePressureGuess(encrypted: Character, guess: Character) -> TimePressureResult {
        guard let game = currentGame else {
            return .invalid
        }
        
        // Check if guess is correct
        let isCorrect = game.correctMappings[encrypted] == guess
        
        if isCorrect {
            // Check if it's the timer letter or gateway
            if encrypted == getCurrentTimerLetter() {
                // Correct guess for timer letter
                incrementStreak()
                moveToNextTimerLetter()
                return .timerLetterCorrect
            } else {
                // Gateway letter - add bonus time
                addBonusTime(2.0)
                return .gatewayBonus(seconds: 2.0)
            }
        } else {
            // Wrong guess
            resetStreak()
            return .incorrect
        }
    }
    
    private func getCurrentTimerLetter() -> Character? {
        // Return current letter from reveal order
        // Implementation depends on your timer state management
        return nil
    }
    
    private func incrementStreak() {
        // Increment streak counter
    }
    
    private func resetStreak() {
        // Reset streak to 0
    }
    
    private func moveToNextTimerLetter() {
        // Move to next letter in reveal order
    }
    
    private func addBonusTime(_ seconds: Double) {
        // Add bonus time to timer
    }
}

// MARK: - Time Pressure Result
enum TimePressureResult {
    case timerLetterCorrect
    case gatewayBonus(seconds: Double)
    case incorrect
    case invalid
    case autoRevealed
}

// MARK: - Statistics Extensions
struct TimePressureStats: Codable {
    var gamesPlayed: Int = 0
    var gamesWon: Int = 0
    var averageTimePerLetter: Double = 0
    var bestStreak: Int = 0
    var totalGatewayBonuses: Int = 0
    var fastestWin: TimeInterval?
    var totalLettersRevealed: Int = 0
    var totalLettersGuessed: Int = 0
    
    var winRate: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(gamesWon) / Double(gamesPlayed) * 100
    }
    
    var guessEfficiency: Double {
        guard totalLettersRevealed > 0 else { return 0 }
        return Double(totalLettersGuessed) / Double(totalLettersRevealed) * 100
    }
    
    mutating func recordGame(
        won: Bool,
        timeElapsed: TimeInterval,
        streak: Int,
        gatewayBonuses: Int,
        lettersRevealed: Int,
        lettersGuessed: Int
    ) {
        gamesPlayed += 1
        if won {
            gamesWon += 1
            if fastestWin == nil || timeElapsed < fastestWin! {
                fastestWin = timeElapsed
            }
        }
        
        bestStreak = max(bestStreak, streak)
        totalGatewayBonuses += gatewayBonuses
        totalLettersRevealed += lettersRevealed
        totalLettersGuessed += lettersGuessed
        
        // Update average time per letter
        let currentTotal = averageTimePerLetter * Double(totalLettersRevealed - lettersRevealed)
        let newTotal = currentTotal + timeElapsed
        averageTimePerLetter = newTotal / Double(totalLettersRevealed)
    }
}

// MARK: - UI Helper Extensions
extension Color {
    static func timerColor(for timeRemaining: Double, maxTime: Double = 8.0) -> Color {
        let percentage = timeRemaining / maxTime
        
        switch percentage {
        case 0.75...:
            return .green
        case 0.5..<0.75:
            return .yellow
        case 0.25..<0.5:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Sound Effects for Time Pressure
extension SoundManager {
    func playTimePressureSound(_ sound: TimePressureSound) {
        switch sound {
        case .tick:
            play(.letterClick) // Reuse existing
        case .autoReveal:
            play(.incorrectGuess) // Use incorrect guess sound for auto-reveal
        case .streakBonus:
            play(.correctGuess)
        case .timeBonus:
            play(.hint)
        case .urgentWarning:
            play(.lose) // Use lose sound for urgent warning
        }
    }
    
    enum TimePressureSound {
        case tick
        case autoReveal
        case streakBonus
        case timeBonus
        case urgentWarning
    }
}
