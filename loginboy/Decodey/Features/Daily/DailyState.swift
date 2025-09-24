// DailyState.swift
// Manages daily challenge state persistence and tab switching

import SwiftUI
import CoreData

class DailyState: ObservableObject {
    static let shared = DailyState()
    
    // MARK: - Published State
    @Published var currentDailyGame: GameModel?
    @Published var todaysDailyCompleted = false
    @Published var showCompletedModal = false
    @Published var dailyStats: DailyStats?
    private let colors = ColorSystem.shared
    
    // MARK: - Daily Stats Structure
    struct DailyStats {
        let completedTime: Date
        let score: Int
        let mistakes: Int
        let timeTaken: Int
        let quote: String
        let author: String
    }
    
    // MARK: - Properties
    private let coreData = CoreDataStack.shared
    private var todaysDateString: String {
        DateFormatter.yyyyMMdd.string(from: Date())
    }
    
    private init() {
        checkDailyStatus()
    }
    
    // MARK: - Public Methods
    
    /// Load or resume today's daily challenge
    func loadTodaysDaily() -> DailyLoadResult {
        // First check if already completed today
        if let stats = getTodaysCompletedStats() {
            self.dailyStats = stats
            self.todaysDailyCompleted = true
            return .alreadyCompleted(stats)
        }
        
        // Check for in-progress daily for today
        if let inProgressGame = getInProgressDailyForToday() {
            self.currentDailyGame = inProgressGame
            return .resumed(inProgressGame)
        }
        
        // Create new daily challenge
        if let newDaily = createTodaysDaily() {
            self.currentDailyGame = newDaily
            saveDailyGame(newDaily)
            return .new(newDaily)
        }
        
        return .error("Failed to load daily challenge")
    }
    
    /// Update daily game state (called after each move)
    func updateDailyGame(_ game: GameModel) {
        guard game.gameId?.hasPrefix("daily-") == true else { return }
        
        self.currentDailyGame = game
        
        // Check if completed
        if game.hasWon {
            handleDailyCompletion(game)
        } else if game.hasLost {
            handleDailyLoss(game)
        } else {
            // Still in progress - save state
            saveDailyGame(game)
        }
    }
    
    /// Check if we should show the daily or switch to random
    func shouldShowDaily() -> Bool {
        // Show daily if:
        // 1. Not completed today OR
        // 2. In progress today
        return !todaysDailyCompleted || currentDailyGame != nil
    }
    
