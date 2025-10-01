// LeaderboardView.swift - Migrated to GameTheme
import SwiftUI
import GameKit

struct LeaderboardView: View {
    @StateObject private var gameCenterManager = GameCenterManager.shared
    // REMOVED: ColorSystem reference
    // private let colors = ColorSystem.shared
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedScope: GKLeaderboard.PlayerScope = .global
    @State private var selectedTime: GKLeaderboard.TimeScope = .allTime
    @State private var leaderboardEntries: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var showingGameCenterSheet = false
    
    // Your leaderboard ID from App Store Connect
    private let leaderboardID = "alltime" // Update this with your actual ID
    
    var body: some View {
        ZStack {
            Color("GameBackground")  // CHANGED: Using color asset
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom header
                customHeader
                
                if gameCenterManager.isAuthenticated {
                    authenticatedContent
                } else {
                    notAuthenticatedView
                }
            }
        }
        .task {
            // Debug: List all available leaderboards
            await gameCenterManager.debugListAllLeaderboards()
            
            // Then try to authenticate
            await authenticateAndLoadLeaderboard()
        }
        .sheet(isPresented: $showingGameCenterSheet) {
            GameCenterView(viewState: .leaderboards)
        }
    }
    
    // MARK: - Custom Header (matching your style)
    private var customHeader: some View {
        HStack {
            Text("Leaderboard")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            if gameCenterManager.isAuthenticated {
                Button(action: {
                    showingGameCenterSheet = true
                }) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding()
        .background(Color("GameSurface"))  // CHANGED: Using color asset
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Authenticated Content
    private var authenticatedContent: some View {
        VStack(spacing: 0) {
            // Scope selector
            scopeSelector
                .padding()
            
            // Leaderboard content
            if isLoading {
                loadingView
            } else if leaderboardEntries.isEmpty {
                emptyLeaderboardView
            } else {
                leaderboardList
            }
        }
    }
    
    // MARK: - Scope Selector
    private var scopeSelector: some View {
        Picker("Scope", selection: $selectedScope) {
            Text("Global").tag(GKLeaderboard.PlayerScope.global)
            Text("Friends").tag(GKLeaderboard.PlayerScope.friendsOnly)
        }
        .pickerStyle(SegmentedPickerStyle())
        .onChange(of: selectedScope) { _ in
            Task {
                await loadLeaderboard()
            }
        }
    }
    
    // MARK: - Leaderboard List
    private var leaderboardList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(leaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                    LeaderboardRow(
                        entry: entry,
                        rank: index + 1,
                        isCurrentPlayer: entry.isLocalPlayer
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading leaderboard...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty Leaderboard View
    private var emptyLeaderboardView: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Scores Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Be the first to set a score!")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Not Authenticated View
    private var notAuthenticatedView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("Game Center Required")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Sign in to Game Center to view leaderboards and compete with friends")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                Task {
                    await gameCenterManager.authenticateLocalPlayer()
                    if gameCenterManager.isAuthenticated {
                        await loadLeaderboard()
                    }
                }
            }) {
                Text("Sign In")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            
            Spacer()
            
            Text("Game Center authentication is handled by iOS")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    private func authenticateAndLoadLeaderboard() async {
        if !gameCenterManager.isAuthenticated {
            await gameCenterManager.authenticateLocalPlayer()
        }
        
        if gameCenterManager.isAuthenticated {
            await loadLeaderboard()
        }
    }
    
    private func loadLeaderboard() async {
        isLoading = true
        
        // Fetch leaderboard scores
        let entries = await gameCenterManager.fetchLeaderboardScores(
            leaderboardID: leaderboardID,
            scope: selectedScope,
            timeScope: selectedTime,
            range: NSRange(location: 1, length: 50)
        )
        
        await MainActor.run {
            self.leaderboardEntries = entries
            self.isLoading = false
        }
    }
}

// MARK: - Leaderboard Row Component
struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    let isCurrentPlayer: Bool
    
    // REMOVED: ColorSystem reference
    // private let colors = ColorSystem.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 40, height: 40)
                
                if rank <= 3 {
                    Image(systemName: rankIcon)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                } else {
                    Text("\(rank)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Player name
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.system(size: 16, weight: isCurrentPlayer ? .bold : .medium))
                    .foregroundColor(.primary)
                
                if isCurrentPlayer {
                    Text("You")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            
            Spacer()
            
            // Score
            Text("\(entry.score)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(isCurrentPlayer ? .accentColor : .primary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentPlayer ?
                    Color.accentColor.opacity(0.1) :
                    Color("GameSurface"))  // CHANGED: Using color asset
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentPlayer ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(white: 0.6)
        case 3: return .orange
        default: return .accentColor
        }
    }
    
    private var rankIcon: String {
        switch rank {
        case 1: return "trophy.fill"
        case 2: return "medal.fill"
        case 3: return "rosette"
        default: return ""
        }
    }
}

// MARK: - Update GameCenterManager LeaderboardIDs
extension GameCenterManager {
    struct UpdatedLeaderboardIDs {
        // Update these with your actual App Store Connect IDs
        static let totalScore = "alltime" // Your actual ID
//        static let dailyScore = "grp.decodey.daily"   // If you have daily
//        static let winStreak = "grp.decodey.streak"   // If you have streak
    }
}
