// GameErrorView.swift
// Decodey
//
// Error state display with retry options

import SwiftUI

struct GameErrorView: View {
    let message: String
    @EnvironmentObject var gameState: GameState
    @Environment(\.colorScheme) var colorScheme
    
    private let colors = ColorSystem.shared
    
    var body: some View {
        VStack(spacing: 24) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(colors.warning)
            
            // Error title
            Text("ERROR")
                .font(.custom("Courier New", size: 18).weight(.bold))
                .tracking(1.5)
                .foregroundColor(colors.primaryText(for: colorScheme))
            
            // Error message
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(colors.secondaryText(for: colorScheme))
                .padding(.horizontal, 40)
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    SoundManager.shared.play(.letterClick)
                    gameState.resetGame()
                }) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.custom("Courier New", size: 14).weight(.semibold))
                        .tracking(1)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colors.accent)
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    SoundManager.shared.play(.letterClick)
                    // For a new random game, we can use setupCustomGame
                    gameState.setupCustomGame()
                }) {
                    Label("New Game", systemImage: "plus.circle")
                        .font(.custom("Courier New", size: 14).weight(.semibold))
                        .tracking(1)
                        .foregroundColor(colors.accent)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(colors.accent, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
