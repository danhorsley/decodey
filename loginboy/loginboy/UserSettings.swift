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
    
    // App version
    let appVersion: String
    
    // Private properties
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()
    private let keychainService = "com.yourapp.settings"
    
    // Flag to prevent repeated sync failures
    private var syncFailureLogged = false
    
    // Initialize with AuthService for user-specific settings
    init(authService: AuthService) {
        self.authService = authService
        // Initialize stored properties first
        self.isDarkMode = true
        self.showTextHelpers = true
        self.useAccessibilityTextSize = false
        self.useBiometricAuth = false
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
        
        // Apply initial appearance
        updateAppAppearance()
        
        // Subscribe to auth changes
        subscribeToAuthChanges()
    }
    
    // Convenience initializer that gets AuthService from the environment
    convenience init() {
        self.init(authService: AuthService())
    }
    
    // MARK: - Preference Management
    
    private func savePreference<T: Encodable>(_ key: String, value: T) {
        // First, always save to UserDefaults as a fallback
        if authService.isAuthenticated && !authService.userId.isEmpty {
            // User-specific key
            UserDefaults.standard.set(value, forKey: "\(authService.userId)_\(key)")
        } else {
            // Generic key for when not logged in
            UserDefaults.standard.set(value, forKey: key)
        }
        
        // If user is authenticated, also try to save to keychain for sync
        if authService.isAuthenticated && !authService.userId.isEmpty {
            do {
                let data = try JSONEncoder().encode(value)
                try KeychainManager.save(
                    service: keychainService,
                    account: "\(authService.userId)_\(key)",
                    password: data
                )
                print("DEBUG: Saved setting \(key) to keychain for user \(authService.userId)")
            } catch {
                print("DEBUG: Failed to save setting to keychain: \(error.localizedDescription)")
            }
        }
        
        // Queue for server sync if online and authenticated
        // Note: We won't actively try to sync settings if the endpoint isn't available
    }
    
    private func loadPreference<T: Decodable>(_ key: String, defaultValue: T) -> T {
        // Try to load from user-specific UserDefaults first (most reliable)
        if authService.isAuthenticated && !authService.userId.isEmpty {
            if let value = UserDefaults.standard.object(forKey: "\(authService.userId)_\(key)") as? T {
                return value
            }
            
            // Try keychain as fallback for user-specific settings
            do {
                let data = try KeychainManager.get(
                    service: keychainService,
                    account: "\(authService.userId)_\(key)"
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
            .sink { [weak self] notification in
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
        
        // Update appearance based on reloaded settings
        updateAppAppearance()
        
        print("DEBUG: Reloaded settings for user \(authService.userId)")
    }
    
    private func loadDefaultSettings() {
        // Load generic settings when user logs out
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        self.showTextHelpers = UserDefaults.standard.bool(forKey: "showTextHelpers")
        self.useAccessibilityTextSize = UserDefaults.standard.bool(forKey: "useAccessibilityTextSize")
        self.useBiometricAuth = UserDefaults.standard.bool(forKey: "useBiometricAuth")
        
        // Update appearance
        updateAppAppearance()
        
        print("DEBUG: Loaded default settings after logout")
    }
    
    // MARK: - Biometric Auth Helpers
    
    private func handleBiometricAuthChange() {
        if !authService.isAuthenticated || authService.userId.isEmpty {
            return
        }
        
        if useBiometricAuth {
            // Try to enable biometric auth
            let biometricHelper = BiometricAuthHelper.shared
            let (available, _) = biometricHelper.biometricAuthAvailable()
            
            if available {
                // Enable biometric auth
                // For simplicity, just save the setting - actual enrollment would happen at login
                print("DEBUG: Enabled biometric auth for user \(authService.userId)")
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
                    account: authService.userId
                )
                print("DEBUG: Disabled and removed biometric auth for user \(authService.userId)")
            } catch {
                print("DEBUG: Error removing biometric auth: \(error)")
            }
        }
    }
    
    private func isBiometricAuthAvailable() -> Bool {
        let (available, _) = BiometricAuthHelper.shared.biometricAuthAvailable()
        return available
    }
    
    // MARK: - Server Sync
    
    private func syncSettingsToServer() {
        // This method is disabled since the endpoint seems to be unavailable (404)
        // We won't try to sync to avoid cluttering the logs
        
        // If we need to re-enable it in the future, we can uncomment this code
        /*
        guard authService.isAuthenticated,
              !authService.userId.isEmpty,
              let token = authService.getAccessToken(),
              let url = URL(string: "\(authService.baseURL)/api/sync_settings") else {
            return
        }
        
        // Create settings payload
        let settingsPayload: [String: Any] = [
            "isDarkMode": isDarkMode,
            "showTextHelpers": showTextHelpers,
            "useAccessibilityTextSize": useAccessibilityTextSize,
            "useBiometricAuth": useBiometricAuth
        ]
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Serialize to JSON
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: settingsPayload)
        } catch {
            print("DEBUG: Failed to serialize settings: \(error)")
            return
        }
        
        // Make the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("DEBUG: Failed to sync settings: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("DEBUG: Settings synced successfully for user \(self.authService.userId)")
            } else {
                print("DEBUG: Settings sync failed with status \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
        }.resume()
        */
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
        
        print("DEBUG: Reset all settings to defaults")
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let userDidLogin = Notification.Name("com.yourapp.userDidLogin")
    static let userDidLogout = Notification.Name("com.yourapp.userDidLogout")
}

// MARK: - Biometric Auth Helper

class BiometricAuthHelper {
    static let shared = BiometricAuthHelper()
    
    // Check if biometric auth is available
    func biometricAuthAvailable() -> (Bool, String) {
        #if os(iOS)
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let biometryType = context.biometryType
            switch biometryType {
            case .faceID:
                return (true, "Face ID")
            case .touchID:
                return (true, "Touch ID")
            default:
                return (false, "None")
            }
        } else {
            // Handle error
            let errorMessage = error?.localizedDescription ?? "Biometric authentication not available"
            return (false, errorMessage)
        }
        #else
        // For macOS, return false for now
        return (false, "Not supported on this platform")
        #endif
    }
}

// MARK: - Missing Imports for iOS
#if os(iOS)
import LocalAuthentication
#endif
