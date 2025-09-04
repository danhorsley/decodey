//
//  UserSettings.swift - Local Settings Management
//  loginboy
//

import SwiftUI
import Combine

class UserSettings: ObservableObject {
    // Published properties for UI binding
    @Published var isDarkMode: Bool {
        didSet {
            savePreference("isDarkMode", value: isDarkMode)
            updateAppAppearance()
        }
    }
    
    @Published var showTextHelpers: Bool {
        didSet {
            savePreference("showTextHelpers", value: showTextHelpers)
        }
    }
    
    @Published var useAccessibilityTextSize: Bool {
        didSet {
            savePreference("useAccessibilityTextSize", value: useAccessibilityTextSize)
        }
    }
    
    @Published var useBiometricAuth: Bool {
        didSet {
            savePreference("useBiometricAuth", value: useBiometricAuth)
            handleBiometricAuthChange()
        }
    }
    
    @Published var gameDifficulty: String {
        didSet {
            savePreference("gameDifficulty", value: gameDifficulty)
        }
    }
    
    @Published var soundEnabled: Bool {
        didSet {
            savePreference("soundEnabled", value: soundEnabled)
        }
    }
    
    @Published var hapticFeedback: Bool {
        didSet {
            savePreference("hapticFeedback", value: hapticFeedback)
        }
    }
    
    // App version (read-only)
    let appVersion: String
    
    // Private properties
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    
    // Settings keys
    private struct Keys {
        static let isDarkMode = "isDarkMode"
        static let showTextHelpers = "showTextHelpers"
        static let useAccessibilityTextSize = "useAccessibilityTextSize"
        static let useBiometricAuth = "useBiometricAuth"
        static let gameDifficulty = "gameDifficulty"
        static let soundEnabled = "soundEnabled"
        static let hapticFeedback = "hapticFeedback"
        static let hasLoadedInitialSettings = "hasLoadedInitialSettings"
    }
    
    // Singleton instance
    static let shared = UserSettings()
    
    // Initialize with default settings
    init() {
        // Get app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            self.appVersion = "\(version) (\(build))"
        } else {
            self.appVersion = "1.0"
        }
        
        // Initialize stored properties with defaults
        self.isDarkMode = true
        self.showTextHelpers = true
        self.useAccessibilityTextSize = false
        self.useBiometricAuth = false
        self.gameDifficulty = "medium"
        self.soundEnabled = true
        self.hapticFeedback = true
        
        // Load saved preferences
        loadPreferences()
        
