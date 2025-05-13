import SwiftUI

struct MainView: View {
    // Inject our state objects
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState
    
    @State private var currentScreen: AppScreen = .home
    
    enum AppScreen {
        case home
        case main
        case login
    }
    
    var body: some View {
        if !userState.isAuthenticated {
            if currentScreen == .home {
                HomeScreen(
                    onBegin: {
                        if !userState.isAuthenticated {
                            currentScreen = .login
                        } else {
                            currentScreen = .main
                        }
                    },
                    onShowLogin: {
                        currentScreen = .login
                    }
                )
                .transition(.opacity)
            } else {
                LoginView()
                    .environmentObject(userState)
                    .overlay(
                        Button(action: {
                            currentScreen = .home
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
                    .transition(.opacity)
                    .onChange(of: userState.isAuthenticated) { isAuthenticated in
                        if isAuthenticated {
                            currentScreen = .main
                        }
                    }
            }
        } else {
            if currentScreen == .home {
                HomeScreen(
                    onBegin: {
                        currentScreen = .main
                    },
                    onShowLogin: {
                        currentScreen = .main
                    }
                )
                .transition(.opacity)
            } else {
                TabView {
                    NavigationViewWrapper {
                        DailyView(auth: userState.authCoordinator)
                    }
                    .tabItem {
                        Label("Daily", systemImage: "calendar")
                    }
                    
                    NavigationViewWrapper {
                        CustomGameView()
                    }
                    .tabItem {
                        Label("Play", systemImage: "gamecontroller")
                    }
                    
                    NavigationViewWrapper {
                        LeaderboardView(auth: userState.authCoordinator)
                    }
                    .tabItem {
                        Label("Leaderboard", systemImage: "list.number")
                    }
                    
                    NavigationViewWrapper {
                        UserStatsView(auth: userState.authCoordinator)
                    }
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar")
                    }
                    
                    NavigationViewWrapper {
                        ProfileView()
                    }
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
                }
                .overlay(
                    Button(action: {
                        currentScreen = .home
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
                .transition(.opacity)
            }
        }
    }
}




// Updated CustomGameView
struct CustomGameView: View {
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        GameView()
            .navigationTitle("Custom Game")
            .onAppear {
                gameState.setupCustomGame()
            }
    }
}
