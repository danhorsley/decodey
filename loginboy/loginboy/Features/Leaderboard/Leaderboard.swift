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
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Text("Leaderboard")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: loadLeaderboard) {
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
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                    Text("Loading leaderboard...")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                        .padding()
                    
                    Text("Error loading leaderboard")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Try Again") {
                        loadLeaderboard()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle)
                    .padding(.top)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !entries.isEmpty || currentUserEntry != nil {
                VStack(spacing: 0) {
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
                    .background(secondaryBackgroundColor)
                    
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
                                
                                if entry.id != entries.last?.id {
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                        .padding(.horizontal)
                                }
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
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text("Play some games to see the leaderboard!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    
                    Button("Refresh") {
                        loadLeaderboard()
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle)
                    .padding(.top)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(groupedBackgroundColor)
        .onAppear {
            loadLeaderboard()
        }
        .refreshable {
            await loadLeaderboardAsync()
        }
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
    
    private var groupedBackgroundColor: Color {
        #if os(iOS)
        return Color(.systemGroupedBackground)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
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

// Keep the existing EntryRow component
struct EntryRow: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack {
            // Rank with medal for top 3
            HStack(spacing: 4) {
                if entry.rank <= 3 {
                    Image(systemName: medalIcon(for: entry.rank))
                        .foregroundColor(medalColor(for: entry.rank))
                        .font(.title3)
                }
                Text("#\(entry.rank)")
                    .fontWeight(.bold)
            }
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
    
    private func medalIcon(for rank: Int) -> String {
        switch rank {
        case 1: return "medal.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return ""
        }
    }
    
    private func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(white: 0.75) // Silver
        case 3: return .orange // Bronze
        default: return .clear
        }
    }
}
