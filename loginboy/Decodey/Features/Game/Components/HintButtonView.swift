import SwiftUI

struct HintButtonView: View {
    let remainingHints: Int
    let isLoading: Bool
    let isDarkMode: Bool  // Can probably remove this
    let onHintRequested: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    
    private let hintTexts = [
        7: "SEVEN",
        6: "█SIX█",
        5: "█FIVE",
        4: "FOUR█",
        3: "THREE",
        2: "█TWO█",
        1: "█ONE█"
    ]
    
    // CHANGED: Button is disabled when remainingHints <= 0 (not <= 1)
    // When remainingHints = 1, you can still use that last hint
    private var isDisabled: Bool {
        isLoading || remainingHints <= 0
    }
    
    var body: some View {
        // CHANGED: Wrap in a Group and conditionally apply button vs non-interactive view
        Group {
            if isDisabled {
                // Non-interactive view when disabled
                disabledView
            } else {
                // Interactive button when enabled
                Button(action: onHintRequested) {
                    buttonContent
                }
                .buttonStyle(PlainButtonStyle())
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = pressing
                    }
                }, perform: {})
            }
        }
    }
    
    // MARK: - Button Content (extracted for reuse)
    
    private var buttonContent: some View {
        VStack(spacing: 2) {
            // Crossword-style display
            Text(hintTexts[remainingHints] ?? "█ONE█")  // CHANGED: Default to "ONE" for safety
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
    
    // MARK: - Disabled View (non-interactive)
    
    private var disabledView: some View {
        buttonContent
            .opacity(0.6) // Visual indication it's disabled
            .allowsHitTesting(false) // Completely prevent interaction
    }
    
    // MARK: - Computed Color Properties
    
    private var textColor: Color {
        switch remainingHints {
        case 0:
            return .hintDanger  // Should never be clickable at 0
        case 1:
            return .hintDanger  // Last usable hint - red/danger
        case 2...3:
            return .hintWarning  // Getting low - orange/warning
        default:
            return .hintSafe  // Plenty left - blue/safe
        }
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? .clear : Color.black.opacity(0.1)
    }
}
