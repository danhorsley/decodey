//
//  AlternatingTextDisplayView.swift
//  Decodey
//
//  FINAL: Matching macOS styling with proper iOS rendering
//

import SwiftUI

struct AlternatingTextDisplayView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState
    
    var body: some View {
        VStack(spacing: GameLayout.padding) {
            if settingsState.showTextHelpers {
                headerView
            }
            
            ScrollView {
                VStack(spacing: 0) {
                    contentView
                        .frame(maxWidth: 600)  // Match macOS max width
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, GameLayout.padding + 4)
                        .padding(.vertical, GameLayout.padding)
                        .background(Color("GameBackground"))
                        .cornerRadius(GameLayout.cornerRadius)
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 40) {
            Text("ENCRYPTED")
                .font(.gameSection)
                .tracking(1.5)
                .foregroundColor(Color("GameEncrypted").opacity(0.8))
            
            Text("SOLUTION")
                .font(.gameSection)
                .tracking(1.5)
                .foregroundColor(Color("GameGuess").opacity(0.8))
        }
        .padding(.vertical, GameLayout.paddingSmall)
    }
    
    private var contentView: some View {
        VStack(alignment: .center, spacing: 16) {
            ForEach(textLines.indices, id: \.self) { index in
                let line = textLines[index]
                
                // Each line pair tightly coupled
                VStack(alignment: .center, spacing: 4) {
                    // Encrypted line
                    HStack(spacing: 0) {
                        ForEach(Array(line.encrypted.enumerated()), id: \.offset) { offset, char in
                            encryptedCharView(char: char)
                        }
                    }
                    
                    // Solution line immediately below
                    HStack(spacing: 0) {
                        ForEach(Array(line.solution.enumerated()), id: \.offset) { offset, char in
                            let encIndex = line.encrypted.index(line.encrypted.startIndex, offsetBy: offset)
                            let encChar = line.encrypted[encIndex]
                            solutionCharView(solutionChar: char, encryptedChar: encChar)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .multilineTextAlignment(.center)
        .lineSpacing(4)
    }
    
    @ViewBuilder
    private func encryptedCharView(char: Character) -> some View {
        let isHighlighted = gameState.highlightedEncryptedLetter == char && char.isLetter
        
        Text(String(char))
            .font(.gameDisplay)  // Using the proper game font
            .foregroundColor(char.isLetter ? Color("GameEncrypted") : Color("GameEncrypted").opacity(0.6))
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(isHighlighted ? Color("HighlightColor").opacity(0.4) : Color.clear)
                    .frame(width: 16, height: 24)
            )
            .onTapGesture {
                if char.isLetter {
                    handleLetterTap(char)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isHighlighted)
    }
    
    @ViewBuilder
    private func solutionCharView(solutionChar: Character, encryptedChar: Character) -> some View {
        let isHighlighted = gameState.highlightedEncryptedLetter == encryptedChar && encryptedChar.isLetter
        
        Group {
            if !solutionChar.isLetter {
                // Punctuation/spaces
                Text(String(solutionChar))
                    .font(.gameDisplay)
                    .foregroundColor(Color("GameGuess").opacity(0.6))
            } else if let guessedChar = gameState.currentGame?.guessedMappings[encryptedChar] {
                // Already guessed letter
                Text(String(guessedChar))
                    .font(.gameDisplay)
                    .foregroundColor(Color("GameGuess"))
            } else {
                // Unguessed block
                Text("█")
                    .font(.gameDisplay)
                    .foregroundColor(isHighlighted ? Color("HighlightColor") : Color("GameGuess"))
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isHighlighted ? Color("HighlightColor").opacity(0.2) : Color.clear)
                            .frame(width: 16, height: 24)
                    )
            }
        }
        .onTapGesture {
            if encryptedChar.isLetter {
                handleLetterTap(encryptedChar)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
    }
    
    private func handleLetterTap(_ letter: Character) {
        gameState.selectLetter(letter)
        if gameState.currentGame?.selectedLetter == letter {
            gameState.selectedEncryptedLetter = letter
        } else {
            gameState.selectedEncryptedLetter = nil
        }
    }
    
    // Smart line breaking that preserves words
    private var textLines: [TextLine] {
        guard let game = gameState.currentGame else { return [] }
        
        let encrypted = game.encrypted
        let solution = game.solution
        
        #if os(iOS)
        // Calculate based on screen width
        let screenWidth = UIScreen.main.bounds.width
        // Account for padding: GameLayout.padding (16) + 4 on each side = 40 total
        // Plus some margin for safety
        let availableWidth = screenWidth - 60
        // Each character in Courier New 22pt is roughly 13-14pt wide
        let charWidth: CGFloat = 13.2
        let maxCharsPerLine = Int(availableWidth / charWidth)
        #else
        let maxCharsPerLine = 40
        #endif
        
        var lines: [TextLine] = []
        var currentEncrypted = ""
        var currentSolution = ""
        var currentWord = ""
        var currentWordSolution = ""
        var lineNumber = 0
        
        for i in 0..<encrypted.count {
            let encChar = encrypted[encrypted.index(encrypted.startIndex, offsetBy: i)]
            let solChar = solution[solution.index(solution.startIndex, offsetBy: i)]
            
            // Build current word
            if encChar != " " {
                currentWord.append(encChar)
                currentWordSolution.append(solChar)
            } else {
                // End of word - check if it fits
                if !currentWord.isEmpty {
                    if currentEncrypted.count + currentWord.count + 1 > maxCharsPerLine && !currentEncrypted.isEmpty {
                        // Start new line
                        lines.append(TextLine(
                            lineNumber: lineNumber,
                            encrypted: currentEncrypted,
                            solution: currentSolution
                        ))
                        lineNumber += 1
                        currentEncrypted = currentWord + " "
                        currentSolution = currentWordSolution + " "
                    } else {
                        // Add to current line
                        currentEncrypted += currentWord + " "
                        currentSolution += currentWordSolution + " "
                    }
                    currentWord = ""
                    currentWordSolution = ""
                }
            }
        }
        
        // Add last word if exists
        if !currentWord.isEmpty {
            if currentEncrypted.count + currentWord.count > maxCharsPerLine && !currentEncrypted.isEmpty {
                lines.append(TextLine(
                    lineNumber: lineNumber,
                    encrypted: currentEncrypted,
                    solution: currentSolution
                ))
                currentEncrypted = currentWord
                currentSolution = currentWordSolution
            } else {
                currentEncrypted += currentWord
                currentSolution += currentWordSolution
            }
        }
        
        // Add final line
        if !currentEncrypted.isEmpty {
            // Trim trailing spaces for cleaner display
            currentEncrypted = currentEncrypted.trimmingCharacters(in: .whitespaces)
            currentSolution = currentSolution.trimmingCharacters(in: .whitespaces)
            lines.append(TextLine(
                lineNumber: lineNumber,
                encrypted: currentEncrypted,
                solution: currentSolution
            ))
        }
        
        return lines
    }
}

// MARK: - Supporting Types

struct TextLine: Identifiable {
    let id = UUID()
    let lineNumber: Int
    var encrypted: String
    var solution: String
}
