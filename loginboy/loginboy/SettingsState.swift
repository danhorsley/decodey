import Foundation
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
    
    @Published var useBiometricAuth: Bool {
        didSet {
            UserDefaults.standard.set(useBiometricAuth, forKey: Keys.useBiometricAuth)
        }
    }
    
    // App version (read-only)
    let appVersion: String
    
    // UserDefaults keys
    private struct Keys {
        static let isDarkMode = "isDarkMode"
        static let showTextHelpers = "showTextHelpers"
        static let useAccessibilityTextSize = "useAccessibilityTextSize"
        static let gameDifficulty = "gameDifficulty"
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
        
        self.useBiometricAuth = UserDefaults.standard.bool(forKey: Keys.useBiometricAuth)
        if !UserDefaults.standard.exists(key: Keys.useBiometricAuth) {
            self.useBiometricAuth = isBiometricAuthAvailable()
        }
        
        // Apply initial appearance
        updateAppAppearance()
    }
    
    // MARK: - Public Methods
    
    /// Update all settings at once
    func updateSettings(darkMode: Bool? = nil, showHelpers: Bool? = nil,
                        accessibilityText: Bool? = nil, gameDifficulty: String? = nil) {
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
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        isDarkMode = true
        showTextHelpers = true
        useAccessibilityTextSize = false
        useBiometricAuth = isBiometricAuthAvailable()
        gameDifficulty = "medium"
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
    
    private func isBiometricAuthAvailable() -> Bool {
        #if os(iOS)
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        #else
        return false
        #endif
    }
}

// Extension to check if a key exists in UserDefaults
extension UserDefaults {
    func exists(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

// Add missing import for biometric authentication
#if os(iOS)
import LocalAuthentication
#endif

//
//  SettingsState.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

