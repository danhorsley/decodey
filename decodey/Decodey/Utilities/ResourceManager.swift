import Foundation
import SwiftUI
import AVFoundation

// A centralized resource manager for sounds and other assets
class ResourceManager {
    static let shared = ResourceManager()
    
    // Sound manager instance
    private(set) var soundManager = SoundManager.shared
    
    // REMOVED: Color, Font, and Design system references
    // private(set) var colors = ColorSystem.shared
    // private(set) var fonts = FontSystem.shared
    // private(set) var design = DesignSystem.shared
    
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
    
    // MARK: - Memory Management
    
    func clearAllCaches() {
        clearImageCache()
        // Add any other cache clearing here if needed
    }
    
    func preloadResources() {
        // Preload any critical images or sounds if needed
        // This can help with performance
    }
    
    // MARK: - Convenience Methods
    
    func playSound(_ sound: SoundManager.SoundType) {
        soundManager.play(sound)
    }
}
