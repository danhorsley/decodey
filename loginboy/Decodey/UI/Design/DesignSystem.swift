import SwiftUI

/// Simplified DesignSystem for portrait-only layout
struct DesignSystem {
    static let shared = DesignSystem()
    
    // MARK: - Screen Size Categories
    enum ScreenSizeCategory {
        case small      // iPhone SE, iPhone 8
        case medium     // iPhone X-14
        case large      // iPhone Plus, Pro Max
        case ipad       // All iPads
        case mac        // macOS
    }
    
    // Determine current device's screen size category
    var currentScreenSize: ScreenSizeCategory {
        #if os(iOS)
        let screen = UIScreen.main.bounds.size
        let width = min(screen.width, screen.height)
        
        switch width {
        case 0..<375:
            return .small
        case 375..<414:
            return .medium
        case 414..<768:
            return .large
        default:
            return .ipad
        }
        #elseif os(macOS)
        return .mac
        #else
        return .medium
        #endif
    }
    
    // MARK: - Game Grid Values (Portrait Only)
    
    /// Fixed cell size for portrait layout
    var letterCellSize: CGFloat {
        switch currentScreenSize {
        case .small:
            return 48
        case .medium:
            return 48
        case .large:
            return 52
        case .ipad:
            return 60
        case .mac:
            return 56
        }
    }
    
    /// Grid spacing
    var letterCellSpacing: CGFloat {
        return 8 // Consistent spacing across all sizes
    }
    
    /// Number of columns for portrait grid
    var gridColumns: Int {
        switch currentScreenSize {
        case .small:
            return 5
        case .medium, .large:
            return 5
        case .ipad, .mac:
            return 6
        }
    }
    
    // MARK: - Text Display
    
    /// Font size for encrypted/solution text
    var displayFontSize: CGFloat {
        switch currentScreenSize {
        case .small:
            return 18
        case .medium:
            return 20
        case .large:
            return 22
        case .ipad, .mac:
            return 24
        }
    }
    
    /// Padding for display areas
    var displayAreaPadding: CGFloat {
        switch currentScreenSize {
        case .small:
            return 16
        case .medium, .large:
            return 20
        case .ipad, .mac:
            return 24
        }
    }
    
    // MARK: - Hint Button
    
    var hintButtonWidth: CGFloat {
        return 140 // Fixed width for consistency
    }
    
    var hintButtonHeight: CGFloat {
        return 80 // Fixed height for consistency
    }
    
    // MARK: - Win/Lose Overlay
    
    var overlayWidth: CGFloat {
        switch currentScreenSize {
        case .small:
            return 320
        case .medium:
            return 340
        case .large:
            return 360
        case .ipad:
            return 420
        case .mac:
            return 400
        }
    }
    
    var overlayCornerRadius: CGFloat {
        return 20
    }
    
    // MARK: - Maximum Content Width
    
    /// Constrains content width on larger devices
    var maxContentWidth: CGFloat {
        switch currentScreenSize {
        case .small, .medium, .large:
            return .infinity
        case .ipad:
            return 600
        case .mac:
            return 500
        }
    }
}
