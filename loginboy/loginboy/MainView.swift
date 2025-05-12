import SwiftUI

struct MainView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        if authService.isAuthenticated {
            // Main tabbed interface
            TabView {
                // Home/Game Tab
                Text("Game View")
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
                VStack {
                    Text("Welcome, \(authService.username)!")
                        .font(.title2)
                        .padding()
                    
                    Button("Logout") {
                        authService.logout()
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
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