        print("⚙️ UserSettings initialized - Version: \(appVersion)")
    }
    
    // MARK: - Preference Management
    
    private func loadPreferences() {
        // Check if this is first run
        let hasLoadedBefore = userDefaults.bool(forKey: Keys.hasLoadedInitialSettings)
        
        if hasLoadedBefore {
            // Load saved preferences
            isDarkMode = userDefaults.object(forKey: Keys.isDarkMode) as? Bool ?? true
            showTextHelpers = userDefaults.object(forKey: Keys.showTextHelpers) as? Bool ?? true
            useAccessibilityTextSize = userDefaults.object(forKey: Keys.useAccessibilityTextSize) as? Bool ?? false
            useBiometricAuth = userDefaults.object(forKey: Keys.useBiometricAuth) as? Bool ?? false
            gameDifficulty = userDefaults.object(forKey: Keys.gameDifficulty) as? String ?? "medium"
            soundEnabled = userDefaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
            hapticFeedback = userDefaults.object(forKey: Keys.hapticFeedback) as? Bool ?? true
            
            print("✅ Loaded saved preferences")
        } else {
            // First run - save defaults
            saveAllPreferences()
            userDefaults.set(true, forKey: Keys.hasLoadedInitialSettings)
            print("🆕 First run - saved default preferences")
        }
        
        // Apply appearance immediately
        updateAppAppearance()
    }
    
    private func saveAllPreferences() {
        savePreference(Keys.isDarkMode, value: isDarkMode)
        savePreference(Keys.showTextHelpers, value: showTextHelpers)
        savePreference(Keys.useAccessibilityTextSize, value: useAccessibilityTextSize)
        savePreference(Keys.useBiometricAuth, value: useBiometricAuth)
        savePreference(Keys.gameDifficulty, value: gameDifficulty)
        savePreference(Keys.soundEnabled, value: soundEnabled)
        savePreference(Keys.hapticFeedback, value: hapticFeedback)
    }
    
    private func savePreference<T>(_ key: String, value: T) {
        userDefaults.set(value, forKey: key)
        userDefaults.synchronize()
    }
    
    // MARK: - Public Methods
    
    func resetToDefaults() {
        // Reset to default values
        isDarkMode = true
        showTextHelpers = true
        useAccessibilityTextSize = false
        useBiometricAuth = false
        gameDifficulty = "medium"
        soundEnabled = true
        hapticFeedback = true
        
        print("🔄 Settings reset to defaults")
    }
    
    func exportSettings() -> [String: Any] {
        return [
            "isDarkMode": isDarkMode,
            "showTextHelpers": showTextHelpers,
            "useAccessibilityTextSize": useAccessibilityTextSize,
            "useBiometricAuth": useBiometricAuth,
            "gameDifficulty": gameDifficulty,
            "soundEnabled": soundEnabled,
            "hapticFeedback": hapticFeedback,
            "appVersion": appVersion
        ]
    }
    
    func importSettings(from data: [String: Any]) {
        isDarkMode = data["isDarkMode"] as? Bool ?? isDarkMode
        showTextHelpers = data["showTextHelpers"] as? Bool ?? showTextHelpers
        useAccessibilityTextSize = data["useAccessibilityTextSize"] as? Bool ?? useAccessibilityTextSize
        useBiometricAuth = data["useBiometricAuth"] as? Bool ?? useBiometricAuth
        gameDifficulty = data["gameDifficulty"] as? String ?? gameDifficulty
        soundEnabled = data["soundEnabled"] as? Bool ?? soundEnabled
        hapticFeedback = data["hapticFeedback"] as? Bool ?? hapticFeedback
        
        print("📥 Settings imported successfully")
    }
    
    // MARK: - Private Implementation
    
    private func updateAppAppearance() {
        DispatchQueue.main.async {
            // Update app-wide appearance
            if self.isDarkMode {
                UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .dark
            } else {
                UIApplication.shared.windows.first?.overrideUserInterfaceStyle = .light
            }
        }
    }
    
    private func handleBiometricAuthChange() {
        if useBiometricAuth {
            // Enable biometric authentication
            enableBiometricAuth()
        } else {
            // Disable biometric authentication
            disableBiometricAuth()
        }
    }
    
    private func enableBiometricAuth() {
        // Check if biometric authentication is available
        guard isBiometricAvailable() else {
            DispatchQueue.main.async {
                self.useBiometricAuth = false
            }
            return
        }
        
        print("🔐 Biometric authentication enabled")
    }
    
    private func disableBiometricAuth() {
        print("🔓 Biometric authentication disabled")
    }
    
    private func isBiometricAvailable() -> Bool {
        // Check device capability for biometric authentication
        // For now, return true for iOS devices
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }
    
    // MARK: - Computed Properties
    
    var difficultyDisplayName: String {
        switch gameDifficulty.lowercased() {
        case "easy": return "Easy"
        case "hard": return "Hard"
        default: return "Medium"
        }
    }
    
    var isDarkModeDisplayName: String {
        return isDarkMode ? "Dark" : "Light"
    }
    
    // MARK: - Game Difficulty Helpers
    
    func setDifficulty(_ difficulty: GameDifficulty) {
        gameDifficulty = difficulty.rawValue
    }
    
    func getCurrentDifficulty() -> GameDifficulty {
        return GameDifficulty(rawValue: gameDifficulty) ?? .medium
    }
}

// MARK: - Supporting Enums

enum GameDifficulty: String, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
    
    var description: String {
        switch self {
        case .easy: return "More mistakes allowed, simpler quotes"
        case .medium: return "Balanced challenge"
        case .hard: return "Few mistakes allowed, complex quotes"
        }
    }
    
    var maxMistakes: Int {
        switch self {
        case .easy: return 8
        case .medium: return 5
        case .hard: return 3
        }
    }
}
