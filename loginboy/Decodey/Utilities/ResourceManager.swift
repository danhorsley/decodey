import Foundation
import SwiftUI
import AVFoundation

// A centralized resource manager for sounds, colors, and other assets
class ResourceManager {
    static let shared = ResourceManager()
    
    // Sound manager instance
    private(set) var soundManager = SoundManager.shared
    
    // Color library
    private(set) var colors = ColorSystem.shared
    
    // Font library
    private(set) var fonts = FontSystem.shared
    
    // Design system
    private(set) var design = DesignSystem.shared
    
    // Image cache
    private var imageCache: [String: Image] = [:]
    
    private init() {
        // Initialize resources
    }
    
    // MARK: - Image Loading
    
    func image(named: String) -> Image {
        if let cachedImage = imageCache[named] {
            return cachedImage
        }
        
        let image = Image(named)
        imageCache[named] = image
        return image
    }
    
    func clearImageCache() {
        imageCache.removeAll()
    }
    
    // MARK: - Color Themes
    
    enum ColorTheme: String, CaseIterable {
        case classic = "Classic"
        case darkMode = "Dark Mode"
        case highContrast = "High Contrast"
        case colorblindFriendly = "Colorblind Friendly"
        
        var primaryColor: Color {
            switch self {
            case .classic: return Color.blue
            case .darkMode: return Color.cyan
            case .highContrast: return Color.yellow
            case .colorblindFriendly: return Color.orange
            }
        }
        
        var secondaryColor: Color {
            switch self {
            case .classic: return Color.green
            case .darkMode: return Color(hex: "4cc9f0")
            case .highContrast: return Color.white
            case .colorblindFriendly: return Color.brown
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .classic: return Color.white
            case .darkMode: return Color.black
            case .highContrast: return Color.black
            case .colorblindFriendly: return Color(hex: "F5F5F5")
            }
        }
    }
    
    // MARK: - Sound Control
    
    func playSound(_ type: SoundManager.SoundType) {
        soundManager.play(type)
    }
    
    func stopAllSounds() {
        soundManager.stopAllSounds()
    }
    
    func setSoundEnabled(_ enabled: Bool) {
        soundManager.isSoundEnabled = enabled
    }
    
    func setSoundVolume(_ volume: Float) {
        soundManager.volume = volume
    }
    
    // MARK: - Appearance Helpers
    
    func applyTheme(_ theme: ColorTheme, to colorScheme: ColorScheme) {
        // This would actually update the app's appearance based on the theme
        // In a real implementation, this would update your Color system or UI theme
        print("Applying theme: \(theme.rawValue) for color scheme: \(colorScheme)")
    }
}

//
//  ResourceManager.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

