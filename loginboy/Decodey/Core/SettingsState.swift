//
//  SettingsState.swift - Fixed for Nuclear Refactor
//  loginboy
//

import Foundation
import CoreData
import Combine
import SwiftUI

/// SettingsState manages application settings and preferences
class SettingsState: ObservableObject {
    // Published settings with property observers to persist changes
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: Keys.isDarkMode)
            updateAppAppearance()
        }
    }
    
    @Published var showTextHelpers: Bool {
        didSet {
            UserDefaults.standard.set(showTextHelpers, forKey: Keys.showTextHelpers)
        }
    }
    
    @Published var useAccessibilityTextSize: Bool {
        didSet {
            UserDefaults.standard.set(useAccessibilityTextSize, forKey: Keys.useAccessibilityTextSize)
        }
    }
    
    @Published var gameDifficulty: String {
        didSet {
            UserDefaults.standard.set(gameDifficulty, forKey: Keys.gameDifficulty)
        }
    }
    
    // Enhanced letter cells setting
    @Published var useEnhancedLetterCells: Bool {
        didSet {
            UserDefaults.standard.set(useEnhancedLetterCells, forKey: Keys.useEnhancedLetterCells)
        }
    }
    
    // Sound settings
    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: Keys.soundEnabled)
            SoundManager.shared.isSoundEnabled = soundEnabled
        }
    }
    
    @Published var soundVolume: Float {
        didSet {
            UserDefaults.standard.set(soundVolume, forKey: Keys.soundVolume)
            SoundManager.shared.volume = soundVolume
        }
    }
    
    // NEW: Haptic feedback setting
    @Published var hapticEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticEnabled, forKey: Keys.hapticEnabled)
            SoundManager.shared.isHapticEnabled = hapticEnabled
        }
    }
    
    // Security settings
    @Published var useBiometricAuth: Bool {
        didSet {
            UserDefaults.standard.set(useBiometricAuth, forKey: Keys.useBiometricAuth)
        }
    }
    
    // App version (read-only)
    let appVersion: String
    
    // Core Data access
    private let coreData = CoreDataStack.shared
    private var cancellables = Set<AnyCancellable>()
    
    // UserDefaults keys
    private struct Keys {
        static let isDarkMode = "isDarkMode"
        static let showTextHelpers = "showTextHelpers"
        static let useAccessibilityTextSize = "useAccessibilityTextSize"
        static let gameDifficulty = "gameDifficulty"
        static let soundEnabled = "soundEnabled"
        static let soundVolume = "soundVolume"
        static let hapticEnabled = "hapticEnabled"  // NEW
        static let useBiometricAuth = "useBiometricAuth"
        static let useEnhancedLetterCells = "useEnhancedLetterCells"
    }
    
    // Singleton instance
    static let shared = SettingsState()
    
    // Initialize with defaults
    private init() {
        // Get app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersion = "\(version) (\(build))"
        } else {
            appVersion = "Unknown"
        }
        
        // Load saved settings or set defaults
        isDarkMode = UserDefaults.standard.object(forKey: Keys.isDarkMode) as? Bool ?? false
        showTextHelpers = UserDefaults.standard.object(forKey: Keys.showTextHelpers) as? Bool ?? false
        useAccessibilityTextSize = UserDefaults.standard.object(forKey: Keys.useAccessibilityTextSize) as? Bool ?? false
        gameDifficulty = UserDefaults.standard.object(forKey: Keys.gameDifficulty) as? String ?? "easy"
        soundEnabled = UserDefaults.standard.object(forKey: Keys.soundEnabled) as? Bool ?? true
        soundVolume = UserDefaults.standard.object(forKey: Keys.soundVolume) as? Float ?? 0.5
        hapticEnabled = UserDefaults.standard.object(forKey: Keys.hapticEnabled) as? Bool ?? true  // NEW
        useEnhancedLetterCells = UserDefaults.standard.object(forKey: Keys.useEnhancedLetterCells) as? Bool ?? true
        
        // Check biometric availability for default
        useBiometricAuth = UserDefaults.standard.object(forKey: Keys.useBiometricAuth) as? Bool ?? BiometricAuthHelper.shared.biometricAuthAvailable().0
        
        // Apply appearance immediately
        updateAppAppearance()
        
        // Setup sound manager
        SoundManager.shared.isSoundEnabled = soundEnabled
        SoundManager.shared.volume = soundVolume
    }
    
    // MARK: - Settings Management
    
    /// Update multiple settings at once
    func updateSettings(
        darkMode: Bool? = nil,
        showHelpers: Bool? = nil,
        accessibilityText: Bool? = nil,
        gameDifficulty: String? = nil,
        soundEnabled: Bool? = nil,
        soundVolume: Float? = nil,
        hapticEnabled: Bool? = nil,  // NEW
        useBiometricAuth: Bool? = nil
    ) {
        if let darkMode = darkMode {
            self.isDarkMode = darkMode
        }
        
        if let showHelpers = showHelpers {
            self.showTextHelpers = showHelpers
        }
        
        if let accessibilityText = accessibilityText {
            self.useAccessibilityTextSize = accessibilityText
        }
        
        if let gameDifficulty = gameDifficulty {
            self.gameDifficulty = gameDifficulty
        }
        
        if let soundEnabled = soundEnabled {
            self.soundEnabled = soundEnabled
        }
        
        if let soundVolume = soundVolume {
            self.soundVolume = soundVolume
        }
        
        if let hapticEnabled = hapticEnabled { self.hapticEnabled = hapticEnabled } //NEW
        
        if let useBiometricAuth = useBiometricAuth {
            self.useBiometricAuth = useBiometricAuth
        }
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        isDarkMode = true
        showTextHelpers = true
        useAccessibilityTextSize = false
        gameDifficulty = "medium"
        soundEnabled = true
        soundVolume = 0.5
        useEnhancedLetterCells = false
        useBiometricAuth = BiometricAuthHelper.shared.biometricAuthAvailable().0
    }
    
    /// Save current settings to a local user's preferences in Core Data
    func saveToUserPreferences(userId: String) {
        let context = coreData.mainContext
        
        // Find the user
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            
            guard let user = users.first else { return }
            
            // Get or create preferences
            let preferences: UserPreferencesCD
            if let existingPrefs = user.preferences {
                preferences = existingPrefs
            } else {
                preferences = UserPreferencesCD(context: context)
                user.preferences = preferences
                preferences.user = user
            }
            
            // Update from settings
            preferences.darkMode = isDarkMode
            preferences.showTextHelpers = showTextHelpers
            preferences.accessibilityTextSize = useAccessibilityTextSize
            preferences.gameDifficulty = gameDifficulty
            preferences.soundEnabled = soundEnabled
            preferences.soundVolume = soundVolume
            preferences.useBiometricAuth = useBiometricAuth
            preferences.lastSyncDate = Date()
            
            // Save changes
            try context.save()
            
            // No more network sync - all local now!
            print("✅ Settings saved locally for user: \(userId)")
            
        } catch {
            print("Error saving user preferences: \(error.localizedDescription)")
        }
    }
    
    /// Load settings from a user's Core Data preferences
    func loadFromUserPreferences(userId: String) {
        let context = coreData.mainContext
        
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first, let prefs = user.preferences else {
                return
            }
            
            // Update settings from preferences
            updateSettings(
                darkMode: prefs.darkMode,
                showHelpers: prefs.showTextHelpers,
                accessibilityText: prefs.accessibilityTextSize,
                gameDifficulty: prefs.gameDifficulty,
                soundEnabled: prefs.soundEnabled,
                soundVolume: prefs.soundVolume,
                useBiometricAuth: prefs.useBiometricAuth
            )
            
        } catch {
            print("Error loading user preferences: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Update app appearance based on dark mode setting
    private func updateAppAppearance() {
        #if os(iOS)
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = self.isDarkMode ? .dark : .light
            }
        }
        #endif
    }
}

// Helper extension for UserDefaults
extension UserDefaults {
    func exists(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

// REMOVED: SettingsSync protocol and UserPreferencesModel
// These were part of the network complexity we deleted! 🔥
