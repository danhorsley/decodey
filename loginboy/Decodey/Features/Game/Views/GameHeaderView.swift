// GameHeaderView.swift
// Decodey
//
// Game header with animated title, back button, and refresh for custom games

import SwiftUI

struct GameHeaderView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) var dismiss
    
    // Use the published variable from GameState
    private var isDailyChallenge: Bool {
        gameState.isDailyChallenge
    }
    
    private var dateString: String? {
        guard isDailyChallenge else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: Date())  // Today's date for daily challenge
    }
    
    var body: some View {
        ZStack {
            // Centered title based on game mode
            VStack(spacing: GameLayout.paddingSmall) {
                if isDailyChallenge {
                    // Daily challenge header
                    Text("decodey daily")
                        .font(.gameTitle)
                        .foregroundColor(.gameTitle)
                    
                    if let dateString = dateString {
                        Text(dateString.uppercased())
                            .font(.gameCaption)
                            .tracking(1.5)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                } else {
                    // Custom game header
                    Text("decodey")
                        .font(.gameTitle)
                        .foregroundColor(.gameTitle)
                    
                    Text("CLASSIC MODE")
                        .font(.gameCaption)
                        .tracking(1.5)
                        .foregroundColor(.primary.opacity(0.7))
                }
            }
            
            // Overlay buttons
            HStack {
                // Back button (left side)
                Button(action: {
                    SoundManager.shared.play(.letterClick)
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Refresh button (right side, only for custom games)
                if !isDailyChallenge {
                    RefreshButton(action: {
                        // Start a new custom game
                        gameState.resetGame()
                    })
                }
            }
        }
        .padding(.horizontal, GameLayout.paddingSmall)
        .padding(.vertical, GameLayout.padding)
    }
}

// MARK: - Simplified Refresh Button

struct RefreshButton: View {
    let action: () -> Void
    @State private var rotation: Double = 0
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Trigger rotation animation
            withAnimation(.easeInOut(duration: 0.5)) {
                rotation += 360
            }
            
            // Play sound
            SoundManager.shared.play(.letterClick)
            
            // Execute action after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
            }
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.primary)
                .rotationEffect(.degrees(rotation))
                .scaleEffect(isPressed ? 0.85 : 1.0)
                .opacity(isPressed ? 0.8 : 1.0)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Preview

struct GameHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Custom game header
            GameHeaderView()
                .environmentObject(GameState.shared)
                .background(Color.gameBackground)
            
            // Daily challenge header (would need daily game in gameState)
            GameHeaderView()
                .environmentObject(GameState.shared)
                .background(Color.gameBackground)
                .preferredColorScheme(.dark)
        }
        .padding()
    }
}
