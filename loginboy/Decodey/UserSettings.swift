//
//  UserSettings.swift - Cross-Platform Settings Management
//  loginboy
//

import SwiftUI
import Combine

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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
            appVersion = "\(version) (\(build))"
        } else {
            appVersion = "1.0"
        }
        
        // Load saved preferences or set defaults
        if userDefaults.bool(forKey: Keys.hasLoadedInitialSettings) {
            // Load existing settings
            isDarkMode = userDefaults.object(forKey: Keys.isDarkMode) as? Bool ?? true
            showTextHelpers = userDefaults.object(forKey: Keys.showTextHelpers) as? Bool ?? true
            useAccessibilityTextSize = userDefaults.object(forKey: Keys.useAccessibilityTextSize) as? Bool ?? false
            useBiometricAuth = userDefaults.object(forKey: Keys.useBiometricAuth) as? Bool ?? false
            gameDifficulty = userDefaults.object(forKey: Keys.gameDifficulty) as? String ?? "medium"
            soundEnabled = userDefaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
            hapticFeedback = userDefaults.object(forKey: Keys.hapticFeedback) as? Bool ?? true
            
            print("✅ Loaded saved preferences")
        } else {
            // First run - use defaults
            isDarkMode = true
            showTextHelpers = true
            useAccessibilityTextSize = false
            useBiometricAuth = false
            gameDifficulty = "medium"
            soundEnabled = true
            hapticFeedback = true
            
            // Save defaults
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
    
    // MARK: - Private Implementation (Cross-Platform)
    
    private func updateAppAppearance() {
        DispatchQueue.main.async {
            #if os(iOS)
            // iOS implementation
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    window.overrideUserInterfaceStyle = self.isDarkMode ? .dark : .light
                }
            }
            #elseif os(macOS)
            // macOS implementation
            NSApp.appearance = self.isDarkMode ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
            #endif
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
        #if os(iOS)
        return true // Simplified - in real app you'd use LocalAuthentication framework
        #else
        return false // macOS doesn't typically use biometric auth for apps
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

// MARK: - Game Difficulty Enum

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
    
    var maxMistakes: Int {
        switch self {
        case .easy: return 8
        case .medium: return 5
        case .hard: return 3
        }
    }
}
