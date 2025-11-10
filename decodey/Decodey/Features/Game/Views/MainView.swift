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

// MARK: - Random Game Wrapper (UPDATED)
struct RandomGameWrapper: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState  // Add this
    
    var body: some View {
        // CHANGED: Use GameModeWrapper instead of GameView directly
        GameModeWrapper()
            .environmentObject(gameState)
            .environmentObject(settingsState)
            .onAppear {
                ensureRandomLoaded()
            }
    }
    
    private func ensureRandomLoaded() {
        // Make sure we're in random mode and have the right game loaded
        if gameState.isDailyChallenge || gameState.currentGame == nil {
            gameState.isDailyChallenge = false
            gameState.loadOrCreateGame(isDaily: false)
            gameState.startTrackingTime()
        }
    }
}

// MARK: - Daily Game Wrapper (UPDATED)
struct DailyGameWrapper: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState  // Add this
    
    var body: some View {
        Group {
            // Check if we have completed daily stats
            if let stats = gameState.lastDailyGameStats, stats.hasWon {
                // Show completed view using the saved stats
                DailyCompletedView(
                    solution: stats.solution,
                    author: stats.author,
                    score: stats.score,
                    mistakes: stats.mistakes,
                    maxMistakes: stats.maxMistakes,
                    timeElapsed: stats.timeElapsed,
                    isDailyChallenge: true,
                    onPlayRandom: {
                        // Switch to random/custom game mode
                        gameState.isDailyChallenge = false
                        gameState.resetGame()
                    }
                )
            } else {
                // CHANGED: Use GameModeWrapper instead of GameView directly
                GameModeWrapper()
                    .environmentObject(gameState)
                    .environmentObject(settingsState)
                    .onAppear {
                        ensureDailyLoaded()
                    }
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


// MARK: - Daily Completed View
struct DailyCompletedView: View {
    let solution: String
    let author: String
    let score: Int
    let mistakes: Int
    let maxMistakes: Int
    let timeElapsed: Int  // Changed from timeTaken to match your struct
    let isDailyChallenge: Bool
    let onPlayRandom: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var showShareSheet = false
    
    // Get current streak for display
    private var currentStreak: Int {
        DailyChallengeManager.shared.getCurrentStreak()
    }
    
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
                    
                    Text(getCurrentDateString())
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                // Score and Stats
                VStack(spacing: 16) {
                    // Score
                    HStack {
                        Text("Score:")
                            .foregroundColor(.secondary)
                        Text("\(score)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    // Mistakes
                    HStack {
                        Text("Mistakes:")
                            .foregroundColor(.secondary)
                        Text("\(mistakes)")
                            .font(.title3)
                    }
                    
                    // Streak (if > 1)
                    if currentStreak > 1 {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(currentStreak) day streak!")
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Quote reveal
                VStack(spacing: 12) {
                    Text("Today's Quote:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(solution)
                        .font(.body)
                        .italic()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("— \(author)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Share Button - Platform specific
                    #if os(iOS)
                    ShareButton(
                        score: score,
                        mistakes: mistakes,
                        streak: currentStreak,
                        onShare: shareResults
                    )
                    #elseif os(macOS)
                    MacShareButton(items: [getShareText()])
                    #endif
                    
                    // Play Random Button
                    Button(action: onPlayRandom) {
                        Label("Play Random Game", systemImage: "shuffle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Next daily timer
                TimeUntilNextDaily()
                    .padding(.top, 20)
            }
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [getShareText()])
        }
    }
    
    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: Date())
    }
    
    private func getShareText() -> String {
        // Calculate solve percentage (similar to web app)
        let solvePercentage = mistakes == 0 ? 100 : max(0, 100 - (mistakes * 100 / maxMistakes))
        
        // Time formatting (using timeElapsed)
        let minutes = timeElapsed / 60
        let seconds = timeElapsed % 60
        let timeString = String(format: "%02d:%02d", minutes, seconds)
        
        // Create rating bar (visual progress indicator)
        let blocks = ["░", "▒", "▓", "█", "⠿", "■", "□"]
        let ratingNum = min(100, score / 10) // Simplified rating calculation
        let filledBlocks = ratingNum / 10
        let ratingBar = String(repeating: blocks[5], count: filledBlocks) +
                        String(repeating: blocks[6], count: 10 - filledBlocks)
        
        // Format message in retro terminal style
        let message: String
        if isDailyChallenge {
            // Daily challenge format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM.dd.yyyy"
            let dateString = dateFormatter.string(from: Date())
            
            message = """
            >> [D E C O D E Y   D A I L Y   \(dateString)] <<
              > T I M E : \(timeString) .  .  .  T O K E N S :  \(mistakes) <
              > S C O R E : \(score) .  .  .  .  .  .  .  .  .  .  .  .<
              > P C T : [\(ratingBar)] \(ratingNum)% <
              \(currentStreak > 1 ? "  > S T R E A K : \(currentStreak) 🔥 .  .  .  .  .  .  .  .  .  .<\n" : "")  > D E C O D E Y . G A M E .  .  .  .  .  .  .<
            """
        } else {
            // Regular game format
            message = """
            >> [D E C O D E Y   C O M P L E T E] <<
              > T I M E : \(timeString) .  .  .  T O K E N S :  \(mistakes) <
              > S C O R E : \(score) .  .  .  .  .  .  .  .  .  .  .  .<
              > P C T : [\(ratingBar)] \(ratingNum)% <
              > D E C O D E Y . G A M E .  .  .  .  .  .  .<
            """
        }
        
        return message
    }
    
    private func shareResults() {
        showShareSheet = true
    }
}

// MARK: - Share Button Component
struct ShareButton: View {
    let score: Int
    let mistakes: Int
    let streak: Int
    let onShare: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onShare) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                
                Text("Share Result")
                    .fontWeight(.medium)
                
                // X/Twitter logo (using text for simplicity)
                Text("𝕏")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.black, Color.black.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Share Sheet (Cross-Platform)
#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Suggest Twitter/X as preferred sharing option
        controller.activityItemsConfiguration = [
            UIActivity.ActivityType.postToTwitter
        ] as? UIActivityItemsConfigurationReading
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#elseif os(macOS)
import AppKit

struct ShareSheet: NSViewControllerRepresentable {
    let items: [Any]
    
    func makeNSViewController(context: Context) -> NSViewController {
        let controller = NSViewController()
        
        // Create sharing picker
        let picker = NSSharingServicePicker(items: items)
        
        // Show picker after a brief delay to ensure view is ready
        DispatchQueue.main.async {
            if let view = controller.view.window?.contentView {
                picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
            } else {
                // Fallback: Use the sharing services directly
                if let service = NSSharingService(named: .postOnTwitter) {
                    service.perform(withItems: items)
                }
            }
        }
        
        return controller
    }
    
    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}

// Alternative macOS implementation using a button with sharing menu
struct MacShareButton: View {
    let items: [Any]
    
    var body: some View {
        Button(action: shareResults) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Result")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func shareResults() {
        let picker = NSSharingServicePicker(items: items)
        
        if let contentView = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }
}
#endif

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
