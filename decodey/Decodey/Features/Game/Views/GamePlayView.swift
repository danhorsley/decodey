// GamePlayView.swift
// Decodey
//
// Main game playing interface with header, display, and controls
// WITH LETTER HIGHLIGHTING SYSTEM

import SwiftUI

struct GamePlayView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState
    
    // Layout constants
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
        Group {
            if settingsState.useAlternatingTextDisplay {
                // Use the new alternating display
                AlternatingTextDisplayView()
            } else {
                // Use the existing stacked display WITH HIGHLIGHTING
                VStack(spacing: GameLayout.padding) {
                    // Encrypted text display
                    encryptedTextView
                    
                    // Solution text display
                    solutionTextView
                }
            }
        }
    }
    
    private var encryptedTextView: some View {
        VStack(alignment: .center, spacing: GameLayout.paddingSmall) {
            if settingsState.showTextHelpers {
                Text("ENCRYPTED")
                    .font(.gameSection)
                    .tracking(1.5)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            // Use the highlightable text instead of plain Text
            highlightableEncryptedText
                .padding(.horizontal, GameLayout.padding + 4)
                .padding(.vertical, GameLayout.padding)
                .background(Color("GameBackground"))
                .cornerRadius(GameLayout.cornerRadius)
        }
    }
    
    // NEW: Character-by-character display with highlighting
    private var highlightableEncryptedText: some View {
        let text = displayedEncryptedText
        
        return HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .font(.gameDisplay)
                    .foregroundColor(Color("GameEncrypted"))
                    .background(
                        // Check if this character matches the selected letter and this position should be highlighted
                        shouldHighlight(char: char, at: index) ?
                        Color("HighlightColor").opacity(0.4) : Color.clear
                    )
                    .animation(.easeInOut(duration: 0.3), value: gameState.highlightedEncryptedLetter)
            }
        }
        .multilineTextAlignment(.center)
        .lineSpacing(4)
    }
    
    // Helper function to determine if a character should be highlighted
    private func shouldHighlight(char: Character, at index: Int) -> Bool {
        guard let highlightedLetter = gameState.highlightedEncryptedLetter else { return false }
        return char == highlightedLetter && gameState.highlightPositions.contains(index)
    }
    
    private var solutionTextView: some View {
        VStack(alignment: .center, spacing: GameLayout.paddingSmall) {
            if settingsState.showTextHelpers {
                Text("YOUR SOLUTION")
                    .font(.gameSection)
                    .tracking(1.5)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            // Use character-by-character display for solution too
            highlightableSolutionText
                .padding(.horizontal, GameLayout.padding + 4)
                .padding(.vertical, GameLayout.padding)
                .background(Color("GameBackground"))
                .cornerRadius(GameLayout.cornerRadius)
        }
    }
    
    //highlight helper for solution text view
    @ViewBuilder
    private var highlightableSolutionText: some View {
        if let game = gameState.currentGame {
            let solution = game.solution
            
            HStack(spacing: 0) {
                ForEach(Array(solution.enumerated()), id: \.offset) { index, char in
                    let encryptedChar = game.encrypted[game.encrypted.index(game.encrypted.startIndex, offsetBy: index)]
                    let isHighlighted = gameState.highlightedEncryptedLetter == encryptedChar && encryptedChar.isLetter
                    
                    if !char.isLetter {
                        // Punctuation and spaces
                        Text(String(char))
                            .font(.gameDisplay)
                            .foregroundColor(Color("GameGuess"))
                    } else if let guessedChar = game.guessedMappings[encryptedChar] {
                        // Already guessed letters
                        Text(String(guessedChar))
                            .font(.gameDisplay)
                            .foregroundColor(Color("GameGuess"))
                    } else {
                        // Unguessed blocks - highlight when corresponding encrypted letter is selected
                        Text("█")
                            .font(.gameDisplay)
                            .foregroundColor(
                                isHighlighted ?
                                Color("HighlightColor") : Color("GameGuess")
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(isHighlighted ?
                                         Color("HighlightColor").opacity(0.2) : Color.clear)
                            )
                            .animation(.easeInOut(duration: 0.3), value: gameState.highlightedEncryptedLetter)
                    }
                }
            }
            .multilineTextAlignment(.center)
            .lineSpacing(4)
        } else {
            Text("")
                .font(.gameDisplay)
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
