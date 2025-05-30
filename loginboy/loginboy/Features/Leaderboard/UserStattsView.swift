import SwiftUI
import CoreData

struct UserStatsView: View {
    @EnvironmentObject var userState: UserState
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var detailedStats: DetailedUserStats?
    
    private let coreData = CoreDataStack.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Text("Your Statistics")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: refreshStats) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
                .disabled(isLoading)
            }
            .padding()
            .background(primaryBackgroundColor)
            .overlay(
                Divider(),
                alignment: .bottom
            )
            
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Text("Calculating statistics...")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                        .padding()
                    
                    Text("Error loading statistics")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Try Again") {
                        refreshStats()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let stats = detailedStats {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Overview Cards
                        overviewSection(stats: stats)
                        
                        // Streaks Section
                        streaksSection(stats: stats)
                        
                        // Time-based Stats
                        timeBasedSection(stats: stats)
                        
                        // Top Scores
                        topScoresSection(stats: stats)
                        
                        // Game Breakdown
                        gameBreakdownSection(stats: stats)
                    }
                    .padding()
                }
            } else {
                // No stats available
                VStack {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                        .padding()
                    
                    Text("No Statistics Yet")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Play some games to see your statistics!")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(groupedBackgroundColor)
        .onAppear {
            refreshStats()
        }
        .refreshable {
            refreshStats()
        }
    }
    
    // MARK: - Sections
    
    private func overviewSection(stats: DetailedUserStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Games Played",
                    value: "\(stats.totalGamesPlayed)",
                    icon: "gamecontroller.fill",
                    color: .blue,
                    backgroundColor: tertiaryBackgroundColor
                )
                
                StatCard(
                    title: "Games Won",
                    value: "\(stats.gamesWon)",
                    icon: "trophy.fill",
                    color: .green,
                    backgroundColor: tertiaryBackgroundColor
                )
                
                StatCard(
                    title: "Win Rate",
                    value: "\(Int(stats.winPercentage))%",
                    icon: "percent",
                    color: .orange,
                    backgroundColor: tertiaryBackgroundColor
                )
                
                StatCard(
                    title: "Total Score",
                    value: "\(stats.totalScore)",
                    icon: "star.fill",
                    color: .purple,
                    backgroundColor: tertiaryBackgroundColor
                )
            }
        }
        .padding()
        .background(secondaryBackgroundColor)
        .cornerRadius(12)
    }
    
    private func streaksSection(stats: DetailedUserStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Streaks")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Current Streak",
                    value: "\(stats.currentStreak)",
                    icon: "flame.fill",
                    color: .red,
                    backgroundColor: tertiaryBackgroundColor
                )
                
                StatCard(
                    title: "Best Streak",
                    value: "\(stats.bestStreak)",
                    icon: "crown.fill",
                    color: .yellow,
                    backgroundColor: tertiaryBackgroundColor
                )
            }
        }
        .padding()
        .background(secondaryBackgroundColor)
        .cornerRadius(12)
    }
    
    private func timeBasedSection(stats: DetailedUserStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Weekly Score",
                    value: "\(stats.weeklyStats.totalScore)",
                    icon: "calendar",
                    color: .cyan,
                    backgroundColor: tertiaryBackgroundColor
                )
                
                StatCard(
                    title: "Games This Week",
                    value: "\(stats.weeklyStats.gamesPlayed)",
                    icon: "calendar.badge.clock",
                    color: .indigo,
                    backgroundColor: tertiaryBackgroundColor
                )
            }
            
            if let lastPlayed = stats.lastPlayedDate {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text("Last played: \(formatRelativeDate(lastPlayed))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(secondaryBackgroundColor)
        .cornerRadius(12)
    }
    
    private func topScoresSection(stats: DetailedUserStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Scores")
                .font(.headline)
                .fontWeight(.semibold)
            
            if !stats.topScores.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(stats.topScores.enumerated()), id: \.offset) { index, score in
                        HStack {
                            Text("#\(index + 1)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(score.score) points")
                                    .font(.headline)
                                
                                Text("\(formatTime(score.timeTaken)) • \(score.mistakes) mistakes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(formatDate(score.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if score.isDaily {
                                    Text("Daily")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(tertiaryBackgroundColor)
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("No completed games yet - play some games to see your top scores!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .padding()
        .background(secondaryBackgroundColor)
        .cornerRadius(12)
    }
    
    private func gameBreakdownSection(stats: DetailedUserStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Game Breakdown")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Average Score")
                    Spacer()
                    Text(String(format: "%.1f", stats.averageScore))
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Average Time")
                    Spacer()
                    Text(formatTime(Int(stats.averageTime)))
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Daily Games")
                    Spacer()
                    Text("\(stats.dailyGamesCompleted)")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Custom Games")
                    Spacer()
                    Text("\(stats.customGamesCompleted)")
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(secondaryBackgroundColor)
        .cornerRadius(12)
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
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Cross-platform colors
    
    private var primaryBackgroundColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    private var secondaryBackgroundColor: Color {
        #if os(iOS)
        return Color(.secondarySystemBackground)
        #else
        return Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    private var tertiaryBackgroundColor: Color {
        #if os(iOS)
        return Color(.tertiarySystemBackground)
        #else
        return Color(NSColor.textBackgroundColor)
        #endif
    }
    
    private var groupedBackgroundColor: Color {
        #if os(iOS)
        return Color(.systemGroupedBackground)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
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

    // MARK: - StatCard Component (nested inside UserStatsView)
    
    private struct StatCard: View {
        let title: String
        let value: String
        let icon: String
        let color: Color
        let backgroundColor: Color
        
        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .cornerRadius(8)
        }
    }
//
//  UserStattsView.swift
//  loginboy
//
//  Created by Daniel Horsley on 30/05/2025.
//

