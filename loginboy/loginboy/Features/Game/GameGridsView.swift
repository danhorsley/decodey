import SwiftUI

struct GameGridsView: View {
    @EnvironmentObject var gameState: GameState
    let showTextHelpers: Bool
    
    @State private var isHintInProgress = false
    
    // Design system references
    private let design = DesignSystem.shared
    private let colors = ColorSystem.shared
    private let fonts = FontSystem.shared
    
    @Environment(\.colorScheme) var colorScheme
    
    // Fixed grid columns for portrait mode
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
    
    var body: some View {
        VStack(spacing: 24) {
            // Encrypted letters grid
            VStack(alignment: .center, spacing: 8) {
                if showTextHelpers {
                    Text("ENCRYPTED LETTERS")
                        .font(fonts.encryptedLetterCell())
                        .tracking(1.5)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                encryptedGrid
            }
            
            // Hint button - floating between grids
            HintButtonView(
                remainingHints: max(0, (gameState.currentGame?.maxMistakes ?? 5) - (gameState.currentGame?.mistakes ?? 0)),
                isLoading: isHintInProgress,
                isDarkMode: colorScheme == .dark,
                onHintRequested: handleHintRequest
            )
            .frame(width: 140, height: 80)
            .padding(.vertical, 8)
            
            // Guess letters grid
            VStack(alignment: .center, spacing: 8) {
                if showTextHelpers {
                    Text("YOUR LETTERS")
                        .font(fonts.guessLetterCell())
                        .tracking(1.5)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                guessGrid
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var encryptedGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 6) {
            if let game = gameState.currentGame {
                ForEach(game.uniqueEncryptedLetters(), id: \.self) { letter in
                    EncryptedLetterCell(
                        letter: letter,
                        isSelected: game.selectedLetter == letter,
                        isGuessed: game.correctlyGuessed().contains(letter),
                        frequency: game.letterFrequency[letter] ?? 0,
                        action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                gameState.selectLetter(letter)
                                // Play sound
                                SoundManager.shared.play(.letterClick)
                            }
                        }
                    )
                    .frame(width: 48, height: 48)
                }
            }
        }
        .frame(maxWidth: 280) // Constrain grid width
    }
    
    private var guessGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 6) {
            if let game = gameState.currentGame {
                let uniqueLetters = game.uniqueSolutionLetters()
                
                ForEach(uniqueLetters, id: \.self) { letter in
                    GuessLetterCell(
                        letter: letter,
                        isUsed: game.guessedMappings.values.contains(letter),
                        action: {
                            if game.selectedLetter != nil {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    let wasCorrect = gameState.currentGame?.guessedMappings[game.selectedLetter!] == nil
                                    gameState.makeGuess(letter)
                                    
                                    // Play appropriate sound after the guess
                                    if wasCorrect && gameState.currentGame?.guessedMappings[game.selectedLetter ?? " "] != nil {
                                        SoundManager.shared.play(.correctGuess)
                                    } else if gameState.currentGame?.hasLost == false && gameState.currentGame?.hasWon == false {
                                        SoundManager.shared.play(.incorrectGuess)
                                    }
                                }
                            }
                        }
                    )
                    .frame(width: 48, height: 48)
                }
            }
        }
        .frame(maxWidth: 280) // Match encrypted grid width
    }
    
    private func handleHintRequest() {
        guard !isHintInProgress else { return }
        
        isHintInProgress = true
        SoundManager.shared.play(.hint)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            gameState.getHint()
            isHintInProgress = false
        }
    }
}
