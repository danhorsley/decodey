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
        static let totalScore = "grp.decodey.alltime"  // Your actual ID
    }
    
    private init() {
        localPlayer = GKLocalPlayer.local
        // Don't call setupAuthentication here - let the app do it
    }
    
    // MARK: - Setup authentication handler (call from app init)
    func setupAuthentication() {
        let localPlayer = GKLocalPlayer.local
        
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
                    // Successfully authenticated
                    self.isAuthenticated = true
                    self.localPlayer = localPlayer
                    self.playerDisplayName = localPlayer.displayName
                    self.isGameCenterAvailable = true
                    print("✅ Game Center authenticated: \(self.playerDisplayName)")
                    self.configureAccessPoint()
                } else if let error = error {
                    // Authentication failed
                    self.isAuthenticated = false
                    self.isGameCenterAvailable = false
                    print("❌ Game Center error: \(error.localizedDescription)")
                } else {
                    // Not authenticated and no UI to show
                    self.isAuthenticated = false
                    self.isGameCenterAvailable = true // But available to try again
                    print("⚠️ Game Center not authenticated, but available")
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
        #endif
        
        // If not authenticated, try opening Game Center settings
        if !isAuthenticated {
            #if os(iOS)
            // Open Game Center app/settings
            if let url = URL(string: "gamecenter:") {
                await UIApplication.shared.open(url)
            }
            #elseif os(macOS)
            // On macOS, the authentication handler should have shown the dialog
            print("Please sign in to Game Center via System Settings")
            #endif
        }
    }
    
    private func configureAccessPoint() {
        // Configure the Game Center access point
        GKAccessPoint.shared.location = .topTrailing
        GKAccessPoint.shared.showHighlights = true
        GKAccessPoint.shared.isActive = false // Don't show the access point overlay for now
    }
    
    // MARK: - Submit score
    func submitTotalScore(_ score: Int) async {
        guard isAuthenticated else {
            print("❌ Cannot submit score - not authenticated")
            return
        }
        
        do {
            try await GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [LeaderboardIDs.totalScore]
            )
            print("✅ Score submitted: \(score) to all-time leaderboard")
        } catch {
            print("❌ Failed to submit score: \(error.localizedDescription)")
        }
    }

    
    // MARK: - Leaderboard Data (Pure GameKit)
    
    func fetchLeaderboardScores(leaderboardID: String, scope: GKLeaderboard.PlayerScope = .global, timeScope: GKLeaderboard.TimeScope = .allTime, range: NSRange = NSRange(location: 1, length: 10)) async -> [LeaderboardEntry] {
        
        guard isAuthenticated else {
            print("❌ Cannot fetch leaderboard - not authenticated")
            return []
        }
        
        do {
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
            
            guard let leaderboard = leaderboards.first else {
                print("❌ Leaderboard not found: \(leaderboardID)")
                return []
            }
            
            let (localPlayerEntry, regularEntries, _) = try await leaderboard.loadEntries(
                for: scope,
                timeScope: timeScope,
                range: range
            )
            
            var entries: [LeaderboardEntry] = []
            
            // Add local player entry if available
            if let localEntry = localPlayerEntry {
                entries.append(LeaderboardEntry(
                    player: localEntry.player,
                    score: localEntry.score,
                    rank: localEntry.rank,
                    isLocalPlayer: true
                ))
            }
            
            // Add other entries
            for entry in regularEntries {
                entries.append(LeaderboardEntry(
                    player: entry.player,
                    score: entry.score,
                    rank: entry.rank,
                    isLocalPlayer: entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
                ))
            }
            
            return entries.sorted { $0.rank < $1.rank }
            
        } catch {
            print("❌ Failed to fetch leaderboard: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - SwiftUI-Friendly Game Center Presentation
    
    func showGameCenter() {
        guard isAuthenticated else {
            print("❌ Cannot show Game Center - not authenticated")
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

// MARK: - SwiftUI Game Center View (No Platform Code!)

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
        .sheet(isPresented: $gameCenterManager.showingGameCenter) {
            GameCenterView(viewState: viewState)
        }
    }
}

// MARK: - Game Center Authentication View

struct GameCenterAuthenticationView: View {
    @StateObject private var gameCenterManager = GameCenterManager.shared
    
    var body: some View {
        Group {
            if gameCenterManager.isAuthenticated {
                EmptyView() // Authentication successful
            } else if gameCenterManager.isGameCenterAvailable {
                VStack(spacing: 16) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Game Center Authentication")
                        .font(.headline)
                    
                    Text("Sign in to Game Center to track scores and compete with friends")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button("Sign In to Game Center") {
                        Task {
                            await gameCenterManager.authenticateLocalPlayer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    
                    Text("Game Center Unavailable")
                        .font(.headline)
                    
                    Text("Game Center is not available on this device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .task {
            await gameCenterManager.authenticateLocalPlayer()
        }
    }
}
