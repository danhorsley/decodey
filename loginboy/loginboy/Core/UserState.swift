import Foundation
import CoreData
import Combine

class UserState: ObservableObject {
    // Published properties for UI binding
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var username = ""
    @Published var userId = ""
    @Published var isSubadmin = false
    
    // User profile data
    @Published var profile: UserModel?
    @Published var stats: UserStatsModel?
    
    // Authentication coordinator - keep this for handling auth API
    let authCoordinator: AuthenticationCoordinator
    
    // Core Data access
    private let cdStack = CoreDataStack.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Singleton instance
    static let shared = UserState()
    
    // Initialize with authentication coordinator
    private init() {
        self.authCoordinator = AuthenticationCoordinator()
        
        // Bind to auth coordinator changes
        setupBindings()
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
                    self?.fetchUserDataFromCD()
                } else {
                    self?.profile = nil
                    self?.stats = nil
                }
            }
            .store(in: &cancellables)
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
    
    /// Fetch user data from Core Data
    func fetchUserDataFromCD() {
        guard isAuthenticated, !userId.isEmpty else { return }
        
        let context = cdStack.mainContext
        
        // Fetch user from Core Data
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let usersCD = try context.fetch(fetchRequest)
            
            if let userCD = usersCD.first {
                // Update from existing user
                updateProfileFromCD(userCD)
            } else {
                // Create a new user in Core Data
                createUserInCD()
            }
        } catch {
            print("Error fetching user data: \(error.localizedDescription)")
        }
    }
    
    /// Update user statistics after game completion
    func updateStatsInCD(gameWon: Bool, score: Int, timeTaken: Int, mistakes: Int = 0) {
        guard isAuthenticated, !userId.isEmpty else { return }
        
        let context = cdStack.mainContext
        
        // Find or create user in Core Data
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let usersCD = try context.fetch(fetchRequest)
            
            // Find or create user
            let userCD: User
            if let existingUser = usersCD.first {
                userCD = existingUser
            } else {
                userCD = User(context: context)
                userCD.id = UUID()
                userCD.userId = userId
                userCD.username = username
                userCD.email = "\(username)@example.com" // Placeholder
                userCD.registrationDate = Date()
                userCD.lastLoginDate = Date()
                userCD.isActive = true
            }
            
            // Get or create stats
            let statsCD: UserStats
            if let existingStats = userCD.stats {
                statsCD = existingStats
            } else {
                statsCD = UserStats(context: context)
                userCD.stats = statsCD
                statsCD.user = userCD
            }
            
            // Update stats
            statsCD.gamesPlayed += 1
            if gameWon {
                statsCD.gamesWon += 1
                statsCD.currentStreak += 1
                statsCD.bestStreak = max(statsCD.bestStreak, statsCD.currentStreak)
            } else {
                statsCD.currentStreak = 0
            }
            
            statsCD.totalScore += Int32(score)
            
            // Update averages
            let oldMistakesTotal = statsCD.averageMistakes * Double(statsCD.gamesPlayed - 1)
            statsCD.averageMistakes = (oldMistakesTotal + Double(mistakes)) / Double(statsCD.gamesPlayed)
            
            let oldTimeTotal = statsCD.averageTime * Double(statsCD.gamesPlayed - 1)
            statsCD.averageTime = (oldTimeTotal + Double(timeTaken)) / Double(statsCD.gamesPlayed)
            
            statsCD.lastPlayedDate = Date()
            
            // Save changes
            try context.save()
            
            // Update published stats property
            refreshStatsFromCD()
        } catch {
            print("Error updating stats: \(error.localizedDescription)")
        }
    }
    
    /// Get user's statistics from Core Data
    func refreshStatsFromCD() {
        guard isAuthenticated, !userId.isEmpty else {
            stats = nil
            return
        }
        
        let context = cdStack.mainContext
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let usersCD = try context.fetch(fetchRequest)
            
            if let userCD = usersCD.first, let userStats = userCD.stats {
                // Create UserStatsModel from Core Data
                stats = UserStatsModel(
                    userId: userId,
                    gamesPlayed: Int(userStats.gamesPlayed),
                    gamesWon: Int(userStats.gamesWon),
                    currentStreak: Int(userStats.currentStreak),
                    bestStreak: Int(userStats.bestStreak),
                    totalScore: Int(userStats.totalScore),
                    averageScore: userStats.gamesPlayed > 0 ?
                        Double(userStats.totalScore) / Double(userStats.gamesPlayed) : 0,
                    averageTime: userStats.averageTime,
                    lastPlayedDate: userStats.lastPlayedDate
                )
            } else {
                stats = nil
            }
        } catch {
            print("Error refreshing stats: \(error.localizedDescription)")
            stats = nil
        }
    }
    
    /// Update user profile information
    func updateProfileInCD(displayName: String? = nil, bio: String? = nil) {
        guard isAuthenticated, !userId.isEmpty else { return }
        
        let context = cdStack.mainContext
        
        // Find user in Core Data
        let fetchRequest: NSFetchRequest<User> = User.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let usersCD = try context.fetch(fetchRequest)
            
            guard let userCD = usersCD.first else { return }
            
            // Update properties
            if let displayName = displayName {
                userCD.displayName = displayName
            }
            
            if let bio = bio {
                userCD.bio = bio
            }
            
            // Update last login date
            userCD.lastLoginDate = Date()
            
            // Save changes
            try context.save()
            
            // Update published profile property
            updateProfileFromCD(userCD)
        } catch {
            print("Error updating profile: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func updateProfileFromCD(_ userCD: User) {
        // Update the profile data
        profile = UserModel(
            userId: userCD.userId ?? "",
            username: userCD.username ?? "",
            email: userCD.email ?? "",
            displayName: userCD.displayName,
            avatarUrl: userCD.avatarUrl,
            bio: userCD.bio,
            registrationDate: userCD.registrationDate ?? Date(),
            lastLoginDate: userCD.lastLoginDate ?? Date(),
            isActive: userCD.isActive,
            isVerified: userCD.isVerified,
            isSubadmin: userCD.isSubAdmin
        )
        
        // Update stats if available
        if let userStats = userCD.stats {
            stats = UserStatsModel(
                userId: userId,
                gamesPlayed: Int(userStats.gamesPlayed),
                gamesWon: Int(userStats.gamesWon),
                currentStreak: Int(userStats.currentStreak),
                bestStreak: Int(userStats.bestStreak),
                totalScore: Int(userStats.totalScore),
                averageScore: userStats.gamesPlayed > 0 ?
                    Double(userStats.totalScore) / Double(userStats.gamesPlayed) : 0,
                averageTime: userStats.averageTime,
                lastPlayedDate: userStats.lastPlayedDate
            )
        } else {
            stats = nil
        }
    }
    
    private func createUserInCD() {
        guard isAuthenticated, !userId.isEmpty, !username.isEmpty else { return }
        
        let context = cdStack.mainContext
        
        do {
            // Create user
            let userCD = User(context: context)
            userCD.id = UUID()
            userCD.userId = userId
            userCD.username = username
            userCD.email = "\(username)@example.com" // Placeholder
            userCD.registrationDate = Date()
            userCD.lastLoginDate = Date()
            userCD.isActive = true
            userCD.isSubAdmin = isSubadmin
            
            // Create default preferences
            let preferencesCD = UserPreferences(context: context)
            userCD.preferences = preferencesCD
            preferencesCD.user = userCD
            
            // Set default values
            preferencesCD.darkMode = true
            preferencesCD.showTextHelpers = true
            preferencesCD.accessibilityTextSize = false
            preferencesCD.gameDifficulty = "medium"
            preferencesCD.soundEnabled = true
            preferencesCD.soundVolume = 0.5
            preferencesCD.useBiometricAuth = false
            preferencesCD.notificationsEnabled = true
            
            // Create empty stats
            let statsCD = UserStats(context: context)
            userCD.stats = statsCD
            statsCD.user = userCD
            
            // Save changes
            try context.save()
            
            // Update local profile
            updateProfileFromCD(userCD)
        } catch {
            print("Error creating user in Core Data: \(error.localizedDescription)")
        }
    }
}
