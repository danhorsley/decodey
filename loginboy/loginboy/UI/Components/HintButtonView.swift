import SwiftUI

struct HintButtonView: View {
    private var colors: ColorSystem { ColorSystem.shared }
    let remainingHints: Int
    let isLoading: Bool
    let isDarkMode: Bool
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
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
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
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(textColor.opacity(0.7))
                    .tracking(1)
            }
            .frame(width: 140, height: 80)
            .background(backgroundGradient)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: 1)
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
    
    private var backgroundGradient: some View {
        Group {
            if colorScheme == .light {
                // Use the existing ColorSystem
                LinearGradient(
                    colors: [
                        colors.primaryBackground(for: colorScheme),
                        colors.secondaryBackground(for: colorScheme)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                // Dark mode gradient using hex colors
                LinearGradient(
                    colors: [
                        Color(hex: "1C1C1E"),
                        Color(hex: "2C2C2E")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
    
    private var textColor: Color {
        switch remainingHints {
        case 0...1: return .red
        case 2...3: return .orange
        default: return colorScheme == .light ? .black : Color(hex: "4cc9f0")
        }
    }
    
    private var borderColor: Color {
        colorScheme == .light ?
            Color.gray.opacity(0.2) :  // Simple cross-platform solution
            Color.white.opacity(0.1)
    }
    
    private var shadowColor: Color {
        colorScheme == .light ?
            Color.black.opacity(0.1) :
            Color.clear
    }
}
