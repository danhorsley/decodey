import SwiftUI

/// FontSystem provides consistent typography across the application
struct FontSystem {
    static let shared = FontSystem()
    
    // MARK: - Font Family
    
    // Base function for Courier New font
    private func courierNew(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Courier New", size: size).weight(weight)
    }
    
    // MARK: - Game-Specific Fonts
    
    // Letter cells
    func encryptedLetterCell() -> Font {
        courierNew(size: 22, weight: .semibold)
    }
    
    func guessLetterCell() -> Font {
        courierNew(size: 22, weight: .semibold)
    }
    
    // Frequency indicator
    func frequencyIndicator() -> Font {
        courierNew(size: 10, weight: .medium)
    }
    
    // Display text
    func encryptedDisplayText() -> Font {
        courierNew(size: 22, weight: .regular)
    }
    
    func solutionDisplayText() -> Font {
        courierNew(size: 22, weight: .semibold)
    }
    
    // Hint button
    func hintValue() -> Font {
        courierNew(size: 24, weight: .semibold)
    }
    
    func hintLabel() -> Font {
        courierNew(size: 10, weight: .medium)
    }
    
    // UI Elements
    func gameTitle() -> Font {
        courierNew(size: 34, weight: .bold)
    }
    
    func sectionTitle() -> Font {
        courierNew(size: 16, weight: .semibold)
    }
    
    func caption() -> Font {
        courierNew(size: 10, weight: .regular)
    }
    
    func buttonText() -> Font {
        courierNew(size: 18, weight: .semibold)
    }
    
    // Score display
    func scoreValue() -> Font {
        courierNew(size: 40, weight: .semibold)
    }
    
    func scoreLabel() -> Font {
        courierNew(size: 12, weight: .medium)
    }
    
    // MARK: - Responsive Fonts for Different Screen Sizes
    
    func encryptedLetterCellForSize(_ screenCategory: DesignSystem.ScreenSizeCategory) -> Font {
        let baseSize: CGFloat
        switch screenCategory {
        case .small:
            baseSize = 22
        case .medium:
            baseSize = 24
        case .large:
            baseSize = 28
        default:
            baseSize = 28
        }
        return courierNew(size: baseSize, weight: .semibold)
    }
    
    func guessLetterCellForSize(_ screenCategory: DesignSystem.ScreenSizeCategory) -> Font {
        let baseSize: CGFloat
        switch screenCategory {
        case .small:
            baseSize = 22
        case .medium:
            baseSize = 24
        case .large:
            baseSize = 28
        default:
            baseSize = 28
        }
        return courierNew(size: baseSize, weight: .semibold)
    }
    
    func displayTextForSize(_ screenCategory: DesignSystem.ScreenSizeCategory, isSolution: Bool) -> Font {
        let baseSize: CGFloat
        switch screenCategory {
        case .small:
            baseSize = 16
        case .medium:
            baseSize = 18
        case .large:
            baseSize = 20
        default:
            baseSize = 20
        }
        return courierNew(size: baseSize, weight: isSolution ? .semibold : .regular)
    }
}
