import SwiftUI

// A singleton that provides styling values based on device characteristics
struct DesignSystem {
    static let shared = DesignSystem()
    
    // MARK: - Screen Size Categories
    enum ScreenSizeCategory {
        case small      // iPhone SE, iPhone 8
        case medium     // iPhone X, iPhone 11, iPhone 12/13
        case large      // iPhone Plus, iPhone Pro Max
        case ipadSmall  // iPad mini
        case ipadMedium // iPad
        case ipadLarge  // iPad Pro
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
        case 768..<834:
            return .ipadSmall
        case 834..<1024:
            return .ipadMedium
        default:
            return .ipadLarge
        }
        #elseif os(macOS)
        return .mac
        #else
        return .medium // Default
        #endif
    }
    
    // MARK: - Game Grid Values
    
    var letterCellSize: CGFloat {
        switch currentScreenSize {
        case .small:
            return 34
        case .medium:
            return 40
        case .large:
            return 45
        case .ipadSmall:
            return 50
        case .ipadMedium, .ipadLarge:
            return 55
        case .mac:
            return 48
        }
    }
    
    var letterCellSpacing: CGFloat {
        switch currentScreenSize {
        case .small:
            return 4
        case .medium, .large:
            return 6
        case .ipadSmall, .ipadMedium, .ipadLarge, .mac:
            return 8
        }
    }
    
    var letterCellFontSize: CGFloat {
        switch currentScreenSize {
        case .small:
            return 18
        case .medium:
            return 22
        case .large:
            return 24
        case .ipadSmall, .ipadMedium, .ipadLarge, .mac:
            return 28
        }
    }
    
    var gridColumnsPortrait: Int {
        switch currentScreenSize {
        case .small:
            return 6
        case .medium, .large:
            return 5
        case .ipadSmall, .ipadMedium:
            return 5
        case .ipadLarge, .mac:
            return 5
        }
    }
    
    var gridColumnsLandscape: Int {
        switch currentScreenSize {
        case .small, .medium:
            return 6
        case .large:
            return 5
        case .ipadSmall:
            return 5
        case .ipadMedium, .ipadLarge, .mac:
            return 5
        }
    }
    
    // MARK: - Hint Button Values
    
    var hintButtonWidth: CGFloat {
        switch currentScreenSize {
        case .small:
            return 90
        case .medium, .large:
            return 110
        case .ipadSmall, .ipadMedium, .ipadLarge, .mac:
            return 130
        }
    }
    
    var hintButtonHeight: CGFloat {
        switch currentScreenSize {
        case .small:
            return 60
        case .medium, .large:
            return 70
        case .ipadSmall, .ipadMedium, .ipadLarge, .mac:
            return 80
        }
    }
    
    // MARK: - Text Display Area
    
    var displayFontSize: CGFloat {
        switch currentScreenSize {
        case .small:
            return 14
        case .medium:
            return 16
        case .large:
            return 18
        case .ipadSmall, .ipadMedium, .ipadLarge, .mac:
            return 20
        }
    }
    
    var displayAreaPadding: CGFloat {
        switch currentScreenSize {
        case .small:
            return 8
        case .medium, .large:
            return 12
        case .ipadSmall, .ipadMedium, .ipadLarge, .mac:
            return 16
        }
    }
    
    // MARK: - Win/Lose Overlay
    
    var overlayWidth: CGFloat {
        switch currentScreenSize {
        case .small:
            return 280
        case .medium:
            return 320
        case .large:
            return 350
        case .ipadSmall:
            return 400
        case .ipadMedium, .ipadLarge, .mac:
            return 450
        }
    }
    
    var overlayCornerRadius: CGFloat {
        switch currentScreenSize {
        case .small, .medium, .large:
            return 20
        case .ipadSmall, .ipadMedium, .ipadLarge, .mac:
            return 24
        }
    }
    
    // MARK: - Colors and Themes
    
    // Colors could also be defined here to maintain a consistent palette
    let primaryColor = Color.blue
    let secondaryColor = Color.gray
    let accentColor = Color.green
    let errorColor = Color.red
    let warningColor = Color.orange
    
    // Dark mode specific colors could be added too
    func backgroundColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black : Color.white
    }
}

//
//  DesignSystem.swift
//  decodey
//
//  Created by Daniel Horsley on 07/05/2025.
//

