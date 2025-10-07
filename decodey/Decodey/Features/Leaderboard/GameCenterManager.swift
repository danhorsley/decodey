import Foundation
import GameKit
import SwiftUI

// MARK: - Game Center Manager (Pure SwiftUI)
@MainActor
class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()
    
    @Published var isAuthenticated = false
    @Published var localPlayer: GKLocalPlayer?
    @Published var playerDisplayName = "Player"
    @Published var isGameCenterAvailable = false
    @Published var showingGameCenter = false
    
    // Store the view controller for iOS
    #if os(iOS)
    private var authenticationViewController: UIViewController?
    #endif
    
    // Leaderboard IDs - just one for simplicity
    struct LeaderboardIDs {
        static let totalScore = "alltime"  // Your actual ID
    }
    
    private init() {
        localPlayer = GKLocalPlayer.local
        // Don't call setupAuthentication here - let the app do it
    }
    
    // MARK: - Setup authentication handler (call from app init)
    func setupAuthentication() {
        let localPlayer = GKLocalPlayer.local
        let identityManager = UserIdentityManager.shared
        
        localPlayer.authenticateHandler = { [weak self] viewController, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let viewController = viewController {
                    // Game Center wants to show sign-in UI
                    #if os(iOS)
                    self.authenticationViewController = viewController
                    self.presentAuthenticationViewController()
                    #endif
                } else if localPlayer.isAuthenticated {
                    self.isAuthenticated = true
                    self.localPlayer = localPlayer
                    
                    // Use alias if display name is empty (common in sandbox)
                    self.playerDisplayName = localPlayer.displayName.isEmpty ?
                        localPlayer.alias : localPlayer.displayName
                    self.isGameCenterAvailable = true
                    
                    // Update identity manager with Game Center info
                    identityManager.setGameCenterUser(
                        id: localPlayer.gamePlayerID,
                        displayName: localPlayer.displayName,
                        alias: localPlayer.alias
                    )
                    
                } else if let error = error {
                    // Authentication failed
                    self.isAuthenticated = false
                    self.isGameCenterAvailable = false
                } else {
                    // Not authenticated and no UI to show
                    self.isAuthenticated = false
                    self.isGameCenterAvailable = true // But available to try again
                }
            }
        }
    }
    
    // MARK: - Present authentication view controller (iOS)
    #if os(iOS)
    private func presentAuthenticationViewController() {
        guard let viewController = authenticationViewController else { return }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            // Find the topmost view controller
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            
            // Present Game Center sign-in
            topController.present(viewController, animated: true) {
                self.authenticationViewController = nil
            }
        }
    }
    #endif
    
    // MARK: - Manual authentication trigger (for button press)
    func authenticateLocalPlayer() async {
        #if os(iOS)
        // If we have a stored view controller, present it
        if let _ = authenticationViewController {
            presentAuthenticationViewController()
            return
        }
        
        // If not authenticated and no view controller stored,
        // force the authentication handler to trigger again
        if !isAuthenticated {
            // This will cause the authentication handler to be called again
            // which should provide a new view controller for sandbox login
            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    if let viewController = viewController {
                        self.authenticationViewController = viewController
                        self.presentAuthenticationViewController()
                    } else if GKLocalPlayer.local.isAuthenticated {
                        self.isAuthenticated = true
                        self.localPlayer = GKLocalPlayer.local
                        self.playerDisplayName = GKLocalPlayer.local.displayName.isEmpty ?
                            GKLocalPlayer.local.alias : GKLocalPlayer.local.displayName
                        
                        // Update identity manager
                        let identityManager = UserIdentityManager.shared
                        identityManager.setGameCenterUser(
                            id: GKLocalPlayer.local.gamePlayerID,
                            displayName: GKLocalPlayer.local.displayName,
                            alias: GKLocalPlayer.local.alias
                        )
                    }
                }
            }
        }
        #elseif os(macOS)
        // On macOS, the authentication handler should have shown the dialog
        #endif
    }
    
    private func configureAccessPoint() {
        // Configure the Game Center access point
        GKAccessPoint.shared.location = .topTrailing
        GKAccessPoint.shared.showHighlights = true
        GKAccessPoint.shared.isActive = false // Don't show the access point overlay for now
    }
    
    func debugListAllLeaderboards() async {
        do {
            // This will fetch ALL leaderboards configured for your app
            let leaderboards = try await GKLeaderboard.loadLeaderboards()
            
            for leaderboard in leaderboards {
                // Silent in production
                _ = leaderboard.baseLeaderboardID
                _ = leaderboard.title ?? "No title"
            }
            
            if leaderboards.isEmpty {
                // No leaderboards found - check App Store Connect configuration
            }
        } catch {
            // Error loading leaderboards
        }
    }
    
    // MARK: - Submit score
    func submitTotalScore(_ score: Int) async {
        guard isAuthenticated else {
            return
        }
        
        do {
            try await GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [LeaderboardIDs.totalScore]
            )
        } catch {
            // Failed to submit score
        }
    }
    
    // MARK: - Leaderboard Data (Pure GameKit)
    
    func fetchLeaderboardScores(
        leaderboardID: String,
        scope: GKLeaderboard.PlayerScope = .global,
        timeScope: GKLeaderboard.TimeScope = .allTime,
        range: NSRange = NSRange(location: 1, length: 50)
    ) async -> [LeaderboardEntry] {
        
        guard isAuthenticated else {
            return []
        }
        
        do {
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
            
            guard let leaderboard = leaderboards.first else {
                return []
            }
            
            let (localPlayerEntry, regularEntries, _) = try await leaderboard.loadEntries(
                for: scope,
                timeScope: timeScope,
                range: range
            )
            
            // Dictionary to track best score per player
            var bestScoresByPlayer: [String: LeaderboardEntry] = [:]
            
            // Process local player entry if available
            if let localEntry = localPlayerEntry {
                let entry = LeaderboardEntry(
                    player: localEntry.player,
                    score: localEntry.score,
                    rank: localEntry.rank,
                    isLocalPlayer: true
                )
                bestScoresByPlayer[localEntry.player.gamePlayerID] = entry
            }
            
            // Process all other entries, keeping only the best score per player
            for entry in regularEntries {
                let playerID = entry.player.gamePlayerID
                let newEntry = LeaderboardEntry(
                    player: entry.player,
                    score: entry.score,
                    rank: entry.rank,
                    isLocalPlayer: entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
                )
                
                // Check if we already have an entry for this player
                if let existingEntry = bestScoresByPlayer[playerID] {
                    // Keep the better score
                    if newEntry.score > existingEntry.score {
                        bestScoresByPlayer[playerID] = newEntry
                    }
                } else {
                    // First entry for this player
                    bestScoresByPlayer[playerID] = newEntry
                }
            }
            
            // Convert to array and re-rank properly
            let dedupedEntries = Array(bestScoresByPlayer.values)
                .sorted { $0.score > $1.score }
                .enumerated()
                .map { index, entry in
                    // Create new entry with corrected rank
                    LeaderboardEntry(
                        player: entry.player,
                        score: entry.score,
                        rank: index + 1,  // Recalculate rank after deduplication
                        isLocalPlayer: entry.isLocalPlayer
                    )
                }
            
            return dedupedEntries
            
        } catch {
            return []
        }
    }
    
    // MARK: - SwiftUI-Friendly Game Center Presentation
    
    func showGameCenter() {
        guard isAuthenticated else {
            return
        }
        
        showingGameCenter = true
    }
}

