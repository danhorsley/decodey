import SwiftUI

struct LeaderboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header for cross-platform compatibility
            customHeader
            
            // Coming Soon content
            comingSoonContent
        }
    }
    
    // MARK: - Custom Header
    
    private var customHeader: some View {
        HStack {
            Text("Leaderboard")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding()
        .background(adaptiveHeaderBackground)
        .overlay(
            Divider()
                .opacity(0.3),
            alignment: .bottom
        )
    }
    
    // MARK: - Coming Soon Content
    
    private var comingSoonContent: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon section
            VStack(spacing: 16) {
                Image(systemName: "trophy.circle")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                
                Text("Global Leaderboards")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                
                Text("Coming Soon")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            // Description
            VStack(spacing: 12) {
                Text("Compete with players worldwide!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                
                Text("Global leaderboards will be available when we connect to GameStore services.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Local stats teaser
            localStatsTeaser
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Local Stats Teaser
    
    private var localStatsTeaser: some View {
        VStack(spacing: 16) {
            Text("For now, check your personal progress in the Profile tab")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 20) {
                localStatCard(
                    title: "Your Best",
                    subtitle: "Personal Stats",
                    icon: "person.crop.circle"
                )
                
                localStatCard(
                    title: "Offline Mode",
                    subtitle: "No Data Collection",
                    icon: "shield.checkered"
                )
                
                localStatCard(
                    title: "Private Play",
                    subtitle: "Your Device Only",
                    icon: "lock.circle"
                )
            }
        }
        .padding(.top, 20)
    }
    
    private func localStatCard(title: String, subtitle: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(adaptiveCardBackground)
                .stroke(adaptiveCardBorder, lineWidth: 0.5)
        )
    }
    
    // MARK: - Platform-Adaptive Colors
    
    private var adaptiveHeaderBackground: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    private var adaptiveCardBackground: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.97)
    }
    
    private var adaptiveCardBorder: Color {
        colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.9)
    }
}

// MARK: - Preview

#Preview {
    LeaderboardView()
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    LeaderboardView()
        .preferredColorScheme(.light)
}
