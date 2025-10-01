import SwiftUI

// MARK: - Encrypted Letter Cell (Simplified)
struct EncryptedLetterCell: View {
    let letter: Character
    let isSelected: Bool
    let isGuessed: Bool
    let frequency: Int
    let action: () -> Void
    
    // No more environment colorScheme needed!
    // No more ColorSystem, FontSystem, DesignSystem references!
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Container
                RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                            .stroke(
                                isSelected ? Color.accentColor : Color.cellBorder,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                
                // Letter - centered in the cell
                Text(String(letter))
                    .font(.gameCell)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Frequency counter in bottom right
                if frequency > 0 && !isGuessed {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(frequency)")
                                .font(.gameFrequency)
                                .foregroundColor(textColor.opacity(0.7))
                                .padding(4)
                        }
                    }
                }
            }
            .frame(width: GameLayout.cellSize, height: GameLayout.cellSize)
            .accessibilityLabel("Letter \(letter), frequency \(frequency)")
            .accessibilityHint(getAccessibilityHint())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isGuessed)
    }
    
    // MUCH SIMPLER color logic!
    private var backgroundColor: Color {
        Color.cellBackground(isSelected: isSelected, isGuessed: isGuessed)
    }
    
    private var textColor: Color {
        Color.cellText(isSelected: isSelected, isGuessed: isGuessed, isEncrypted: true)
    }
    
    private func getAccessibilityHint() -> String {
        if isGuessed {
            return "Already guessed"
        } else if isSelected {
            return "Currently selected"
        } else {
            return "Tap to select"
        }
    }
}

// MARK: - Guess Letter Cell (Simplified)
struct GuessLetterCell: View {
    let letter: Character
    let isUsed: Bool
    let isIncorrectForSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Container
                RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                            .stroke(Color.cellBorder, lineWidth: 1)
                    )
                
                // Letter - centered in the cell
                Text(String(letter))
                    .font(.gameCell)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: GameLayout.cellSize, height: GameLayout.cellSize)
            .accessibilityLabel("Letter \(letter)")
            .accessibilityHint(accessibilityHint)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isUsed)
        .opacity(isUsed || isIncorrectForSelected ? 0.5 : 1.0)
    }
    
    private var backgroundColor: Color {
        if isUsed {
            return Color.gray.opacity(0.1)
        } else if isIncorrectForSelected {
            return Color.red.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private var textColor: Color {
        if isUsed {
            return .secondary
        } else if isIncorrectForSelected {
            return Color.red.opacity(0.6)
        } else {
            return .gameGuess  
        }
    }
    
    private var accessibilityHint: String {
        if isUsed {
            return "Already used"
        } else if isIncorrectForSelected {
            return "Incorrect for selected letter"
        } else {
            return "Tap to guess"
        }
    }
}

// MARK: - Preview Provider
struct LetterCells_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            VStack(spacing: 20) {
                HStack(spacing: 10) {
                    EncryptedLetterCell(letter: "A", isSelected: false, isGuessed: false, frequency: 3, action: {})
                    EncryptedLetterCell(letter: "B", isSelected: true, isGuessed: false, frequency: 1, action: {})
                    EncryptedLetterCell(letter: "C", isSelected: false, isGuessed: true, frequency: 0, action: {})
                }
                
                HStack(spacing: 10) {
                    GuessLetterCell(letter: "X", isUsed: false, isIncorrectForSelected: false, action: {})
                    GuessLetterCell(letter: "Y", isUsed: true, isIncorrectForSelected: false, action: {})
                    GuessLetterCell(letter: "Z", isUsed: false, isIncorrectForSelected: true, action: {})
                }
            }
            .padding()
            .preferredColorScheme(.light)
            
            // Dark mode preview
            VStack(spacing: 20) {
                HStack(spacing: 10) {
                    EncryptedLetterCell(letter: "A", isSelected: false, isGuessed: false, frequency: 3, action: {})
                    EncryptedLetterCell(letter: "B", isSelected: true, isGuessed: false, frequency: 1, action: {})
                    EncryptedLetterCell(letter: "C", isSelected: false, isGuessed: true, frequency: 0, action: {})
                }
                
                HStack(spacing: 10) {
                    GuessLetterCell(letter: "X", isUsed: false, isIncorrectForSelected: false, action: {})
                    GuessLetterCell(letter: "Y", isUsed: true, isIncorrectForSelected: false, action: {})
                    GuessLetterCell(letter: "Z", isUsed: false, isIncorrectForSelected: true, action: {})
                }
            }
            .padding()
            .background(Color.black)
            .preferredColorScheme(.dark)
        }
    }
}
