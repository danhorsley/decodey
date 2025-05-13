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
                        DailyView(auth:AuthenticationCoordinator())
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
                        LeaderboardView(auth:AuthenticationCoordinator())
                    }
                    .tabItem {
                        Label("Leaderboard", systemImage: "list.number")
                    }
                    
                    NavigationViewWrapper {
                        UserStatsView(auth:AuthenticationCoordinator())
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

// Updated platform-specific NavigationView wrapper (unchanged)
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

// Updated Profile view
struct ProfileView: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var settingsState: SettingsState
    
    var body: some View {
        Form {
            // User section
            Section(header: Text("Account")) {
                HStack {
                    Text("Logged in as")
                    Spacer()
                    Text(userState.username)
                        .foregroundColor(.secondary)
                }
                
                if userState.isSubadmin {
                    Label("Admin privileges", systemImage: "checkmark.shield")
                        .foregroundColor(.blue)
                }
            }
            
            // Appearance section
            Section(header: Text("Appearance")) {
                Toggle("Dark Mode", isOn: $settingsState.isDarkMode)
                Toggle("Show Text Helpers", isOn: $settingsState.showTextHelpers)
                Toggle("Accessibility Text Size", isOn: $settingsState.useAccessibilityTextSize)
                
                Picker("Game Difficulty", selection: $settingsState.gameDifficulty) {
                    Text("Easy").tag("easy")
                    Text("Medium").tag("medium")
                    Text("Hard").tag("hard")
                }
            }
            // Security section
            Section(header: Text("Security")) {
                Toggle("Use Biometric Auth", isOn: $settingsState.useBiometricAuth)
            }
            
            // Reset section
            Section {
                Button(action: settingsState.resetToDefaults) {
                    Text("Reset All Settings")
                        .foregroundColor(.red)
                }
            }
            
            // About section
            Section(header: Text("About")) {
                HStack {
                    Text("App Version")
                    Spacer()
                    Text(settingsState.appVersion)
                        .foregroundColor(.secondary)
                }
            }
            
            // Logout section
            Section {
                Button(action: userState.logout) {
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
