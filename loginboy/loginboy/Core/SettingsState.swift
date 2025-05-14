// SettingsState.swift - Simplified for Realm
import SwiftUI
import Combine
import Foundation
import RealmSwift

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
    
    // Security settings
    @Published var useBiometricAuth: Bool {
        didSet {
            UserDefaults.standard.set(useBiometricAuth, forKey: Keys.useBiometricAuth)
        }
    }
    
    // App version (read-only)
    let appVersion: String
    
    // Realm access
    private let realm = RealmManager.shared.getRealm()
    
    // UserDefaults keys
    private struct Keys {
        static let isDarkMode = "isDarkMode"
        static let showTextHelpers = "showTextHelpers"
        static let useAccessibilityTextSize = "useAccessibilityTextSize"
        static let gameDifficulty = "gameDifficulty"
        static let soundEnabled = "soundEnabled"
        static let soundVolume = "soundVolume"
        static let useBiometricAuth = "useBiometricAuth"
    }
    
    // Singleton instance
    static let shared = SettingsState()
    
    // Initialize with defaults
    private init() {
        // Get app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            self.appVersion = "\(version) (\(build))"
        } else {
            self.appVersion = "Unknown"
        }
        
        // Load settings with defaults
        self.isDarkMode = UserDefaults.standard.bool(forKey: Keys.isDarkMode)
        
        // If isDarkMode has never been set, use system setting
        if !UserDefaults.standard.exists(key: Keys.isDarkMode) {
            #if os(iOS)
            self.isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
            #else
            self.isDarkMode = true
            #endif
        }
        
        self.showTextHelpers = UserDefaults.standard.bool(forKey: Keys.showTextHelpers)
        if !UserDefaults.standard.exists(key: Keys.showTextHelpers) {
            self.showTextHelpers = true // Default to true
        }
        
        self.useAccessibilityTextSize = UserDefaults.standard.bool(forKey: Keys.useAccessibilityTextSize)
        
        self.gameDifficulty = UserDefaults.standard.string(forKey: Keys.gameDifficulty) ?? "medium"
        
        self.soundEnabled = UserDefaults.standard.bool(forKey: Keys.soundEnabled)
        if !UserDefaults.standard.exists(key: Keys.soundEnabled) {
            self.soundEnabled = true // Default to true
        }
        
        self.soundVolume = UserDefaults.standard.float(forKey: Keys.soundVolume)
        if !UserDefaults.standard.exists(key: Keys.soundVolume) {
            self.soundVolume = 0.5 // Default to 50%
        }
        
        self.useBiometricAuth = UserDefaults.standard.bool(forKey: Keys.useBiometricAuth)
        if !UserDefaults.standard.exists(key: Keys.useBiometricAuth) {
            self.useBiometricAuth = BiometricAuthHelper.shared.biometricAuthAvailable().0
        }
        
        // Apply initial appearance
        updateAppAppearance()
    }
    
    // MARK: - Public Methods
    
    /// Update all settings at once
    func updateSettings(
        darkMode: Bool? = nil,
        showHelpers: Bool? = nil,
        accessibilityText: Bool? = nil,
        gameDifficulty: String? = nil,
        soundEnabled: Bool? = nil,
        soundVolume: Float? = nil,
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
        useBiometricAuth = BiometricAuthHelper.shared.biometricAuthAvailable().0
    }
    
    /// Save current settings to a logged-in user's preferences in Realm
    func saveToUserPreferences(userId: String) {
        guard let realm = realm else { return }
        
        do {
            try realm.write {
                // Find or create user
                guard let user = realm.object(ofType: UserRealm.self, forPrimaryKey: userId) else {
                    return
                }
                
                // Create preferences if needed
                if user.preferences == nil {
                    user.preferences = UserPreferencesRealm()
                }
                
                guard let prefs = user.preferences else { return }
                
                // Update from settings
                prefs.darkMode = isDarkMode
                prefs.showTextHelpers = showTextHelpers
                prefs.accessibilityTextSize = useAccessibilityTextSize
                prefs.gameDifficulty = gameDifficulty
                prefs.soundEnabled = soundEnabled
                prefs.soundVolume = soundVolume
                prefs.useBiometricAuth = useBiometricAuth
                prefs.lastSyncDate = Date()
            }
        } catch {
            print("Error saving user preferences: \(error.localizedDescription)")
        }
    }
    
    /// Load settings from a user's preferences in Realm
    func loadFromUserPreferences(userId: String) {
        guard let realm = realm else { return }
        
        // Find user and preferences
        guard let user = realm.object(ofType: UserRealm.self, forPrimaryKey: userId),
              let prefs = user.preferences else {
            return
        }
        
        // Update settings from preferences
        self.isDarkMode = prefs.darkMode
        self.showTextHelpers = prefs.showTextHelpers
        self.useAccessibilityTextSize = prefs.accessibilityTextSize
        self.gameDifficulty = prefs.gameDifficulty
        self.soundEnabled = prefs.soundEnabled
        self.soundVolume = prefs.soundVolume
        self.useBiometricAuth = prefs.useBiometricAuth
    }
    
    // MARK: - Private Methods
    
    private func updateAppAppearance() {
        #if os(iOS)
        // Update UI appearance based on dark mode setting
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
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
