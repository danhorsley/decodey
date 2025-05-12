import SwiftUI

class UserSettings: ObservableObject {
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
            updateAppAppearance()
            
            // Queue settings for sync
            queueSettingsForSync()
        }
    }
    
    @Published var showTextHelpers: Bool {
        didSet {
            UserDefaults.standard.set(showTextHelpers, forKey: "showTextHelpers")
            
            // Queue settings for sync
            queueSettingsForSync()
        }
    }
    
    @Published var useAccessibilityTextSize: Bool {
        didSet {
            UserDefaults.standard.set(useAccessibilityTextSize, forKey: "useAccessibilityTextSize")
            
            // Queue settings for sync
            queueSettingsForSync()
        }
    }
    
    @Published var useBiometricAuth: Bool {
        didSet {
            UserDefaults.standard.set(useBiometricAuth, forKey: "useBiometricAuth")
            
            // If enabling, ensure we have auth state to work with
            if useBiometricAuth {
                // Try to enable biometric auth
                let success = AuthState.shared.enableBiometricAuth()
                
                // If failed, revert the setting
                if !success {
                    DispatchQueue.main.async {
                        self.useBiometricAuth = false
                    }
                }
            } else {
                // If disabling, remove biometric entry from keychain
                if let userId = AuthState.shared.user?.userId {
                    KeychainService.shared.delete(key: "biometric_\(userId)")
                }
            }
        }
    }
    
    // Non-persistent properties
    @Published var isOfflineMode = false
    
    // App version
    let appVersion: String
    
    init() {
        // Load saved settings or use defaults
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        self.showTextHelpers = UserDefaults.standard.bool(forKey: "showTextHelpers")
        self.useAccessibilityTextSize = UserDefaults.standard.bool(forKey: "useAccessibilityTextSize")
        self.useBiometricAuth = UserDefaults.standard.bool(forKey: "useBiometricAuth")
        
        // Get app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            self.appVersion = "\(version) (\(build))"
        } else {
            self.appVersion = "Unknown"
        }
        
        // If this is the first launch, set default values
        if UserDefaults.standard.object(forKey: "isDarkMode") == nil {
            self.isDarkMode = true // Default to dark mode
            UserDefaults.standard.set(true, forKey: "isDarkMode")
        }
        
        if UserDefaults.standard.object(forKey: "showTextHelpers") == nil {
            self.showTextHelpers = true // Default to showing text helpers
            UserDefaults.standard.set(true, forKey: "showTextHelpers")
        }
        
        if UserDefaults.standard.object(forKey: "useAccessibilityTextSize") == nil {
            self.useAccessibilityTextSize = false // Default to standard text size
            UserDefaults.standard.set(false, forKey: "useAccessibilityTextSize")
        }
        
        if UserDefaults.standard.object(forKey: "useBiometricAuth") == nil {
            // Default to enabled if biometrics are available
            let biometricAvailable = BiometricAuthHelper.shared.biometricAuthAvailable().0
            self.useBiometricAuth = biometricAvailable
            UserDefaults.standard.set(biometricAvailable, forKey: "useBiometricAuth")
        }
        
        // Check offline status
        self.isOfflineMode = !NetworkMonitor.shared.isConnected
        
        // Subscribe to network changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkStatusChanged),
            name: .connectivityChanged,
            object: nil
        )
        
        // Apply initial appearance
        updateAppAppearance()
    }
    
    // Update app appearance based on dark mode setting
    private func updateAppAppearance() {
        #if os(iOS)
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        window?.overrideUserInterfaceStyle = isDarkMode ? .dark : .light
        #endif
    }
    
    // Handle network status changes
    @objc private func networkStatusChanged(_ notification: Notification) {
        DispatchQueue.main.async {
            self.isOfflineMode = !NetworkMonitor.shared.isConnected
        }
    }
    
    // Queue settings for sync when online
    private func queueSettingsForSync() {
        // Only queue if there are actual changes
        if AuthState.shared.isAuthenticated && !AuthState.shared.isOfflineMode {
            OfflineSyncService.shared.queueSettingsForSync(settings: self)
        }
    }
    
    // Reset all settings to defaults
    func resetToDefaults() {
        isDarkMode = true
        showTextHelpers = true
        useAccessibilityTextSize = false
        useBiometricAuth = BiometricAuthHelper.shared.biometricAuthAvailable().0
    }
}

// Add notification name for connectivity changes
extension Notification.Name {
    static let connectivityChanged = Notification.Name("com.decodey.connectivityChanged")
}

// Extension for NetworkMonitor to post notifications
extension NetworkMonitor {
    func postConnectivityNotification() {
        NotificationCenter.default.post(name: .connectivityChanged, object: nil)
    }
}
