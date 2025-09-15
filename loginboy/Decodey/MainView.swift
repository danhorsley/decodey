import SwiftUI

struct MainView: View {
    @StateObject private var gameState = GameState.shared
    @StateObject private var userState = UserState.shared
    @StateObject private var settingsState = SettingsState.shared
    @StateObject private var soundManager = SoundManager.shared
    @StateObject private var tutorialManager = TutorialManager.shared  // <-- ADD THIS
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var gameCenterManager: GameCenterManager
    
    @State private var showingHomeScreen = true
    @State private var hasCheckedTutorial = false  // <-- ADD THIS
    
    var body: some View {
        ZStack {
            if showingHomeScreen {
                HomeScreen {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showingHomeScreen = false
                    }
                }
                .environmentObject(authManager)  // Pass through
                .environmentObject(gameCenterManager)  // Pass through
                .transition(.opacity)
            } else {
                // Main game interface
                VStack(spacing: 0) {
                    // Game content
                    TabView {
                        // Daily Challenge Tab
                        GameView()
                            .tabItem {
                                Image(systemName: "calendar")
                                Text("Daily")
                            }
                        
                        // Random Game Tab
                        GameView()
                            .tabItem {
                                Image(systemName: "shuffle")
                                Text("Random")
                            }
                        
                        // Stats Tab
                        UserStatsView()
                            .tabItem {
                                Image(systemName: "chart.bar")
                                Text("Stats")
                            }
                        
                        // Game Center Leaderboard tab
                        LeaderboardView()
                            .tabItem {
                                Label("Leaderboard", systemImage: "trophy.fill")
                            }
                            .tag(2)
                        
                        // Settings Tab
                        SettingsView()
                            .tabItem {
                                Image(systemName: "gear")
                                Text("Settings")
                            }
                    }
                    .tutorialTarget(.tabBar)  // Mark the TabView for tutorial
                }
                .transition(.slide)
                .withTutorialOverlay()  // Tutorial overlay ONLY on game view
                .onAppear {
                    // Check for pending tutorial from settings or first launch
                    if !hasCheckedTutorial {
                        hasCheckedTutorial = true
                        
                        // Check if tutorial was triggered from settings
                        if UserDefaults.standard.bool(forKey: "tutorial-pending") {
                            UserDefaults.standard.set(false, forKey: "tutorial-pending")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                tutorialManager.startTutorial()
                            }
                        }
                        // Or check for first launch
                        else if !tutorialManager.hasCompletedTutorial &&
                                !UserDefaults.standard.bool(forKey: "tutorial-started") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                tutorialManager.startTutorial()
                            }
                        }
                    }
                }
            }
        }
        .environmentObject(gameState)
        .environmentObject(userState)
        .environmentObject(settingsState)
        .environmentObject(soundManager)
        .environmentObject(tutorialManager)
                .overlay(  // <-- ADD THIS OVERLAY
                    EnhancedTutorialOverlay()
                        .allowsHitTesting(tutorialManager.isShowingTutorial)
                )
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
