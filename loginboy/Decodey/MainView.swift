// MainView.swift
// Fixed version with proper tab switching between Daily and Random games

import SwiftUI
import CoreData

struct MainView: View {
    // Critical state objects only
    @StateObject private var gameState = GameState.shared
    @StateObject private var userState = UserState.shared
    
    // Environment
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var gameCenterManager: GameCenterManager
    
    // View state
    @State private var showingHomeScreen = true
    @State private var selectedTab = 0
    @State private var previousTab = 0  // Track previous tab to detect changes
    
    // Track initial load states
    @State private var dailyInitialized = false
    @State private var randomInitialized = false
    
    // Lazy load non-critical managers
    @State private var managersLoaded = false
    
    var body: some View {
        ZStack {
            if showingHomeScreen {
                OptimizedHomeScreen {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingHomeScreen = false
                    }
                }
                .environmentObject(authManager)
                .environmentObject(gameCenterManager)
                .transition(.opacity)
            } else {
                mainGameInterface
                    .onAppear {
                        // Load the initial tab (Daily) when first showing the game interface
                        if selectedTab == 0 && !dailyInitialized {
                            loadDailyGame()
                        }
                    }
            }
        }
        .task {
            // Load non-critical managers after UI renders
            if !managersLoaded {
                _ = SettingsState.shared
                _ = SoundManager.shared
                _ = TutorialManager.shared
                managersLoaded = true
            }
        }
        .onChange(of: selectedTab) { newTab in
            // Handle tab changes
            handleTabChange(from: previousTab, to: newTab)
            previousTab = newTab
        }
    }
    
    private var mainGameInterface: some View {
        TabView(selection: $selectedTab) {
            // Daily Challenge
            DailyGameWrapper()
                .tabItem {
                    Label("Daily", systemImage: "calendar")
                }
                .tag(0)
            
            // Random Game
            RandomGameWrapper()
                .tabItem {
                    Label("Random", systemImage: "shuffle")
                }
                .tag(1)
            
            // Stats
            UserStatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(2)
            
            // Leaderboard
            LeaderboardView()
                .tabItem {
                    Label("Leaders", systemImage: "trophy")
                }
                .tag(3)
            
            // Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
        }
        .environmentObject(gameState)
        .environmentObject(userState)
        .environmentObject(authManager)
        .environmentObject(gameCenterManager)
    }
    
    private func handleTabChange(from oldTab: Int, to newTab: Int) {
        // Stop tracking time when leaving game tabs
        if (oldTab == 0 || oldTab == 1) && newTab > 1 {
            gameState.stopTrackingTime()
        }
        
        // Load appropriate game when switching to game tabs
        if newTab == 0 {
            // Switching to Daily
            loadDailyGame()
        } else if newTab == 1 {
            // Switching to Random
            loadRandomGame()
        }
    }
    
    private func loadDailyGame() {
        // Simply call the GameState method - it handles everything
        gameState.loadOrCreateGame(isDaily: true)
        gameState.startTrackingTime()
        dailyInitialized = true
    }
    
    private func loadRandomGame() {
        // Simply call the GameState method - it handles everything
        gameState.loadOrCreateGame(isDaily: false)
        gameState.startTrackingTime()
        randomInitialized = true
    }
}

// MARK: - Daily Game Wrapper
struct DailyGameWrapper: View {
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        Group {
            // Check if we have completed daily stats
            if let stats = gameState.lastDailyGameStats, stats.hasWon {
                // Show completed view using the saved stats
                DailyCompletedView(
                    solution: stats.solution,
                    author: stats.author,
                    score: stats.score,
                    onPlayRandom: {
                        // Switch to random tab would be handled by parent
                    }
                )
            } else {
                // Show game
                GameView()
            }
        }
    }
    
    private func ensureDailyLoaded() {
        // Make sure we're in daily mode and have the right game loaded
        if !gameState.isDailyChallenge || gameState.currentGame == nil {
            gameState.isDailyChallenge = true
            gameState.loadOrCreateGame(isDaily: true)
            gameState.startTrackingTime()
        }
    }
}

// MARK: - Random Game Wrapper
struct RandomGameWrapper: View {
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        GameView()
    }
}

