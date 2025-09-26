import SwiftUI

/// ColorSystem provides consistent color theming across the application
/// Rewritten to use modern SwiftUI cross-platform approach
struct ColorSystem {
    static let shared = ColorSystem()
    
    // MARK: - Brand Colors
    
    /// Primary app accent color
    var accent: Color {
        Color.blue
    }
    
    // MARK: - Semantic Colors
    
    var success: Color {
        Color.green
    }
    
    var warning: Color {
        Color.orange
    }
    
    var error: Color {
        Color.red
    }
    
    // MARK: - Text Colors
    
    func primaryText(for colorScheme: ColorScheme) -> Color {
        // Using semantic color that automatically adapts
        Color.primary
    }
    
    func secondaryText(for colorScheme: ColorScheme) -> Color {
        // Using semantic color for secondary text
        Color.secondary
    }
    
    // MARK: - Background Colors
    
    func primaryBackground(for colorScheme: ColorScheme) -> Color {
        // True cross-platform approach using colorScheme
        colorScheme == .dark ? Color.black : Color.white
    }
    
    func secondaryBackground(for colorScheme: ColorScheme) -> Color {
        // Cross-platform secondary background
        colorScheme == .dark ? Color(white: 0.11) : Color(white: 0.95)
    }
    
    func tertiaryBackground(for colorScheme: ColorScheme) -> Color {
        // Platform-adaptive tertiary background
        colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.92)
    }
    
    // MARK: - Border Colors
    
    func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.gray.opacity(0.4) : Color.gray.opacity(0.3)
    }
    
    // MARK: - Game-Specific Colors
    
    // Encrypted Text & Grid - now combined
    func encryptedColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "4cc9f0") : Color(hex: "0076FF")
    }
    
    // Guess Text & Grid - now combined
    func guessColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "00ed99") : Color(hex: "0042aa")
    }
    
    func cellBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.gray.opacity(0.4) : Color.gray.opacity(0.3)
    }
    
    // Selected state
    func selectedBackground(for colorScheme: ColorScheme, isEncrypted: Bool) -> Color {
        if isEncrypted {
            return encryptedColor(for: colorScheme)
        } else {
            return guessColor(for: colorScheme)
        }
    }
    
    func selectedText(for colorScheme: ColorScheme) -> Color {
        // Always high contrast for selected text
        colorScheme == .dark ? Color.black : Color.white
    }
    
    // Guessed state
    func guessedText(for colorScheme: ColorScheme) -> Color {
        Color.gray
    }
    
    func guessedBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)
    }
    
    // MARK: - Hint Button Colors
    
    func hintButtonSafe(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "4cc9f0") : Color.blue
    }
    
    func hintButtonWarning(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "FF9E64") : Color.orange
    }
    
    func hintButtonDanger(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "FF5277") : Color.red
    }
    
    // MARK: - Overlay Colors
    
    func overlayBackground(opacity: Double = 0.75) -> Color {
        Color.black.opacity(opacity)
    }
    
    func winColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "00ed99") : Color.green
    }
    
    func loseColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(hex: "FF5277") : Color.red
    }
}

// MARK: - Modern SwiftUI Extensions

extension Color {
    /// True cross-platform background colors
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    static func secondaryBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.11) : Color(white: 0.95)
    }
    
    static func tertiaryBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.92)
    }
}

// MARK: - Platform-Adaptive Color Protocol

/// For cases where you need platform-specific behavior
@available(iOS 14.0, macOS 11.0, *)
struct AdaptiveColor: ShapeStyle {
    let light: Color
    let dark: Color
    
    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        environment.colorScheme == .dark ? dark : light
    }
}

// MARK: - Environment Extensions

extension EnvironmentValues {
    /// Convenience for accessing color system
    var colors: ColorSystem {
        ColorSystem.shared
    }
}

// MARK: - View Extensions for Easy Access

extension View {
    /// Apply adaptive background color
    func adaptiveBackground(_ colorScheme: ColorScheme, style: BackgroundStyle = .primary) -> some View {
        let color: Color
        switch style {
        case .primary:
            color = ColorSystem.shared.primaryBackground(for: colorScheme)
        case .secondary:
            color = ColorSystem.shared.secondaryBackground(for: colorScheme)
        case .tertiary:
            color = ColorSystem.shared.tertiaryBackground(for: colorScheme)
        }
        return self.background(color)
    }
    
    /// Apply adaptive text color
    func adaptiveText(_ colorScheme: ColorScheme, style: TextStyle = .primary) -> some View {
        let color: Color
        switch style {
        case .primary:
            color = ColorSystem.shared.primaryText(for: colorScheme)
        case .secondary:
            color = ColorSystem.shared.secondaryText(for: colorScheme)
        case .encrypted:
            color = ColorSystem.shared.encryptedColor(for: colorScheme)
        case .guess:
            color = ColorSystem.shared.guessColor(for: colorScheme)
        }
        return self.foregroundColor(color)
    }
}

// MARK: - Supporting Types

enum BackgroundStyle {
    case primary, secondary, tertiary
}

enum TextStyle {
    case primary, secondary, encrypted, guess
}

// MARK: - Hex Color Extension (keeping this as it's still useful)

//extension Color {
//    init(hex: String) {
//        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//        var int: UInt64 = 0
//        Scanner(string: hex).scanHexInt64(&int)
//        let a, r, g, b: UInt64
//        switch hex.count {
//        case 3: // RGB (12-bit)
//            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
//        case 6: // RGB (24-bit)
//            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
//        case 8: // ARGB (32-bit)
//            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
//        default:
//            (a, r, g, b) = (1, 1, 1, 0)
//        }
//        self.init(
//            .sRGB,
//            red: Double(r) / 255,
//            green: Double(g) / 255,
//            blue: Double(b) / 255,
//            opacity: Double(a) / 255
//        )
//    }
//}

// MARK: - Usage Examples

/*
 // Old way:
 #if os(iOS)
 Color(UIColor.systemBackground)
 #else
 Color(NSColor.windowBackgroundColor)
 #endif
 
 // New way:
 ColorSystem.shared.primaryBackground(for: colorScheme)
 // or in a View:
 @Environment(\.colorScheme) var colorScheme
 Color.background(for: colorScheme)
 
 // In a View:
 Text("Hello")
     .adaptiveText(colorScheme, style: .primary)
     .adaptiveBackground(colorScheme, style: .secondary)
*/
