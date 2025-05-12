import SwiftUI
import Combine

// MARK: - Auth Service to match your existing backend
class AuthService: ObservableObject {
    // Published properties for UI binding
    @Published var isLoading = false
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    @Published var username = ""
    @Published var hasActiveGame = false
    @Published var isSubadmin = false
    @Published var userId = ""
    
    // Events system (similar to your JS events.emit)
    var onLoginCallback: ((LoginResponse) -> Void)?
    
    // Network and storage
    private var cancellables = Set<AnyCancellable>()
    private let keyAccessToken = "uncrypt-token"
    private let keyRefreshToken = "refresh_token"
    private let keyRememberMe = "uncrypt-remember-me"
    
    // Base URL - change to match your setup
    private var baseURL: String =  "https://7264097a-b4a2-42c7-988c-db8c0c9b107a-00-1lx57x7wg68m5.janeway.replit.dev"
    //helper to set base url
    func setBaseURL(_ url: String) {
        // Validate the URL format
        guard let _ = URL(string: url) else {
            print("WARNING: Invalid URL format provided: \(url)")
            return
        }
        
        // Directly set the property
        self.baseURL = url
        print("DEBUG: Updated base URL to \(url)")
    }
    // MARK: - Login matching your backend expectations
    func login(username: String, password: String, rememberMe: Bool, completion: @escaping (Bool, String?) -> Void) {
        // Reset state
        isLoading = true
        errorMessage = nil
        
        // Log attempt (matching your JS debug)
        print("DEBUG: Login attempt with credentials: username=\(username), password=[REDACTED], rememberMe=\(rememberMe)")
        
        // Create login data exactly matching your backend expectations
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
        
        // Add these headers to match browser behavior
        request.addValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.addValue(baseURL, forHTTPHeaderField: "Origin")
        request.addValue("loginboy", forHTTPHeaderField: "User-Agent") // Or another identifier
        
        // Handle CORS by explicitly allowing credentials
        // This is crucial if your server has supports_credentials=True
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
        
        // Print full request details for debugging (matching your JS debug)
        print("DEBUG: Login request to: \(url.absoluteString)")
        print("DEBUG: Request headers: \(request.allHTTPHeaderFields ?? [:])")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("DEBUG: Request body: \(bodyString)")
        }
        
        // Create a custom URLSession configuration
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        
        // Make the request with the custom session
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                // Log response details
                print("DEBUG: Response received")
                if let httpResponse = response as? HTTPURLResponse {
                    print("DEBUG: Status code: \(httpResponse.statusCode)")
                    print("DEBUG: Response headers: \(httpResponse.allHeaderFields)")
                }
                
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
                
                // Log response data for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("DEBUG: Response body: \(responseString)")
                }
                
                // Check response status
                if let httpResponse = response as? HTTPURLResponse {
                    // Check for error status codes
                    if httpResponse.statusCode == 401 {
                        self.errorMessage = "Invalid credentials"
                        completion(false, self.errorMessage)
                        return
                    } else if httpResponse.statusCode >= 400 {
                        // Try to parse error message from JSON
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
                    
                    // Handle successful login as before...
                    print("DEBUG: Login successful, got response")
                    
                    // Store tokens based on rememberMe (matching your JS logic)
                    if let accessToken = response.access_token {
                        if rememberMe {
                            UserDefaults.standard.set(accessToken, forKey: self.keyAccessToken)
                            print("DEBUG: ✅ Saved access token to UserDefaults (rememberMe=true)")
                        } else {
                            // In Swift, sessionStorage equivalent would be temporary storage
                            UserDefaults.standard.set(accessToken, forKey: "temp_\(self.keyAccessToken)")
                            print("DEBUG: ✅ Saved access token to temporary storage (rememberMe=false)")
                        }
                        
                        // Store refresh token if provided (always persistent regardless of rememberMe)
                        if let refreshToken = response.refresh_token {
                            UserDefaults.standard.set(refreshToken, forKey: self.keyRefreshToken)
                            print("DEBUG: ✅ Saved refresh token to UserDefaults")
                        } else {
                            print("DEBUG: ⚠️ NO REFRESH TOKEN PROVIDED IN LOGIN RESPONSE")
                        }
                        
                        // Store rememberMe preference
                        UserDefaults.standard.set(rememberMe, forKey: self.keyRememberMe)
                        print("DEBUG: ✅ Saved remember-me preference: \(rememberMe)")
                        
                        // Update authentication state
                        self.isAuthenticated = true
                        self.username = response.username
                        self.hasActiveGame = response.has_active_game ?? false
                        self.isSubadmin = response.subadmin ?? false
                        self.userId = response.user_id
                        
                        // Log storage after login (matching your JS debug)
                        print("DEBUG: AFTER LOGIN - Storage check:")
                        print("- UserDefaults.\(self.keyAccessToken): \(UserDefaults.standard.string(forKey: self.keyAccessToken) != nil)")
                        print("- UserDefaults.\(self.keyRefreshToken): \(UserDefaults.standard.string(forKey: self.keyRefreshToken) != nil)")
                        print("- Temporary.\(self.keyAccessToken): \(UserDefaults.standard.string(forKey: "temp_\(self.keyAccessToken)") != nil)")
                        
                        // Emit login event via callback
                        self.onLoginCallback?(response)
                        
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
                    
                    // Log the raw response for debugging
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("DEBUG: Raw response: \(responseString)")
                    }
                    
                    completion(false, self.errorMessage)
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Logout function
    func logout() {
        // Clear tokens
        UserDefaults.standard.removeObject(forKey: keyAccessToken)
        UserDefaults.standard.removeObject(forKey: "temp_\(keyAccessToken)")
        UserDefaults.standard.removeObject(forKey: keyRefreshToken)
        
        // Reset state
        isAuthenticated = false
        username = ""
        hasActiveGame = false
        isSubadmin = false
        userId = ""
        
        print("DEBUG: User logged out, tokens cleared")
    }
    
    // MARK: - Check if user is authenticated
    func checkAuthentication() -> Bool {
        // Check for token based on rememberMe preference
        let rememberMe = UserDefaults.standard.bool(forKey: keyRememberMe)
        
        if rememberMe {
            return UserDefaults.standard.string(forKey: keyAccessToken) != nil
        } else {
            return UserDefaults.standard.string(forKey: "temp_\(keyAccessToken)") != nil
        }
    }
    
    // MARK: - Get stored token
    func getAccessToken() -> String? {
        let rememberMe = UserDefaults.standard.bool(forKey: keyRememberMe)
        
        if rememberMe {
            return UserDefaults.standard.string(forKey: keyAccessToken)
        } else {
            return UserDefaults.standard.string(forKey: "temp_\(keyAccessToken)")
        }
    }
    
    // MARK: - Response model matching your backend
    struct LoginResponse: Codable {
        let access_token: String?
        let refresh_token: String?
        let username: String
        let user_id: String
        let has_active_game: Bool?
        let subadmin: Bool?
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
            
            // Check if already authenticated
            if authService.checkAuthentication() {
                print("User already has a stored token")
            }
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

