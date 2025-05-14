// UserState.swift - Reimplemented for Realm
import Foundation
import Combine
import SwiftUI
import RealmSwift

/// UserState manages user authentication and profile information
class UserState: ObservableObject {
    // Published properties for UI binding
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var username = ""
    @Published var userId = ""
    @Published var isSubadmin = false
    
    // User profile data
    @Published var profile: UserProfile?
    @Published var stats: UserStats?
    
    // Authentication coordinator - keep this for handling auth API
    let authCoordinator: AuthenticationCoordinator
    
    // Direct Realm access
    private let realm = RealmManager.shared.getRealm()
    private var userNotificationToken: NotificationToken?
    private var cancellables = Set<AnyCancellable>()
    
    // Singleton instance
    static let shared = UserState()
    
    // Initialize with authentication coordinator
    private init() {
        self.authCoordinator = AuthenticationCoordinator()
        
        // Bind to auth coordinator changes
        setupBindings()
        
        // Setup Realm notifications
        setupRealmObservers()
    }
    
    deinit {
        // Clean up notification tokens
        userNotificationToken?.invalidate()
    }
    
    private func setupBindings() {
        // Observe auth coordinator state changes
        authCoordinator.$isAuthenticated
            .assign(to: &$isAuthenticated)
        
        authCoordinator.$isLoading
            .assign(to: &$isLoading)
        
        authCoordinator.$errorMessage
            .assign(to: &$errorMessage)
        
        authCoordinator.$username
            .assign(to: &$username)
        
        authCoordinator.$userId
            .assign(to: &$userId)
        
        authCoordinator.$isSubadmin
            .assign(to: &$isSubadmin)
        
        // When authentication state changes, fetch user data
        $isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.fetchUserData()
                } else {
                    self?.profile = nil
                    self?.stats = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // Set up Realm notifications for real-time updates
    private func setupRealmObservers() {
        guard let realm = realm else { return }
        
        // Observe UserRealm objects
        let users = realm.objects(UserRealm.self)
        
        userNotificationToken = users.observe { [weak self] (changes: RealmCollectionChange) in
            guard let self = self else { return }
            
            switch changes {
            case .update(let collection, _, _, _):
                // Only update if it's our user
                if let userObj = collection.first(where: { $0.userId == self.userId }) {
                    self.updateUserProfileFromRealm(userObj)
                }
            case .initial(let collection):
                // Initial load after observation starts
                if let userObj = collection.first(where: { $0.userId == self.userId }) {
                    self.updateUserProfileFromRealm(userObj)
                }
            case .error(let error):
                print("Error observing users in Realm: \(error)")
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Login with username and password
    func login(username: String, password: String, rememberMe: Bool) async throws {
        // Create a proper error enum to throw
        enum LoginError: Error, LocalizedError {
            case authenticationFailed(String)
            case unknown
            
            var errorDescription: String? {
                switch self {
                case .authenticationFailed(let msg): return msg
                case .unknown: return "Unknown login error occurred"
                }
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            authCoordinator.login(username: username, password: password, rememberMe: rememberMe) { success, error in
                if success {
                    continuation.resume()
                } else if let errorMessage = error {
                    continuation.resume(throwing: LoginError.authenticationFailed(errorMessage))
                } else {
                    continuation.resume(throwing: LoginError.unknown)
                }
            }
        }
    }
    
    /// Logout the current user
    func logout() {
        authCoordinator.logout()
    }
    
    /// Fetch user data from Realm
    func fetchUserData() {
        guard isAuthenticated, !userId.isEmpty else { return }
        
        // Check if user exists in Realm
        if let user = getUserFromRealm() {
            // Update from existing user
            updateUserProfileFromRealm(user)
        } else {
            // Create a new user in Realm
            createUserInRealm()
        }
    }
    
    /// Update user statistics after game completion
    func updateStats(gameWon: Bool, score: Int, timeTaken: Int, mistakes: Int = 0) {
        guard isAuthenticated, !userId.isEmpty else { return }
        guard let realm = realm else { return }
        
        do {
            try realm.write {
                // Find user or create
                guard let user = getUserFromRealm() else {
                    return
                }
                
                // Create stats if needed
                if user.stats == nil {
                    user.stats = UserStatsRealm()
                }
                
                guard let stats = user.stats else { return }
                
                // Update stats
                stats.gamesPlayed += 1
                if gameWon {
                    stats.gamesWon += 1
                    stats.currentStreak += 1
                    stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
                } else {
                    stats.currentStreak = 0
                }
                
                stats.totalScore += score
                
                // Update averages
                let oldMistakesTotal = stats.averageMistakes * Double(stats.gamesPlayed - 1)
                stats.averageMistakes = (oldMistakesTotal + Double(mistakes)) / Double(stats.gamesPlayed)
                
                let oldTimeTotal = stats.averageTime * Double(stats.gamesPlayed - 1)
                stats.averageTime = (oldTimeTotal + Double(timeTaken)) / Double(stats.gamesPlayed)
                
                stats.lastPlayedDate = Date()
            }
            
            // Update published stats property
            self.refreshStats()
        } catch {
            print("Error updating stats: \(error.localizedDescription)")
        }
    }
    
    /// Get user's statistics
    func refreshStats() {
        guard isAuthenticated, let user = getUserFromRealm(), let realmStats = user.stats else {
            stats = nil
            return
        }
        
        // Create UserStats from Realm data
        stats = UserStats(
            userId: userId,
            gamesPlayed: realmStats.gamesPlayed,
            gamesWon: realmStats.gamesWon,
            currentStreak: realmStats.currentStreak,
            bestStreak: realmStats.bestStreak,
            totalScore: realmStats.totalScore,
            averageScore: realmStats.gamesPlayed > 0 ?
                Double(realmStats.totalScore) / Double(realmStats.gamesPlayed) : 0,
            averageTime: realmStats.averageTime
        )
    }
    
    /// Update user profile information
    func updateProfile(displayName: String? = nil, bio: String? = nil) {
        guard isAuthenticated, !userId.isEmpty else { return }
        guard let realm = realm else { return }
        
        do {
            try realm.write {
                guard let user = getUserFromRealm() else { return }
                
                if let displayName = displayName {
                    user.displayName = displayName
                }
                
                if let bio = bio {
                    user.bio = bio
                }
                
                // Update last modified date
                user.lastLoginDate = Date()
            }
            
            // Update published profile property
            updateUserProfileFromRealm(getUserFromRealm())
        } catch {
            print("Error updating profile: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func getUserFromRealm() -> UserRealm? {
        guard let realm = realm else { return nil }
        return realm.object(ofType: UserRealm.self, forPrimaryKey: userId)
    }
    
    private func updateUserProfileFromRealm(_ user: UserRealm?) {
        guard let user = user else {
            profile = nil
            stats = nil
            return
        }
        
        // Update the profile data
        profile = UserProfile(
            userId: user.userId,
            username: user.username,
            email: user.email,
            displayName: user.displayName,
            avatarUrl: user.avatarUrl,
            bio: user.bio,
            registrationDate: user.registrationDate,
            lastLoginDate: user.lastLoginDate
        )
        
        // Update stats if available
        if let realmStats = user.stats {
            stats = UserStats(
                userId: userId,
                gamesPlayed: realmStats.gamesPlayed,
                gamesWon: realmStats.gamesWon,
                currentStreak: realmStats.currentStreak,
                bestStreak: realmStats.bestStreak,
                totalScore: realmStats.totalScore,
                averageScore: realmStats.gamesPlayed > 0 ?
                    Double(realmStats.totalScore) / Double(realmStats.gamesPlayed) : 0,
                averageTime: realmStats.averageTime
            )
        } else {
            stats = nil
        }
    }
    
    private func createUserInRealm() {
        guard isAuthenticated, !userId.isEmpty, !username.isEmpty else { return }
        guard let realm = realm else { return }
        
        do {
            try realm.write {
                let user = UserRealm()
                user.userId = userId
                user.username = username
                user.email = "\(username)@example.com" // Placeholder
                user.registrationDate = Date()
                user.lastLoginDate = Date()
                user.isSubadmin = isSubadmin
                
                // Create default preferences
                let preferences = UserPreferencesRealm()
                user.preferences = preferences
                
                // Create empty stats
                let stats = UserStatsRealm()
                user.stats = stats
                
                realm.add(user)
                
                // Update local profile
                updateUserProfileFromRealm(user)
            }
        } catch {
            print("Error creating user in Realm: \(error.localizedDescription)")
        }
    }
}

// User profile model (non-Realm, for publishing)
struct UserProfile {
    let userId: String
    let username: String
    let email: String
    let displayName: String?
    let avatarUrl: String?
    let bio: String?
    let registrationDate: Date
    let lastLoginDate: Date
}

// User stats model (non-Realm, for publishing)
struct UserStats {
    let userId: String
    let gamesPlayed: Int
    let gamesWon: Int
    let currentStreak: Int
    let bestStreak: Int
    let totalScore: Int
    let averageScore: Double
    let averageTime: Double // in seconds
    
    var winPercentage: Double {
        return gamesPlayed > 0 ? Double(gamesWon) / Double(gamesPlayed) * 100 : 0
    }
}
