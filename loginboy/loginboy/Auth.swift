// MARK: - Auth Service to match existing backend
import SwiftUI
import Security
import Combine

// MARK: - KeychainManager
class KeychainManager {
    enum KeychainError: Error {
        case duplicateEntry
        case unknown(OSStatus)
        case noPassword
        case unexpectedPasswordData
        case unhandledError(status: OSStatus)
    }
    
    static func save(service: String, account: String, password: Data) throws {
        let query: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject,
            kSecValueData as String: password as AnyObject
        ]
        
        // Delete any existing items with this service & account
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    static func get(service: String, account: String) throws -> Data {
        let query: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject,
            kSecReturnData as String: kCFBooleanTrue,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status != errSecItemNotFound else { throw KeychainError.noPassword }
        guard status == errSecSuccess else { throw KeychainError.unhandledError(status: status) }
        
        guard let passwordData = item as? Data else { throw KeychainError.unexpectedPasswordData }
        
        return passwordData
    }
    
    static func delete(service: String, account: String) throws {
        let query: [String: AnyObject] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service as AnyObject,
            kSecAttrAccount as String: account as AnyObject
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}

// MARK: - Enhanced AuthService with Keychain Storage
class AuthService: ObservableObject {
    // Published properties for UI binding
    @Published var isLoading = false
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var username = ""
    @Published var hasActiveGame = false
    @Published var isSubadmin = false
    @Published var userId = ""
    
    // Events system
    var onLoginCallback: ((LoginResponse) -> Void)?
    
    // Network and storage
    private var cancellables = Set<AnyCancellable>()
    private let keyAccessToken = "access_token"
    private let keyRefreshToken = "refresh_token"
    private let keyRememberMe = "remember_me"
    private let keychainService = "com.yourapp.auth"
    
    // Base URL
    var baseURL: String = "https://7264097a-b4a2-42c7-988c-db8c0c9b107a-00-1lx57x7wg68m5.janeway.replit.dev"
    
    // Initialize and check for existing auth
    init() {
        checkSavedAuthentication()
    }
    
    //helper to set base url
    func setBaseURL(_ url: String) {
        guard let _ = URL(string: url) else {
            print("WARNING: Invalid URL format provided: \(url)")
            return
        }
        
        self.baseURL = url
        print("DEBUG: Updated base URL to \(url)")
    }
    
    // MARK: - Check for saved authentication on init
    private func checkSavedAuthentication() {
        if let token = getAccessToken(), !token.isEmpty {
            // We have a token, try to verify it
            verifyToken(token)
        }
    }
    
    // MARK: - Verify token
    private func verifyToken(_ token: String) {
        guard let url = URL(string: "\(baseURL)/verify_token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let valid = json["valid"] as? Bool, valid,
                   let username = json["username"] as? String,
                   let userId = json["user_id"] as? String {
                    
                    // Token is valid, update state
                    self.isAuthenticated = true
                    self.username = username
                    self.userId = userId
                    self.isSubadmin = json["subadmin"] as? Bool ?? false
                    
                    print("DEBUG: ✅ Verified saved token for user: \(username)")
                } else {
                    // Token invalid, clear it
                    print("DEBUG: ❌ Saved token is invalid, clearing")
                    self.clearTokens()
                }
            }
        }.resume()
    }
    
    // MARK: - Login function
    func login(username: String, password: String, rememberMe: Bool, completion: @escaping (Bool, String?) -> Void) {
        // Reset state
        isLoading = true
        errorMessage = nil
        
        // Log attempt
        print("DEBUG: Login attempt with credentials: username=\(username), password=[REDACTED], rememberMe=\(rememberMe)")
        
        // Create login data
        let loginData: [String: Any] = [
            "username": username,
            "password": password,
            "rememberMe": rememberMe
        ]
        
        // Create URL
        guard let url = URL(string: "\(baseURL)/login") else {
            self.isLoading = false
            self.errorMessage = "Invalid URL configuration"
            completion(false, "Invalid URL configuration")
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add browser-like headers
        request.addValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.addValue(baseURL, forHTTPHeaderField: "Origin")
        request.addValue("loginboy", forHTTPHeaderField: "User-Agent")
        
        // Handle CORS
        request.httpShouldHandleCookies = true
        
        // Serialize to JSON
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: loginData)
        } catch {
            self.isLoading = false
            self.errorMessage = "Failed to serialize request: \(error.localizedDescription)"
            completion(false, self.errorMessage)
            return
        }
        
