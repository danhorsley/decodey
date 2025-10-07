import SwiftUI
import CoreData

struct UserStatsView: View {
    @EnvironmentObject var userState: UserState
    
    private let coreData = CoreDataStack.shared
    
    // Compute stats directly - no async, no loading state needed
    private var userStats: UserStatsCD? {
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        
        // Try to find user by primary identifier first, then by username
        if !userState.userId.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "primaryIdentifier == %@ OR userId == %@",
                                                userState.userId, userState.userId)
        } else if !userState.playerName.isEmpty {
            fetchRequest.predicate = NSPredicate(format: "username == %@", userState.playerName)
        } else {
            // No user identifier available
            return nil
        }
        
        fetchRequest.fetchLimit = 1
        
        do {
            let users = try context.fetch(fetchRequest)
            return users.first?.stats
        } catch {
            print("Error fetching stats: \(error)")
            return nil
        }
    }
    
    var body: some View {
        ThemedDataDisplay(title: "Your Statistics") {
            if let stats = userStats {
                ScrollView {
                    VStack(spacing: 24) {
                        // Overview Cards Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ThemedStatCard(
                                title: "Games Played",
                                value: "\(stats.gamesPlayed)",
                                icon: "gamecontroller.fill",
                                trend: nil
                            )
                            
                            ThemedStatCard(
                                title: "Games Won",
                                value: "\(stats.gamesWon)",
                                icon: "trophy.fill",
                                trend: nil
                            )
                            
                            ThemedStatCard(
                                title: "Win Rate",
                                value: String(format: "%.1f%%", winPercentage(stats)),
                                icon: "percent",
                                trend: nil
                            )
                            
                            ThemedStatCard(
                                title: "Total Score",
                                value: "\(stats.totalScore)",
                                icon: "star.fill",
                                trend: nil
                            )
                        }
                        .padding(.horizontal)
                        
                        // Detailed Stats
                        VStack(spacing: 16) {
                            detailRow(title: "Current Streak", value: "\(stats.currentStreak) games")
                            detailRow(title: "Best Streak", value: "\(stats.bestStreak) games")
                            detailRow(title: "Average Mistakes", value: String(format: "%.1f", stats.averageMistakes))
                            detailRow(title: "Average Time", value: formatTime(stats.averageTime))
                            if let lastPlayed = stats.lastPlayedDate {
                                detailRow(title: "Last Played", value: formatDate(lastPlayed))
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }
            } else {
                // No stats available
                VStack(spacing: 20) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No Statistics Available")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Play some games to see your stats!")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Functions
    
    private func winPercentage(_ stats: UserStatsCD) -> Double {
        guard stats.gamesPlayed > 0 else { return 0 }
        return Double(stats.gamesWon) / Double(stats.gamesPlayed) * 100
    }
    
    private func formatTime(_ seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.0f sec", seconds)
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return String(format: "%d:%02d", minutes, secs)
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds - Double(hours * 3600)) / 60)
            return String(format: "%d:%02d hrs", hours, minutes)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
