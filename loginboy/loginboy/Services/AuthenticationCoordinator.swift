import Foundation
import Combine
import Security

class AuthenticationCoordinator: ObservableObject {
    // Published properties for UI binding
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var username = ""
    @Published var userId = ""
    @Published var hasActiveGame = false
    @Published var isSubadmin = false
    
    // Base URL
    private(set) var baseURL = "https://7264097a-b4a2-42c7-988c-db8c0c9b107a-00-1lx57x7wg68m5.janeway.replit.dev"
    
    // Keychain keys
    private let keyAccessToken = "access_token"
    private let keyRefreshToken = "refresh_token"
    private let keyRememberMe = "remember_me"
    private let keychainService = "com.yourapp.auth"
    
    init() {
        checkSavedAuthentication()
    }
    
    // MARK: - Public Methods
    
    func setBaseURL(_ url: String) {
        guard URL(string: url) != nil else {
            print("WARNING: Invalid URL format provided: \(url)")
            return
        }
        
        self.baseURL = url
    }
    
    func login(username: String, password: String, rememberMe: Bool, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        errorMessage = nil
        
        let loginData: [String: Any] = [
            "username": username,
            "password": password,
            "rememberMe": rememberMe
        ]
        
        guard let url = URL(string: "\(baseURL)/login") else {
            self.isLoading = false
            self.errorMessage = "Invalid URL configuration"
            completion(false, "Invalid URL configuration")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.addValue(baseURL, forHTTPHeaderField: "Origin")
        request.addValue("loginboy", forHTTPHeaderField: "User-Agent")
        request.httpShouldHandleCookies = true
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: loginData)
        } catch {
            self.isLoading = false
            self.errorMessage = "Failed to serialize request: \(error.localizedDescription)"
            completion(false, self.errorMessage)
            return
        }
        
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        
        let session = URLSession(configuration: config)
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(false, self.errorMessage)
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received from server"
                    completion(false, self.errorMessage)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 401 {
                        self.errorMessage = "Invalid credentials"
                        completion(false, self.errorMessage)
                        return
                    } else if httpResponse.statusCode >= 400 {
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
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(LoginResponse.self, from: data)
                    
                    if let accessToken = response.access_token {
                        try? KeychainManager.save(
                            service: self.keychainService,
                            account: self.keyAccessToken,
                            password: accessToken.data(using: .utf8) ?? Data()
                        )
                        
                        if let refreshToken = response.refresh_token {
                            try? KeychainManager.save(
                                service: self.keychainService,
                                account: self.keyRefreshToken,
                                password: refreshToken.data(using: .utf8) ?? Data()
                            )
                        }
                        
                        UserDefaults.standard.set(rememberMe, forKey: self.keyRememberMe)
                        
                        self.isAuthenticated = true
                        self.username = response.username
                        self.hasActiveGame = response.has_active_game ?? false
                        self.isSubadmin = response.subadmin ?? false
                        self.userId = response.user_id
                        
                        NotificationCenter.default.post(name: .userDidLogin, object: nil)
                        
                        completion(true, nil)
                    } else {
                        self.errorMessage = "Login response missing access token"
                        completion(false, "Login response missing access token")
                    }
                } catch {
                    self.errorMessage = "Failed to parse response: \(error.localizedDescription)"
                    completion(false, self.errorMessage)
                }
            }
        }.resume()
    }
    
    func logout() {
        if let token = getAccessToken() {
            callLogoutAPI(token)
        }
        
        clearTokens()
        
        isAuthenticated = false
        username = ""
        hasActiveGame = false
        isSubadmin = false
        userId = ""
        
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }
    
    func getAccessToken() -> String? {
        do {
            let data = try KeychainManager.get(service: keychainService, account: keyAccessToken)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    func getRefreshToken() -> String? {
        do {
            let data = try KeychainManager.get(service: keychainService, account: keyRefreshToken)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    func refreshToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = getRefreshToken(),
              let url = URL(string: "\(baseURL)/refresh") else {
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
    
    // MARK: - Private Methods
    
    private func checkSavedAuthentication() {
        if let token = getAccessToken(), !token.isEmpty {
            verifyToken(token)
        }
    }
    
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
                    
                    self.isAuthenticated = true
                    self.username = username
                    self.userId = userId
                    self.isSubadmin = json["subadmin"] as? Bool ?? false
                    
                    print("DEBUG: ✅ Verified saved token for user: \(username)")
                } else {
                    print("DEBUG: ❌ Saved token is invalid, clearing")
                    self.clearTokens()
                }
            }
        }.resume()
    }
    
    private func callLogoutAPI(_ token: String) {
        guard let url = URL(string: "\(baseURL)/logout") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { _, _, _ in
            print("DEBUG: Logout API called")
        }.resume()
    }
    
    private func clearTokens() {
        try? KeychainManager.delete(service: keychainService, account: keyAccessToken)
        try? KeychainManager.delete(service: keychainService, account: keyRefreshToken)
        UserDefaults.standard.removeObject(forKey: keyRememberMe)
    }
}

// MARK: - Models
extension AuthenticationCoordinator {
    struct LoginResponse: Codable {
        let access_token: String?
        let refresh_token: String?
        let username: String
        let user_id: String
        let has_active_game: Bool?
        let subadmin: Bool?
    }
    
    struct RefreshResponse: Codable {
        let access_token: String?
    }
}

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

// MARK: - Notification Extensions
extension Notification.Name {
    static let userDidLogin = Notification.Name("com.yourapp.userDidLogin")
    static let userDidLogout = Notification.Name("com.yourapp.userDidLogout")
}
