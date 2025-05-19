import SwiftUI
import RealmSwift

/// Extension for safely accessing array indices
//extension Array {
//    subscript(safe index: Index) -> Element? {
//        return indices.contains(index) ? self[index] : nil
//    }
//}

/// Extension for Results collection to safely access indices
extension Results {
    subscript(safe index: Int) -> Element? {
        return index < count ? self[index] : nil
    }
}

struct UserStatsView: View {
    @EnvironmentObject var userState: UserState
    @State private var isLoading = false
    
    // Realm access
    private let realm = RealmManager.shared.getRealm()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with username
                Text("\(userState.username)'s Stats")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                if isLoading {
                    // Loading state
                    ProgressView("Loading your stats...")
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: 200)
                } else if !userState.isAuthenticated {
                    // Not logged in state
                    VStack {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                            .padding()
                        
                        Text("Please log in to view your stats")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .padding()
                } else if let stats = userState.stats {
                    // Stats content
                    VStack(spacing: 24) {
                        // Overall Stats Card
                        StatsCard(title: "Overall Performance") {
                            VStack(spacing: 12) {
                                StatRow(title: "Games Played", value: "\(stats.gamesPlayed)")
                                StatRow(title: "Games Won", value: "\(stats.gamesWon)")
                                StatRow(title: "Win Rate", value: String(format: "%.1f%%", stats.winPercentage))
                                StatRow(title: "Total Score", value: "\(stats.totalScore)")
                            }
                        }
                        
                        // Streaks Card
                        StatsCard(title: "Streaks") {
                            VStack(spacing: 12) {
                                StatRow(title: "Current Streak", value: "\(stats.currentStreak)")
                                StatRow(title: "Best Streak", value: "\(stats.bestStreak)")
                            }
                        }
                        
                        // Weekly Stats Card
                        StatsCard(title: "This Week") {
                            VStack(spacing: 12) {
                                StatRow(title: "Weekly Games", value: "\(getWeeklyGames())")
                                StatRow(title: "Weekly Score", value: "\(getWeeklyScore())")
                                
                                if getWeeklyGames() > 0 {
                                    StatRow(
                                        title: "Weekly Average",
                                        value: String(format: "%.1f", Double(getWeeklyScore()) / Double(getWeeklyGames()))
                                    )
                                }
                            }
                        }
                        
                        // Top Scores Card
                        StatsCard(title: "Top Scores") {
                            VStack(spacing: 4) {
                                // Top scores table header
                                HStack {
                                    Text("Rank")
                                        .fontWeight(.medium)
                                        .frame(width: 50, alignment: .leading)
                                    
                                    Text("Score")
                                        .fontWeight(.medium)
                                        .frame(width: 70, alignment: .trailing)
                                    
                                    Text("Time")
                                        .fontWeight(.medium)
                                        .frame(width: 80, alignment: .trailing)
                                    
                                    Text("Date")
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 8)
                                
                                let topScores = getTopScores()
                                
                                if topScores.isEmpty {
                                    Text("No scores recorded yet")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 10)
                                } else {
                                    ForEach(Array(topScores.enumerated()), id: \.element.id) { index, score in
                                        HStack {
                                            Text("#\(index + 1)")
                                                .fontWeight(.bold)
                                                .frame(width: 50, alignment: .leading)
                                            
                                            Text("\(score.score)")
                                                .fontWeight(.semibold)
                                                .frame(width: 70, alignment: .trailing)
                                            
                                            Text(score.formattedTime)
                                                .frame(width: 80, alignment: .trailing)
                                            
                                            Text(score.formattedDate)
                                                .foregroundColor(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                        .padding(.vertical, 4)
                                        
                                        if index < topScores.count - 1 {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    // Empty state
                    VStack {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                            .padding()
                        
                        Text("No stats available yet")
                            .foregroundColor(.secondary)
                        
                        Button("Refresh") {
                            refreshStats()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
                
                Spacer()
            }
        }
        .onAppear {
            refreshStats()
        }
        .refreshable {
            refreshStats()
        }
    }
    
    // MARK: - Data Methods
    
    private func refreshStats() {
        isLoading = true
        
        // Refresh user stats
        userState.refreshStats()
        
        isLoading = false
    }
    
    // Get weekly games count
    private func getWeeklyGames() -> Int {
        guard userState.isAuthenticated, let realm = realm else { return 0 }
        
        // Get one week ago date
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        // Get games played in the last week
        let games = realm.objects(GameRealm.self)
            .filter("userId == %@ AND lastUpdateTime >= %@", userState.userId, oneWeekAgo)
        
        return games.count
    }
    
    // Get weekly score total
    private func getWeeklyScore() -> Int {
        guard userState.isAuthenticated, let realm = realm else { return 0 }
        
        // Get one week ago date
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        // Get games played in the last week
        let games = realm.objects(GameRealm.self)
            .filter("userId == %@ AND lastUpdateTime >= %@ AND hasWon == true", userState.userId, oneWeekAgo)
        
        // Sum scores
        var totalScore = 0
        for game in games {
            // Calculate score if not stored
            if let storedScore = game.score {
                totalScore += storedScore
            } else {
                // Convert to regular Game and calculate score manually
                var tempGame = Game(
                    gameId: game.gameId,
                    encrypted: game.encrypted,
                    solution: game.solution,
                    currentDisplay: game.currentDisplay,
                    mapping: [:],
                    correctMappings: [:],
                    guessedMappings: [:],
                    mistakes: game.mistakes,
                    maxMistakes: game.maxMistakes,
                    hasWon: game.hasWon,
                    hasLost: game.hasLost,
                    difficulty: game.difficulty,
                    startTime: game.startTime,
                    lastUpdateTime: game.lastUpdateTime
                )
                totalScore += tempGame.calculateScore()
            }
        }
        
        return totalScore
    }
    
    // Model for top scores
    struct TopScore: Identifiable {
        let id = UUID()
        let score: Int
        let timeTaken: Int
        let date: Date
        
        var formattedTime: String {
            let minutes = timeTaken / 60
            let seconds = timeTaken % 60
            return "\(minutes)m \(seconds)s"
        }
        
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
    
    // Get top scores
    private func getTopScores() -> [TopScore] {
        guard userState.isAuthenticated, let realm = realm else { return [] }
        
        // Get completed games
        let games = realm.objects(GameRealm.self)
            .filter("userId == %@ AND hasWon == true", userState.userId)
            .sorted(byKeyPath: "score", ascending: false)
            .prefix(5) // Top 5 scores
        
        // Convert to top scores
        var topScores: [TopScore] = []
        
        for game in games {
            // If score and time are stored directly
            if let score = game.score, let timeTaken = game.timeTaken {
                topScores.append(TopScore(
                    score: score,
                    timeTaken: timeTaken,
                    date: game.lastUpdateTime
                ))
            } else {
                // Calculate score manually if not stored
                let calculatedScore = Game(
                    gameId: game.gameId,
                    encrypted: game.encrypted,
                    solution: game.solution,
                    currentDisplay: game.currentDisplay,
                    mapping: [:],
                    correctMappings: [:],
                    guessedMappings: [:],
                    mistakes: game.mistakes,
                    maxMistakes: game.maxMistakes,
                    hasWon: true,
                    hasLost: false,
                    difficulty: game.difficulty,
                    startTime: game.startTime,
                    lastUpdateTime: game.lastUpdateTime
                ).calculateScore()
                
                let timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
                
                topScores.append(TopScore(
                    score: calculatedScore,
                    timeTaken: timeTaken,
                    date: game.lastUpdateTime
                ))
            }
        }
        
        return topScores
    }
}

// MARK: - Supporting Views

struct StatsCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 4)
            
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
    }
}
