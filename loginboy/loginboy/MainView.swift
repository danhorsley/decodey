import SwiftUI

struct MainView: View {
    @EnvironmentObject var auth: AuthenticationCoordinator
    @EnvironmentObject var settings: UserSettings
    
    @State private var currentScreen: AppScreen = .home
    
    enum AppScreen {
        case home
        case main
        case login
    }
    
    var body: some View {
        if !auth.isAuthenticated {
            if currentScreen == .home {
                HomeScreen(
                    onBegin: {
                        if !auth.isAuthenticated {
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
                    .environmentObject(auth)
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
                    .onChange(of: auth.isAuthenticated) { isAuthenticated in
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
                        DailyView(auth: auth)
                    }
                    .tabItem {
                        Label("Daily", systemImage: "calendar")
                    }
                    
                    NavigationViewWrapper {
                        CustomGameView()
                            .environmentObject(auth)
                            .environmentObject(settings)
                    }
                    .tabItem {
                        Label("Play", systemImage: "gamecontroller")
                    }
                    
                    NavigationViewWrapper {
                        LeaderboardView(auth: auth)
                    }
                    .tabItem {
                        Label("Leaderboard", systemImage: "list.number")
                    }
                    
                    NavigationViewWrapper {
                        UserStatsView(auth: auth)
                            .environmentObject(auth)
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

// Platform-specific NavigationView wrapper
struct NavigationViewWrapper<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        #if os(iOS)
        NavigationView {
            content
        }
        .navigationViewStyle(StackNavigationViewStyle())
        #else
        // For macOS, don't use NavigationView at all
        content
            .frame(minWidth: 600, idealWidth: 800, maxWidth: .infinity,
                   minHeight: 500, idealHeight: 700, maxHeight: .infinity)
        #endif
    }
}

// Profile view component for the settings tab
struct ProfileView: View {
    @EnvironmentObject var authService: AuthenticationCoordinator
    @EnvironmentObject var settings: UserSettings
    
    var body: some View {
        Form {
            // User section
            Section(header: Text("Account")) {
                HStack {
                    Text("Logged in as")
                    Spacer()
                    Text(authService.username)
                        .foregroundColor(.secondary)
                }
                
                if authService.isSubadmin {
                    Label("Admin privileges", systemImage: "checkmark.shield")
                        .foregroundColor(.blue)
                }
            }
            
            // Appearance section
            Section(header: Text("Appearance")) {
                Toggle("Dark Mode", isOn: $settings.isDarkMode)
                Toggle("Show Text Helpers", isOn: $settings.showTextHelpers)
                Toggle("Accessibility Text Size", isOn: $settings.useAccessibilityTextSize)
                
                Picker("Game Difficulty", selection: $settings.gameDifficulty) {
                    Text("Easy").tag("easy")
                    Text("Medium").tag("medium")
                    Text("Hard").tag("hard")
                }
            }
            // Security section
            Section(header: Text("Security")) {
                Toggle("Use Biometric Auth", isOn: $settings.useBiometricAuth)
            }
            
            // Reset section
            Section {
                Button(action: settings.resetToDefaults) {
                    Text("Reset All Settings")
                        .foregroundColor(.red)
                }
            }
            
            // About section
            Section(header: Text("About")) {
                HStack {
                    Text("App Version")
                    Spacer()
                    Text(settings.appVersion)
                        .foregroundColor(.secondary)
                }
            }
            
            // Logout section
            Section {
                Button(action: authService.logout) {
                    HStack {
                        Spacer()
                        Text("Logout")
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Profile & Settings")
    }
}

struct CustomGameView: View {
    @EnvironmentObject var auth: AuthenticationCoordinator
    @EnvironmentObject var settings: UserSettings
    @StateObject private var gameController: GameController
    
    init() {
        // Create a GameController for custom games
        let controller = GameController(auth: AuthenticationCoordinator())
        self._gameController = StateObject(wrappedValue: controller)
    }
    
    var body: some View {
        GameView(gameController: gameController)
            .navigationTitle("Custom Game")
            .onAppear {
                // When we appear, make sure we have the latest auth coordinator
                if let auth = self.auth as? AuthenticationCoordinator {
                    gameController.updateAuth(auth)
                }
                gameController.setupCustomGame()
            }
    }
}