        // Debug info
        print("DEBUG: Login request to: \(url.absoluteString)")
        
        // Create a custom URLSession configuration
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        
        // Make the request
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                // Handle network error
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    print("DEBUG: Login error: \(error.localizedDescription)")
                    completion(false, self.errorMessage)
                    return
                }
                
                // Make sure we have data
                guard let data = data else {
                    self.errorMessage = "No data received from server"
                    print("DEBUG: Login error: No data received")
                    completion(false, self.errorMessage)
                    return
                }
                
                // Check response status
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 401 {
                        self.errorMessage = "Invalid credentials"
                        completion(false, self.errorMessage)
                        return
                    } else if httpResponse.statusCode >= 400 {
                        // Try to parse error message
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorMsg = json["msg"] as? String {
                            self.errorMessage = errorMsg
                            completion(false, errorMsg)
                        } else {
                            self.errorMessage = "Error during login (Status \(httpResponse.statusCode))"
                            completion(false, self.errorMessage)
                        }
                        return
                    }
                }
                
                // Parse the response
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(LoginResponse.self, from: data)
                    
                    print("DEBUG: Login successful, got response")
                    
                    // Store tokens securely in keychain
                    if let accessToken = response.access_token {
                        // Save token to keychain
                        try? KeychainManager.save(
                            service: self.keychainService,
                            account: self.keyAccessToken,
                            password: accessToken.data(using: .utf8) ?? Data()
                        )
                        
                        // Store refresh token if provided
                        if let refreshToken = response.refresh_token {
                            try? KeychainManager.save(
                                service: self.keychainService,
                                account: self.keyRefreshToken,
                                password: refreshToken.data(using: .utf8) ?? Data()
                            )
                            print("DEBUG: ✅ Saved refresh token to Keychain")
                        }
                        
                        // Store rememberMe preference (this is not sensitive)
                        UserDefaults.standard.set(rememberMe, forKey: self.keyRememberMe)
                        
                        // Update authentication state
                        self.isAuthenticated = true
                        self.username = response.username
                        self.hasActiveGame = response.has_active_game ?? false
                        self.isSubadmin = response.subadmin ?? false
                        self.userId = response.user_id
                        
                        // Emit login event via callback
                        self.onLoginCallback?(response)
                        
                        print("DEBUG: ✅ Authentication successful for: \(response.username)")
                        
                        // Call completion handler with success
                        completion(true, nil)
                    } else {
                        print("DEBUG: ⚠️ LOGIN RESPONSE MISSING ACCESS TOKEN")
                        self.errorMessage = "Login response missing access token"
                        completion(false, "Login response missing access token")
                    }
                } catch {
                    // JSON decoding error
                    self.errorMessage = "Failed to parse response: \(error.localizedDescription)"
                    print("DEBUG: Login error: \(error.localizedDescription)")
                    completion(false, self.errorMessage)
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Logout function
    func logout() {
        // First, call logout API if we have a token
        if let token = getAccessToken() {
            callLogoutAPI(token)
        }
        
        // Clear tokens regardless of API response
        clearTokens()
        
        // Reset state
        isAuthenticated = false
        username = ""
        hasActiveGame = false
        isSubadmin = false
        userId = ""
        
        print("DEBUG: User logged out, tokens cleared")
    }
    
    // Call the logout API
    private func callLogoutAPI(_ token: String) {
        guard let url = URL(string: "\(baseURL)/logout") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { _, _, _ in
            // We don't really care about the response here
            print("DEBUG: Logout API called")
        }.resume()
    }
    
    // Clear all tokens
    private func clearTokens() {
        // Clear tokens from keychain
        try? KeychainManager.delete(service: keychainService, account: keyAccessToken)
        try? KeychainManager.delete(service: keychainService, account: keyRefreshToken)
        
        // Clear rememberMe preference
        UserDefaults.standard.removeObject(forKey: keyRememberMe)
    }
    
    // MARK: - Get stored access token
    func getAccessToken() -> String? {
        do {
            let data = try KeychainManager.get(service: keychainService, account: keyAccessToken)
            return String(data: data, encoding: .utf8)
        } catch {
            print("DEBUG: No access token in keychain or error: \(error)")
            return nil
        }
    }
    
    // MARK: - Get stored refresh token
    func getRefreshToken() -> String? {
        do {
            let data = try KeychainManager.get(service: keychainService, account: keyRefreshToken)
            return String(data: data, encoding: .utf8)
        } catch {
            print("DEBUG: No refresh token in keychain or error: \(error)")
            return nil
        }
    }
    
    // MARK: - Response model
    struct LoginResponse: Codable {
        let access_token: String?
        let refresh_token: String?
        let username: String
        let user_id: String
        let has_active_game: Bool?
        let subadmin: Bool?
    }
    
    // MARK: - Token refresh
    func refreshToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = getRefreshToken() else {
            completion(false)
            return
        }
        
        guard let url = URL(string: "\(baseURL)/refresh") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  error == nil,
                  let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let refreshResponse = try decoder.decode(RefreshResponse.self, from: data)
                
                if let newAccessToken = refreshResponse.access_token {
                    // Save new access token
                    try? KeychainManager.save(
                        service: self.keychainService,
                        account: self.keyAccessToken,
                        password: newAccessToken.data(using: .utf8) ?? Data()
                    )
                    
                    DispatchQueue.main.async {
                        completion(true)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Model for refresh token response
    struct RefreshResponse: Codable {
        let access_token: String?
    }
}

// MARK: - Simple login view to test the service
struct LoginView: View {
    @StateObject private var authService = AuthService()
    @State private var username = ""
    @State private var password = ""
    @State private var rememberMe = true
    @State private var backendURL = "https://7264097a-b4a2-42c7-988c-db8c0c9b107a-00-1lx57x7wg68m5.janeway.replit.dev"
    
    // Get a reference to the URL field to programmatically focus it
    @FocusState private var isURLFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Auth Test")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Backend URL (for testing)
            VStack(alignment: .leading) {
                Text("Backend URL")
                    .font(.caption)
                
                TextField("Backend URL", text: $backendURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                    .focused($isURLFieldFocused)
                    .onSubmit {
                        // Update the AuthService URL when submitted
                        authService.setBaseURL(backendURL)
                    }
                
                // Update button next to the field
                Button("Update URL") {
                    authService.setBaseURL(backendURL)
                }
                .font(.caption)
                .padding(.top, 4)
            }
            .padding(.bottom, 10)
            
            // Username field
            VStack(alignment: .leading) {
                Text("Username or Email")
                    .font(.caption)
                TextField("Username or Email", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
            }
            
            // Password field
            VStack(alignment: .leading) {
                Text("Password")
                    .font(.caption)
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Remember me toggle
            Toggle(isOn: $rememberMe) {
                Text("Remember me")
            }
            
            // Login button
            Button(action: {
                authService.login(username: username, password: password, rememberMe: rememberMe) { success, error in
                    if success {
                        print("Login successful!")
                    } else {
                        print("Login failed: \(error ?? "Unknown error")")
                    }
                }
            }) {
                if authService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                } else {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .disabled(username.isEmpty || password.isEmpty || authService.isLoading)
            
            // Error message
            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            // Success message
            if authService.isAuthenticated {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Logged in successfully!")
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                    
                    Text("Username: \(authService.username)")
                    Text("User ID: \(authService.userId)")
                    Text("Admin access: \(authService.isSubadmin ? "Yes" : "No")")
                    Text("Has active game: \(authService.hasActiveGame ? "Yes" : "No")")
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                
                // Logout button
                Button(action: {
                    authService.logout()
                }) {
                    Text("Logout")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top)
            }
            
            Spacer()
            
            // Debug section
            VStack(alignment: .leading, spacing: 4) {
                Text("Debug Info")
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("Try using http:// instead of https:// if you experience connection issues")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("For Replit URLs, make sure your server is running")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .onAppear {
            // Focus the URL field when the view appears
            isURLFieldFocused = true
            
            // The token check is now done automatically in AuthService's init
            // No need to manually check here
        }
    }
}

// Helper for creating a preview in Xcode
#if DEBUG
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
#endif

