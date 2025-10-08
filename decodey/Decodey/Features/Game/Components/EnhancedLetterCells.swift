// EnhancedLetterCells.swift - Updated with GameTheme
import SwiftUI

// MARK: - Enhanced Encrypted Letter Cell
struct EnhancedEncryptedLetterCell: View {
    let letter: Character
    let isSelected: Bool
    let isGuessed: Bool
    let frequency: Int
    let action: () -> Void
//    let highlightState: HighlightState
    
    
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    @State private var showRipple = false
    
    // No more ColorSystem/FontSystem needed!
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if colorScheme == .dark {
                    // Laser projection style
                    LaserKeyShape(isPressed: isPressed || isSelected)
                        .opacity(isGuessed ? 0.3 : 1.0)
                } else {
                    // Apple keyboard style
                    AppleKeyShape(isPressed: isPressed || isSelected)
                        .opacity(isGuessed ? 0.5 : 1.0)
                }
                
                // Key content
                VStack(spacing: 0) {
                    ZStack {
                        // Main letter
                        Text(String(letter))
                            .font(.gameCell)
                            .foregroundColor(letterColor)
                        
                        // Frequency indicator (top-right superscript)
                        if frequency > 1 && !isGuessed {
                            VStack {
                                HStack {
                                    Spacer()
                                    Text("\(frequency)")
                                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                                        .foregroundColor(letterColor.opacity(0.6))
                                        .offset(x: -4, y: 2)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .offset(y: isPressed || isSelected ? 0 : -1)
                
                // Holographic ripple effect for dark mode
                if colorScheme == .dark && showRipple {
                    LaserRippleEffect()
                }
                
                // Selected state border
                if isSelected {
                    RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                        .stroke(
                            Color("GameEncrypted"),  // Use GameEncrypted color for encrypted cell borders
                            lineWidth: colorScheme == .dark ? 1.5 : 2
                        )
                        .shadow(
                            color: Color("GameEncrypted").opacity(colorScheme == .dark ? 0.8 : 0.3),
                            radius: colorScheme == .dark ? 10 : 4
                        )
                }
            }
            .frame(width: 56, height: 44) // Keyboard key proportions
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isGuessed)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
                if pressing && colorScheme == .dark {
                    showRipple = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showRipple = false
                    }
                }
            },
            perform: {}
        )
    }
    
    private var letterColor: Color {
        if isSelected {
            // Use subtle grays for contrast
            return colorScheme == .dark ? Color.gray : Color.gray.opacity(0.8)
        } else if isGuessed {
            return Color.secondary
        } else {
            // Match the encrypted text color from the display
            return .gameEncrypted
        }
    }
}

// MARK: - Enhanced Guess Letter Cell
struct EnhancedGuessLetterCell: View {
    let letter: Character
    let isUsed: Bool
    let isIncorrectForSelected: Bool
    let action: () -> Void
//    let highlightState: HighlightState  // ADD THIS
    
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    @State private var showRipple = false
    
    var body: some View {
        Button(action: {
            action()
            // Optionally trigger highlight for guess letters too
//            if !isUsed && !isIncorrectForSelected {
//                highlightState.highlightLetter(letter)
//            }
        }) {
            ZStack {
                if colorScheme == .dark {
                    LaserKeyShape(isPressed: isPressed)
                        .opacity(isUsed || isIncorrectForSelected ? 0.3 : 1.0)
                } else {
                    AppleKeyShape(isPressed: isPressed)
                        .opacity(isUsed || isIncorrectForSelected ? 0.5 : 1.0)
                }
                
                // border
                if !isUsed && !isIncorrectForSelected && colorScheme == .dark {
                    RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                        .stroke(
                            Color("GameGuess").opacity(0.3),
                            lineWidth: 1
                        )
                        .shadow(
                            color: Color("GameGuess").opacity(0.8),
                            radius: 10
                        )
                }
                
                // Letter
                Text(String(letter))
                    .font(.gameCell)
                    .foregroundColor(letterColor)
                    .offset(y: isPressed ? 0 : -1)
                
                // Holographic ripple effect for dark mode
                if colorScheme == .dark && showRipple {
                    LaserRippleEffect()
                }
            }
            .frame(width: 56, height: 44) // Keyboard key proportions
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isUsed || isIncorrectForSelected)
        .opacity(isUsed || isIncorrectForSelected ? 0.7 : 1.0)
//        .highlightable(  // ADD THIS if using the modifier approach
//            for: letter,
////            state: highlightState,
//            style: .cell
//        )
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
                if pressing && colorScheme == .dark {
                    showRipple = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showRipple = false
                    }
                }
            },
            perform: {}
        )
    }
    
    private var letterColor: Color {
        if isUsed {
            return Color.secondary
        } else if isIncorrectForSelected {
            return Color.red.opacity(0.8)
        } else {
            // Match the solution text color
            return .gameGuess
        }
    }
}

