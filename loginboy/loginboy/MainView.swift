import SwiftUI

struct MainView: View {
    @StateObject private var gameState = GameState.shared
    @StateObject private var userState = UserState.shared
    @StateObject private var settingsState = SettingsState.shared
    @StateObject private var soundManager = SoundManager.shared
    
    @State private var showingHomeScreen = true
    
    var body: some View {
        ZStack {
            if showingHomeScreen {
                HomeScreen {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showingHomeScreen = false
                    }
                }
                .transition(.opacity)
            } else {
                // Main game interface
                VStack(spacing: 0) {
                    // Top bar with user info and settings
//                    HStack {
//                        // User info
//                        if userState.isSignedIn {
//                            VStack(alignment: .leading, spacing: 2) {
//                                Text(userState.playerName)
//                                    .font(.headline)
//                                    .foregroundColor(.primary)
//                                
//                                Text("Score: \(userState.totalScore)")
//                                    .font(.caption)
//                                    .foregroundColor(.secondary)
//                            }
//                        }
//                        
//                        Spacer()
//                        
//                        // Settings button
//                        Button(action: {
//                            // Show settings
//                        }) {
//                            Image(systemName: "gear")
//                                .font(.title2)
//                                .foregroundColor(.primary)
//                        }
//                    }
//                    .padding()
//                    .background(Material.regularMaterial)
                    
                    // Game content
                    TabView {
                        // Daily Challenge Tab
                        GameView(gameMode: .daily)
                            .tabItem {
                                Image(systemName: "calendar")
                                Text("Daily")
                            }
                        
                        // Random Game Tab
                        GameView(gameMode: .random)
                            .tabItem {
                                Image(systemName: "shuffle")
                                Text("Random")
                            }
                        
                        // Stats Tab
                        StatsView()
                            .tabItem {
                                Image(systemName: "chart.bar")
                                Text("Stats")
                            }
                        
                        // ADD THIS SETTINGS TAB:
                        SettingsView()
                            .tabItem {
                                Image(systemName: "gear")
                                Text("Settings")
                            }
                    }
                }
                .transition(.slide)
            }
        }
        .environmentObject(gameState)
        .environmentObject(userState)
        .environmentObject(settingsState)
        .environmentObject(soundManager)
    }
}

// Simple Stats View
struct StatsView: View {
    @EnvironmentObject var userState: UserState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Your Stats")
                    .font(.largeTitle.bold())
                    .padding(.top)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    StatCard(title: "Games Played", value: "\(userState.gamesPlayed)")
                    StatCard(title: "Games Won", value: "\(userState.gamesWon)")
                    StatCard(title: "Win Rate", value: String(format: "%.1f%%", userState.winPercentage))
                    StatCard(title: "Total Score", value: "\(userState.totalScore)")
                    StatCard(title: "Avg Score", value: String(format: "%.0f", userState.averageScore))
                }
                .padding()
                
                Spacer()
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.primary)
        }
        .padding()
        .background(Material.thin)
        .cornerRadius(12)
    }
}
