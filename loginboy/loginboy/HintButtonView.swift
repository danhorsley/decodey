import SwiftUI

struct HintButtonView: View {
    let remainingHints: Int
    let isLoading: Bool
    let isDarkMode: Bool
    let onHintRequested: () -> Void
    
    // Use design systems
    private let colors = ColorSystem.shared
    private let fonts = FontSystem.shared
    private let design = DesignSystem.shared
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onHintRequested) {
            hintButtonContent
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading || remainingHints <= 0)
        .accessibilityLabel("Hint Button")
        .accessibilityHint("You have \(remainingHints) hint tokens remaining")
    }
    
    // Extract content into a separate computed property
    private var hintButtonContent: some View {
        VStack(spacing: 4) {
            // Show spinner or hint count
            if isLoading {
                loadingView
            } else {
                hintCountView
            }
            
            // Label underneath
            Text("HINT TOKENS")
                .font(fonts.hintLabel())
                .foregroundColor(.secondary)
        }
        .frame(width: design.hintButtonWidth, height: design.hintButtonHeight)
        .background(buttonBackground)
        .overlay(buttonBorder)
        .cornerRadius(10)
    }
    
    // Loading indicator
    private var loadingView: some View {
        ProgressView()
            .scaleEffect(1.2)
            .progressViewStyle(CircularProgressViewStyle(tint: statusColor))
            .frame(height: 30)
            .padding(.vertical, 4)
    }
    
    // Hint count display
    private var hintCountView: some View {
        Text("\(remainingHints)")
            .font(fonts.hintValue())
            .foregroundColor(statusColor)
            .frame(height: 30)
    }
    
    // Background color
    private var buttonBackground: some View {
        colorScheme == .dark ?
            Color.black.opacity(0.3) :
            Color.gray.opacity(0.1)
    }
    
    // Border around button
    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(statusColor, lineWidth: 2)
    }
    
    // Determine the status color based on remaining hints
    private var statusColor: Color {
        if remainingHints <= 1 {
            return colors.hintButtonDanger(for: colorScheme)
        } else if remainingHints <= 3 {
            return colors.hintButtonWarning(for: colorScheme)
        } else {
            return colors.hintButtonSafe(for: colorScheme)
        }
    }
}