// MARK: - Laser Projection Key Shape (Dark Mode)
struct LaserKeyShape: View {
    let isPressed: Bool
    
    var body: some View {
        ZStack {
            // Base projection area
            RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.6),
                            Color.black.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Laser edge glow
            RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.gameEncrypted.opacity(isPressed ? 0.9 : 0.7),
                            Color.gameEncrypted.opacity(isPressed ? 0.7 : 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isPressed ? 1.5 : 1
                )
                .shadow(color: Color.gameEncrypted.opacity(0.5), radius: isPressed ? 8 : 4)
            
            // Inner glow
            if !isPressed {
                RoundedRectangle(cornerRadius: GameLayout.cornerRadius - 1)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.gameEncrypted.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .padding(1)
            }
        }
    }
}

// MARK: - Apple Keyboard Key Shape (Light Mode)
struct AppleKeyShape: View {
    let isPressed: Bool
    
    var body: some View {
        ZStack {
            // Shadow layer
            if !isPressed {
                RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                    .fill(Color.black.opacity(0.08))
                    .offset(y: 1)
            }
            
            // Main key
            RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(hex: "F8F8F8")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Laser Ripple Effect
struct LaserRippleEffect: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.8
    
    var body: some View {
        RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
            .stroke(Color.gameEncrypted, lineWidth: 1)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.2
                    opacity = 0
                }
            }
            .allowsHitTesting(false)
    }
}

// MARK: - Hex Color Extension (keep this helper)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 255, 255, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

//// MARK: - Preview Provider
//struct EnhancedLetterCells_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            // Light mode
//            VStack(spacing: 20) {
//                HStack(spacing: 10) {
//                    EnhancedEncryptedLetterCell(letter: "A", isSelected: false, isGuessed: false, frequency: 3, action: {})
//                    EnhancedEncryptedLetterCell(letter: "B", isSelected: true, isGuessed: false, frequency: 1, action: {})
//                    EnhancedEncryptedLetterCell(letter: "C", isSelected: false, isGuessed: true, frequency: 0, action: {})
//                }
//                
//                HStack(spacing: 10) {
//                    EnhancedGuessLetterCell(letter: "X", isUsed: false, isIncorrectForSelected: false, action: {})
//                    EnhancedGuessLetterCell(letter: "Y", isUsed: true, isIncorrectForSelected: false, action: {})
//                    EnhancedGuessLetterCell(letter: "Z", isUsed: false, isIncorrectForSelected: true, action: {})
//                }
//            }
//            .padding()
//            .preferredColorScheme(.light)
//            
//            // Dark mode
//            VStack(spacing: 20) {
//                HStack(spacing: 10) {
//                    EnhancedEncryptedLetterCell(letter: "A", isSelected: false, isGuessed: false, frequency: 3, action: {})
//                    EnhancedEncryptedLetterCell(letter: "B", isSelected: true, isGuessed: false, frequency: 1, action: {})
//                    EnhancedEncryptedLetterCell(letter: "C", isSelected: false, isGuessed: true, frequency: 0, action: {})
//                }
//                
//                HStack(spacing: 10) {
//                    EnhancedGuessLetterCell(letter: "X", isUsed: false, isIncorrectForSelected: false, action: {})
//                    EnhancedGuessLetterCell(letter: "Y", isUsed: true, isIncorrectForSelected: false, action: {})
//                    EnhancedGuessLetterCell(letter: "Z", isUsed: false, isIncorrectForSelected: true, action: {})
//                }
//            }
//            .padding()
//            .background(Color.black)
//            .preferredColorScheme(.dark)
//        }
//    }
//}
