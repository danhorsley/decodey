import SwiftUI

// MARK: - Game Theme
// Simplified design system using SwiftUI's built-in semantic colors where possible
// Only defining what's unique to Decodey

extension Color {
    
    
    // MARK: - Game-Specific Colors
    // These are your unique brand colors that make Decodey special
    
//    /// Encrypted letter color (cyan in dark, blue in light)
//    static let gameEncrypted = Color("GameEncrypted")
//    // Create in Assets.xcassets: Light: #0076FF, Dark: #4CC9F0
//    
//    /// Guess letter color (green in dark, blue in light)
//    static let gameGuess = Color("GameGuess")
//    // Create in Assets.xcassets: Light: #0042AA, Dark: #00ED99
//    
//    /// Hint button colors based on remaining hints
//    static let hintSafe = Color("HintSafe")
//    // Create in Assets.xcassets: Light: .blue, Dark: #4CC9F0
//    
//    static let hintWarning = Color("HintWarning")
//    // Create in Assets.xcassets: Light: .orange, Dark: #FF9E64
//    
//    static let hintDanger = Color("HintDanger")
//    // Create in Assets.xcassets: Light: .red, Dark: #FF5277
//    
//    /// Win/Loss overlay colors
//    static let gameWin = Color("GameWin")
//    // Create in Assets.xcassets: Light: .green, Dark: #00ED99
//    
//    static let gameLoss = Color("GameLoss")
//    // Create in Assets.xcassets: Light: .red, Dark: #FF5277
    
    // MARK: - Helper Methods for Complex States
    
    /// Cell background color based on state
    static func cellBackground(isSelected: Bool, isGuessed: Bool) -> Color {
        if isSelected {
            // Use the appropriate game color when selected
            return isGuessed ? .gameGuess : .gameEncrypted
        } else if isGuessed {
            // Guessed but not selected - subtle gray
            return Color.gray.opacity(0.2)
        } else {
            // Default - clear
            return Color.clear
        }
    }
    
    /// Cell text color based on state
    static func cellText(isSelected: Bool, isGuessed: Bool, isEncrypted: Bool) -> Color {
        if isSelected {
            // High contrast when selected
            return .white  // Works in both light/dark since background is colored
        } else if isGuessed {
            // Muted when already guessed
            return .secondary
        } else if isEncrypted {
            // Encrypted letters use the theme color
            return .gameEncrypted
        } else {
            // Guess letters use the theme color
            return .gameGuess
        }
    }
    
    /// Cell border - adapts to color scheme automatically
    static var cellBorder: Color {
        Color.gray.opacity(0.3)
    }
}

// MARK: - Typography

extension Font {
    
    // MARK: - Core Game Fonts
    
    /// Main game title
    static let gameTitle = Font.custom("Courier New", size: 34).bold()
    
    /// Letter cells in grids
    static let gameCell = Font.custom("Courier New", size: 24).weight(.semibold)
    
    /// Small letter cells (for compact layouts)
    static let gameCellSmall = Font.custom("Courier New", size: 20).weight(.semibold)
    
    /// Display text (encrypted/solution)
    static let gameDisplay = Font.custom("Courier New", size: 22)
    
    /// Buttons
    static let gameButton = Font.custom("Courier New", size: 18).weight(.semibold)
    
    /// Section headers
    static let gameSection = Font.custom("Courier New", size: 16).weight(.semibold)
    
    /// Captions and labels
    static let gameCaption = Font.custom("Courier New", size: 12)
    
    /// Frequency indicators
    static let gameFrequency = Font.custom("Courier New", size: 10).weight(.medium)
    
    /// Score display
    static let gameScore = Font.custom("Courier New", size: 40).weight(.bold)
    
    /// Hint button
    static let hintValue = Font.custom("Courier New", size: 26).weight(.bold)
    static let hintLabel = Font.custom("Courier New", size: 12)
    
    // MARK: - Responsive Sizing
    // Only implement if you really need different sizes for iPad vs iPhone
    
    static func cellFont(for sizeClass: UserInterfaceSizeClass?) -> Font {
        sizeClass == .regular ? gameCell : gameCellSmall
    }
}

// MARK: - Layout Constants

enum GameLayout {
    /// Standard padding
    static let padding: CGFloat = 16
    static let paddingSmall: CGFloat = 8
    static let paddingLarge: CGFloat = 24
    
    /// Grid spacing
    static let gridSpacing: CGFloat = 8
    static let gridSpacingCompact: CGFloat = 4
    
    /// Cell sizing
    static let cellSize: CGFloat = 44
    static let cellSizeCompact: CGFloat = 36
    
    /// Corner radius
    static let cornerRadius: CGFloat = 8
    static let cornerRadiusLarge: CGFloat = 12
    
    /// Animation durations
    static let animationDuration: Double = 0.3
    static let animationDurationFast: Double = 0.2
}

// MARK: - Migration Helpers
// Temporary helpers to make migration easier - delete after migration

extension Color {
    /// Temporary helper - maps old system to new
    static func primaryBackground(_ colorScheme: ColorScheme) -> Color {
        // Just use the system background
        #if os(iOS)
        return Color(UIColor.systemBackground)
        #else
        return colorScheme == .dark ? .black : .white
        #endif
    }
    
    static func secondaryBackground(_ colorScheme: ColorScheme) -> Color {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #else
        return colorScheme == .dark ? Color(white: 0.11) : Color(white: 0.95)
        #endif
    }
}

// MARK: - Hex Initializer (keep this, it's useful)

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
//            (a, r, g, b) = (255, 255, 255, 0)
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
 BEFORE (old system):
 ```swift
 @Environment(\.colorScheme) var colorScheme
 private let colors = ColorSystem.shared
 private let fonts = FontSystem.shared
 
 Text("A")
     .font(fonts.encryptedLetterCell())
     .foregroundColor(colors.encryptedColor(for: colorScheme))
     .background(colors.selectedBackground(for: colorScheme, isEncrypted: true))
 ```
 
 AFTER (new system):
 ```swift
 Text("A")
     .font(.gameCell)
     .foregroundColor(.cellText(isSelected: false, isGuessed: false, isEncrypted: true))
     .background(Color.cellBackground(isSelected: true, isGuessed: false))
 ```
 
 EVEN SIMPLER for standard UI:
 ```swift
 Text("Settings")
     .font(.gameSection)
     .foregroundColor(.primary)  // Automatically adapts!
     .background(Color(UIColor.systemBackground))  // Automatically adapts!
 ```
*/
