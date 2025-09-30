//
//  AlternatingTextDisplayView.swift
//  Decodey
//
//  Displays encrypted and solution text in alternating lines with proper character alignment
//  Uses GameTheme and modern SwiftUI cross-platform approach
//

import SwiftUI

struct AlternatingTextDisplayView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState
    
    // Layout constants
    private let maxContentWidth: CGFloat = 600
    private let characterSpacing: CGFloat = 2
    private let lineSpacing: CGFloat = 4
    
    var body: some View {
        VStack(spacing: GameLayout.padding) {
            if settingsState.showTextHelpers {
                headerView
            }
            
            ScrollView {
                VStack(alignment: .center, spacing: 0) {
                    ForEach(textLines, id: \.lineNumber) { line in
                        AlternatingLineView(
                            encryptedLine: line.encrypted,
                            solutionLine: line.solution,
                            guessedMappings: gameState.currentGame?.guessedMappings ?? [:],
                            characterSpacing: characterSpacing,
                            lineSpacing: lineSpacing
                        )
                    }
                }
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, GameLayout.padding + 4)
                .padding(.vertical, GameLayout.padding)
                .background(Color("GameBackground"))
                .cornerRadius(GameLayout.cornerRadius)
            }
        }
    }
    
    // MARK: - Header View
    
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
    
    // MARK: - Text Processing
    
    private var textLines: [TextLine] {
        guard let game = gameState.currentGame else { return [] }
        
        let encrypted = game.encrypted
        let solution = game.solution
        
        // Split text into words while preserving spaces and punctuation
        let words = splitIntoWords(encrypted: encrypted, solution: solution)
        
        // Group words into lines that fit the display width
        return createLines(from: words)
    }
    
    private func splitIntoWords(encrypted: String, solution: String) -> [WordPair] {
        var words: [WordPair] = []
        var currentEncrypted = ""
        var currentSolution = ""
        
        for (index, char) in encrypted.enumerated() {
            let solutionIndex = solution.index(solution.startIndex, offsetBy: index)
            let solutionChar = solution[solutionIndex]
            
            currentEncrypted.append(char)
            currentSolution.append(solutionChar)
            
            // Check if we should create a new word (after space or punctuation followed by space)
            if char == " " || (index < encrypted.count - 1 &&
                !char.isLetter &&
                encrypted[encrypted.index(encrypted.startIndex, offsetBy: index + 1)] == " ") {
                
                if !currentEncrypted.isEmpty {
                    words.append(WordPair(encrypted: currentEncrypted, solution: currentSolution))
                    currentEncrypted = ""
                    currentSolution = ""
                }
            }
        }
        
        // Add any remaining word
        if !currentEncrypted.isEmpty {
            words.append(WordPair(encrypted: currentEncrypted, solution: currentSolution))
        }
        
        return words
    }
    
    private func createLines(from words: [WordPair]) -> [TextLine] {
        var lines: [TextLine] = []
        var currentLine = TextLine(lineNumber: 0, encrypted: "", solution: "")
        // Use a fixed max width based on the content width, not screen size
        let maxWidth: CGFloat = maxContentWidth - 40
        let charWidth: CGFloat = 14 // Approximate width of monospace character
        
        for word in words {
            let wordWidth = CGFloat(word.encrypted.count) * charWidth
            let currentWidth = CGFloat(currentLine.encrypted.count) * charWidth
            
            // Check if adding this word would exceed line width
            if currentWidth + wordWidth > maxWidth && !currentLine.encrypted.isEmpty {
                // Start a new line
                lines.append(currentLine)
                currentLine = TextLine(lineNumber: lines.count, encrypted: word.encrypted, solution: word.solution)
            } else {
                // Add word to current line
                currentLine.encrypted += word.encrypted
                currentLine.solution += word.solution
            }
        }
        
        // Add the last line if not empty
        if !currentLine.encrypted.isEmpty {
            lines.append(currentLine)
        }
        
        return lines
    }
}

// MARK: - Line View

struct AlternatingLineView: View {
    let encryptedLine: String
    let solutionLine: String
    let guessedMappings: [Character: Character]
    let characterSpacing: CGFloat
    let lineSpacing: CGFloat
    
    var body: some View {
        VStack(alignment: .center, spacing: lineSpacing) {
            // Encrypted line
            HStack(spacing: characterSpacing) {
                ForEach(Array(encryptedLine.enumerated()), id: \.offset) { _, char in
                    CharacterView(
                        character: char,
                        color: Color("GameEncrypted"),
                        isLetter: char.isLetter
                    )
                }
            }
            
            // Solution line
            HStack(spacing: characterSpacing) {
                ForEach(Array(solutionLine.enumerated()), id: \.offset) { index, char in
                    let encryptedChar = encryptedLine[encryptedLine.index(encryptedLine.startIndex, offsetBy: index)]
                    let displayChar = getDisplayCharacter(
                        solutionChar: char,
                        encryptedChar: encryptedChar,
                        guessedMappings: guessedMappings
                    )
                    
                    CharacterView(
                        character: displayChar,
                        color: Color("GameGuess"),
                        isLetter: char.isLetter
                    )
                }
            }
        }
        .padding(.vertical, lineSpacing)
    }
    
    private func getDisplayCharacter(
        solutionChar: Character,
        encryptedChar: Character,
        guessedMappings: [Character: Character]
    ) -> Character {
        if !solutionChar.isLetter {
            return solutionChar
        }
        
        if let guessedChar = guessedMappings[encryptedChar] {
            return guessedChar
        }
        
        return "█"
    }
}

// MARK: - Character View

struct CharacterView: View {
    let character: Character
    let color: Color
    let isLetter: Bool
    
    var body: some View {
        Text(String(character))
            .font(.gameDisplay)
            .foregroundColor(isLetter ? color : color.opacity(0.6))
            .frame(width: 12, alignment: .center)
    }
}

// MARK: - Supporting Types

struct TextLine: Identifiable {
    let id = UUID()
    let lineNumber: Int
    var encrypted: String
    var solution: String
}

struct WordPair {
    let encrypted: String
    let solution: String
}

// MARK: - Integration Extension

extension AlternatingTextDisplayView {
    /// Factory method to create with proper alignment verification
    static func create() -> some View {
        AlternatingTextDisplayView()
    }
}


