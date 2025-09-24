import SwiftUI

struct MainView: View {
    @StateObject private var gameState = GameState.shared
    @StateObject private var userState = UserState.shared
    @StateObject private var settingsState = SettingsState.shared
    @StateObject private var soundManager = SoundManager.shared
    @StateObject private var tutorialManager = TutorialManager.shared
    @StateObject private var dailyState = DailyState.shared  // ADD: Daily state management
    
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var gameCenterManager: GameCenterManager
    
    @State private var showingHomeScreen = true
    @State private var hasCheckedTutorial = false
    @State private var selectedTab = 0  // ADD: Track selected tab
    
    var body: some View {
        ZStack {
            if showingHomeScreen {
                HomeScreen {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showingHomeScreen = false
                    }
                }
                .environmentObject(authManager)
                .environmentObject(gameCenterManager)
                .transition(.opacity)
            } else {
                // Main game interface
                VStack(spacing: 0) {
                    // Game content
                    TabView(selection: $selectedTab) {
                        // Daily Challenge Tab
                        DailyGameView()
                            .tabItem {
                                Image(systemName: "calendar")
                                Text("Daily")
                            }
                            .tag(0)
                            .badge(dailyState.todaysDailyCompleted ? nil : "NEW")  // Show badge if not completed
                        
                        // Random Game Tab
                        RandomGameView()
                            .tabItem {
                                Image(systemName: "shuffle")
                                Text("Random")
                            }
                            .tag(1)
                        
                        // Stats Tab
                        UserStatsView()
                            .tabItem {
                                Image(systemName: "chart.bar")
                                Text("Stats")
                            }
                            .tag(2)
                        
                        // Game Center Leaderboard tab
                        LeaderboardView()
                            .tabItem {
                                Label("Leaderboard", systemImage: "trophy.fill")
                            }
                            .tag(3)
                        
                        // Settings Tab
                        SettingsView()
                            .tabItem {
                                Image(systemName: "gear")
                                Text("Settings")
                            }
                            .tag(4)
                    }
                    .tutorialTarget(.tabBar)
                    .onChange(of: selectedTab) { newTab in
                        handleTabChange(newTab)
                    }
                }
                .transition(.slide)
                .withTutorialOverlay()
                .onAppear {
                    handleInitialSetup()
                }
            }
        }
        .environmentObject(gameState)
        .environmentObject(userState)
        .environmentObject(settingsState)
        .environmentObject(soundManager)
        .environmentObject(tutorialManager)
        .environmentObject(dailyState)  // ADD: Pass daily state to child views
    }
    
    // MARK: - Tab Change Handler
    private func handleTabChange(_ tab: Int) {
        switch tab {
        case 0:
            // Daily Challenge Tab
            handleDailyTabSelection()
        case 1:
            // Random Game Tab
            handleRandomTabSelection()
        default:
            break
        }
    }
    
    // MARK: - Daily Tab Selection
    private func handleDailyTabSelection() {
        // Load or resume daily challenge
        let result = dailyState.loadTodaysDaily()
        
        switch result {
        case .new(let game):
            print("📅 Starting new daily challenge")
            gameState.loadFromGameModel(game)
            gameState.isDailyChallenge = true
            
        case .resumed(let game):
            print("📅 Resuming daily challenge")
            gameState.loadFromGameModel(game)
            gameState.isDailyChallenge = true
            
        case .alreadyCompleted(let stats):
            print("📅 Today's daily already completed")
            dailyState.showCompletedModal = true
            // Optionally load the completed game for review
            if let completedGame = dailyState.currentDailyGame {
                gameState.loadFromGameModel(completedGame)
                gameState.isDailyChallenge = true
            }
            
        case .error(let message):
            print("❌ Error loading daily: \(message)")
            gameState.errorMessage = message
        }
    }
    
    // MARK: - Random Tab Selection
    private func handleRandomTabSelection() {
        // Clear daily challenge flag
        gameState.isDailyChallenge = false
        dailyState.showCompletedModal = false
        
        // Setup a new random game
        gameState.setupCustomGame()
    }
    
    // MARK: - Initial Setup
    private func handleInitialSetup() {
        // Check for pending tutorial
        if !hasCheckedTutorial {
            hasCheckedTutorial = true
            // Check if tutorial hasn't been completed
            let shouldShowTutorial = !UserDefaults.standard.bool(forKey: "tutorial-completed")
            let tutorialRequested = UserDefaults.standard.bool(forKey: "tutorial-requested")
            
            if shouldShowTutorial || tutorialRequested {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tutorialManager.startTutorial()
                    UserDefaults.standard.set(false, forKey: "tutorial-requested")
                }
            }
        }
        
        // Check daily challenge status on app launch
        dailyState.checkDailyStatus()
        
        // Optionally auto-switch to daily tab if not completed
        if !dailyState.todaysDailyCompleted && dailyState.shouldShowDaily() {
            selectedTab = 0
        }
    }
}