// MARK: - Supporting Types

struct LeaderboardEntry: Identifiable, Equatable {
    let id = UUID()
    let player: GKPlayer
    let score: Int
    let rank: Int
    let isLocalPlayer: Bool
    
    var displayName: String {
        return player.displayName
    }
}

// MARK: - Game Center View

struct GameCenterView: View {
    @StateObject private var gameCenterManager = GameCenterManager.shared
    @Environment(\.dismiss) private var dismiss
    
    let viewState: GKGameCenterViewControllerState
    
    init(viewState: GKGameCenterViewControllerState = .leaderboards) {
        self.viewState = viewState
    }
    
    var body: some View {
        GameCenterRepresentable(viewState: viewState)
            .ignoresSafeArea()
    }
}

// MARK: - Platform-Specific Representable

#if os(iOS)
struct GameCenterRepresentable: UIViewControllerRepresentable {
    let viewState: GKGameCenterViewControllerState
    
    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let viewController = GKGameCenterViewController(state: viewState)
        viewController.gameCenterDelegate = context.coordinator
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
#elseif os(macOS)
struct GameCenterRepresentable: NSViewControllerRepresentable {
    let viewState: GKGameCenterViewControllerState
    
    func makeNSViewController(context: Context) -> GKGameCenterViewController {
        let viewController = GKGameCenterViewController(state: viewState)
        viewController.gameCenterDelegate = context.coordinator
        return viewController
    }
    
    func updateNSViewController(_ nsViewController: GKGameCenterViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, GKGameCenterControllerDelegate {
        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(nil)
        }
    }
}
#endif

// MARK: - SwiftUI Game Center Button

struct GameCenterButton: View {
    let title: String
    let viewState: GKGameCenterViewControllerState
    @StateObject private var gameCenterManager = GameCenterManager.shared
    
    init(_ title: String, viewState: GKGameCenterViewControllerState = .leaderboards) {
        self.title = title
        self.viewState = viewState
    }
    
    var body: some View {
        Button(title) {
            gameCenterManager.showGameCenter()
        }
        .disabled(!gameCenterManager.isAuthenticated)
        .opacity(gameCenterManager.isAuthenticated ? 1.0 : 0.6)
    }
}