// MARK: - Daily Completed View
struct DailyCompletedView: View {
    let solution: String
    let author: String
    let score: Int
    let onPlayRandom: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Success icon
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 40)
                
                // Title
                VStack(spacing: 8) {
                    Text("Daily Complete!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("You've solved today's challenge")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Solution display
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today's Quote:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\"\(solution)\"")
                            .font(.system(.body, design: .serif))
                            .italic()
                            .multilineTextAlignment(.leading)
                        
                        Text("— \(author)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.05))
                )
                .padding(.horizontal)
                
                // Score
                VStack(spacing: 8) {
                    Text("YOUR SCORE")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                    
                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                // Time until next
                TimeUntilNextDaily()
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 12) {
                    Text("Want to keep playing?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: onPlayRandom) {
                        Label("Play Random Game", systemImage: "shuffle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Button(action: shareScore) {
                        Label("Share Score", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Daily Challenge")
    }
    
    private func shareScore() {
        // Implement sharing functionality
        let shareText = "I scored \(score) on today's Decodey daily challenge! 🎯"
        
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let activityController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        window.rootViewController?.present(activityController, animated: true)
        #endif
    }
}

// MARK: - Time Until Next Daily
struct TimeUntilNextDaily: View {
    @State private var timeRemaining = ""
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Next daily in:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(timeRemaining)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
        .onAppear {
            updateTimeRemaining()
        }
    }
    
    private func updateTimeRemaining() {
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let nextMidnight = calendar.startOfDay(for: tomorrow)
        
        let components = calendar.dateComponents([.hour, .minute, .second], from: now, to: nextMidnight)
        
        if let hours = components.hour,
           let minutes = components.minute,
           let seconds = components.second {
            timeRemaining = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}

// Add this extension to GameState if it doesn't exist
extension GameState {
    func getTodaysDailyGame() -> GameModel? {
        // Check if current game is today's daily
        if isDailyChallenge,
           let game = currentGame,
           let gameId = game.gameId {
            let todayString = DateFormatter.yyyyMMdd.string(from: Date())
            if gameId.contains(todayString) {
                return game
            }
        }
        
        // Otherwise fetch from CoreData
        let context = CoreDataStack.shared.mainContext
        let todayString = DateFormatter.yyyyMMdd.string(from: Date())
        let dailyUUID = dailyStringToUUID("daily-\(todayString)")
        
        let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "gameId == %@ AND isDaily == YES", dailyUUID as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            if let entity = try context.fetch(fetchRequest).first {
                // Decode mappings
                var mapping: [Character: Character] = [:]
                var correctMappings: [Character: Character] = [:]
                var guessedMappings: [Character: Character] = [:]
                var incorrectGuesses: [Character: Set<Character>] = [:]
                
                if let data = entity.correctMappings,
                   let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
                    correctMappings = decoded.stringDictToCharDict()
                }
                
                if let data = entity.guessedMappings,
                   let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
                    guessedMappings = decoded.stringDictToCharDict()
                }
                
                if let data = entity.mapping,
                   let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
                    mapping = decoded.stringDictToCharDict()
                }
                
                if let data = entity.incorrectGuesses,
                   let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
                    for (key, values) in decoded {
                        if let keyChar = key.first {
                            incorrectGuesses[keyChar] = Set(values.compactMap { $0.first })
                        }
                    }
                }
                
                return GameModel(
                    gameId: "daily-\(todayString)",
                    encrypted: entity.encrypted ?? "",
                    solution: entity.solution ?? "",
                    currentDisplay: entity.currentDisplay ?? "",
                    mapping: mapping,
                    correctMappings: correctMappings,
                    guessedMappings: guessedMappings,
                    incorrectGuesses: incorrectGuesses,
                    mistakes: Int(entity.mistakes),
                    maxMistakes: Int(entity.maxMistakes),
                    hasWon: entity.hasWon,
                    hasLost: entity.hasLost,
                    difficulty: entity.difficulty ?? "medium",
                    startTime: entity.startTime ?? Date(),
                    lastUpdateTime: entity.lastUpdateTime ?? Date()
                )
            }
        } catch {
            print("Error fetching daily game: \(error)")
        }
        
        return nil
    }
    
    private func dailyStringToUUID(_ dailyId: String) -> UUID {
        let hash = abs(dailyId.hashValue)
        let uuidString = String(format: "00000000-0000-0000-0000-%012d", hash % 1000000000000)
        return UUID(uuidString: uuidString) ?? UUID()
    }
}
