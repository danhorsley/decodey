// GameHeaderView.swift
// Decodey
//
// Game header with animated title and back button

import SwiftUI

struct GameHeaderView: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private let colors = ColorSystem.shared
    
    var body: some View {
        ZStack {
            // Centered title
            TypewriterTerminalTitle(
                text: "decodey",
                isTerminalMode: colorScheme == .dark
            )
            .frame(height: 44)
            
            // Overlay buttons on top
            HStack {
                // Back button
                Button(action: {
                    SoundManager.shared.play(.letterClick)
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(colors.primaryText(for: colorScheme))
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }
}
