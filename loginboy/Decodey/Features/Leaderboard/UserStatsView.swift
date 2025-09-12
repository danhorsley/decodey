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
                                value: String(format: "%.1f%%", stats.winPercentage),
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
                        
                        // Weekly Stats Section
                        weeklyStatsSection(stats: stats)
                        
                        // Top Scores Section
                        topScoresSection(stats: stats)
                        
                        // Game Breakdown Section
                        gameBreakdownSection(stats: stats)
                        
                        // Last Played
                        if let lastPlayed = stats.lastPlayedDate {
                            Text("Last played: \(formatDate(lastPlayed))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            } else {
                // Empty state
                ThemedEmptyState(
//                    title: "No Statistics Yet",
                    message: "Play some games to see your stats!",
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
        
        // For Apple Sign In users, we don't need playerName - we'll use userId
        let playerName = userState.playerName.isEmpty ? userState.username : userState.playerName
        
        // Don't check if playerName is empty if we have userId
        if userState.userId.isEmpty && playerName.isEmpty {
            isLoading = false
            detailedStats = nil
            return
        }
        
        do {
            let stats = try calculateDetailedStats(context: context, playerName: playerName)
            detailedStats = stats
            isLoading = false
        } catch {
            errorMessage = "Failed to calculate statistics: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func calculateDetailedStats(context: NSManagedObjectContext, playerName: String) throws -> DetailedUserStats {
        // Determine which user to fetch stats for
        let userFetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        
        // IMPORTANT: Use userId (primaryIdentifier) if available, otherwise fall back to username
        if !userState.userId.isEmpty {
            // User is signed in with Apple - use primaryIdentifier
            userFetchRequest.predicate = NSPredicate(format: "primaryIdentifier == %@", userState.userId)
        } else if !playerName.isEmpty {
            // Local user - use username
            userFetchRequest.predicate = NSPredicate(format: "username == %@", playerName)
        } else {
            // Show anonymous user stats
            userFetchRequest.predicate = NSPredicate(format: "primaryIdentifier == %@", "anonymous-user")
        }
        
        let users = try context.fetch(userFetchRequest)
        
        // If no user found by primary method, try fallbacks
        let user: UserCD?
        if let foundUser = users.first {
            user = foundUser
        } else if !playerName.isEmpty {
            // Try username/displayName as fallback
            userFetchRequest.predicate = NSPredicate(format: "username == %@ OR displayName == %@", playerName, playerName)
            let fallbackUsers = try context.fetch(userFetchRequest)
            user = fallbackUsers.first
        } else {
            user = nil
        }
        
        // If still no user, create empty stats
        guard let validUser = user else {
            print("⚠️ No user found for: userId='\(userState.userId)' playerName='\(playerName)', returning empty stats")
            return DetailedUserStats(
                totalGamesPlayed: 0,
                gamesWon: 0,
                totalScore: 0,
                winPercentage: 0,
                averageScore: 0,
                averageTime: 0,
                currentStreak: 0,
                bestStreak: 0,
                lastPlayedDate: nil,
                weeklyStats: WeeklyStats(gamesPlayed: 0, totalScore: 0),
                topScores: [],
                dailyGamesCompleted: 0,
                customGamesCompleted: 0
            )
        }
        
        // Get the stored stats (this includes imported legacy games)
        let userStats = validUser.stats
        let totalGamesPlayed = Int(userStats?.gamesPlayed ?? 0)
        let gamesWon = Int(userStats?.gamesWon ?? 0)
        let totalScore = Int(userStats?.totalScore ?? 0)
        let currentStreak = Int(userStats?.currentStreak ?? 0)
        let bestStreak = Int(userStats?.bestStreak ?? 0)
        let averageTime = userStats?.averageTime ?? 0
        let lastPlayedDate = userStats?.lastPlayedDate
        
        // Calculate derived stats
        let winPercentage = totalGamesPlayed > 0 ? (Double(gamesWon) / Double(totalGamesPlayed)) * 100 : 0
        let averageScore = totalGamesPlayed > 0 ? Double(totalScore) / Double(totalGamesPlayed) : 0
        
        // Now get actual game records for detailed breakdowns
        let gameFetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        gameFetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "user == %@", validUser),
            NSPredicate(format: "(hasWon == YES OR hasLost == YES)")
        ])
        gameFetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastUpdateTime", ascending: false)]
        
        let completedGames = try context.fetch(gameFetchRequest)
        
        print("📊 Found \(completedGames.count) completed games for \(validUser.displayName ?? validUser.username ?? "user")")
        
        // Calculate weekly stats from actual games
        let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
        let weeklyGames = completedGames.filter { game in
            if let updateTime = game.lastUpdateTime {
                return updateTime >= oneWeekAgo
            }
            return false
        }
        
        let weeklyStats = WeeklyStats(
            gamesPlayed: weeklyGames.count,
            totalScore: weeklyGames.reduce(0) { $0 + Int($1.score) }
        )
        
        // Get top scores
        let topScores = completedGames
            .filter { $0.hasWon }
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
        
        // Count daily vs custom games
        let dailyGamesCompleted = completedGames.filter { $0.isDaily }.count
        let customGamesCompleted = completedGames.filter { !$0.isDaily }.count
        
        return DetailedUserStats(
            totalGamesPlayed: totalGamesPlayed,
            gamesWon: gamesWon,
            totalScore: totalScore,
            winPercentage: winPercentage,
            averageScore: averageScore,
            averageTime: averageTime,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            lastPlayedDate: lastPlayedDate,
            weeklyStats: weeklyStats,
            topScores: Array(topScores),
            dailyGamesCompleted: dailyGamesCompleted,
            customGamesCompleted: customGamesCompleted
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
