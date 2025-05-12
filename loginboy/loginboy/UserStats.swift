import SwiftUI

// MARK: - Models
struct TopScore: Identifiable, Codable {
    let score: Int
    let time_taken: Int
    let date: String
    
    var id: String { date } // Using date as unique identifier
    
    // Computed property for formatted time
    var formattedTime: String {
        let minutes = time_taken / 60
        let seconds = time_taken % 60
        return "\(minutes)m \(seconds)s"
    }
    
    // Computed property for formatted date
    var formattedDate: String {
        if let date = ISO8601DateFormatter().date(from: date) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        return date
    }
}

struct WeeklyStats: Codable {
    let score: Int
    let games_played: Int
}

struct UserStatsResponse: Codable {
    let user_id: String
    let current_streak: Int
    let max_streak: Int
    let current_noloss_streak: Int
    let max_noloss_streak: Int
    let total_games_played: Int
    let games_won: Int
    let win_percentage: Double
    let cumulative_score: Int
    let highest_weekly_score: Int
    let last_played_date: String?
    let weekly_stats: WeeklyStats
    let top_scores: [TopScore]
}

// MARK: - UserStatsService
class UserStatsService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userStats: UserStatsResponse?
    
    private let authService: AuthService
    
    init(authService: AuthService) {
        self.authService = authService
    }
    
    func fetchUserStats() {
        guard let token = authService.getAccessToken() else {
            self.errorMessage = "You need to be logged in to view your stats"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(authService.baseURL)/api/user_stats") else {
            self.isLoading = false
            self.errorMessage = "Invalid URL configuration"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid response from server"
                    return
                }
                
                // Log response details for debugging
                print("User Stats API Response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 401 {
                    self.errorMessage = "Authentication required. Please log in again."
                    self.authService.logout() // Token might be expired, log out
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    // Try to parse error message
                    if let data = data, let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMsg = errorJson["error"] as? String {
                        self.errorMessage = errorMsg
                    } else {
                        self.errorMessage = "Error fetching stats (Status \(httpResponse.statusCode))"
                    }
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received from server"
                    return
                }
                
                // Log response data for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("User Stats Response: \(responseString)")
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(UserStatsResponse.self, from: data)
                    self.userStats = response
                } catch {
                    self.errorMessage = "Failed to parse user stats data: \(error.localizedDescription)"
                    print("JSON parsing error: \(error)")
                    
                    // Log the JSON structure for debugging
                    if let json = try? JSONSerialization.jsonObject(with: data) {
                        print("Raw JSON: \(json)")
                    }
                }
            }
        }.resume()
    }
}

// MARK: - UserStatsView
struct UserStatsView: View {
    @StateObject private var statsService: UserStatsService
    @EnvironmentObject var authService: AuthService
    
    // Initialize with AuthService
    init(authService: AuthService) {
        _statsService = StateObject(wrappedValue: UserStatsService(authService: authService))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with username
                Text("\(authService.username)'s Stats")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                if statsService.isLoading {
                    // Loading state
                    ProgressView("Loading your stats...")
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: 200)
                } else if let errorMessage = statsService.errorMessage {
                    // Error state
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                            .padding()
                        
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Try Again") {
                            statsService.fetchUserStats()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                } else if let stats = statsService.userStats {
                    // Stats content
                    VStack(spacing: 24) {
                        // Overall Stats Card
                        StatsCard(title: "Overall Performance") {
                            VStack(spacing: 12) {
                                StatRow(title: "Games Played", value: "\(stats.total_games_played)")
                                StatRow(title: "Games Won", value: "\(stats.games_won)")
                                StatRow(title: "Win Rate", value: "\(stats.win_percentage)%")
                                StatRow(title: "Total Score", value: "\(stats.cumulative_score)")
                                
                                if let lastPlayed = stats.last_played_date {
                                    StatRow(title: "Last Played", value: formatDate(lastPlayed))
                                }
                            }
                        }
                        
                        // Streaks Card
                        StatsCard(title: "Streaks") {
                            VStack(spacing: 12) {
                                StatRow(title: "Current Streak", value: "\(stats.current_streak)")
                                StatRow(title: "Best Streak", value: "\(stats.max_streak)")
                                StatRow(title: "Current No-Loss", value: "\(stats.current_noloss_streak)")
                                StatRow(title: "Best No-Loss", value: "\(stats.max_noloss_streak)")
                            }
                        }
                        
                        // Weekly Stats Card
                        StatsCard(title: "This Week") {
                            VStack(spacing: 12) {
                                StatRow(title: "Games Played", value: "\(stats.weekly_stats.games_played)")
                                StatRow(title: "Score", value: "\(stats.weekly_stats.score)")
                                StatRow(title: "Highest Weekly", value: "\(stats.highest_weekly_score)")
                                
                                if stats.weekly_stats.games_played > 0 {
                                    StatRow(
                                        title: "Average Score",
                                        value: String(format: "%.1f", Double(stats.weekly_stats.score) / Double(stats.weekly_stats.games_played))
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
                                
                                if stats.top_scores.isEmpty {
                                    Text("No scores recorded yet")
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 10)
                                } else {
                                    ForEach(Array(stats.top_scores.enumerated()), id: \.element.id) { index, score in
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
                                        
                                        if index < stats.top_scores.count - 1 {
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
                            statsService.fetchUserStats()
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
            statsService.fetchUserStats()
        }
        .refreshable {
            statsService.fetchUserStats()
        }
    }
    
    // Helper to format ISO dates
    private func formatDate(_ isoDate: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoDate) else {
            return "Unknown"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Stats Components
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

// MARK: - Preview
struct UserStatsView_Previews: PreviewProvider {
    static var previews: some View {
        let authService = AuthService()
        authService.username = "TestUser"
        
        return UserStatsView(authService: authService)
            .environmentObject(authService)
    }
}

//
//  UserStats.swift
//  loginboy
//
//  Created by Daniel Horsley on 12/05/2025.
//