    /// Clean up abandoned random games
    func cleanupAbandonedGames() {
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
        
        // Find games that are neither won nor lost and older than today
        fetchRequest.predicate = NSPredicate(
            format: "hasWon == NO AND hasLost == NO AND lastUpdateTime < %@ AND isDaily == NO",
            Calendar.current.startOfDay(for: Date()) as NSDate
        )
        
        do {
            let abandonedGames = try context.fetch(fetchRequest)
            
            for game in abandonedGames {
                // Mark as lost
                game.hasLost = true
                game.isAbandoned = true  // Add this field to track abandoned games
                print("📝 Marking abandoned game as lost: \(game.gameId?.uuidString ?? "unknown")")
            }
            
            if !abandonedGames.isEmpty {
                try context.save()
                print("✅ Cleaned up \(abandonedGames.count) abandoned games")
            }
            
        } catch {
            print("❌ Error cleaning up abandoned games: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
//    private func checkDailyStatus() {
//        // Check if today's daily is completed
//        if let stats = getTodaysCompletedStats() {
//            self.dailyStats = stats
//            self.todaysDailyCompleted = true
//        }
//        
//        // Clean up old abandoned games on app launch
//        cleanupAbandonedGames()
//    }
    
    private func getInProgressDailyForToday() -> GameModel? {
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
        
        let gameId = "daily-\(todaysDateString)"
        fetchRequest.predicate = NSPredicate(
            format: "gameId == %@ AND hasWon == NO AND hasLost == NO",
            gameId
        )
        fetchRequest.fetchLimit = 1
        
        do {
            if let gameEntity = try context.fetch(fetchRequest).first {
                return gameEntity.toModel()
            }
        } catch {
            print("❌ Error fetching in-progress daily: \(error)")
        }
        
        return nil
    }
    
    private func getTodaysCompletedStats() -> DailyStats? {
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
        
        let gameId = "daily-\(todaysDateString)"
        fetchRequest.predicate = NSPredicate(
            format: "gameId == %@ AND hasWon == YES",
            gameId
        )
        fetchRequest.fetchLimit = 1
        
        do {
            if let gameEntity = try context.fetch(fetchRequest).first {
                // Get quote info
                let quoteFetch: NSFetchRequest<QuoteCD> = QuoteCD.fetchRequest()
                quoteFetch.predicate = NSPredicate(format: "text == %@", gameEntity.solution ?? "")
                quoteFetch.fetchLimit = 1
                
                let quote = try context.fetch(quoteFetch).first
                
                return DailyStats(
                    completedTime: gameEntity.lastUpdateTime ?? Date(),
                    score: Int(gameEntity.score),
                    mistakes: Int(gameEntity.mistakes),
                    timeTaken: Int(gameEntity.timeTaken),
                    quote: gameEntity.solution ?? "",
                    author: quote?.author ?? "Unknown"
                )
            }
        } catch {
            print("❌ Error fetching completed daily stats: \(error)")
        }
        
        return nil
    }
    
    private func createTodaysDaily() -> GameModel? {
        guard let dailyQuote = DailyChallengeManager.shared.getTodaysDailyQuote() else {
            return nil
        }
        
        let gameId = "daily-\(todaysDateString)"
        let text = dailyQuote.text.uppercased()
        let correctMappings = generateCryptogramMapping(for: text)
        let encrypted = encryptText(text, with: correctMappings)
        
        return GameModel(
            gameId: gameId,
            encrypted: encrypted,
            solution: text,
            currentDisplay: encrypted,
            mapping: [:],
            correctMappings: correctMappings,
            guessedMappings: [:],
            incorrectGuesses: [:],
            mistakes: 0,
            maxMistakes: 5,  // Standard for daily
            hasWon: false,
            hasLost: false,
            difficulty: "medium",
            startTime: Date(),
            lastUpdateTime: Date()
        )
    }
    
    private func saveDailyGame(_ game: GameModel) {
        // Save to Core Data
        let context = coreData.mainContext
        
        do {
            let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "gameId == %@", game.gameId ?? "")
            
            let gameEntity: GameCD
            if let existing = try context.fetch(fetchRequest).first {
                gameEntity = existing
            } else {
                gameEntity = GameCD(context: context)
                gameEntity.gameId = UUID(uuidString: game.gameId ?? "") ?? UUID()
            }
            
            // Update all fields
            gameEntity.encrypted = game.encrypted
            gameEntity.solution = game.solution
            gameEntity.currentDisplay = game.currentDisplay
            gameEntity.mistakes = Int16(game.mistakes)
            gameEntity.maxMistakes = Int16(game.maxMistakes)
            gameEntity.hasWon = game.hasWon
            gameEntity.hasLost = game.hasLost
            gameEntity.isDaily = true
            gameEntity.difficulty = game.difficulty
            gameEntity.startTime = game.startTime
            gameEntity.lastUpdateTime = Date()
            
            try context.save()
            
        } catch {
            print("❌ Error saving daily game: \(error)")
        }
    }
    
    private func handleDailyCompletion(_ game: GameModel) {
        // Mark as completed
        self.todaysDailyCompleted = true
        self.currentDailyGame = nil
        
        // Save completion stats
        let stats = DailyStats(
            completedTime: Date(),
            score: game.calculateScore(),
            mistakes: game.mistakes,
            timeTaken: Int(Date().timeIntervalSince(game.startTime)),
            quote: game.solution,
            author: "" // Would need to fetch from quote
        )
        self.dailyStats = stats
        
        // Update daily streak
        DailyChallengeManager.shared.markTodayCompleted()
        
        // Save to Core Data
        saveDailyGame(game)
        
        // Show completion modal
        self.showCompletedModal = true
    }
    
    private func handleDailyLoss(_ game: GameModel) {
        // Don't mark as completed - they can retry
        self.currentDailyGame = nil
        
        // Save to Core Data
        saveDailyGame(game)
    }
    
    // MARK: - Helper Methods (move these from GameState)
    
    private func generateCryptogramMapping(for text: String) -> [Character: Character] {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let shuffled = alphabet.shuffled()
        var mapping: [Character: Character] = [:]
        
        for (original, encrypted) in zip(alphabet, shuffled) {
            mapping[encrypted] = original
        }
        return mapping
    }
    
    private func encryptText(_ text: String, with mapping: [Character: Character]) -> String {
        let reversedMapping = Dictionary(uniqueKeysWithValues: mapping.map { ($1, $0) })
        
        return text.map { char in
            if char.isLetter {
                guard let upperChar = char.uppercased().first else {
                    return String(char)
                }
                
                if let mappedChar = reversedMapping[upperChar] {
                    return String(mappedChar)
                } else {
                    return String(char)
                }
            } else {
                return String(char)
            }
        }.joined()
    }
}

// MARK: - Load Result Enum
enum DailyLoadResult {
    case new(GameModel)
    case resumed(GameModel)
    case alreadyCompleted(DailyState.DailyStats)
    case error(String)
}

// MARK: - Completion Modal View
struct DailyCompletedModal: View {
    @ObservedObject var dailyState = DailyState.shared
    @EnvironmentObject var gameState: GameState
    private let colors = ColorSystem.shared
    @Environment(\.colorScheme) private var colorScheme
    
    let onPlayRandom: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Daily Challenge Complete!")
                .font(.title)
                .fontWeight(.bold)
            
            if let stats = dailyState.dailyStats {
                VStack(spacing: 12) {
                    HStack {
                        Text("Score:")
                        Spacer()
                        Text("\(stats.score)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Mistakes:")
                        Spacer()
                        Text("\(stats.mistakes)")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Time:")
                        Spacer()
                        Text(formatTime(stats.timeTaken))
                            .fontWeight(.semibold)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            Text("Come back tomorrow for a new challenge!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button("Play Random") {
                    onPlayRandom()
                    dailyState.showCompletedModal = false
                }
                .buttonStyle(.borderedProminent)
                
                Button("Done") {
                    onDismiss()
                    dailyState.showCompletedModal = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(30)
        colors.primaryBackground(for: colorScheme)
            .ignoresSafeArea()
        .cornerRadius(20)
        .shadow(radius: 20)
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Core Data Extension
extension GameCD {
    // Add this property to track abandoned games
    @NSManaged var isAbandoned: Bool
}
