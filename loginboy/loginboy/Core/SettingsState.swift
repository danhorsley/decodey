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
    private let cdStack = CoreDataStack.shared
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
                    self?.loadFromUserPreferencesCD(userId: UserState.shared.userId)
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
    func saveToUserPreferencesCD(userId: String) {
        let context = cdStack.mainContext
        
        // Find the user in Core Data
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let usersCD = try context.fetch(fetchRequest)
            
            guard let userCD = usersCD.first else { return }
            
            // Get or create preferences
            let preferencesCD: UserPreferences
            if let existingPrefs = userCD.preferences {
                preferencesCD = existingPrefs
            } else {
                preferencesCD = UserPreferences(context: context)
                userCD.preferences = preferencesCD
                preferencesCD.user = userCD
            }
            
            // Update from settings
            preferencesCD.darkMode = isDarkMode
            preferencesCD.showTextHelpers = showTextHelpers
            preferencesCD.accessibilityTextSize = useAccessibilityTextSize
            preferencesCD.gameDifficulty = gameDifficulty
            preferencesCD.soundEnabled = soundEnabled
            preferencesCD.soundVolume = soundVolume
            preferencesCD.useBiometricAuth = useBiometricAuth
            preferencesCD.lastSyncDate = Date()
            
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
                    notificationsEnabled: preferencesCD.notificationsEnabled,
                    lastSyncDate: Date()
                ))
            }
        } catch {
            print("Error saving user preferences: \(error.localizedDescription)")
        }
    }
    
    /// Load settings from a user's preferences in Core Data
    func loadFromUserPreferencesCD(userId: String) {
        let context = cdStack.mainContext
        
        // Find user and preferences
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let usersCD = try context.fetch(fetchRequest)
            guard let userCD = usersCD.first, let prefsCD = userCD.preferences else {
                return
            }
            
            // Update settings from preferences
            DispatchQueue.main.async {
                self.isDarkMode = prefsCD.darkMode
                self.showTextHelpers = prefsCD.showTextHelpers
                self.useAccessibilityTextSize = prefsCD.accessibilityTextSize
                self.gameDifficulty = prefsCD.gameDifficulty ?? "medium"
                self.soundEnabled = prefsCD.soundEnabled
                self.soundVolume = prefsCD.soundVolume
                self.useBiometricAuth = prefsCD.useBiometricAuth
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
