import SwiftUI

struct HintButtonView: View {
    let remainingHints: Int
    let isLoading: Bool
    let isDarkMode: Bool  // Can probably remove this
    let onHintRequested: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    
    private let hintTexts = [
        8: "SEVEN",
        7: "█SIX█",
        6: "█FIVE",
        5: "FOUR█",
        4: "THREE",
        3: "█TWO█",
        2: "█ONE█",
        1: "ZERO█",
        0: "█████"
    ]
    
    var body: some View {
        Button(action: onHintRequested) {
            VStack(spacing: 2) {
                // Crossword-style display
                Text(hintTexts[remainingHints] ?? "█████")
                    .font(.hintValue)
                    .foregroundColor(textColor)
                    .tracking(2)
                    .frame(height: 40)
                    .overlay(
                        isLoading ?
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                            .scaleEffect(0.8) : nil
                    )
                
                // Label
                Text("HINT TOKENS")
                    .font(.hintLabel)
                    .foregroundColor(textColor.opacity(0.7))
                    .tracking(1)
            }
            .frame(width: 140, height: 80)
            .background(.gameBackground)  // Use system semantic color
            .cornerRadius(GameLayout.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                    .strokeBorder(Color.cellBorder, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: isPressed ? 2 : 8, x: 0, y: isPressed ? 1 : 4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading || remainingHints <= 0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
    
    // MARK: - Computed Color Properties
    
    private var textColor: Color {
        switch remainingHints {
        case 0...1:
            return .hintDanger  // Uses HintDanger.colorset from Assets
        case 2...3:
            return .hintWarning  // Uses HintWarning.colorset from Assets
        default:
            return .hintSafe  // Uses HintSafe.colorset from Assets
        }
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? .clear : Color.black.opacity(0.1)
    }
}
