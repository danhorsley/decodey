import SwiftUI
import CoreData

struct ProfileView: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var settingsState: SettingsState
    @State private var showLogoutConfirmation = false
    @State private var showResetConfirmation = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        // Cross-platform approach - no NavigationView wrapper
        VStack(spacing: 0) {
            // Custom header for cross-platform compatibility
            customHeader
            
            // Main content in a Form
            Form {
                // Player Info Section
                Section {
                    playerInfoRow(
                        title: "Player Name",
                        value: userState.playerName,
                        icon: "person.circle.fill"
                    )
                    
                    playerInfoRow(
                        title: "Total Score",
                        value: "\(userState.totalScore)",
                        icon: "star.fill"
                    )
                    
                    playerInfoRow(
                        title: "Games Played",
                        value: "\(userState.gamesPlayed)",
                        icon: "gamecontroller.fill"
                    )
                    
                    playerInfoRow(
                        title: "Games Won",
                        value: "\(userState.gamesWon)",
                        icon: "trophy.fill"
                    )
                    
                    playerInfoRow(
                        title: "Win Rate",
                        value: String(format: "%.1f%%", userState.winPercentage),
                        icon: "percent"
                    )
                    
                    playerInfoRow(
                        title: "Average Score",
                        value: String(format: "%.0f", userState.averageScore),
                        icon: "chart.bar"
                    )
                } header: {
                    ThemedSectionHeader("PLAYER STATS", icon: "person.crop.circle")
                }
                
                // Game Settings Section
                Section {
                    gameSettingRow(
                        label: "Difficulty",
                        icon: "dial.high.fill",
                        value: settingsState.gameDifficulty.capitalized
                    )
                    
                    gameSettingRow(
                        label: "Sound",
                        icon: "speaker.wave.2.fill",
                        value: settingsState.soundEnabled ? "On" : "Off"
                    )
                    
                    gameSettingRow(
                        label: "Enhanced Letters",
                        icon: "textformat",
                        value: settingsState.useEnhancedLetterCells ? "On" : "Off"
                    )
                } header: {
                    ThemedSectionHeader("GAME SETTINGS", icon: "gearshape.fill")
                }
                
                // App Info Section
                Section {
                    playerInfoRow(
                        title: "Version",
                        value: settingsState.appVersion,
                        icon: "info.circle"
                    )
                    
                    playerInfoRow(
                        title: "Build",
                        value: "Local Edition",
                        icon: "hammer"
                    )
                    
                    playerInfoRow(
                        title: "Mode",
                        value: "Offline Only",
                        icon: "airplane"
                    )
                } header: {
                    ThemedSectionHeader("ABOUT", icon: "questionmark.circle")
                }
                
                // Account Actions Section
                Section {
                    actionButton(
                        title: "Reset All Stats",
                        icon: "arrow.clockwise.circle",
                        color: .orange,
                        action: { showResetConfirmation = true }
                    )
                    
                    if userState.isSignedIn {
                        actionButton(
                            title: "Sign Out",
                            icon: "rectangle.portrait.and.arrow.right",
                            color: .red,
                            action: { showLogoutConfirmation = true }
                        )
                    }
                } header: {
                    ThemedSectionHeader("ACTIONS", icon: "gear")
                }
            }
            .themedFormStyle()
        }
        .alert("Reset Statistics?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllStats()
            }
        } message: {
            Text("This will permanently delete all your game statistics and progress. This cannot be undone.")
        }
        .alert("Sign Out?", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    // MARK: - Custom Header (Cross-Platform)
    
    private var customHeader: some View {
        HStack {
            Text("Profile")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Spacer()
            
            // Optional: Add settings button or other actions
            // Button("Settings") { /* action */ }
        }
        .padding()
        .background(adaptiveHeaderBackground)
        .overlay(
            Divider()
                .opacity(0.3),
            alignment: .bottom
        )
    }
    
    // Platform-adaptive header background
    private var adaptiveHeaderBackground: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func playerInfoRow(title: String, value: String, icon: String) -> some View {
        ThemedListRow {
            ThemedInfoRow(
                title: title,
                value: value,
                icon: icon
            )
        }
    }
    
    @ViewBuilder
    private func gameSettingRow(label: String, icon: String, value: String) -> some View {
        ThemedListRow {
            HStack {
                Label(label, systemImage: icon)
                    .foregroundColor(.primary)
                Spacer()
                Text(value)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        ThemedListRow(isButton: true) {
            Button(action: action) {
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                        Text(title)
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Actions
    
    private func resetAllStats() {
        // Reset UserState stats using the public method
        userState.resetStats()
        
        // Reset SettingsState to defaults
        settingsState.resetToDefaults()
        
        // Clear Core Data stats
        let context = CoreDataStack.shared.mainContext
        
        // Delete all games
        let gameRequest: NSFetchRequest<NSFetchRequestResult> = GameCD.fetchRequest()
        let deleteGamesRequest = NSBatchDeleteRequest(fetchRequest: gameRequest)
        
        // Delete all user stats
        let statsRequest: NSFetchRequest<NSFetchRequestResult> = UserStatsCD.fetchRequest()
        let deleteStatsRequest = NSBatchDeleteRequest(fetchRequest: statsRequest)
        
        do {
            try context.execute(deleteGamesRequest)
            try context.execute(deleteStatsRequest)
            try context.save()
            
            // Refresh context
            context.refreshAllObjects()
            
            print("✅ All stats reset successfully")
        } catch {
            print("❌ Error resetting stats: \(error)")
        }
    }
    
    private func signOut() {
        userState.signOut()
    }
}

#Preview {
    ProfileView()
        .environmentObject(UserState.shared)
        .environmentObject(SettingsState.shared)
}
