import SwiftUI

// Models to match your backend response
struct LeaderboardEntry: Identifiable, Codable {
    let rank: Int
    let username: String
    let user_id: String
    let score: Int
    let games_played: Int
    let avg_score: Double
    let is_current_user: Bool
    
    var id: String { user_id }
}

struct Pagination: Codable {
    let current_page: Int
    let total_pages: Int
    let total_entries: Int
    let per_page: Int
}

struct LeaderboardResponse: Codable {
    let entries: [LeaderboardEntry]
    let currentUserEntry: LeaderboardEntry?
    let pagination: Pagination
    let period: String
}

// Leaderboard service to fetch data
class LeaderboardService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var leaderboardData: LeaderboardResponse?
    
    private let authService: AuthService
    
    init(authService: AuthService) {
        self.authService = authService
    }
    
    func fetchLeaderboard(period: String = "all-time", page: Int = 1, perPage: Int = 10) {
        guard let token = authService.getAccessToken() else {
            self.errorMessage = "You need to be logged in to view the leaderboard"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Construct URL with query parameters
        var urlComponents = URLComponents(string: "\(authService.baseURL)/api/leaderboard")
        urlComponents?.queryItems = [
            URLQueryItem(name: "period", value: period),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ]
        
        guard let url = urlComponents?.url else {
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
                print("Leaderboard API Response: \(httpResponse.statusCode)")
                
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
                        self.errorMessage = "Error fetching leaderboard (Status \(httpResponse.statusCode))"
                    }
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received from server"
                    return
                }
                
                // Log response data for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Leaderboard Response: \(responseString)")
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(LeaderboardResponse.self, from: data)
                    self.leaderboardData = response
                } catch {
                    self.errorMessage = "Failed to parse leaderboard data: \(error.localizedDescription)"
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

struct LeaderboardView: View {
    @StateObject private var leaderboardService: LeaderboardService
    @State private var selectedPeriod = "all-time"
    @State private var selectedPage = 1
    
    // Initialize with AuthService
    init(authService: AuthService) {
        _leaderboardService = StateObject(wrappedValue: LeaderboardService(authService: authService))
    }
    
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
            .onChange(of: selectedPeriod) { newValue in
                selectedPage = 1 // Reset to first page when changing period
                leaderboardService.fetchLeaderboard(period: newValue, page: 1)
            }
            
            if leaderboardService.isLoading {
                // Loading state
                ProgressView("Loading leaderboard...")
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = leaderboardService.errorMessage {
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
                        leaderboardService.fetchLeaderboard(
                            period: selectedPeriod,
                            page: selectedPage
                        )
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let leaderboardData = leaderboardService.leaderboardData {
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
                            if let currentUserEntry = leaderboardData.currentUserEntry {
                                EntryRow(entry: currentUserEntry, showDivider: true)
                                    .padding(.vertical, 8)
                                    .background(Color.yellow.opacity(0.2))
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                    .padding(.horizontal)
                            }
                            
                            // Regular entries
                            ForEach(leaderboardData.entries) { entry in
                                EntryRow(entry: entry)
                                    .padding(.vertical, 8)
                                    .background(entry.is_current_user ? Color.green.opacity(0.2) : Color.clear)
                                
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Pagination controls
                    HStack {
                        Button(action: {
                            if selectedPage > 1 {
                                selectedPage -= 1
                                leaderboardService.fetchLeaderboard(
                                    period: selectedPeriod,
                                    page: selectedPage
                                )
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .padding(.horizontal, 8)
                        }
                        .disabled(selectedPage <= 1)
                        .opacity(selectedPage <= 1 ? 0.5 : 1)
                        
                        Text("Page \(selectedPage) of \(leaderboardData.pagination.total_pages)")
                            .font(.caption)
                        
                        Button(action: {
                            if selectedPage < leaderboardData.pagination.total_pages {
                                selectedPage += 1
                                leaderboardService.fetchLeaderboard(
                                    period: selectedPeriod,
                                    page: selectedPage
                                )
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .padding(.horizontal, 8)
                        }
                        .disabled(selectedPage >= leaderboardData.pagination.total_pages)
                        .opacity(selectedPage >= leaderboardData.pagination.total_pages ? 0.5 : 1)
                    }
                    .padding()
                    
                    // Stats summary
                    HStack {
                        Text("\(leaderboardData.pagination.total_entries) players")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(selectedPeriod == "weekly" ? "Weekly Rankings" : "All-Time Rankings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
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
                        leaderboardService.fetchLeaderboard(
                            period: selectedPeriod,
                            page: selectedPage
                        )
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
            leaderboardService.fetchLeaderboard(period: selectedPeriod, page: selectedPage)
        }
    }
}

// Reusable row component for leaderboard entries
struct EntryRow: View {
    let entry: LeaderboardEntry
    var showDivider: Bool = false
    
    var body: some View {
        HStack {
            // Rank with medal for top 3
            HStack(spacing: 4) {
                if entry.rank <= 3 {
                    Image(systemName: "medal.fill")
                        .foregroundColor(
                            entry.rank == 1 ? .yellow :
                            entry.rank == 2 ? .gray :
                            .brown
                        )
                }
                
                Text("\(entry.rank)")
                    .fontWeight(entry.rank <= 3 ? .bold : .regular)
            }
            .frame(width: 60, alignment: .leading)
            
            // Username
            Text(entry.username)
                .fontWeight(entry.is_current_user ? .bold : .regular)
                .lineLimit(1)
                .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
            
            // Score
            Text("\(entry.score)")
                .fontWeight(.medium)
                .frame(width: 80, alignment: .trailing)
            
            // Games played
            Text("\(entry.games_played)")
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
            
            // Average score
            Text(String(format: "%.1f", entry.avg_score))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal)
    }
}

// Preview provider for SwiftUI Canvas
struct LeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock AuthService for preview
        let authService = AuthService()
        authService.isAuthenticated = true
        
        return LeaderboardView(authService: authService)
    }
}

//
//  Leaderboard.swift
//  loginboy
//
//  Created by Daniel Horsley on 12/05/2025.
//

