//
//  GameGridsView.swift - NUCLEAR COMPATIBLE VERSION
//  loginboy
//

import SwiftUI

struct GameGridsView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState
    let showTextHelpers: Bool
    
    @State private var isHintInProgress = false
    
    // Keep colorScheme for HintButtonView compatibility
    @Environment(\.colorScheme) var colorScheme
    
    // Fixed grid columns with consistent spacing
    private var gridColumns: [GridItem] {
        // Match the spacing to be consistent (8 for enhanced, 6 for regular)
        let spacing: CGFloat = settingsState.useEnhancedLetterCells ? 8 : 6
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: 5)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Encrypted letters grid
            VStack(alignment: .center, spacing: 8) {
                if showTextHelpers {
                    Text("ENCRYPTED LETTERS")
                        .font(.custom("Courier New", size: 10).weight(.medium))
                        .tracking(1.5)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                encryptedGrid
                    .tutorialTarget(.encryptedGrid)  // <-- ADD THIS
            }
            
            // Hint button - floating between grids
            HintButtonView(
                remainingHints: max(0, (gameState.currentGame?.maxMistakes ?? 5) - (gameState.currentGame?.mistakes ?? 0)),
                isLoading: isHintInProgress,
                isDarkMode: colorScheme == .dark,
                onHintRequested: handleHintRequest
            )
            .tutorialTarget(.hintButton)
            .frame(width: 140, height: 80)
            .padding(.vertical, 8)
            
            // Guess letters grid
            VStack(alignment: .center, spacing: 8) {
                if showTextHelpers {
                    Text("SOLUTION LETTERS")
                        .font(.custom("Courier New", size: 10).weight(.medium))
                        .tracking(1.5)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                guessGrid
                    .tutorialTarget(.guessGrid)  // <-- ADD THIS
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Encrypted Letters Grid
    
    private var encryptedGrid: some View {
        // Use the same spacing for both horizontal and vertical
        let spacing: CGFloat = settingsState.useEnhancedLetterCells ? 8 : 6
        
        return LazyVGrid(columns: gridColumns, spacing: spacing) {
            if let game = gameState.currentGame {
                ForEach(game.getUniqueEncryptedLetters(), id: \.self) { letter in
                    if settingsState.useEnhancedLetterCells {
                        EnhancedEncryptedLetterCell(
                            letter: letter,
                            isSelected: game.selectedLetter == letter,
                            isGuessed: game.isLetterGuessed(letter),
                            frequency: game.getLetterFrequency(letter),
                            action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    gameState.selectLetter(letter)
                                    SoundManager.shared.play(.letterClick)
                                }
                            }
                        )
                    } else {
                        EncryptedLetterCell(
                            letter: letter,
                            isSelected: game.selectedLetter == letter,
                            isGuessed: game.isLetterGuessed(letter),
                            frequency: game.getLetterFrequency(letter),
                            action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    gameState.selectLetter(letter)
                                    SoundManager.shared.play(.letterClick)
                                }
                            }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: 320) // Slightly wider to accommodate keyboard-style cells
    }
    
    // MARK: - Guess Letters Grid
    
    private var guessGrid: some View {
        // Use the same spacing for both horizontal and vertical
        let spacing: CGFloat = settingsState.useEnhancedLetterCells ? 8 : 6
        
        return LazyVGrid(columns: gridColumns, spacing: spacing) {
            if let game = gameState.currentGame {
                let uniqueLetters = game.getUniqueSolutionLetters()
                
                ForEach(uniqueLetters, id: \.self) { (letter: Character) in
                    let isIncorrect: Bool = {
                        if let selected = game.selectedLetter {
                            return game.incorrectGuesses[selected]?.contains(letter) ?? false
                        }
                        return false
                    }()
                    
                    if settingsState.useEnhancedLetterCells {
                        EnhancedGuessLetterCell(
                            letter: letter,
                            isUsed: game.guessedMappings.values.contains(letter),
                            isIncorrectForSelected: isIncorrect,
                            action: {
                                // FIXED: Use if-let to safely unwrap selectedLetter
                                if let selected = game.selectedLetter, !isIncorrect {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        // Check if this will be a correct guess
                                        let willBeCorrect = game.correctMappings[selected] == letter
                                        
                                        // Call makeGuess with proper parameters
                                        gameState.makeGuess(for: selected, with: letter)
                                        
                                        // Play appropriate sound after the guess
                                        if willBeCorrect {
                                            SoundManager.shared.play(.correctGuess)
                                        } else if gameState.currentGame?.hasLost == false && gameState.currentGame?.hasWon == false {
                                            SoundManager.shared.play(.incorrectGuess)
                                        }
                                    }
                                }
                            }
                        )
                    } else {
                        GuessLetterCell(
                            letter: letter,
                            isUsed: game.guessedMappings.values.contains(letter),
                            isIncorrectForSelected: isIncorrect,
                            action: {
                                // FIXED: Use if-let to safely unwrap selectedLetter
                                if let selected = game.selectedLetter, !isIncorrect {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        // Check if this will be a correct guess
                                        let willBeCorrect = game.correctMappings[selected] == letter
                                        
                                        // Call makeGuess with proper parameters
                                        gameState.makeGuess(for: selected, with: letter)
                                        
                                        // Play appropriate sound after the guess
                                        if willBeCorrect {
                                            SoundManager.shared.play(.correctGuess)
                                        } else if gameState.currentGame?.hasLost == false && gameState.currentGame?.hasWon == false {
                                            SoundManager.shared.play(.incorrectGuess)
                                        }
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: 320) // Slightly wider to accommodate keyboard-style cells
    }
    
    // MARK: - Hint Handling
    
    private func handleHintRequest() {
        guard !isHintInProgress else { return }
        
        guard let game = gameState.currentGame else { return }
        
        // FIXED: In infinite mode, always allow hints
        if gameState.isInfiniteMode {
            isHintInProgress = true
            SoundManager.shared.play(.hint)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                gameState.getHint()
                isHintInProgress = false
            }
            return
        }
        
        // Normal mode - check if we have hints remaining
        let remainingHints = game.maxMistakes - game.mistakes
        guard remainingHints > 1 else { return }  // Keep 1 mistake in reserve
        
        isHintInProgress = true
        SoundManager.shared.play(.hint)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            gameState.getHint()
            isHintInProgress = false
        }
    }
}
// MARK: - Preview

struct GameGridsView_Previews: PreviewProvider {
    static var previews: some View {
        GameGridsView(showTextHelpers: true)
            .environmentObject(GameState.shared)
            .environmentObject(SettingsState.shared)
            .preferredColorScheme(.dark)
    }
}
