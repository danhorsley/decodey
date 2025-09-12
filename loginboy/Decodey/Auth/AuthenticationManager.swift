// AuthenticationManager.swift - Updated to use UserIdentityManager
import Foundation
import AuthenticationServices
import SwiftUI
import CoreData

class AuthenticationManager: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var userID = ""
    @Published var userName = ""
    @Published var userEmail = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Properties
    static let shared = AuthenticationManager()
    private let identityManager = UserIdentityManager.shared
    
    // MARK: - Keys for UserDefaults
    private let userIDKey = "apple_user_id"
    private let userNameKey = "apple_user_name"
    private let userEmailKey = "apple_user_email"
    private let hasAuthenticatedKey = "has_authenticated"
    
    override init() {
        super.init()
        checkAuthenticationStatus()
    }
    
    // MARK: - Check Authentication Status
    func checkAuthenticationStatus() {
        // Check if user has previously authenticated
        if let savedUserID = UserDefaults.standard.string(forKey: userIDKey),
           !savedUserID.isEmpty {
            
            // Check credential state with Apple
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            appleIDProvider.getCredentialState(forUserID: savedUserID) { [weak self] (credentialState, error) in
                DispatchQueue.main.async {
                    switch credentialState {
                    case .authorized:
                        // User is still authorized
                        self?.userID = savedUserID
                        self?.userName = UserDefaults.standard.string(forKey: self?.userNameKey ?? "") ?? ""
                        self?.userEmail = UserDefaults.standard.string(forKey: self?.userEmailKey ?? "") ?? ""
                        self?.isAuthenticated = true
                        
                        // Update identity manager
                        self?.identityManager.setAppleSignInUser(
                            id: savedUserID,
                            name: self?.userName,
                            email: self?.userEmail
                        )
                        
                        // local storage userid et
                        UserState.shared.userId = savedUserID
                        UserState.shared.username = self?.userName ?? ""
                        UserState.shared.playerName = self?.userName ?? ""
                        UserState.shared.isAuthenticated = true
                        UserState.shared.isSignedIn = true
                        
                        print("✅ User still authorized with Apple ID: \(savedUserID)")
                        
                    case .revoked, .notFound:
                        // User has revoked authorization or not found
                        self?.signOut()
                        print("⚠️ Apple ID authorization revoked or not found")
                        
                    default:
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - Sign In with Apple
    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        isLoading = false
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Failed to get Apple ID credentials"
            return
        }
        
        // Save user ID (this is persistent)
        userID = appleIDCredential.user
        UserDefaults.standard.set(userID, forKey: userIDKey)
        
        // Extract name (only provided on first sign in)
        var extractedName: String? = nil
        if let fullName = appleIDCredential.fullName {
            let firstName = fullName.givenName ?? ""
            let lastName = fullName.familyName ?? ""
            let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                extractedName = name
                userName = name
                UserDefaults.standard.set(userName, forKey: userNameKey)
            }
        }
        
        // If no name from this sign in, check saved
        if extractedName == nil {
            if let savedName = UserDefaults.standard.string(forKey: userNameKey), !savedName.isEmpty {
                userName = savedName
            } else if let email = appleIDCredential.email {
                // Generate from email if available
                userName = email.components(separatedBy: "@").first ?? "Player"
                UserDefaults.standard.set(userName, forKey: userNameKey)
            }
        }
        
        // Save email (only provided on first sign in)
        if let email = appleIDCredential.email {
            userEmail = email
            UserDefaults.standard.set(email, forKey: userEmailKey)
        } else {
            userEmail = UserDefaults.standard.string(forKey: userEmailKey) ?? ""
        }
        
        UserDefaults.standard.set(true, forKey: hasAuthenticatedKey)
        isAuthenticated = true
        
        // Update identity manager with all info
        identityManager.setAppleSignInUser(
            id: userID,
            name: userName.isEmpty ? nil : userName,
            email: userEmail.isEmpty ? nil : userEmail
        )
        
        UserState.shared.userId = userID
        UserState.shared.username = userName
        UserState.shared.playerName = userName
        UserState.shared.isAuthenticated = true
        UserState.shared.isSignedIn = true
        
        print("✅ Successfully signed in with Apple ID: \(userID)")
        print("   Display name: \(identityManager.displayName)")
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false
        
        if let error = error as? ASAuthorizationError {
            switch error.code {
            case .canceled:
                print("User canceled Apple Sign In")
            case .failed:
                errorMessage = "Sign in failed. Please try again."
            case .invalidResponse:
                errorMessage = "Invalid response from Apple Sign In"
            case .notHandled:
                errorMessage = "Sign in request not handled"
            case .unknown:
                errorMessage = "An unknown error occurred"
            @unknown default:
                errorMessage = "An error occurred during sign in"
            }
        }
        
        print("❌ Apple Sign In error: \(error.localizedDescription)")
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
        #elseif os(macOS)
        return NSApplication.shared.windows.first ?? NSWindow()
        #endif
    }
    
    // MARK: - Sign Out
    func signOut() {
        // Clear stored credentials
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: hasAuthenticatedKey)
        
        // Reset properties
        userID = ""
        userName = ""
        userEmail = ""
        isAuthenticated = false
        
        // Update identity manager
        identityManager.signOut()
        
        print("👋 User signed out")
    }
}
