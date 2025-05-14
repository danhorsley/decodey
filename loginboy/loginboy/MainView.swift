import SwiftUI

struct MainView: View {
    // Inject our state objects
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState
    
    // Use navigation coordinator
    @StateObject private var coordinator = NavigationCoordinator(auth: UserState.shared.authCoordinator)
    
    var body: some View {
        Group {
            switch coordinator.currentRoute {
            case .home:
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
                
            case .login:
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
                
            case .main:
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
        }
        .environmentObject(coordinator)
        .withCoordinatedNavigation(coordinator)
    }
}
