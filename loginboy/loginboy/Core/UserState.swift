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
    private let coreData = CoreDataStack.shared
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
        
        authCoordinator.$isAuthenticated
                .sink { [weak self] isAuthenticated in
                    guard let self = self else { return }
                    
                    if isAuthenticated {
                        self.fetchUserData()
                        
                        // Add quote sync after login
                        self.syncQuotesAfterLogin()
                        
                        // Existing game sync
                        self.syncGamesAfterLogin()
                    } else {
                        self.profile = nil
                        self.stats = nil
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
    
    /// Fetch user data from Core Data only - no server calls
    func fetchUserData() {
        guard isAuthenticated, !userId.isEmpty else { return }
        
        let context = coreData.mainContext
        
        // Fetch user
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            
            if let user = users.first {
                // Update profile from existing user
                updateProfileFromCoreData(user)
            } else {
                // Create a new user in Core Data
                createUserInCoreData()
            }
            
            // Always refresh local stats
            refreshStats()
        } catch {
            print("Error fetching user data: \(error.localizedDescription)")
        }
    }
    //sync games after login
    private func syncGamesAfterLogin() {
        // Don't sync immediately - wait a bit for UI to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.performGameSync()
        }
    }

    private func performGameSync() {
        guard isAuthenticated else { return }
        
        // Check if this is first login (needs legacy stats)
        let hasInitializedKey = "hasInitialized_\(userId)"
        let hasInitialized = UserDefaults.standard.bool(forKey: hasInitializedKey)
        
        if !hasInitialized {
            print("🔄 First login detected - retrieving legacy stats...")
            
            GameSyncManager.shared.performInitialStatsSync { [weak self] success in
                guard let self = self else { return }
                
                if success {
                    print("✅ Legacy stats retrieved successfully")
                    UserDefaults.standard.set(true, forKey: hasInitializedKey)
                    
                    // After getting stats, process any pending uploads
                    GameSyncManager.shared.processPendingUploads()
                } else {
                    print("❌ Failed to retrieve legacy stats")
                    // Still try to upload pending games
                    GameSyncManager.shared.processPendingUploads()
                }
            }
        } else {
            // Not first login, just process pending uploads
            print("🔄 Processing pending game uploads...")
            GameSyncManager.shared.processPendingUploads()
        }
    }
    // quote sync on login
    private func syncQuotesAfterLogin() {
        QuoteStore.shared.syncIfNeeded { success in
            print(success ? "✅ Post-login quote sync complete" : "❌ Post-login quote sync failed")
        }
    }
    /// Update user statistics after game completion - LOCAL ONLY
    func updateStats(gameWon: Bool, score: Int, timeTaken: Int, mistakes: Int = 0) {
        guard isAuthenticated, !userId.isEmpty else { return }
        
        let context = coreData.mainContext
        
        // Find or create user
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            
            // Find or create user
            let user: UserCD
            if let existingUser = users.first {
                user = existingUser
            } else {
                user = UserCD(context: context)
                user.id = UUID()
                user.userId = userId
                user.username = username
                user.email = "\(username)@example.com" // Placeholder
                user.registrationDate = Date()
                user.lastLoginDate = Date()
                user.isActive = true
            }
            
            // Get or create stats
            let stats: UserStatsCD
            if let existingStats = user.stats {
                stats = existingStats
            } else {
                stats = UserStatsCD(context: context)
                user.stats = stats
                stats.user = user
            }
            
            // Update stats
            stats.gamesPlayed += 1
            if gameWon {
                stats.gamesWon += 1
                stats.currentStreak += 1
                stats.bestStreak = max(stats.bestStreak, stats.currentStreak)
            } else {
                stats.currentStreak = 0
            }
            
            stats.totalScore += Int32(score)
            
            // Update averages
            let oldMistakesTotal = stats.averageMistakes * Double(stats.gamesPlayed - 1)
            stats.averageMistakes = (oldMistakesTotal + Double(mistakes)) / Double(stats.gamesPlayed)
            
            let oldTimeTotal = stats.averageTime * Double(stats.gamesPlayed - 1)
            stats.averageTime = (oldTimeTotal + Double(timeTaken)) / Double(stats.gamesPlayed)
            
            stats.lastPlayedDate = Date()
            
            // Save changes
            try context.save()
            
            // Update published stats property
            refreshStats()
        } catch {
            print("Error updating stats: \(error.localizedDescription)")
        }
    }
    
    /// Get user's statistics from local Core Data only
    func refreshStats() {
        guard isAuthenticated, !userId.isEmpty else {
            stats = nil
            return
        }
        
        let context = coreData.mainContext
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            
            if let user = users.first, let userStats = user.stats {
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
    func updateProfile(displayName: String? = nil, bio: String? = nil) {
        guard isAuthenticated, !userId.isEmpty else { return }
        
        let context = coreData.mainContext
        
        // Find user
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            
            guard let user = users.first else { return }
            
            // Update properties
            if let displayName = displayName {
                user.displayName = displayName
            }
            
            if let bio = bio {
                user.bio = bio
            }
            
            // Update last login date
            user.lastLoginDate = Date()
            
            // Save changes
            try context.save()
            
            // Update published profile property
            updateProfileFromCoreData(user)
        } catch {
            print("Error updating profile: \(error.localizedDescription)")
        }
    }
    
    /// Recalculate stats from all games (useful after sync)
    func recalculateStatsFromGames() {
        guard isAuthenticated, !userId.isEmpty else { return }
        
        let context = coreData.mainContext
        
        // Get all completed games for this user
        let gameFetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        gameFetchRequest.predicate = NSPredicate(format: "user.userId == %@ AND (hasWon == YES OR hasLost == YES)", userId)
        gameFetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastUpdateTime", ascending: true)]
        
        do {
            let completedGames = try context.fetch(gameFetchRequest)
            
            // Find user
            let userFetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
            userFetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
            let users = try context.fetch(userFetchRequest)
            
            guard let user = users.first else { return }
            
            // Get or create stats
            let stats: UserStatsCD
            if let existingStats = user.stats {
                stats = existingStats
            } else {
                stats = UserStatsCD(context: context)
                user.stats = stats
                stats.user = user
            }
            
            // Reset and recalculate everything
            var totalGames = 0
            var gamesWon = 0
            var totalScore = 0
            var currentStreak = 0
            var bestStreak = 0
            var totalTime = 0.0
            var totalMistakes = 0
            var lastPlayedDate: Date?
            
            // Calculate stats from all games
            for game in completedGames {
                totalGames += 1
                totalScore += Int(game.score)
                totalMistakes += Int(game.mistakes)
                lastPlayedDate = max(lastPlayedDate ?? Date.distantPast, game.lastUpdateTime ?? Date.distantPast)
                
                // Calculate time taken for this game
                if let startTime = game.startTime, let endTime = game.lastUpdateTime {
                    totalTime += endTime.timeIntervalSince(startTime)
                }
                
                if game.hasWon {
                    gamesWon += 1
                    currentStreak += 1
                    bestStreak = max(bestStreak, currentStreak)
                } else if game.hasLost {
                    currentStreak = 0
                }
            }
            
            // Update stats
            stats.gamesPlayed = Int32(totalGames)
            stats.gamesWon = Int32(gamesWon)
            stats.totalScore = Int32(totalScore)
            stats.currentStreak = Int32(currentStreak)
            stats.bestStreak = Int32(bestStreak)
            stats.averageTime = totalGames > 0 ? totalTime / Double(totalGames) : 0
            stats.averageMistakes = totalGames > 0 ? Double(totalMistakes) / Double(totalGames) : 0
            stats.lastPlayedDate = lastPlayedDate
            
            // Save changes
            try context.save()
            
            // Update published stats
            refreshStats()
            
            print("✅ Recalculated stats from \(totalGames) games: \(gamesWon) wins, streak: \(currentStreak)")
        } catch {
            print("Error recalculating stats: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func updateProfileFromCoreData(_ user: UserCD) {
        // Update the profile data
        profile = UserModel(
            userId: user.userId ?? "",
            username: user.username ?? "",
            email: user.email ?? "",
            displayName: user.displayName,
            avatarUrl: user.avatarUrl,
            bio: user.bio,
            registrationDate: user.registrationDate ?? Date(),
            lastLoginDate: user.lastLoginDate ?? Date(),
            isActive: user.isActive,
            isVerified: user.isVerified,
            isSubadmin: user.isSubadmin
        )
        
        // Update stats if available
        if let userStats = user.stats {
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
    
    private func createUserInCoreData() {
        guard isAuthenticated, !userId.isEmpty, !username.isEmpty else { return }
        
        let context = coreData.mainContext
        
        do {
            // Create user
            let user = UserCD(context: context)
            user.id = UUID()
            user.userId = userId
            user.username = username
            user.email = "\(username)@example.com" // Placeholder
            user.registrationDate = Date()
            user.lastLoginDate = Date()
            user.isActive = true
            user.isSubadmin = isSubadmin
            
            // Create default preferences
            let preferences = UserPreferencesCD(context: context)
            user.preferences = preferences
            preferences.user = user
            
            // Set default values
            preferences.darkMode = true
            preferences.showTextHelpers = true
            preferences.accessibilityTextSize = false
            preferences.gameDifficulty = "medium"
            preferences.soundEnabled = true
            preferences.soundVolume = 0.5
            preferences.useBiometricAuth = false
            preferences.notificationsEnabled = true
            
            // Create empty stats
            let stats = UserStatsCD(context: context)
            user.stats = stats
            stats.user = user
            
            // Save changes
            try context.save()
            
            // Update local profile
            updateProfileFromCoreData(user)
        } catch {
            print("Error creating user in Core Data: \(error.localizedDescription)")
        }
    }
}

