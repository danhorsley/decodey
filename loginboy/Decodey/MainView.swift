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
    
    // Track loaded states
    @State private var dailyLoaded = false
    @State private var randomLoaded = false
    
    // Lazy load non-critical managers
    @State private var managersLoaded = false
    
    var body: some View {
        ZStack {
            if showingHomeScreen {
                OptimizedHomeScreen {  // Use optimized version!
                    withAnimation(.easeInOut(duration: 0.3)) {  // Faster animation
                        showingHomeScreen = false
                    }
                }
                .environmentObject(authManager)
                .environmentObject(gameCenterManager)
                .transition(.opacity)
            } else {
                mainGameInterface
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
    }
    
    private var mainGameInterface: some View {
        TabView(selection: $selectedTab) {
            // Daily Challenge
            GameView()
                .tabItem {
                    Label("Daily", systemImage: "calendar")
                }
                .tag(0)
                .onAppear {
                    handleDailyTab()
                }
                .onDisappear {
                    gameState.stopTrackingTime()
                }
            
            // Random Game
            GameView()
                .tabItem {
                    Label("Random", systemImage: "shuffle")
                }
                .tag(1)
                .onAppear {
                    handleRandomTab()
                }
                .onDisappear {
                    gameState.stopTrackingTime()
                }
            
            // Stats - Lazy loaded
            UserStatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(2)
            
            // Leaderboard - Lazy loaded
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
    
    private func handleDailyTab() {
        if !dailyLoaded {
            gameState.loadOrCreateGame(isDaily: true)
            dailyLoaded = true
        }
        gameState.startTrackingTime()
    }
    
    private func handleRandomTab() {
        if !randomLoaded {
            gameState.loadOrCreateGame(isDaily: false)
            randomLoaded = true
        }
        gameState.startTrackingTime()
    }
}

// MARK: - Simplified Daily Game View
struct DailyGameView: View {
    @EnvironmentObject var gameState: GameState
    @State private var dailyStatus: DailyStatus = .loading
    @State private var showDailyInfo = false
    
    enum DailyStatus {
        case loading
        case playing(GameModel)
        case completed(solution: String, author: String, score: Int)
        case notStarted
    }
    
    var body: some View {
        ZStack {
            switch dailyStatus {
            case .loading:
                ProgressView("Loading daily challenge...")
                    .onAppear { loadDailyStatus() }
                
            case .playing(let game):
                GameView()
                    .onAppear {
                        // Load the game into GameState
                        gameState.loadFromGameModel(game)
                        gameState.isDailyChallenge = true
                    }
                
            case .completed(let solution, let author, let score):
                DailyCompletedSimpleView(
                    solution: solution,
                    author: author,
                    score: score,
                    onPlayRandom: { switchToRandomTab() }
                )
                
            case .notStarted:
                DailyStartView(onStart: { startNewDaily() })
            }
        }
        .sheet(isPresented: $showDailyInfo) {
            DailyInfoSheet()
        }
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
    
    // Direct DB query - no complex state management
    private func loadDailyStatus() {
        let context = CoreDataStack.shared.mainContext
        let todayString = DateFormatter.yyyyMMdd.string(from: Date())
        let dailyId = "daily-\(todayString)"
        let dailyUUID = dailyStringToUUID(dailyId)
        
        // Check if there's a game for today
        let request: NSFetchRequest<GameCD> = GameCD.fetchRequest()
        request.predicate = NSPredicate(format: "gameId == %@", dailyUUID as CVarArg)
        request.fetchLimit = 1
        
        if let gameEntity = try? context.fetch(request).first {
            if gameEntity.hasWon {
                // Completed
                dailyStatus = .completed(
                    solution: gameEntity.solution ?? "",
                    author: "Unknown", // You'd fetch this from quote
                    score: Int(gameEntity.score)
                )
            } else if gameEntity.hasLost {
                // Lost - show as completed
                dailyStatus = .completed(
                    solution: gameEntity.solution ?? "",
                    author: "Unknown",
                    score: 0
                )
            } else {
                // In progress
                if let model = gameEntity.toModel() {
                    dailyStatus = .playing(model)
                }
            }
        } else {
            // No game started yet
            dailyStatus = .notStarted
        }
    }
    
    private func startNewDaily() {
        // Create new daily game
        guard let quote = DailyChallengeManager.shared.getTodaysDailyQuote() else { return }
        
        let todayString = DateFormatter.yyyyMMdd.string(from: Date())
        let gameModel = createDailyGame(quote: quote, dateString: todayString)
        
        // Save to DB
        saveDailyGame(gameModel)
        
        // Start playing
        dailyStatus = .playing(gameModel)
    }
    
    private func createDailyGame(quote: LocalQuoteModel, dateString: String) -> GameModel {
        let gameId = "daily-\(dateString)"
        let text = quote.text.uppercased()
        
        // Simple cryptogram generation
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var shuffled = alphabet.shuffled()
        var correctMappings: [Character: Character] = [:]
        
        for (original, encrypted) in zip(alphabet, shuffled) {
            correctMappings[original] = encrypted
        }
        
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
            maxMistakes: 5,
            hasWon: false,
            hasLost: false,
            difficulty: "medium",
            startTime: Date(),
            lastUpdateTime: Date()
        )
    }
    
    private func saveDailyGame(_ game: GameModel) {
        let context = CoreDataStack.shared.mainContext
        let gameEntity = GameCD(context: context)
        
        gameEntity.gameId = dailyStringToUUID(game.gameId ?? "")
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
        
        try? context.save()
    }
    
    private func switchToRandomTab() {
        // Would need to access parent's selectedTab binding
    }
    
    private func dailyStringToUUID(_ dailyId: String) -> UUID {
        let hash = abs(dailyId.hashValue)
        let uuidString = String(format: "00000000-0000-0000-0000-%012d", hash % 1000000000000)
        return UUID(uuidString: uuidString) ?? UUID()
    }
}

// MARK: - Simple Views
struct DailyStartView: View {
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Daily Challenge")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("A new puzzle every day at midnight")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: onStart) {
                Label("Start Today's Challenge", systemImage: "play.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

struct DailyCompletedSimpleView: View {
    let solution: String
    let author: String
    let score: Int
    let onPlayRandom: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Daily Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(solution)
                    .font(.system(.body, design: .serif))
                    .italic()
                Text("— \(author)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Text("Score: \(score)")
                .font(.title2)
                .fontWeight(.semibold)
            
            TimeUntilNextDaily()
            
            Button(action: onPlayRandom) {
                Text("Play Random Game")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Random Game View (Super Simple)
struct RandomGameView: View {
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        GameView()
            .onAppear {
                // Just start a random game
                gameState.isDailyChallenge = false
                gameState.setupCustomGame()
            }
    }
}

// MARK: - Helper Extensions
extension GameCD {
    func toModel() -> GameModel? {
        let gameIdString: String
        if self.isDaily {
            let dateString = DateFormatter.yyyyMMdd.string(from: self.startTime ?? Date())
            gameIdString = "daily-\(dateString)"
        } else {
            gameIdString = self.gameId?.uuidString ?? UUID().uuidString
        }
        
        return GameModel(
            gameId: gameIdString,
            encrypted: self.encrypted ?? "",
            solution: self.solution ?? "",
            currentDisplay: self.currentDisplay ?? "",
            mapping: [:],
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

extension GameState {
    func loadFromGameModel(_ model: GameModel) {
        self.currentGame = model
        self.isDailyChallenge = model.gameId?.hasPrefix("daily-") ?? false
    }
}

// Keep existing helper views
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

struct DailyInfoSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationViewWrapper {
            VStack(spacing: 20) {
                Text("Daily Challenge")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                VStack(alignment: .leading, spacing: 16) {
                    Label("New puzzle every day at midnight", systemImage: "calendar")
                    Label("Everyone gets the same puzzle", systemImage: "globe")
                    Label("Build your streak!", systemImage: "flame")
                    Label("Compare scores on the leaderboard", systemImage: "trophy")
                }
                .font(.body)
                .padding()
                
                Spacer()
                
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding()
            }
            .navigationTitle("About Daily")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
