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

struct LeaderboardView: View {
    @EnvironmentObject var userState: UserState
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var entries: [LeaderboardEntry] = []
    @State private var currentUserEntry: LeaderboardEntry?
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var selectedPeriod = "all-time"
    
    var body: some View {
        ThemedDataDisplay(title: "Leaderboard") {
            VStack(spacing: 0) {
                // Period selector
                Picker("Time Period", selection: $selectedPeriod) {
                    Text("All Time").tag("all-time")
                    Text("This Week").tag("weekly")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.bottom, 16)
                .onChange(of: selectedPeriod) { _, _ in
                    currentPage = 1
                    loadLeaderboard()
                }
                
                if isLoading {
                    ThemedLoadingView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    errorView(message: errorMessage)
                } else if !entries.isEmpty || currentUserEntry != nil {
                    leaderboardContent
                } else {
                    ThemedEmptyState(
                        message: "No leaderboard data available.\nPlay some games to see the leaderboard!",
                        icon: "trophy"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            loadLeaderboard()
        }
        .refreshable {
            await loadLeaderboardAsync()
        }
    }
    
    private var leaderboardContent: some View {
        VStack(spacing: 0) {
            // Table header
            ThemedTableHeader(columns: ["Rank", "Player", "Score", "Games", "Avg"])
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Show current user entry at top if not in visible range
                    if let currentUserEntry = currentUserEntry,
                       !entries.contains(where: { $0.userId == userState.userId }) {
                        ThemedDataRow(
                            data: formatEntryData(currentUserEntry),
                            isHighlighted: true
                        )
                        .padding(.vertical, 4)
                    }
                    
                    // Regular entries
                    ForEach(entries) { entry in
                        ThemedDataRow(
                            data: formatEntryData(entry),
                            isHighlighted: entry.isCurrentUser
                        )
                        .padding(.vertical, 2)
                    }
                }
            }
            
            // Pagination controls
            paginationControls
                .padding(.top, 16)
        }
    }
    
    private var paginationControls: some View {
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
    }
    
    private func formatEntryData(_ entry: LeaderboardEntry) -> [String] {
        return [
            "#\(entry.rank)",
            entry.username,
            "\(entry.score)",
            "\(entry.gamesPlayed)",
            String(format: "%.1f", entry.avgScore)
        ]
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error loading leaderboard")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Try Again") {
                loadLeaderboard()
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - API Call to Backend
    
    private func loadLeaderboard() {
        Task {
            await loadLeaderboardAsync()
        }
    }
    
    @MainActor
    private func loadLeaderboardAsync() async {
        isLoading = true
        errorMessage = nil
        
        guard let token = userState.authCoordinator.getAccessToken() else {
            errorMessage = "Authentication required"
            isLoading = false
            return
        }
        
        do {
            let response = try await fetchLeaderboardFromAPI(
                token: token,
                period: selectedPeriod,
                page: currentPage,
                perPage: 10
            )
            
            // Convert API response to our LeaderboardEntry model
            entries = response.entries.map { apiEntry in
                LeaderboardEntry(
                    rank: apiEntry.rank,
                    username: apiEntry.username,
                    userId: apiEntry.user_id,
                    score: apiEntry.score,
                    gamesPlayed: apiEntry.games_played,
                    avgScore: apiEntry.avg_score,
                    isCurrentUser: apiEntry.is_current_user
                )
            }
            
            // Set current user entry if provided
            if let apiCurrentUser = response.currentUserEntry {
                currentUserEntry = LeaderboardEntry(
                    rank: apiCurrentUser.rank,
                    username: apiCurrentUser.username,
                    userId: apiCurrentUser.user_id,
                    score: apiCurrentUser.score,
                    gamesPlayed: apiCurrentUser.games_played,
                    avgScore: apiCurrentUser.avg_score,
                    isCurrentUser: true
                )
            }
            
            // Update pagination
            currentPage = response.pagination.current_page
            totalPages = response.pagination.total_pages
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func fetchLeaderboardFromAPI(
        token: String,
        period: String,
        page: Int,
        perPage: Int
    ) async throws -> LeaderboardAPIResponse {
        
        let baseURL = userState.authCoordinator.baseURL
        
        var components = URLComponents(string: "\(baseURL)/api/leaderboard")!
        components.queryItems = [
            URLQueryItem(name: "period", value: period),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 401 {
            // Token expired, need to re-authenticate
            throw NSError(domain: "Leaderboard", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication expired. Please log in again."])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "Leaderboard", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server returned status \(httpResponse.statusCode)"])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(LeaderboardAPIResponse.self, from: data)
    }
}

// MARK: - API Response Models

struct LeaderboardAPIResponse: Codable {
    let entries: [APILeaderboardEntry]
    let currentUserEntry: APILeaderboardEntry?
    let pagination: APIPagination
    let period: String
}

struct APILeaderboardEntry: Codable {
    let rank: Int
    let username: String
    let user_id: String
    let score: Int
    let games_played: Int
    let avg_score: Double
    let is_current_user: Bool
}

struct APIPagination: Codable {
    let current_page: Int
    let total_pages: Int
    let total_entries: Int
    let per_page: Int
}
