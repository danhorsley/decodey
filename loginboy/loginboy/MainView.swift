import SwiftUI

struct MainView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var settings: UserSettings
    
    var body: some View {
        if authService.isAuthenticated {
            // Main tabbed interface
            TabView {
                // Daily Challenge Tab (new primary tab)
                DailyView(authService: authService)
                    .tabItem {
                        Label("Daily", systemImage: "calendar")
                    }
                
                // Game Tab (for custom games)
                GameView()
                    .environmentObject(authService)
                    .environmentObject(settings)
                    .tabItem {
                        Label("Play", systemImage: "gamecontroller")
                    }
                
                // Leaderboard Tab
                LeaderboardView(authService: authService)
                    .tabItem {
                        Label("Leaderboard", systemImage: "list.number")
                    }
                
                // Stats Tab
                UserStatsView(authService: authService)
                    .environmentObject(authService)
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar")
                    }
                
                // Profile/Settings Tab
                ProfileView()
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

// Profile view component for the settings tab
struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var settings: UserSettings
    
    var body: some View {
        NavigationView {
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
}
