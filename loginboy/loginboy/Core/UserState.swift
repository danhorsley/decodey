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
    @Published var playerName = ""  // Simple local player name
    @Published var isSignedIn = false // Simple local auth state
    
    // User profile data (simplified)
    @Published var gamesPlayed = 0
    @Published var gamesWon = 0
    @Published var totalScore = 0
    
    // Core Data access
    private let coreData = CoreDataStack.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Singleton instance
    static let shared = UserState()
    
    // Simple initialization without AuthenticationCoordinator
    private init() {
        // Load saved player name
        self.playerName = UserDefaults.standard.string(forKey: "playerName") ?? ""
        self.isSignedIn = !playerName.isEmpty
        self.isAuthenticated = isSignedIn
        self.username = playerName
        
        loadStats()
    }
    
    // MARK: - Simple Local Methods
    
    func setPlayerName(_ name: String) {
        playerName = name
        username = name
        isSignedIn = !name.isEmpty
        isAuthenticated = isSignedIn
        
        UserDefaults.standard.set(name, forKey: "playerName")
    }
    
    func signOut() {
        playerName = ""
        username = ""
        isSignedIn = false
        isAuthenticated = false
        
        UserDefaults.standard.removeObject(forKey: "playerName")
        resetStats()
    }
    
    // MARK: - Stats Management
    
    private func loadStats() {
        gamesPlayed = UserDefaults.standard.integer(forKey: "gamesPlayed")
        gamesWon = UserDefaults.standard.integer(forKey: "gamesWon")
        totalScore = UserDefaults.standard.integer(forKey: "totalScore")
    }
    
    func updateStats(won: Bool, score: Int) {
        gamesPlayed += 1
        if won {
            gamesWon += 1
        }
        totalScore += score
        
        UserDefaults.standard.set(gamesPlayed, forKey: "gamesPlayed")
        UserDefaults.standard.set(gamesWon, forKey: "gamesWon")
        UserDefaults.standard.set(totalScore, forKey: "totalScore")
    }
    
    // Make this public so ProfileView can call it
    func resetStats() {
        gamesPlayed = 0
        gamesWon = 0
        totalScore = 0
        
        UserDefaults.standard.removeObject(forKey: "gamesPlayed")
        UserDefaults.standard.removeObject(forKey: "gamesWon")
        UserDefaults.standard.removeObject(forKey: "totalScore")
    }
    
    // MARK: - Computed Properties
    
    var winPercentage: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(gamesWon) / Double(gamesPlayed) * 100
    }
    
    var averageScore: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(totalScore) / Double(gamesPlayed)
    }
}