// MARK: - Daily Game View
struct DailyGameView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var dailyState: DailyState
    @State private var showDailyInfo = false
    
    var body: some View {
        ZStack {
            if dailyState.todaysDailyCompleted && dailyState.showCompletedModal {
                // Show completed view
                DailyCompletedView()
            } else {
                // Show game view
                GameView()
                    .onAppear {
                        if !gameState.isDailyChallenge {
                            // Make sure we're in daily mode
                            gameState.isDailyChallenge = true
                        }
                    }
            }
        }
        .sheet(isPresented: $showDailyInfo) {
            DailyInfoSheet()
        }
        // Cross-platform toolbar approach
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showDailyInfo = true }) {
                    Image(systemName: "info.circle")
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                Button(action: { showDailyInfo = true }) {
                    Image(systemName: "info.circle")
                }
            }
            #endif
        }
    }
}

// MARK: - Random Game View
struct RandomGameView: View {
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        GameView()
            .onAppear {
                if gameState.isDailyChallenge {
                    // Switch to random mode
                    gameState.setupCustomGame()
                }
            }
    }
}

// MARK: - Daily Completed View
struct DailyCompletedView: View {
    @EnvironmentObject var dailyState: DailyState
    @EnvironmentObject var userState: UserState
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Checkmark animation
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .scaleEffect(1.1)
                .animation(
                    Animation.spring(response: 0.5, dampingFraction: 0.6)
                        .repeatCount(1, autoreverses: true),
                    value: dailyState.showCompletedModal
                )
            
            Text("Daily Challenge Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Show stats if available
            if let stats = dailyState.dailyStats {
                VStack(alignment: .leading, spacing: 12) {
                    StatRow(label: "Score", value: "\(stats.score)")
                    StatRow(label: "Mistakes", value: "\(stats.mistakes)")
                    StatRow(label: "Time", value: formatTime(stats.timeTaken))
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stats.quote)
                            .font(.system(.body, design: .serif))
                            .italic()
                        Text("— \(stats.author)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding()
            }
            
            // Streak information - using DailyChallengeManager
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Current Streak: \(DailyChallengeManager.shared.getCurrentStreak()) days")
                        .fontWeight(.semibold)
                }
                
                if DailyChallengeManager.shared.getCurrentStreak() > 0 {
                    Text("Keep it up! Come back tomorrow!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Time until next daily
            TimeUntilNextDaily()
                .padding()
            
            Spacer()
        }
        .padding()
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Daily Info Sheet
struct DailyInfoSheet: View {
    @Environment(\.dismiss) var dismiss  // Cross-platform dismissal
    @EnvironmentObject var dailyState: DailyState
    
    var body: some View {
        NavigationViewWrapper {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: "calendar")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Daily Challenge")
                                .font(.title)
                                .fontWeight(.bold)
                            Text("A new cryptogram every day!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                    // Info sections
                    InfoSection(
                        title: "How it works",
                        icon: "lightbulb",
                        content: "Every day at midnight, a new cryptogram puzzle becomes available. All players worldwide get the same puzzle!"
                    )
                    
                    InfoSection(
                        title: "Streaks",
                        icon: "flame",
                        content: "Complete daily challenges consecutive days to build your streak. Don't break the chain!"
                    )
                    
                    InfoSection(
                        title: "Leaderboard",
                        icon: "trophy",
                        content: "Compare your solving time with players around the world. Can you make it to the top?"
                    )
                    
                    // Current status
                    if dailyState.todaysDailyCompleted {
                        CompletedStatusCard()
                    } else {
                        PendingStatusCard()
                    }
                }
                .padding()
            }
            .navigationTitle("About Daily Challenge")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                #endif
            }
        }
    }
}

