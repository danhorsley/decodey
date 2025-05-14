import Foundation
import Combine

class UserService: ObservableObject {
    // Published properties
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var username = ""
    @Published var userId = ""
    @Published var isSubadmin = false
    
    // User data
    @Published var userProfile: UserProfile?
    @Published var userPreferences: UserPreferences?
    @Published var gameStatistics: GameStatistics?
    
    // Dependencies
    private let userRepository: UserRepositoryProtocol
    private let gameRepository: GameRepositoryProtocol
    private let authCoordinator: AuthenticationCoordinator
    private var cancellables = Set<AnyCancellable>()
    
    init(
        userRepository: UserRepositoryProtocol,
        gameRepository: GameRepositoryProtocol,
        authCoordinator: AuthenticationCoordinator
    ) {
        self.userRepository = userRepository
        self.gameRepository = gameRepository
        self.authCoordinator = authCoordinator
        
        // Setup bindings to auth coordinator
        setupBindings()
    }
    
    // Convenience initializer using repository provider
    convenience init(authCoordinator: AuthenticationCoordinator) {
        let provider = RepositoryProvider.shared
        self.init(
            userRepository: provider.userRepository,
            gameRepository: provider.gameRepository,
            authCoordinator: authCoordinator
        )
    }
    
    private func setupBindings() {
        // Bind to auth coordinator properties
        authCoordinator.$isAuthenticated
            .assign(to: \.isLoggedIn, on: self)
            .store(in: &cancellables)
        
        authCoordinator.$isLoading
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        authCoordinator.$errorMessage
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        authCoordinator.$username
            .assign(to: \.username, on: self)
            .store(in: &cancellables)
        
        authCoordinator.$userId
            .assign(to: \.userId, on: self)
            .store(in: &cancellables)
        
        authCoordinator.$isSubadmin
            .assign(to: \.isSubadmin, on: self)
            .store(in: &cancellables)
        
        // React to authentication state changes
        authCoordinator.$isAuthenticated
            .removeDuplicates()
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.loadUserData()
                } else {
                    self?.clearUserData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Log in the user
    func login(username: String, password: String, rememberMe: Bool) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            authCoordinator.login(username: username, password: password, rememberMe: rememberMe) { success, error in
                if success {
                    continuation.resume()
                } else if let errorMessage = error {
                    continuation.resume(throwing: NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
                } else {
                    continuation.resume(throwing: NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unknown login error"]))
                }
            }
        }
    }
    
    /// Log out the user
    func logout() {
        authCoordinator.logout()
    }
    
    /// Load user data after login
    func loadUserData() {
        guard isLoggedIn, !userId.isEmpty else { return }
        
        Task {
            await loadProfile()
            await loadPreferences()
            await loadGameStatistics()
        }
    }
    
    /// Update user preferences
    func updatePreferences(
        darkMode: Bool? = nil,
        showTextHelpers: Bool? = nil,
        accessibilityTextSize: Bool? = nil,
        gameDifficulty: String? = nil,
        soundEnabled: Bool? = nil,
        soundVolume: Float? = nil,
        useBiometricAuth: Bool? = nil,
        notificationsEnabled: Bool? = nil
    ) {
        guard isLoggedIn, !userId.isEmpty, var prefs = userPreferences else { return }
        
        if let darkMode = darkMode { prefs.darkMode = darkMode }
        if let showTextHelpers = showTextHelpers { prefs.showTextHelpers = showTextHelpers }
        if let accessibilityTextSize = accessibilityTextSize { prefs.accessibilityTextSize = accessibilityTextSize }
        if let gameDifficulty = gameDifficulty { prefs.gameDifficulty = gameDifficulty }
        if let soundEnabled = soundEnabled { prefs.soundEnabled = soundEnabled }
        if let soundVolume = soundVolume { prefs.soundVolume = soundVolume }
        if let useBiometricAuth = useBiometricAuth { prefs.useBiometricAuth = useBiometricAuth }
        if let notificationsEnabled = notificationsEnabled { prefs.notificationsEnabled = notificationsEnabled }
        
        Task {
            do {
                // Update last sync date
                prefs.lastSyncDate = Date()
                
                // Save to repository
                try await userRepository.saveUserPreferences(preferences: prefs)
                
                // Update local state
                await MainActor.run {
                    self.userPreferences = prefs
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save preferences: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Update game statistics after game completion
    func updateGameStatistics(gameWon: Bool, score: Int, timeTaken: Int, mistakes: Int) {
        guard isLoggedIn, !userId.isEmpty else { return }
        
        Task {
            do {
                try await gameRepository.updateStatistics(
                    userId: userId,
                    gameWon: gameWon,
                    mistakes: mistakes,
                    timeTaken: timeTaken,
                    score: score
                )
                
                // Refresh stats
                await loadGameStatistics()
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update statistics: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadProfile() async {
        guard isLoggedIn, !userId.isEmpty else { return }
        
        do {
            // Load user profile
            let profile = try await userRepository.getUserProfile(userId: userId)
            
            // Update UI on main thread
            await MainActor.run {
                self.userProfile = profile
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load user profile: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadPreferences() async {
        guard isLoggedIn, !userId.isEmpty else { return }
        
        do {
            // Load user preferences
            let preferences = try await userRepository.getUserPreferences(userId: userId)
            
            // Update UI on main thread
            await MainActor.run {
                self.userPreferences = preferences
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load user preferences: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadGameStatistics() async {
        guard isLoggedIn, !userId.isEmpty else { return }
        
        do {
            // Load game statistics
            let statistics = try await gameRepository.getGameStatistics(userId: userId)
            
            // Update UI on main thread
            await MainActor.run {
                self.gameStatistics = statistics
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load game statistics: \(error.localizedDescription)"
            }
        }
    }
    
    private func clearUserData() {
        userProfile = nil
        userPreferences = nil
        gameStatistics = nil
    }
}

//
//  UserService.swift
//  loginboy
//
//  Created by Daniel Horsley on 15/05/2025.
//

//
//  UserService.swift
//  loginboy
//
//  Created by Daniel Horsley on 14/05/2025.
//

