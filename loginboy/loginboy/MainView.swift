import SwiftUI

struct MainView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var settings: UserSettings
    
    var body: some View {
        if authService.isAuthenticated {
            // Main tabbed interface
            TabView {
                // Daily Challenge Tab
                NavigationViewWrapper {
                    DailyView(authService: authService)
                }
                .tabItem {
                    Label("Daily", systemImage: "calendar")
                }
                
                // Game Tab (for custom games)
                NavigationViewWrapper {
                    CustomGameView()
                        .environmentObject(authService)
                        .environmentObject(settings)
                }
                .tabItem {
                    Label("Play", systemImage: "gamecontroller")
                }
                
                // Leaderboard Tab
                NavigationViewWrapper {
                    LeaderboardView(authService: authService)
                }
                .tabItem {
                    Label("Leaderboard", systemImage: "list.number")
                }
                
                // Stats Tab
                NavigationViewWrapper {
                    UserStatsView(authService: authService)
                        .environmentObject(authService)
                }
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                
                // Profile/Settings Tab
                NavigationViewWrapper {
                    ProfileView()
                }
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
            }
        } else {
            // Login screen
            LoginView()
                .environmentObject(authService)
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
    @EnvironmentObject var authService: AuthService
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
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var settings: UserSettings
    @StateObject private var gameController: GameController
    
    init() {
        // Create a GameController for custom games
        let controller = GameController(authService: AuthService())
        self._gameController = StateObject(wrappedValue: controller)
    }
    
    var body: some View {
        GameView(gameController: gameController)
            .navigationTitle("Custom Game")
            .onAppear {
                gameController.setupCustomGame()
            }
    }
}
