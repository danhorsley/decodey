// AuthenticationManager.swift - Fixed for cross-platform
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
    private let coreData = CoreDataStack.shared
    
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
                        self?.updateUserState()
                        print("✅ User still authorized with Apple ID")
                        
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
        
        // Save name (only provided on first sign in)
        if let fullName = appleIDCredential.fullName {
            let firstName = fullName.givenName ?? ""
            let lastName = fullName.familyName ?? ""
            let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                userName = name
                UserDefaults.standard.set(userName, forKey: userNameKey)
            }
        }
        
        // If no name from this sign in, use saved or generate from email
        if userName.isEmpty {
            if let savedName = UserDefaults.standard.string(forKey: userNameKey), !savedName.isEmpty {
                userName = savedName
            } else if let email = appleIDCredential.email {
                userName = email.components(separatedBy: "@").first ?? "Player"
                UserDefaults.standard.set(userName, forKey: userNameKey)
            } else {
                userName = "Player"
            }
        }
        
        // Save email (only provided on first sign in)
        if let email = appleIDCredential.email {
            userEmail = email
            UserDefaults.standard.set(email, forKey: userEmailKey)
        }
        
        UserDefaults.standard.set(true, forKey: hasAuthenticatedKey)
        isAuthenticated = true
        
        // Create or update user in Core Data
        createOrUpdateUser()
        
        // Update UserState
        updateUserState()
        
        // Adopt any orphaned games
        adoptOrphanedGames()
        
        print("✅ Successfully signed in with Apple ID: \(userID)")
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false
        
        if let error = error as? ASAuthorizationError {
            switch error.code {
            case .canceled:
                // User canceled the sign in
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
        // iOS implementation
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
        #elseif os(macOS)
        // macOS implementation
        return NSApplication.shared.windows.first ?? NSWindow()
        #endif
    }
    
    // MARK: - Core Data Management
    private func createOrUpdateUser() {
        let context = coreData.mainContext
        
        let fetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userID)
        
        do {
            let users = try context.fetch(fetchRequest)
            let user: UserCD
            
            if let existingUser = users.first {
                user = existingUser
                user.lastLoginDate = Date()
                print("✅ Updated existing user in Core Data")
            } else {
                user = UserCD(context: context)
                user.userId = userID
                user.username = userName
                user.displayName = userName
                user.email = userEmail
                user.isActive = true
                user.registrationDate = Date()
                user.lastLoginDate = Date()
                
                // Create initial stats
                let stats = UserStatsCD(context: context)
                stats.user = user
                user.stats = stats
                
                print("✅ Created new user in Core Data")
            }
            
            try context.save()
            
        } catch {
            print("❌ Error managing user in Core Data: \(error)")
        }
    }
    
    private func adoptOrphanedGames() {
        let context = coreData.mainContext
        
        // Find the current user
        let userFetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
        userFetchRequest.predicate = NSPredicate(format: "userId == %@", userID)
        
        do {
            guard let user = try context.fetch(userFetchRequest).first else { return }
            
            // Find orphaned games
            let gameFetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
            gameFetchRequest.predicate = NSPredicate(format: "user == nil")
            
            let orphanedGames = try context.fetch(gameFetchRequest)
            
            if !orphanedGames.isEmpty {
                print("📊 Found \(orphanedGames.count) orphaned games")
                
                // Adopt all orphaned games
                for game in orphanedGames {
                    game.user = user
                }
                
                // Update user stats based on adopted games
                if let stats = user.stats {
                    let completedGames = orphanedGames.filter { $0.hasWon || $0.hasLost }
                    stats.gamesPlayed += Int32(completedGames.count)
                    stats.gamesWon += Int32(completedGames.filter { $0.hasWon }.count)
                    stats.totalScore += completedGames.reduce(0) { $0 + $1.score }
                }
                
                try context.save()
                print("✅ Adopted \(orphanedGames.count) orphaned games")
            }
            
        } catch {
            print("❌ Error adopting orphaned games: \(error)")
        }
    }
    
    private func updateUserState() {
        // Update the shared UserState
        UserState.shared.userId = userID
        UserState.shared.username = userName
        UserState.shared.playerName = userName
        UserState.shared.isAuthenticated = isAuthenticated
        UserState.shared.isSignedIn = isAuthenticated
        
        // Update SimpleUserManager if you're using it
        if isAuthenticated {
            SimpleUserManager.shared.setupLocalPlayer(name: userName)
        }
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
        
        // Update other states
        updateUserState()
        
        print("👋 User signed out")
    }
}

// MARK: - Sign In with Apple Button View (Cross-Platform)
struct SignInWithAppleButton: View {
    @StateObject private var authManager = AuthenticationManager.shared
    var onSignIn: (() -> Void)?
    
    var body: some View {
        #if os(iOS)
        SignInWithAppleButtoniOS(authManager: authManager, onSignIn: onSignIn)
        #elseif os(macOS)
        SignInWithAppleButtonMac(authManager: authManager, onSignIn: onSignIn)
        #endif
    }
}

#if os(iOS)
import UIKit

struct SignInWithAppleButtoniOS: UIViewRepresentable {
    let authManager: AuthenticationManager
    let onSignIn: (() -> Void)?
    
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: .signIn,
            authorizationButtonStyle: .black
        )
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleAuthorizationAppleIDButtonPress),
            for: .touchUpInside
        )
        return button
    }
    
    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(authManager: authManager, onSignIn: onSignIn)
    }
    
    class Coordinator: NSObject {
        let authManager: AuthenticationManager
        let onSignIn: (() -> Void)?
        
        init(authManager: AuthenticationManager, onSignIn: (() -> Void)?) {
            self.authManager = authManager
            self.onSignIn = onSignIn
        }
        
        @objc func handleAuthorizationAppleIDButtonPress() {
            authManager.signInWithApple()
            onSignIn?()
        }
    }
}
#endif

#if os(macOS)
import AppKit

struct SignInWithAppleButtonMac: NSViewRepresentable {
    let authManager: AuthenticationManager
    let onSignIn: (() -> Void)?
    
    func makeNSView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: .signIn,
            authorizationButtonStyle: .black
        )
        button.target = context.coordinator
        button.action = #selector(Coordinator.handleAuthorizationAppleIDButtonPress)
        return button
    }
    
    func updateNSView(_ nsView: ASAuthorizationAppleIDButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(authManager: authManager, onSignIn: onSignIn)
    }
    
    class Coordinator: NSObject {
        let authManager: AuthenticationManager
        let onSignIn: (() -> Void)?
        
        init(authManager: AuthenticationManager, onSignIn: (() -> Void)?) {
            self.authManager = authManager
            self.onSignIn = onSignIn
        }
        
        @objc func handleAuthorizationAppleIDButtonPress() {
            authManager.signInWithApple()
            onSignIn?()
        }
    }
}
#endif

// MARK: - Authentication Required View (Cross-Platform Fixed)
struct AuthenticationRequiredView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    var message: String = "Sign in with Apple to track your game statistics"
    var onAuthenticated: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Sign In Required")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            SignInWithAppleButton(onSignIn: onAuthenticated)
                .frame(height: 50)
                .frame(maxWidth: 280)
                .padding(.horizontal, 40)
            
            Text("Your games and statistics will be saved after signing in")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorSystem.shared.primaryBackground(for: colorScheme))
    }
}
