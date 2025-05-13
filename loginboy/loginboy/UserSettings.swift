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
            
            // Handle biometric auth enabling/disabling
            handleBiometricAuthChange()
        }
    }
    
    @Published var gameDifficulty: String {
        didSet {
            savePreference("gameDifficulty", value: gameDifficulty)
        }
    }
    
    // App version
    let appVersion: String
    
    // Private properties
    private let auth: AuthenticationCoordinator
    private var cancellables = Set<AnyCancellable>()
    private let keychainService = "com.yourapp.settings"
    
    // Flag to prevent repeated sync failures
    private var syncFailureLogged = false
    
    // Initialize with AuthenticationCoordinator for user-specific settings
    init(auth: AuthenticationCoordinator) {
        self.auth = auth
        
        // Initialize stored properties first
        self.isDarkMode = true
        self.showTextHelpers = true
        self.useAccessibilityTextSize = false
        self.useBiometricAuth = false
        self.gameDifficulty = "medium"
        
        // Get app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            self.appVersion = "\(version) (\(build))"
        } else {
            self.appVersion = "Unknown"
        }
        
        // Load settings with defaults
        self.isDarkMode = loadPreference("isDarkMode", defaultValue: true)
        self.showTextHelpers = loadPreference("showTextHelpers", defaultValue: true)
        self.useAccessibilityTextSize = loadPreference("useAccessibilityTextSize", defaultValue: false)
        self.useBiometricAuth = loadPreference("useBiometricAuth", defaultValue: isBiometricAuthAvailable())
        self.gameDifficulty = loadPreference("gameDifficulty", defaultValue: "medium")
        
        // Apply initial appearance
        updateAppAppearance()
        
        // Subscribe to auth changes
        subscribeToAuthChanges()
    }
    
    // MARK: - Preference Management
    
    private func savePreference<T: Encodable>(_ key: String, value: T) {
        // First, always save to UserDefaults as a fallback
        if auth.isAuthenticated && !auth.userId.isEmpty {
            // User-specific key
            UserDefaults.standard.set(value, forKey: "\(auth.userId)_\(key)")
        } else {
            // Generic key for when not logged in
            UserDefaults.standard.set(value, forKey: key)
        }
        
        // If user is authenticated, also try to save to keychain for sync
        if auth.isAuthenticated && !auth.userId.isEmpty {
            do {
                let data = try JSONEncoder().encode(value)
                try KeychainManager.save(
                    service: keychainService,
                    account: "\(auth.userId)_\(key)",
                    password: data
                )
                print("DEBUG: Saved setting \(key) to keychain for user \(auth.userId)")
            } catch {
                print("DEBUG: Failed to save setting to keychain: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadPreference<T: Decodable>(_ key: String, defaultValue: T) -> T {
        // Try to load from user-specific UserDefaults first (most reliable)
        if auth.isAuthenticated && !auth.userId.isEmpty {
            if let value = UserDefaults.standard.object(forKey: "\(auth.userId)_\(key)") as? T {
                return value
            }
            
            // Try keychain as fallback for user-specific settings
            do {
                let data = try KeychainManager.get(
                    service: keychainService,
                    account: "\(auth.userId)_\(key)"
                )
                
                if let value = try? JSONDecoder().decode(T.self, from: data) {
                    return value
                }
            } catch {
                // Keychain error - fall back to generic UserDefaults
                if !(error is KeychainManager.KeychainError) {
                    print("DEBUG: Keychain error for \(key): \(error)")
                }
            }
        }
        
        // If not found in user-specific storage, try generic UserDefaults
        if let value = UserDefaults.standard.object(forKey: key) as? T {
            return value
        }
        
        // Return default value if nothing found
        return defaultValue
    }
    
    // MARK: - Auth Integration
    
    private func subscribeToAuthChanges() {
        // Observe login events
        NotificationCenter.default.publisher(for: .userDidLogin)
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // Reload settings for the new user
                DispatchQueue.main.async {
                    self.reloadUserSettings()
                }
            }
            .store(in: &cancellables)
        
        // Observe logout events
        NotificationCenter.default.publisher(for: .userDidLogout)
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // Reset to default/generic settings
                DispatchQueue.main.async {
                    self.loadDefaultSettings()
                }
            }
            .store(in: &cancellables)
    }
    
    private func reloadUserSettings() {
        // Reload user-specific settings
        self.isDarkMode = loadPreference("isDarkMode", defaultValue: true)
        self.showTextHelpers = loadPreference("showTextHelpers", defaultValue: true)
        self.useAccessibilityTextSize = loadPreference("useAccessibilityTextSize", defaultValue: false)
        self.useBiometricAuth = loadPreference("useBiometricAuth", defaultValue: isBiometricAuthAvailable())
        self.gameDifficulty = loadPreference("gameDifficulty", defaultValue: "medium")
        
        // Update appearance based on reloaded settings
        updateAppAppearance()
        
        print("DEBUG: Reloaded settings for user \(auth.userId)")
    }
    
    private func loadDefaultSettings() {
        // Load generic settings when user logs out
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        self.showTextHelpers = UserDefaults.standard.bool(forKey: "showTextHelpers")
        self.useAccessibilityTextSize = UserDefaults.standard.bool(forKey: "useAccessibilityTextSize")
        self.useBiometricAuth = UserDefaults.standard.bool(forKey: "useBiometricAuth")
        self.gameDifficulty = UserDefaults.standard.string(forKey: "gameDifficulty") ?? "medium"
        
        // Update appearance
        updateAppAppearance()
        
        print("DEBUG: Loaded default settings after logout")
    }
    
    // MARK: - Biometric Auth Helpers
    
    private func handleBiometricAuthChange() {
        if !auth.isAuthenticated || auth.userId.isEmpty {
            return
        }
        
        if useBiometricAuth {
            // Try to enable biometric auth
            let biometricHelper = BiometricAuthHelper.shared
            let (available, _) = biometricHelper.biometricAuthAvailable()
            
            if available {
                // Enable biometric auth
                // For simplicity, just save the setting - actual enrollment would happen at login
                print("DEBUG: Enabled biometric auth for user \(auth.userId)")
            } else {
                // Biometrics not available, revert setting
                DispatchQueue.main.async {
                    self.useBiometricAuth = false
                    print("DEBUG: Biometric auth not available, setting disabled")
                }
            }
        } else {
            // Disable biometric auth - remove from keychain
            do {
                try KeychainManager.delete(
                    service: "com.yourapp.auth.biometric",
                    account: auth.userId
                )
                print("DEBUG: Disabled and removed biometric auth for user \(auth.userId)")
            } catch {
                print("DEBUG: Error removing biometric auth: \(error)")
            }
        }
    }
    
    private func isBiometricAuthAvailable() -> Bool {
        let (available, _) = BiometricAuthHelper.shared.biometricAuthAvailable()
        return available
    }
    
    // MARK: - Appearance Updates
    
    private func updateAppAppearance() {
        #if os(iOS)
        // Update UI appearance based on dark mode setting
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
        }
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        isDarkMode = true
        showTextHelpers = true
        useAccessibilityTextSize = false
        useBiometricAuth = isBiometricAuthAvailable()
        gameDifficulty = "medium"
        
        print("DEBUG: Reset all settings to defaults")
    }
}



// MARK: - Missing Imports for iOS
#if os(iOS)
import LocalAuthentication
#endif
