// Updated GameGridsView.swift

import SwiftUI

struct GameGridsView: View {
    @EnvironmentObject var gameState: GameState
    
    let showTextHelpers: Bool
    
    @State private var isHintInProgress = false
    
    // Use DesignSystem for consistent sizing
    private let design = DesignSystem.shared
    private let colors = ColorSystem.shared
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        GeometryReader { geometry in
            // Detect orientation using GeometryReader instead of UIKit
            let isLandscape = geometry.size.width > geometry.size.height
            
            if isLandscape || horizontalSizeClass == .regular {
                // Landscape or iPad layout
                HStack(alignment: .center) {
                    encryptedGrid
                    
                    Spacer()
                    
                    hintButton
                    
                    Spacer()
                    
                    guessGrid
                }
                .padding(.horizontal)
            } else {
                // Portrait layout for phones
                VStack(spacing: 24) {
                    encryptedGrid
                    
                    hintButton
                        .padding(.vertical, 8)
                    
                    guessGrid
                }
            }
        }
        .background(colors.primaryBackground(for: colorScheme))
    }
    
    // Encrypted grid
    private var encryptedGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showTextHelpers {
                Text("Select a letter to decode:")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Create grid with columns based on geometry
            GeometryReader { gridGeometry in
                // Create grid with number of columns based on size
                let isLandscape = gridGeometry.size.width > gridGeometry.size.height
                
                if let game = gameState.currentGame {
                    LazyVGrid(columns: createGridColumns(isLandscape: isLandscape), spacing: design.letterCellSpacing) {
                        ForEach(game.uniqueEncryptedLetters(), id: \.self) { letter in
                            EncryptedLetterCell(
                                letter: letter,
                                isSelected: game.selectedLetter == letter,
                                isGuessed: game.correctlyGuessed().contains(letter),
                                frequency: game.letterFrequency[letter] ?? 0,
                                action: {
                                    withAnimation {
                                        gameState.selectLetter(letter)
                                    }
                                }
                            )
                            .frame(width: design.letterCellSize, height: design.letterCellSize)
                        }
                    }
                    .frame(width: gridGeometry.size.width)
                }
            }
        }
    }
    
    // Guess grid
    var guessGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showTextHelpers {
                Text("Guess with:")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Get unique letters from the solution (not the encrypted version)
            if let game = gameState.currentGame {
                let uniqueLetters = game.uniqueSolutionLetters()
                
                // Create grid with adaptive columns
                GeometryReader { gridGeometry in
                    let isLandscape = gridGeometry.size.width > gridGeometry.size.height
                    
                    LazyVGrid(columns: createGridColumns(isLandscape: isLandscape), spacing: design.letterCellSpacing) {
                        ForEach(uniqueLetters, id: \.self) { letter in
                            GuessLetterCell(
                                letter: letter,
                                isUsed: game.guessedMappings.values.contains(letter),
                                action: {
                                    if game.selectedLetter != nil {
                                        withAnimation {
                                            gameState.makeGuess(letter)
                                        }
                                    }
                                }
                            )
                            .frame(width: design.letterCellSize, height: design.letterCellSize)
                        }
                    }
                    .frame(width: gridGeometry.size.width)
                }
            }
        }
    }
    
    // Helper to create adaptive grid columns
    private func createGridColumns(isLandscape: Bool) -> [GridItem] {
        let columnCount = isLandscape ?
            design.gridColumnsLandscape :
            design.gridColumnsPortrait
            
        return Array(repeating: GridItem(.flexible(), spacing: design.letterCellSpacing), count: columnCount)
    }
    
    // Hint button
    private var hintButton: some View {
        HintButtonView(
            remainingHints: gameState.currentGame?.maxMistakes ?? 5 - (gameState.currentGame?.mistakes ?? 0),
            isLoading: isHintInProgress,
            isDarkMode: colorScheme == .dark,
            onHintRequested: {
                // Only perform action if not already in progress
                guard !isHintInProgress else { return }
                
                // Show loading state
                isHintInProgress = true
                
                // Process hint with slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    gameState.getHint()
                    
                    // Reset loading state
                    isHintInProgress = false
                }
            }
        )
        .frame(width: design.hintButtonWidth, height: design.hintButtonHeight)
    }
}
