// GamePlayView.swift
// Decodey
//
// Main game playing interface with header, display, and controls

import SwiftUI

struct GamePlayView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState
    @Environment(\.colorScheme) var colorScheme
    
    private let fonts = FontSystem.shared
    private let colors = ColorSystem.shared
    private let maxContentWidth: CGFloat = 600
    private let sectionSpacing: CGFloat = 32
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with game controls
            GameHeaderView()
                .padding(.top, 8)
                .padding(.horizontal, 16)
            
            ScrollView {
                VStack(spacing: sectionSpacing) {
                    // Current game display
                    gameDisplaySection
                        .padding(.top, 24)
                    
                    // Letter grids and controls
                    GameGridsView(showTextHelpers: settingsState.showTextHelpers)
                        .environmentObject(gameState)
                        .environmentObject(settingsState)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Game Display Section
    
    private var gameDisplaySection: some View {
        VStack(spacing: 16) {
            // Encrypted text display
            encryptedTextView
            
            // Solution text display
            solutionTextView
        }
    }
    
    private var encryptedTextView: some View {
        VStack(alignment: .center, spacing: 8) {
            if settingsState.showTextHelpers {
                Text("ENCRYPTED")
                    .font(.custom("Courier New", size: 10).weight(.medium))
                    .tracking(1.5)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            Text(displayedEncryptedText)
                .font(fonts.encryptedDisplayText())
                .foregroundColor(colors.encryptedColor(for: colorScheme))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
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
                .font(fonts.solutionDisplayText())
                .foregroundColor(colors.guessColor(for: colorScheme))
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
