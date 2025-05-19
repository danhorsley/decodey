
import SwiftUI
import CoreData

// Use the existing LeaderboardEntry model or replace with this simplified version
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
    var showDivider: Bool = false
    
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
            .onChange(of: selectedPeriod) { _, newValue in
                currentPage = 1 // Reset to first page when changing period
                fetchLeaderboard()
            }
            
            if isLoading {
                // Loading state
                ProgressView("Loading leaderboard...")
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                // Error state
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
                        fetchLeaderboard()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !entries.isEmpty {
                // Leaderboard content
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
                    
                    // Entries list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Show the users's entry at the top if not in the visible range
                            if let currentUserEntry = currentUserEntry, !entries.contains(where: { $0.userId == userState.userId }) {
                                EntryRow(entry: currentUserEntry, showDivider: true)
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
                                fetchLeaderboard()
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
                                fetchLeaderboard()
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
                // Empty state
                VStack {
                    Image(systemName: "trophy")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                        .padding()
                    
                    Text("No leaderboard data available")
                        .foregroundColor(.secondary)
                    
                    Button("Refresh") {
                        fetchLeaderboard()
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
            fetchLeaderboard()
        }
    }
    
    // Fetch leaderboard data - either from Core Data or API depending on needs
    private func fetchLeaderboard() {
        isLoading = true
        errorMessage = nil
        
        if selectedPeriod == "all-time" {
            // For all time, we can use local Core Data
            fetchLeaderboardFromCoreData()
        } else {
            // For weekly, we might need API data
            fetchLeaderboardFromAPI()
        }
    }
    
    // Fetch leaderboard from local Core Data
    private func fetchLeaderboardFromCoreData() {
        let context = coreData.mainContext
        
        // Get all users with stats
        let fetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        fetchRequest.predicate = NSPredicate(format: "stats != nil")
        
        do {
            // First get all users
            let users = try context.fetch(fetchRequest)
            
            // Sort by total score
            let sortedUsers = users.sorted {
                guard let stats1 = $0.stats, let stats2 = $1.stats else { return false }
                return stats1.totalScore > stats2.totalScore
            }
            
            // Convert to entries
            var leaderboardEntries: [LeaderboardEntry] = []
            var userRank = 0
            var currentUserFound = false
            
            for (index, user) in sortedUsers.enumerated() {
                guard let stats = user.stats else { continue }
                
                let rank = index + 1
                let isCurrentUser = user.userId == userState.userId
                
                let entry = LeaderboardEntry(
                    rank: rank,
                    username: user.username ?? "Unknown",
                    userId: user.userId ?? "",
                    score: Int(stats.totalScore),
                    gamesPlayed: Int(stats.gamesPlayed),
                    avgScore: stats.gamesPlayed > 0 ? Double(stats.totalScore) / Double(stats.gamesPlayed) : 0,
                    isCurrentUser: isCurrentUser
                )
                
                leaderboardEntries.append(entry)
                
                if isCurrentUser {
                    currentUserFound = true
                    userRank = rank
                    currentUserEntry = entry
                }
            }
            
            // If current user not found but has stats, add them
            if !currentUserFound && userState.isAuthenticated, let stats = userState.stats {
                currentUserEntry = LeaderboardEntry(
                    rank: userRank,
                    username: userState.username,
                    userId: userState.userId,
                    score: stats.totalScore,
                    gamesPlayed: stats.gamesPlayed,
                    avgScore: stats.averageScore,
                    isCurrentUser: true
                )
            }
            
            // Paginate results - 10 per page
            let pageSize = 10
            totalPages = max(1, (leaderboardEntries.count + pageSize - 1) / pageSize)
            
            // Calculate start and end indices
            let startIndex = (currentPage - 1) * pageSize
            let endIndex = min(startIndex + pageSize, leaderboardEntries.count)
            
            // Get entries for current page
            if startIndex < leaderboardEntries.count {
                entries = Array(leaderboardEntries[startIndex..<endIndex])
            } else {
                entries = []
            }
            
            isLoading = false
        } catch {
            print("Error fetching leaderboard data: \(error.localizedDescription)")
            errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // Fetch leaderboard from API
    private func fetchLeaderboardFromAPI() {
        guard let token = userState.authCoordinator.getAccessToken() else {
            isLoading = false
            errorMessage = "Authentication required"
            return
        }
        
        // Build URL
        guard let url = URL(string: "\(userState.authCoordinator.baseURL)/api/leaderboard") else {
            isLoading = false
            errorMessage = "Invalid URL configuration"
            return
        }
        
        // Add query parameters
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "period", value: selectedPeriod),
            URLQueryItem(name: "page", value: "\(currentPage)"),
            URLQueryItem(name: "per_page", value: "10")
        ]
        
        guard let requestURL = components?.url else {
            isLoading = false
            errorMessage = "Invalid URL configuration"
            return
        }
        
        // Create request
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Execute request
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid response from server"
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    self.errorMessage = "Server error (Status \(httpResponse.statusCode))"
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received"
                    return
                }
                
                // Parse response
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(LeaderboardResponse.self, from: data)
                    
                    // Update state
                    self.entries = response.entries.map { entry in
                        LeaderboardEntry(
                            rank: entry.rank,
                            username: entry.username,
                            userId: entry.user_id,
                            score: entry.score,
                            gamesPlayed: entry.games_played,
                            avgScore: entry.avg_score,
                            isCurrentUser: entry.is_current_user
                        )
                    }
                    
                    if let userEntry = response.currentUserEntry {
                        self.currentUserEntry = LeaderboardEntry(
                            rank: userEntry.rank,
                            username: userEntry.username,
                            userId: userEntry.user_id,
                            score: userEntry.score,
                            gamesPlayed: userEntry.games_played,
                            avgScore: userEntry.avg_score,
                            isCurrentUser: true
                        )
                    }
                    
                    self.totalPages = response.pagination.total_pages
                } catch {
                    self.errorMessage = "Failed to parse response: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

// API response model
struct LeaderboardResponse: Codable {
    let entries: [LeaderboardEntryResponse]
    let currentUserEntry: LeaderboardEntryResponse?
    let pagination: PaginationResponse
    let period: String
    
    enum CodingKeys: String, CodingKey {
        case entries
        case currentUserEntry = "current_user_entry"
        case pagination
        case period
    }
}

struct LeaderboardEntryResponse: Codable, Identifiable {
    let rank: Int
    let username: String
    let user_id: String
    let score: Int
    let games_played: Int
    let avg_score: Double
    let is_current_user: Bool
    
    var id: String { user_id }
}

struct PaginationResponse: Codable {
    let current_page: Int
    let total_pages: Int
    let total_entries: Int
    let per_page: Int
}
