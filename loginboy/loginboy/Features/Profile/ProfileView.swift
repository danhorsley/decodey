import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var settingsState: SettingsState
    @State private var showLogoutConfirmation = false
    @State private var showResetConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                // Player Info Section
                Section {
                    ThemedListRow {
                        ThemedInfoRow(
                            title: "Player Name",
                            value: userState.playerName,
                            icon: "person.circle.fill"
                        )
                    }
                    
                    ThemedListRow {
                        ThemedInfoRow(
                            title: "Total Score",
                            value: "\(userState.totalScore)",
                            icon: "star.fill"
                        )
                    }
                    
                    ThemedListRow {
                        ThemedInfoRow(
                            title: "Games Played",
                            value: "\(userState.stats?.gamesPlayed ?? 0)",
                            icon: "gamecontroller.fill"
                        )
                    }
                    
                    ThemedListRow {
                        ThemedInfoRow(
                            title: "Games Won",
                            value: "\(userState.stats?.gamesWon ?? 0)",
                            icon: "trophy.fill"
                        )
                    }
                    
                    ThemedListRow {
                        ThemedInfoRow(
                            title: "Current Streak",
                            value: "\(userState.stats?.currentStreak ?? 0)",
                            icon: "flame.fill"
                        )
                    }
                    
                    ThemedListRow {
                        ThemedInfoRow(
                            title: "Best Streak",
                            value: "\(userState.stats?.bestStreak ?? 0)",
                            icon: "crown.fill"
                        )
                    }
                } header: {
                    ThemedSectionHeader("PLAYER STATS", icon: "person.crop.circle")
                }
                
                // Game Settings Section
                Section {
                    ThemedListRow {
                        HStack {
                            Label("Difficulty", systemImage: "dial.high.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(settingsState.gameDifficulty.capitalized)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    ThemedListRow {
                        HStack {
                            Label("Sound", systemImage: "speaker.wave.2.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(settingsState.soundEnabled ? "On" : "Off")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    ThemedListRow {
                        HStack {
                            Label("Enhanced Letters", systemImage: "textformat")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(settingsState.useEnhancedLetterCells ? "On" : "Off")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    ThemedSectionHeader("GAME SETTINGS", icon: "gearshape.fill")
                }
                
                // App Info Section
                Section {
                    ThemedListRow {
                        ThemedInfoRow(
                            title: "Version",
                            value: settingsState.appVersion,
                            icon: "info.circle"
                        )
                    }
                    
                    ThemedListRow {
                        ThemedInfoRow(
                            title: "Build",
                            value: "Local Edition",
                            icon: "hammer"
                        )
                    }
                    
                    ThemedListRow {
                        ThemedInfoRow(
                            title: "Mode",
                            value: "Offline Only",
                            icon: "airplane"
                        )
                    }
                } header: {
                    ThemedSectionHeader("ABOUT", icon: "questionmark.circle")
                }
                
                // Account Actions Section
                Section {
                    ThemedListRow(isButton: true) {
                        Button(action: { showResetConfirmation = true }) {
                            HStack {
                                Spacer()
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise.circle")
                                    Text("Reset All Stats")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .listRowBackground(Color.clear)
                    
                    if userState.isSignedIn {
                        ThemedListRow(isButton: true) {
                            Button(action: { showLogoutConfirmation = true }) {
                                HStack {
                                    Spacer()
                                    HStack(spacing: 8) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                        Text("Sign Out")
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.red)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .themedFormStyle()
            .navigationTitle("Profile")
        }
        .alert("Reset All Stats?", isPresented: $showResetConfirmation) {
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
    
    // MARK: - Actions
    
    private func resetAllStats() {
        // Reset UserState stats
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
