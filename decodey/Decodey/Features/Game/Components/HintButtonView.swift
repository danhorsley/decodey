// HintButtonView.swift - Fixed version with correct hint counting
import SwiftUI

struct HintButtonView: View {
    let remainingHints: Int  // This is actually remaining mistakes (maxMistakes - mistakes)
    let isLoading: Bool
    let isDarkMode: Bool
    let onHintRequested: () -> Void
    
    @EnvironmentObject var gameState: GameState  // ADD THIS
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    
    private let hintTexts = [
        7: "SEVEN",
        6: "█SIX█",
        5: "█FIVE",
        4: "FOUR█",
        3: "THREE",
        2: "█TWO█",
        1: "█ONE█",
        0: "EMPTY"
    ]
    
    // Special text for infinite mode
    private let infiniteText = "█∞█∞█"
    
    // FIXED: Calculate actual hints available
    private var actualHintsAvailable: Int {
        // In infinite mode, always show infinite
        if gameState.isInfiniteMode {
            return 999  // Special value for infinite
        }
        // Normal mode - keep 1 mistake in reserve
        return max(0, remainingHints - 1)
    }
    
    // Button is disabled logic
    private var isDisabled: Bool {
        // Never disabled in infinite mode
        if gameState.isInfiniteMode {
            return isLoading
        }
        // Normal mode - disabled when no hints available
        return isLoading || actualHintsAvailable <= 0
    }
    
    var body: some View {
        Group {
            if isDisabled {
                disabledView
            } else {
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
    
    private var buttonContent: some View {
        VStack(spacing: 2) {
            // Display text based on mode
            if gameState.isInfiniteMode {
                Text(infiniteText)  // Show infinity symbol in infinite mode
                    .font(.hintValue)
                    .foregroundColor(.green)  // Green for infinite mode
                    .tracking(2)
                    .frame(height: 40)
            } else {
                Text(hintTexts[actualHintsAvailable] ?? "EMPTY")
                    .font(.hintValue)
                    .foregroundColor(textColor)
                    .tracking(2)
                    .frame(height: 40)
            }
            
            // Loading overlay
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                    .scaleEffect(0.8)
            }
            
            // Label
            Text(gameState.isInfiniteMode ? "INFINITE MODE" : "HINT TOKENS")
                .font(.hintLabel)
                .foregroundColor(gameState.isInfiniteMode ?
                    Color.green.opacity(0.7) : textColor.opacity(0.7))
                .tracking(1)
        }
        .frame(width: 140, height: 80)
        .background(.gameBackground)
        .cornerRadius(GameLayout.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                .strokeBorder(
                    gameState.isInfiniteMode ? Color.green : Color.cellBorder,
                    lineWidth: 1
                )
        )
        .shadow(
            color: gameState.isInfiniteMode ?
                Color.green.opacity(0.3) : shadowColor,
            radius: isPressed ? 2 : 8,
            x: 0,
            y: isPressed ? 1 : 4
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
    }
    // MARK: - Disabled View
    
    private var disabledView: some View {
        buttonContent
            .opacity(0.6)
            .allowsHitTesting(false)
    }
    
    // MARK: - Computed Color Properties
    
    private var textColor: Color {
        switch actualHintsAvailable {
        case 0:
            return .hintDanger  // No hints available
        case 1:
            return .hintDanger  // Last hint available
        case 2...3:
            return .hintWarning  // Getting low
        default:
            return .hintSafe  // Plenty left
        }
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? .clear : Color.black.opacity(0.1)
    }
}
