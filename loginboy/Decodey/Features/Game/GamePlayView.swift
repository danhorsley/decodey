// GamePlayView.swift
// Decodey
//
// Main game playing interface with header, display, and controls

import SwiftUI

struct GamePlayView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState
    
    // No more ColorSystem/FontSystem needed!
    // Just keep what's necessary
    private let maxContentWidth: CGFloat = 600
    private let sectionSpacing: CGFloat = 32
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with game controls
            GameHeaderView()
                .padding(.top, GameLayout.paddingSmall)
                .padding(.horizontal, GameLayout.padding)
            
            ScrollView {
                VStack(spacing: sectionSpacing) {
                    // Current game display
                    gameDisplaySection
                        .padding(.top, GameLayout.paddingLarge)
                    
                    // Letter grids and controls
                    GameGridsView(showTextHelpers: settingsState.showTextHelpers)
                        .environmentObject(gameState)
                        .environmentObject(settingsState)
                }
                .padding(.horizontal, GameLayout.padding)
                .padding(.bottom, GameLayout.paddingLarge + 8)
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Game Display Section
    
    private var gameDisplaySection: some View {
        VStack(spacing: GameLayout.padding) {
            // Encrypted text display
            encryptedTextView
            
            // Solution text display
            solutionTextView
        }
    }
    
    private var encryptedTextView: some View {
        VStack(alignment: .center, spacing: GameLayout.paddingSmall) {
            if settingsState.showTextHelpers {
                Text("ENCRYPTED")
                    .font(.gameCaption)  // Use GameTheme font
                    .tracking(1.5)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            Text(displayedEncryptedText)
                .font(.gameDisplay)  // Updated from fonts.encryptedDisplayText()
                .foregroundColor(.gameEncrypted)  // Updated from colors.encryptedColor(for: colorScheme)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, GameLayout.padding + 4)
                .padding(.vertical, GameLayout.padding)
        }
    }
    
    private var solutionTextView: some View {
        VStack(alignment: .center, spacing: 8) {
            if settingsState.showTextHelpers {
                Text("YOUR SOLUTION")
                    .font(.custom("Courier New", size: 10).weight(.medium))
                    .tracking(1.5)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            Text(displayedSolutionText)
                .font(.gameDisplay)  // Updated from fonts.solutionDisplayText()
                .foregroundColor(.gameGuess)  // Updated from colors.guessColor(for: colorScheme)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
    }
    
    // MARK: - Display Text Logic
    
    private var displayedEncryptedText: String {
        guard let game = gameState.currentGame else { return "" }
        let encrypted = game.encrypted
        
        // Show spaces correctly
        return encrypted.map { char -> String in
            if !char.isLetter {
                return String(char)
            }
            return String(char)
        }.joined()
    }
    
    private var displayedSolutionText: String {
        guard let game = gameState.currentGame else { return "" }
        let solution = game.solution
        
        // Build the display with guessed letters or blocks
        return solution.enumerated().map { index, char -> String in
            if !char.isLetter {
                return String(char)
            }
            
            let encryptedChar = game.encrypted[game.encrypted.index(game.encrypted.startIndex, offsetBy: index)]
            
            if let guessedChar = game.guessedMappings[encryptedChar] {
                return String(guessedChar)
            }
            
            return "█"
        }.joined()
    }
}

// MARK: - Preview

struct GamePlayView_Previews: PreviewProvider {
    static var previews: some View {
        GamePlayView()
            .environmentObject(GameState.shared)
            .environmentObject(SettingsState.shared)
    }
}
