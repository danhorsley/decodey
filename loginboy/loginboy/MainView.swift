import SwiftUI

struct MainView: View {
    // Environment state objects
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState
    
    // Use navigation coordinator
    @StateObject private var coordinator = NavigationCoordinator(auth: UserState.shared.authCoordinator)
    
    var body: some View {
        mainContent
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
        .sheet(item: $coordinator.activeSheet) { sheetType in
            sheetContent(for: sheetType)
        }
    }
    
    // Home screen view
    private var homeView: some View {
        HomeScreen(
            onBegin: {
                if userState.isAuthenticated {
                    coordinator.navigate(to: .main(.daily))
                } else {
                    coordinator.navigate(to: .login)
                }
            },
            onShowLogin: {
                coordinator.navigate(to: .login)
            }
        )
    }
    
    // Login view
    private var loginView: some View {
        LoginView()
            .environmentObject(userState.authCoordinator)
            .overlay(
                Button(action: {
                    coordinator.navigate(to: .home)
                }) {
                    Image(systemName: "house")
                        .font(.title)
                        .padding()
                        .background(Circle().fill(Color.black.opacity(0.7)))
                        .foregroundColor(.white)
                }
                .padding(),
                alignment: .topLeading
            )
    }
    
    // Main tab view
    private var mainTabView: some View {
        TabView(selection: $coordinator.selectedTab) {
            NavigationViewWrapper {
                DailyView(auth: userState.authCoordinator)
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
                LeaderboardView(auth: userState.authCoordinator)
                    .environmentObject(userState.authCoordinator)
            }
            .tabItem {
                Label("Leaderboard", systemImage: "list.number")
            }
            .tag(NavigationCoordinator.AppRoute.TabRoute.leaderboard)
            
            NavigationViewWrapper {
                UserStatsView(auth: userState.authCoordinator)
                    .environmentObject(userState.authCoordinator)
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
        .overlay(
            Button(action: {
                coordinator.navigate(to: .home)
            }) {
                Image(systemName: "house")
                    .font(.title)
                    .padding()
                    .background(Circle().fill(Color.black.opacity(0.7)))
                    .foregroundColor(.white)
            }
            .padding(),
            alignment: .topLeading
        )
    }
    
    // Sheet content factory function
    @ViewBuilder
    private func sheetContent(for sheetType: NavigationCoordinator.SheetType) -> some View {
        switch sheetType {
        case .settings:
            NavigationView {
                ProfileView()
                    .environmentObject(coordinator)
            }
        case .login:
            NavigationView {
                LoginView()
                    .environmentObject(coordinator)
            }
        case .continueGame:
            ContinueGameSheet(isDailyChallenge: gameState.isDailyChallenge)
                .presentationDetents([.medium])
        }
    }
}
