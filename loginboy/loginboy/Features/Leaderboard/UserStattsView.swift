import SwiftUI
import CoreData

struct UserStatsView: View {
    @EnvironmentObject var userState: UserState
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var detailedStats: DetailedUserStats?
    
    private let coreData = CoreDataStack.shared
    
    var body: some View {
        ThemedDataDisplay(title: "Your Statistics") {
            if isLoading {
                ThemedLoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else if let stats = detailedStats {
                ScrollView {
                    VStack(spacing: 24) {
                        // Overview Cards Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ThemedStatCard(
                                title: "Games Played",
                                value: "\(stats.totalGamesPlayed)",
                                icon: "gamecontroller.fill",
                                trend: nil
                            )
                            
                            ThemedStatCard(
                                title: "Games Won",
                                value: "\(stats.gamesWon)",
                                icon: "trophy.fill",
                                trend: nil
                            )
                            
                            ThemedStatCard(
                                title: "Win Rate",
                                value: "\(Int(stats.winPercentage))%",
                                icon: "percent",
                                trend: nil
                            )
                            
                            ThemedStatCard(
                                title: "Total Score",
                                value: "\(stats.totalScore)",
                                icon: "star.fill",
                                trend: nil
                            )
                            
                            ThemedStatCard(
                                title: "Average Score",
                                value: String(format: "%.0f", stats.averageScore),
                                icon: "chart.line.uptrend.xyaxis",
                                trend: nil
                            )
                            
                            ThemedStatCard(
                                title: "Avg Time",
                                value: formatTime(Int(stats.averageTime)),
                                icon: "clock.fill",
                                trend: nil
                            )
                        }
                        .padding(.horizontal)
                        
                        // Streaks Section
                        HStack(spacing: 16) {
                            ThemedStatCard(
                                title: "Current Streak",
                                value: "\(stats.currentStreak)",
                                icon: "flame.fill",
                                trend: nil
                            )
                            
                            ThemedStatCard(
                                title: "Best Streak",
                                value: "\(stats.bestStreak)",
                                icon: "crown.fill",
                                trend: nil
                            )
                        }
                        .padding(.horizontal)
                        
                        // Weekly Performance
                        weeklyStatsSection(stats: stats)
                        
                        // Top Scores Table
                        topScoresSection(stats: stats)
                        
                        // Game Type Breakdown
                        gameBreakdownSection(stats: stats)
                    }
                    .padding(.bottom, 24)
                }
            } else {
                ThemedEmptyState(
                    message: "No statistics yet.\nPlay some games to see your stats!",
                    icon: "chart.bar"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            refreshStats()
        }
        .refreshable {
            refreshStats()
        }
    }
    
    // MARK: - Sections
    
    private func weeklyStatsSection(stats: DetailedUserStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 16) {
                ThemedStatCard(
                    title: "Weekly Score",
                    value: "\(stats.weeklyStats.totalScore)",
                    icon: "calendar",
                    trend: calculateWeeklyTrend(current: stats.weeklyStats.totalScore)
                )
                
                ThemedStatCard(
                    title: "Games This Week",
                    value: "\(stats.weeklyStats.gamesPlayed)",
                    icon: "calendar.badge.clock",
                    trend: nil
                )
            }
            .padding(.horizontal)
        }
    }
    
    private func topScoresSection(stats: DetailedUserStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Scores")
                .font(.headline)
                .padding(.horizontal)
            
            if !stats.topScores.isEmpty {
                ThemedTableHeader(columns: ["Rank", "Score", "Time", "Mistakes", "Date"])
                
                ForEach(Array(stats.topScores.enumerated()), id: \.offset) { index, score in
                    ThemedDataRow(
                        data: [
                            "#\(index + 1)",
                            "\(score.score)",
                            formatTime(score.timeTaken),
                            "\(score.mistakes)",
                            formatDate(score.date)
                        ],
                        isHighlighted: score.isDaily
                    )
                    .padding(.vertical, 2)
                }
                .padding(.horizontal)
            } else {
                Text("No completed games yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }
    
    private func gameBreakdownSection(stats: DetailedUserStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Game Breakdown")
                .font(.headline)
                .padding(.horizontal)
            
            ThemedTableHeader(columns: ["Type", "Count", "Percentage"])
            
            ThemedDataRow(
                data: [
                    "Daily Challenges",
                    "\(stats.dailyGamesCompleted)",
                    "\(calculatePercentage(stats.dailyGamesCompleted, of: stats.totalGamesPlayed))%"
                ],
                isHighlighted: false
            )
            .padding(.vertical, 2)
            .padding(.horizontal)
            
            ThemedDataRow(
                data: [
                    "Custom Games",
                    "\(stats.customGamesCompleted)",
                    "\(calculatePercentage(stats.customGamesCompleted, of: stats.totalGamesPlayed))%"
                ],
                isHighlighted: false
            )
            .padding(.vertical, 2)
            .padding(.horizontal)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error loading statistics")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Try Again") {
                refreshStats()
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func refreshStats() {
        isLoading = true
        errorMessage = nil
        
        // Calculate stats from local Core Data
        let context = coreData.mainContext
        
        guard userState.isAuthenticated, !userState.userId.isEmpty else {
            isLoading = false
            detailedStats = nil
            return
        }
        
        do {
            let stats = try calculateDetailedStats(context: context, userId: userState.userId)
            detailedStats = stats
            isLoading = false
        } catch {
            errorMessage = "Failed to calculate statistics: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func calculateDetailedStats(context: NSManagedObjectContext, userId: String) throws -> DetailedUserStats {
        // Get user's completed games
        let gameFetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        gameFetchRequest.predicate = NSPredicate(format: "user.userId == %@ AND (hasWon == YES OR hasLost == YES)", userId)
        gameFetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastUpdateTime", ascending: false)]
        
        let completedGames = try context.fetch(gameFetchRequest)
        
        // Calculate basic stats
        let totalGamesPlayed = completedGames.count
        let gamesWon = completedGames.filter { $0.hasWon }.count
        let totalScore = completedGames.reduce(0) { $0 + Int($1.score) }
        let winPercentage = totalGamesPlayed > 0 ? (Double(gamesWon) / Double(totalGamesPlayed)) * 100 : 0
        let averageScore = totalGamesPlayed > 0 ? Double(totalScore) / Double(totalGamesPlayed) : 0
        
        // Calculate streaks by going through games chronologically
        let gamesSortedByTime = completedGames.sorted {
            ($0.lastUpdateTime ?? Date.distantPast) < ($1.lastUpdateTime ?? Date.distantPast)
        }
        
        var currentStreak = 0
        var bestStreak = 0
        var tempStreak = 0
        
        for game in gamesSortedByTime {
            if game.hasWon {
                tempStreak += 1
                bestStreak = max(bestStreak, tempStreak)
            } else {
                tempStreak = 0
            }
        }
        
        // Current streak is calculated from the end
        for game in gamesSortedByTime.reversed() {
            if game.hasWon {
                currentStreak += 1
            } else {
                break
            }
        }
        
        // Calculate weekly stats
        let now = Date()
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        let weeklyGames = completedGames.filter {
            ($0.lastUpdateTime ?? Date.distantPast) >= startOfWeek
        }
        let weeklyTotalScore = weeklyGames.reduce(0) { $0 + Int($1.score) }
        
        // Calculate average time
        let totalTime = completedGames.reduce(0.0) { total, game in
            total + (game.lastUpdateTime?.timeIntervalSince(game.startTime ?? Date()) ?? 0)
        }
        let averageTime = totalGamesPlayed > 0 ? totalTime / Double(totalGamesPlayed) : 0
        
        // Get top scores
        let topScores = completedGames
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map { game in
                TopScore(
                    score: Int(game.score),
                    timeTaken: Int(game.lastUpdateTime?.timeIntervalSince(game.startTime ?? Date()) ?? 0),
                    mistakes: Int(game.mistakes),
                    date: game.lastUpdateTime ?? Date(),
                    isDaily: game.isDaily
                )
            }
        
        // Game type breakdown
        let dailyGames = completedGames.filter { $0.isDaily }.count
        let customGames = totalGamesPlayed - dailyGames
        
        return DetailedUserStats(
            totalGamesPlayed: totalGamesPlayed,
            gamesWon: gamesWon,
            totalScore: totalScore,
            winPercentage: winPercentage,
            averageScore: averageScore,
            averageTime: averageTime,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            lastPlayedDate: completedGames.first?.lastUpdateTime,
            weeklyStats: WeeklyStats(
                gamesPlayed: weeklyGames.count,
                totalScore: weeklyTotalScore
            ),
            topScores: Array(topScores),
            dailyGamesCompleted: dailyGames,
            customGamesCompleted: customGames
        )
    }
    
    private func calculatePercentage(_ value: Int, of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(value) / Double(total)) * 100)
    }
    
    private func calculateWeeklyTrend(current: Int) -> Double? {
        // This would compare to last week's score
        // For now, return nil or implement comparison logic
        return nil
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Data Models

struct DetailedUserStats {
    let totalGamesPlayed: Int
    let gamesWon: Int
    let totalScore: Int
    let winPercentage: Double
    let averageScore: Double
    let averageTime: Double
    let currentStreak: Int
    let bestStreak: Int
    let lastPlayedDate: Date?
    let weeklyStats: WeeklyStats
    let topScores: [TopScore]
    let dailyGamesCompleted: Int
    let customGamesCompleted: Int
}

struct WeeklyStats {
    let gamesPlayed: Int
    let totalScore: Int
}

struct TopScore: Identifiable {
    let id = UUID()
    let score: Int
    let timeTaken: Int
    let mistakes: Int
    let date: Date
    let isDaily: Bool
}
