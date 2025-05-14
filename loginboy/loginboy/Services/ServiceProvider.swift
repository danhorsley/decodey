import Foundation
import SwiftUI

/// ServiceProvider is a centralized access point for all app services
class ServiceProvider: ObservableObject {
    // Singleton instance
    static let shared = ServiceProvider()
    
    // Authentication
    let authCoordinator = AuthenticationCoordinator()
    
    // Services
    private(set) lazy var userService = UserService(authCoordinator: authCoordinator)
    private(set) lazy var gameService = GameService(authCoordinator: authCoordinator)
    private(set) lazy var settingsService = SettingsService()
    
    // Initialize dependencies
    private init() {
        // Nothing needed here - lazy initialization handles everything
    }
    
    // Provide all required environment objects to a view
    func provideEnvironment<Content: View>(_ content: Content) -> some View {
        content
            .environmentObject(authCoordinator)
            .environmentObject(userService)
            .environmentObject(gameService)
            .environmentObject(settingsService)
    }
}

/// Settings service that manages app-wide settings
class SettingsService: ObservableObject {
    // UI settings
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
            updateAppAppearance()
        }
    }
    
    @Published var showTextHelpers: Bool {
        didSet {
            UserDefaults.standard.set(showTextHelpers, forKey: "showTextHelpers")
        }
    }
    
    @Published var useAccessibilityTextSize: Bool {
        didSet {
            UserDefaults.standard.set(useAccessibilityTextSize, forKey: "useAccessibilityTextSize")
        }
    }
    
    @Published var gameDifficulty: String {
        didSet {
            UserDefaults.standard.set(gameDifficulty, forKey: "gameDifficulty")
        }
    }
    
    // Sound settings
    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
            ResourceManager.shared.setSoundEnabled(soundEnabled)
        }
    }
    
    @Published var soundVolume: Float {
        didSet {
            UserDefaults.standard.set(soundVolume, forKey: "soundVolume")
            ResourceManager.shared.setSoundVolume(soundVolume)
        }
    }
    
    // Security settings
    @Published var useBiometricAuth: Bool {
        didSet {
            UserDefaults.standard.set(useBiometricAuth, forKey: "useBiometricAuth")
        }
    }
    
    // App version (read-only)
    let appVersion: String
    
    init() {
        // Get app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            self.appVersion = "\(version) (\(build))"
        } else {
            self.appVersion = "Unknown"
        }
        
        // Load settings with defaults
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        
        // If isDarkMode has never been set, use system setting
        if UserDefaults.standard.object(forKey: "isDarkMode") == nil {
            #if os(iOS)
            self.isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
            #else
            self.isDarkMode = true
            #endif
        }
        
        self.showTextHelpers = UserDefaults.standard.bool(forKey: "showTextHelpers")
        if UserDefaults.standard.object(forKey: "showTextHelpers") == nil {
            self.showTextHelpers = true // Default to true
        }
        
        self.useAccessibilityTextSize = UserDefaults.standard.bool(forKey: "useAccessibilityTextSize")
        
        self.gameDifficulty = UserDefaults.standard.string(forKey: "gameDifficulty") ?? "medium"
        
        self.soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil {
            self.soundEnabled = true // Default to true
        }
        
        self.soundVolume = UserDefaults.standard.float(forKey: "soundVolume")
        if UserDefaults.standard.object(forKey: "soundVolume") == nil {
            self.soundVolume = 0.5 // Default to 50%
        }
        
        self.useBiometricAuth = UserDefaults.standard.bool(forKey: "useBiometricAuth")
        if UserDefaults.standard.object(forKey: "useBiometricAuth") == nil {
            self.useBiometricAuth = BiometricAuthHelper.shared.biometricAuthAvailable().0
        }
        
        // Apply initial appearance
        updateAppAppearance()
    }
    
    // Update all settings at once
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
    
    // Reset all settings to defaults
    func resetToDefaults() {
        isDarkMode = true
        showTextHelpers = true
        useAccessibilityTextSize = false
        gameDifficulty = "medium"
        soundEnabled = true
        soundVolume = 0.5
        useBiometricAuth = BiometricAuthHelper.shared.biometricAuthAvailable().0
    }
    
    // Apply dark mode setting
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
// Only declare this if it's not already defined elsewhere
/*
extension UserDefaults {
    func exists(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
*/

//
//  ServiceProvider.swift
//  loginboy
//
//  Created by Daniel Horsley on 15/05/2025.
//