// MARK: - Helper Components
struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct InfoSection: View {
    let title: String
    let icon: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

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
        
        // Get tomorrow at midnight
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

struct CompletedStatusCard: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundColor(.green)
            VStack(alignment: .leading) {
                Text("Today's Challenge")
                    .font(.headline)
                Text("Completed! Come back tomorrow")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
    }
}

struct PendingStatusCard: View {
    var body: some View {
        HStack {
            Image(systemName: "play.circle.fill")
                .font(.title)
                .foregroundColor(.blue)
            VStack(alignment: .leading) {
                Text("Today's Challenge")
                    .font(.headline)
                Text("Ready to play!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Daily Load Result Extension
extension DailyState {
    enum DailyLoadResult {
        case new(GameModel)
        case resumed(GameModel)
        case alreadyCompleted(DailyStats)
        case error(String)
    }
    
    // Add this method if not present in DailyState
    func checkDailyStatus() {
        // Check if today's daily is completed
        let todayString = DateFormatter.yyyyMMdd.string(from: Date())
        todaysDailyCompleted = UserDefaults.standard.bool(forKey: "daily_completed_\(todayString)")
        
        // Load stats if completed
        if todaysDailyCompleted {
            dailyStats = getTodaysCompletedStats()
        }
    }
    
    // Placeholder methods - implement these in your actual DailyState.swift
    private func getTodaysCompletedStats() -> DailyStats? {
        let context = CoreDataStack.shared.mainContext
        let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
        
        // Compute today's date string locally
        let todaysDateString = DateFormatter.yyyyMMdd.string(from: Date())
        let gameId = "daily-\(todaysDateString)"
        
        // Convert daily string ID to UUID for Core Data
        let gameUUID: UUID
        if gameId.hasPrefix("daily-") {
            // Create a deterministic UUID from the daily string
            let hash = abs(gameId.hashValue)
            let uuidString = String(format: "00000000-0000-0000-0000-%012d", hash % 1000000000000)
            gameUUID = UUID(uuidString: uuidString) ?? UUID()
        } else {
            gameUUID = UUID(uuidString: gameId) ?? UUID()
        }
        
        fetchRequest.predicate = NSPredicate(
            format: "gameId == %@ AND hasWon == YES",
            gameUUID as CVarArg
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
    
    private func getInProgressDailyForToday() -> GameModel? {
        let context = CoreDataStack.shared.mainContext
        let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
        
        // Compute today's date string locally
        let todaysDateString = DateFormatter.yyyyMMdd.string(from: Date())
        let gameId = "daily-\(todaysDateString)"
        
        // Convert daily string ID to UUID for Core Data
        let gameUUID: UUID
        if gameId.hasPrefix("daily-") {
            let hash = abs(gameId.hashValue)
            let uuidString = String(format: "00000000-0000-0000-0000-%012d", hash % 1000000000000)
            gameUUID = UUID(uuidString: uuidString) ?? UUID()
        } else {
            gameUUID = UUID(uuidString: gameId) ?? UUID()
        }
        
        fetchRequest.predicate = NSPredicate(
            format: "gameId == %@ AND hasWon == NO AND hasLost == NO",
            gameUUID as CVarArg
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
    
    private func createTodaysDaily() -> GameModel? {
        guard let dailyQuote = DailyChallengeManager.shared.getTodaysDailyQuote() else {
            return nil
        }
        
        // Compute today's date string locally
        let todaysDateString = DateFormatter.yyyyMMdd.string(from: Date())
        let gameId = "daily-\(todaysDateString)"
        let text = dailyQuote.text.uppercased()
        
        // Generate cryptogram mapping (simplified version)
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var shuffled = alphabet.shuffled()
        var correctMappings: [Character: Character] = [:]
        
        for (original, encrypted) in zip(alphabet, shuffled) {
            correctMappings[original] = encrypted
        }
        
        // Encrypt the text
        var encrypted = ""
        for char in text {
            if char.isLetter {
                encrypted.append(correctMappings[char] ?? char)
            } else {
                encrypted.append(char)
            }
        }
        
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
        let context = CoreDataStack.shared.mainContext
        
        guard let gameId = game.gameId else { return }
        
        // Convert daily string ID to UUID for Core Data
        let gameUUID: UUID
        if gameId.hasPrefix("daily-") {
            let hash = abs(gameId.hashValue)
            let uuidString = String(format: "00000000-0000-0000-0000-%012d", hash % 1000000000000)
            gameUUID = UUID(uuidString: uuidString) ?? UUID()
        } else {
            gameUUID = UUID(uuidString: gameId) ?? UUID()
        }
        
        do {
            let fetchRequest: NSFetchRequest<GameCD> = GameCD.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameUUID as CVarArg)
            
            let gameEntity: GameCD
            if let existing = try context.fetch(fetchRequest).first {
                gameEntity = existing
            } else {
                gameEntity = GameCD(context: context)
                gameEntity.gameId = gameUUID
            }
            
            // Update entity with game data
            gameEntity.encrypted = game.encrypted
            gameEntity.solution = game.solution
            gameEntity.currentDisplay = game.currentDisplay
            gameEntity.mistakes = Int16(game.mistakes)
            gameEntity.maxMistakes = Int16(game.maxMistakes)
            gameEntity.hasWon = game.hasWon
            gameEntity.hasLost = game.hasLost
            gameEntity.difficulty = game.difficulty
            gameEntity.startTime = game.startTime
            gameEntity.lastUpdateTime = game.lastUpdateTime
            gameEntity.isDaily = true
            
            try context.save()
        } catch {
            print("❌ Error saving daily game: \(error)")
        }
    }
    
    private func handleDailyCompletion(_ game: GameModel) {
        // Implementation for when daily is completed
        DailyChallengeManager.shared.markTodayCompleted()
    }
    
    private func handleDailyLoss(_ game: GameModel) {
        // Implementation for when daily is lost
    }
}

// MARK: - GameState Extension
extension GameState {
    // Add this method if not present in GameState
    func loadFromGameModel(_ model: GameModel) {
        self.currentGame = model
        // Update other relevant state properties from the model
        self.isDailyChallenge = model.gameId?.hasPrefix("daily-") ?? false
    }
}

// MARK: - GameCD Extension for Model Conversion
extension GameCD {
    func toModel() -> GameModel? {
        // Convert UUID back to string for daily games
        let gameIdString: String
        if let uuid = self.gameId {
            // Check if this is a daily game by looking at the pattern
            if self.isDaily {
                // Reconstruct the daily string from the date
                let dateString = DateFormatter.yyyyMMdd.string(from: self.startTime ?? Date())
                gameIdString = "daily-\(dateString)"
            } else {
                gameIdString = uuid.uuidString
            }
        } else {
            return nil
        }
        
        return GameModel(
            gameId: gameIdString,
            encrypted: self.encrypted ?? "",
            solution: self.solution ?? "",
            currentDisplay: self.currentDisplay ?? "",
            mapping: [:],  // You'd need to decode these from stored data
            correctMappings: [:],
            guessedMappings: [:],
            incorrectGuesses: [:],
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

// MARK: - SettingsState Extension
extension SettingsState {
    // Add this property if not present
    var tutorialRequested: Bool {
        get { UserDefaults.standard.bool(forKey: "tutorial-requested") }
        set { UserDefaults.standard.set(newValue, forKey: "tutorial-requested") }
    }
}
