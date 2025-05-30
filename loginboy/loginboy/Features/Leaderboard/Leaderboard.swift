import SwiftUI
import CoreData

struct LeaderboardEntry: Identifiable {
    let rank: Int
    let username: String
    let userId: String
    let score: Int
    let gamesPlayed: Int
    let avgScore: Double
    let isCurrentUser: Bool
    
    var id: String { userId }
}

struct EntryRow: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack {
            Text("#\(entry.rank)")
                .fontWeight(.bold)
                .frame(width: 60, alignment: .leading)
            
            Text(entry.username)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
            
            Text("\(entry.score)")
                .fontWeight(.medium)
                .frame(width: 80, alignment: .trailing)
            
            Text("\(entry.gamesPlayed)")
                .frame(width: 60, alignment: .trailing)
            
            Text(String(format: "%.1f", entry.avgScore))
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal)
    }
}

struct LeaderboardView: View {
    @EnvironmentObject var userState: UserState
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var entries: [LeaderboardEntry] = []
    @State private var currentUserEntry: LeaderboardEntry?
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var selectedPeriod = "all-time"
    
    // Core Data access
    private let coreData = CoreDataStack.shared
    
    var body: some View {
        VStack {
            // Header
            Text("Leaderboard")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            // Period selector
            Picker("Time Period", selection: $selectedPeriod) {
                Text("All Time").tag("all-time")
                Text("This Week").tag("weekly")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: selectedPeriod) { _, _ in
                currentPage = 1
                loadLeaderboard()
            }
            
            if isLoading {
                ProgressView("Loading leaderboard...")
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                        .padding()
                    
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Try Again") {
                        loadLeaderboard()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !entries.isEmpty {
                VStack {
                    // Table header
                    HStack {
                        Text("Rank")
                            .fontWeight(.bold)
                            .frame(width: 60, alignment: .leading)
                        
                        Text("Player")
                            .fontWeight(.bold)
                            .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                        
                        Text("Score")
                            .fontWeight(.bold)
                            .frame(width: 80, alignment: .trailing)
                        
                        Text("Games")
                            .fontWeight(.bold)
                            .frame(width: 60, alignment: .trailing)
                        
                        Text("Avg")
                            .fontWeight(.bold)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Show current user entry at top if not in visible range
                            if let currentUserEntry = currentUserEntry,
                               !entries.contains(where: { $0.userId == userState.userId }) {
                                EntryRow(entry: currentUserEntry)
                                    .padding(.vertical, 8)
                                    .background(Color.yellow.opacity(0.2))
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                    .padding(.horizontal)
                            }
                            
                            // Regular entries
                            ForEach(entries) { entry in
                                EntryRow(entry: entry)
                                    .padding(.vertical, 8)
                                    .background(entry.isCurrentUser ? Color.green.opacity(0.2) : Color.clear)
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Pagination controls
                    HStack {
                        Button(action: {
                            if currentPage > 1 {
                                currentPage -= 1
                                loadLeaderboard()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .padding(.horizontal, 8)
                        }
                        .disabled(currentPage <= 1)
                        .opacity(currentPage <= 1 ? 0.5 : 1)
                        
                        Text("Page \(currentPage) of \(totalPages)")
                            .font(.caption)
                        
                        Button(action: {
                            if currentPage < totalPages {
                                currentPage += 1
                                loadLeaderboard()
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .padding(.horizontal, 8)
                        }
                        .disabled(currentPage >= totalPages)
                        .opacity(currentPage >= totalPages ? 0.5 : 1)
                    }
                    .padding()
                }
            } else {
                VStack {
                    Image(systemName: "trophy")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                        .padding()
                    
                    Text("No leaderboard data available")
                        .foregroundColor(.secondary)
                    
                    Text("Games need to be synced from other players")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    Button("Refresh") {
                        loadLeaderboard()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.top)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.bottom)
        .onAppear {
            loadLeaderboard()
        }
        .refreshable {
            loadLeaderboard()
        }
    }
    
    // MARK: - Local Leaderboard Calculation
    
    private func loadLeaderboard() {
        isLoading = true
        errorMessage = nil
        
        // Calculate leaderboard from local Core Data
        let context = coreData.mainContext
        
        do {
            var leaderboardData: [(userId: String, username: String, totalScore: Int, gamesPlayed: Int, avgScore: Double)] = []
            
            if selectedPeriod == "weekly" {
                leaderboardData = try calculateWeeklyLeaderboard(context: context)
            } else {
                leaderboardData = try calculateAllTimeLeaderboard(context: context)
            }
            
            // Sort by total score descending
            leaderboardData.sort { $0.totalScore > $1.totalScore }
            
            // Convert to LeaderboardEntry objects with ranks
            var allEntries: [LeaderboardEntry] = []
            var currentUserFound = false
            
            for (index, data) in leaderboardData.enumerated() {
                let rank = index + 1
                let isCurrentUser = data.userId == userState.userId
                
                let entry = LeaderboardEntry(
                    rank: rank,
                    username: data.username,
                    userId: data.userId,
                    score: data.totalScore,
                    gamesPlayed: data.gamesPlayed,
                    avgScore: data.avgScore,
                    isCurrentUser: isCurrentUser
                )
                
                allEntries.append(entry)
                
                if isCurrentUser {
                    currentUserFound = true
                    currentUserEntry = entry
                }
            }
            
            // If current user not found but they have games, create entry with 0 scores
            if !currentUserFound && userState.isAuthenticated {
                currentUserEntry = LeaderboardEntry(
                    rank: allEntries.count + 1,
                    username: userState.username,
                    userId: userState.userId,
                    score: 0,
                    gamesPlayed: 0,
                    avgScore: 0,
                    isCurrentUser: true
                )
            }
            
            // Paginate results
            let pageSize = 10
            totalPages = max(1, (allEntries.count + pageSize - 1) / pageSize)
            
            let startIndex = (currentPage - 1) * pageSize
            let endIndex = min(startIndex + pageSize, allEntries.count)
            
            if startIndex < allEntries.count {
                entries = Array(allEntries[startIndex..<endIndex])
            } else {
                entries = []
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func calculateAllTimeLeaderboard(context: NSManagedObjectContext) throws -> [(userId: String, username: String, totalScore: Int, gamesPlayed: Int, avgScore: Double)] {
        // Get all users with stats
        let userFetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        userFetchRequest.predicate = NSPredicate(format: "stats != nil")
        
        let users = try context.fetch(userFetchRequest)
        
        return users.compactMap { user in
            guard let stats = user.stats,
                  let userId = user.userId,
                  let username = user.username,
                  stats.gamesPlayed > 0 else { return nil }
            
            let totalScore = Int(stats.totalScore)
            let gamesPlayed = Int(stats.gamesPlayed)
            let avgScore = gamesPlayed > 0 ? Double(totalScore) / Double(gamesPlayed) : 0
            
            return (userId: userId, username: username, totalScore: totalScore, gamesPlayed: gamesPlayed, avgScore: avgScore)
        }
    }
    
    private func calculateWeeklyLeaderboard(context: NSManagedObjectContext) throws -> [(userId: String, username: String, totalScore: Int, gamesPlayed: Int, avgScore: Double)] {
        // Calculate start of current week
        let now = Date()
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        // Get all completed games from this week
        let gameFetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        gameFetchRequest.predicate = NSPredicate(format: "lastUpdateTime >= %@ AND (hasWon == YES OR hasLost == YES)", startOfWeek as NSDate)
        
        let weeklyGames = try context.fetch(gameFetchRequest)
        
        // Group by user and calculate weekly scores
        var userWeeklyData: [String: (username: String, totalScore: Int, gamesPlayed: Int)] = [:]
        
        for game in weeklyGames {
            guard let user = game.user,
                  let userId = user.userId,
                  let username = user.username else { continue }
            
            let currentData = userWeeklyData[userId] ?? (username: username, totalScore: 0, gamesPlayed: 0)
            userWeeklyData[userId] = (
                username: username,
                totalScore: currentData.totalScore + Int(game.score),
                gamesPlayed: currentData.gamesPlayed + 1
            )
        }
        
        return userWeeklyData.map { (userId, data) in
            let avgScore = data.gamesPlayed > 0 ? Double(data.totalScore) / Double(data.gamesPlayed) : 0
            return (userId: userId, username: data.username, totalScore: data.totalScore, gamesPlayed: data.gamesPlayed, avgScore: avgScore)
        }
    }
}
