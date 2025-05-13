import Foundation
import Combine
import SwiftUI

/// UserState manages user authentication and profile information
class UserState: ObservableObject {
    // Published properties for UI binding
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var username = ""
    @Published var userId = ""
    @Published var isSubadmin = false
    
    // User statistics
    @Published var stats: UserStats?
    @Published var isLoadingStats = false
    
    // Leaderboard data
    @Published var leaderboardData: LeaderboardResponse?
    @Published var isLoadingLeaderboard = false
    
    // Services
    let authCoordinator: AuthenticationCoordinator
    private let databaseManager = DatabaseManager.shared
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
            .assign(to: \.isAuthenticated, on: self)
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
        
        authCoordinator.$errorMessage
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        authCoordinator.$isLoading
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        // When authentication state changes, fetch user data
        $isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.fetchUserStats()
                } else {
                    self?.stats = nil
                    self?.leaderboardData = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Login with username and password
    func login(username: String, password: String, rememberMe: Bool) async throws {
        // Fix for 'NSError' is not convertible to 'Never'
        // Create a proper error enum to throw
        enum LoginError: Error {
            case authenticationFailed(String)
            case unknown
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
    
    /// Fetch user statistics
    func fetchUserStats() {
        guard isAuthenticated else { return }
        isLoadingStats = true
        
        // Fix for unreachable catch block by adding potential throwing calls
        Task {
            do {
                // Simulate fetching stats from database or API
                // This would be a throwing call in a real implementation
                try await Task.sleep(nanoseconds: 500_000_000) // Sleep for 0.5 seconds
                
                // Create mock stats - in a real app, you'd fetch this from a server
                let statsResponse = UserStats(
                    userId: userId,
                    gamesPlayed: 10,
                    gamesWon: 7,
                    currentStreak: 3,
                    bestStreak: 5,
                    totalScore: 1500,
                    averageScore: 150,
                    averageTime: 180 // 3 minutes
                )
                
                await MainActor.run {
                    self.stats = statsResponse
                    self.isLoadingStats = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load user stats: \(error.localizedDescription)"
                    self.isLoadingStats = false
                }
            }
        }
    }
    
    /// Fetch leaderboard data
    func fetchLeaderboard(period: String = "all-time", page: Int = 1) {
        guard isAuthenticated else { return }
        isLoadingLeaderboard = true
        
        // Fix for unreachable catch block by adding potential throwing calls
        Task {
            do {
                // Simulate fetching leaderboard from API
                // This would be a throwing call in a real implementation
                try await Task.sleep(nanoseconds: 1_000_000_000) // Sleep for 1 second
                
                // In a real app, you'd fetch from a server
                await MainActor.run {
                    self.isLoadingLeaderboard = false
                    // Set leaderboard data
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load leaderboard: \(error.localizedDescription)"
                    self.isLoadingLeaderboard = false
                }
            }
        }
    }
    
    /// Update user statistics after game completion
    /// Fix for missing 'mistakes' parameter
    func updateStats(gameWon: Bool, score: Int, timeTaken: Int, mistakes: Int = 0) {
        guard isAuthenticated, !userId.isEmpty else { return }
        
        Task {
            do {
                try databaseManager.updateStatistics(
                    userId: userId,
                    gameWon: gameWon,
                    mistakes: mistakes,
                    timeTaken: timeTaken,
                    score: score,
                )
                
                // Refresh stats
                await MainActor.run {
                    fetchUserStats()
                }
            } catch {
                print("Error updating stats: \(error.localizedDescription)")
            }
        }
    }
    
    /// Get access token for API calls
    func getAccessToken() -> String? {
        return authCoordinator.getAccessToken()
    }
}

// User stats model
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
