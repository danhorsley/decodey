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
        
        // Subscribe to user state changes
        subscribeToUserStateChanges()
    }
    
    private func subscribeToUserStateChanges() {
        UserState.shared.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.loadFromUserPreferences(userId: UserState.shared.userId)
                }
            }
            .store(in: &cancellables)
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
    
    /// Save current settings to a logged-in user's preferences in Core Data
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
            
            if let settings = UserState.shared.authCoordinator as? SettingsSync {
                settings.syncSettingsToServer(preferences: UserPreferencesModel(
                    darkMode: isDarkMode,
                    showTextHelpers: showTextHelpers,
                    accessibilityTextSize: useAccessibilityTextSize,
                    gameDifficulty: gameDifficulty,
                    soundEnabled: soundEnabled,
                    soundVolume: soundVolume,
                    useBiometricAuth: useBiometricAuth,
                    notificationsEnabled: preferences.notificationsEnabled,
                    lastSyncDate: Date()
                ))
            }
        } catch {
            print("Error saving user preferences: \(error.localizedDescription)")
        }
    }
    
    /// Load settings from a user's preferences in Core Data
    func loadFromUserPreferences(userId: String) {
        let context = coreData.mainContext
        
        // Find user and preferences
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first, let prefs = user.preferences else {
                return
            }
            
            // Update settings from preferences
            DispatchQueue.main.async {
                self.isDarkMode = prefs.darkMode
                
                // Handle NSObject conversion for showTextHelpers
                if let showHelpersValue = prefs.showTextHelpers as? Bool {
                    self.showTextHelpers = showHelpersValue
                } else {
                    // Default if conversion fails
                    self.showTextHelpers = true
                }
                
                self.useAccessibilityTextSize = prefs.accessibilityTextSize
                
                if let gameDifficulty = prefs.gameDifficulty {
                    self.gameDifficulty = gameDifficulty
                }
                
                self.soundEnabled = prefs.soundEnabled
                self.soundVolume = prefs.soundVolume
                self.useBiometricAuth = prefs.useBiometricAuth
            }
        } catch {
            print("Error loading user preferences: \(error.localizedDescription)")
        }
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

// Protocol for syncing settings to server
protocol SettingsSync {
    func syncSettingsToServer(preferences: UserPreferencesModel)
}
