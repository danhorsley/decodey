// MainView.swift - Rewritten for Realm
import SwiftUI

struct MainView: View {
    // Environment state objects
    @StateObject private var userState = UserState.shared
    @StateObject private var gameState = GameState.shared
    @EnvironmentObject var settingsState: SettingsState
    
    // Use navigation coordinator
    @StateObject private var coordinator = NavigationCoordinator(auth: UserState.shared.authCoordinator)
    
    // State for sheet presentations
    @State private var showLoginSheet = false
    @State private var showContinueGameSheet = false
    
    var body: some View {
        mainContent
            .environmentObject(userState)
            .environmentObject(gameState)
            .environmentObject(settingsState)
            .environmentObject(coordinator)
    }
    
    // Extract main content to avoid generic parameter inference issues
    private var mainContent: some View {
        Group {
            switch coordinator.currentRoute {
            case .home:
                homeView
                
            case .login:
                loginView
                
            case .main:
                mainTabView
            }
        }
        .sheet(isPresented: $showLoginSheet) {
            NavigationView {
                LoginView()
                    .environmentObject(userState.authCoordinator)
                    .navigationTitle("Login")
            }
        }
        .sheet(isPresented: $showContinueGameSheet) {
            if let savedGame = gameState.savedGame {
                ContinueGameSheet(
                    isDailyChallenge: savedGame.gameId?.starts(with: "daily-") ?? false
                )
                .presentationDetents([.medium])
            }
        }
        .onChange(of: gameState.showContinueGameModal) { _, showModal in
            showContinueGameSheet = showModal
        }
    }
    
    // Home screen view
    private var homeView: some View {
        ZStack {
            HomeScreen(
                onBegin: {
                    if userState.isAuthenticated {
                        coordinator.navigate(to: .main(.daily))
                    } else {
                        coordinator.navigate(to: .login)
                    }
                },
                onShowLogin: {
                    showLoginSheet = true
                }
            )
            .environmentObject(userState.authCoordinator) 
            
            #if DEBUG
            // Add performance monitor in debug builds
            VStack {
                HStack {
                    Spacer()
                    PerformanceMonitor()
                }
                Spacer()
            }
            .padding()
            #endif
        }
    }
    
    // Login view
    private var loginView: some View {
        LoginView()
            .environmentObject(userState.authCoordinator)
    }
    
    // Main tab view
    private var mainTabView: some View {
        TabView(selection: $coordinator.selectedTab) {
            
            NavigationViewWrapper {
                
                DailyView()
                    .environmentObject(userState.authCoordinator)
            }
            .tabItem {
                Label("Daily", systemImage: "calendar")
            }
            .tag(NavigationCoordinator.AppRoute.TabRoute.daily)
            
            NavigationViewWrapper {
                CustomGameView()
            }
            .tabItem {
                Label("Play", systemImage: "gamecontroller")
            }
            .tag(NavigationCoordinator.AppRoute.TabRoute.game)
            
            NavigationViewWrapper {
                LeaderboardView()
                    .environmentObject(userState.authCoordinator)
            }
            .tabItem {
                Label("Leaderboard", systemImage: "list.number")
            }
            .tag(NavigationCoordinator.AppRoute.TabRoute.leaderboard)
            
            NavigationViewWrapper {
                            UserStatsView()
                        }
                        .tabItem {
                            Label("Stats", systemImage: "chart.bar")
                        }
                        .tag(NavigationCoordinator.AppRoute.TabRoute.stats)
            
            NavigationViewWrapper {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person")
            }
            .tag(NavigationCoordinator.AppRoute.TabRoute.profile)
        }
        
    }
}
