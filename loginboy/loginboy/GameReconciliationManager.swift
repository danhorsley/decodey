import Foundation
import CoreData
import SwiftUI

// MARK: - Game Reconciliation Manager
class GameReconciliationManager {
    static let shared = GameReconciliationManager()
    
    private let coreData = CoreDataStack.shared
    private let authCoordinator = UserState.shared.authCoordinator
    
    // MARK: - Reconciliation Strategy
    
    /// Main reconciliation method - decides which strategy to use
    func reconcileGames(completion: @escaping (Bool, String?) -> Void) {
        guard let token = authCoordinator.getAccessToken() else {
            completion(false, "Authentication required")
            return
        }
        
        // Get last sync timestamp
        let lastSyncKey = "lastGameSyncTimestamp"
        let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        
        if let lastSync = lastSync {
            // Incremental sync - only games modified since last sync
            incrementalReconciliation(since: lastSync, token: token, completion: completion)
        } else {
            // Full reconciliation for first-time sync
            fullReconciliation(token: token, completion: completion)
        }
    }
    
    // MARK: - Full Reconciliation (First Time)
    
    private func fullReconciliation(token: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔄 Starting full game reconciliation...")
        
        // Get local games summary
        let localSummary = getLocalGamesSummary()
        
        // Send to server and get reconciliation plan
        sendReconciliationRequest(
            type: "full",
            localSummary: localSummary,
            sinceTimestamp: nil,
            token: token
        ) { [weak self] result in
            switch result {
            case .success(let plan):
                self?.executeReconciliationPlan(plan, token: token, completion: completion)
            case .failure(let error):
                completion(false, error.localizedDescription)
            }
        }
    }
    
    // MARK: - Incremental Reconciliation
    
    private func incrementalReconciliation(since: Date, token: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔄 Starting incremental game reconciliation since \(since)...")
        
        // Get local games modified since last sync
        let localChanges = getLocalChanges(since: since)
        
        sendReconciliationRequest(
            type: "incremental",
            localSummary: nil,
            localChanges: localChanges,
            sinceTimestamp: since,
            token: token
        ) { [weak self] result in
            switch result {
            case .success(let plan):
                self?.executeReconciliationPlan(plan, token: token, completion: completion)
            case .failure(let error):
                completion(false, error.localizedDescription)
            }
        }
    }
    
    // MARK: - Local Data Collection
    
    private func getLocalGamesSummary() -> LocalGamesSummary {
        let context = coreData.mainContext
        
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        fetchRequest.predicate = NSPredicate(format: "user.userId == %@", UserState.shared.userId)
        
        do {
            let games = try context.fetch(fetchRequest)
            
            let summaries = games.compactMap { game -> GameSummary? in
                guard let gameId = game.gameId?.uuidString,
                      let lastUpdate = game.lastUpdateTime else { return nil }
                
                return GameSummary(
                    gameId: gameId,
                    lastModified: lastUpdate,
                    isCompleted: game.hasWon || game.hasLost,
                    score: game.hasWon || game.hasLost ? Int(game.score) : nil,
                    checksum: generateGameChecksum(game)
                )
            }
            
            return LocalGamesSummary(
                totalGames: summaries.count,
                completedGames: summaries.filter { $0.isCompleted }.count,
                lastModified: summaries.map { $0.lastModified }.max(),
                games: summaries
            )
        } catch {
            print("Error getting local games summary: \(error)")
            return LocalGamesSummary(totalGames: 0, completedGames: 0, lastModified: nil, games: [])
        }
    }
    
    private func getLocalChanges(since: Date) -> [GameChange] {
        let context = coreData.mainContext
        
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        fetchRequest.predicate = NSPredicate(format: "user.userId == %@ AND lastUpdateTime > %@",
                                           UserState.shared.userId, since as NSDate)
        
        do {
            let games = try context.fetch(fetchRequest)
            
            return games.compactMap { game -> GameChange? in
                guard let gameId = game.gameId?.uuidString,
                      let lastUpdate = game.lastUpdateTime else { return nil }
                
                return GameChange(
                    gameId: gameId,
                    changeType: determineChangeType(game, since: since),
                    lastModified: lastUpdate,
                    data: game.hasWon || game.hasLost ? convertToGameData(game) : nil
                )
            }
        } catch {
            print("Error getting local changes: \(error)")
            return []
        }
    }
    
    private func determineChangeType(_ game: GameCD, since: Date) -> GameChangeType {
        guard let created = game.startTime else { return .updated }
        return created > since ? .created : .updated
    }
    
    // MARK: - Server Communication
    
    private func sendReconciliationRequest(
        type: String,
        localSummary: LocalGamesSummary? = nil,
        localChanges: [GameChange]? = nil,
        sinceTimestamp: Date? = nil,
        token: String,
        completion: @escaping (Result<ReconciliationPlan, Error>) -> Void
    ) {
        guard let url = URL(string: "\(authCoordinator.baseURL)/api/games/reconcile") else {
            completion(.failure(NSError(domain: "GameSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ReconciliationRequest(
            type: type,
            userId: UserState.shared.userId,
            sinceTimestamp: sinceTimestamp?.timeIntervalSince1970,
            localSummary: localSummary,
            localChanges: localChanges
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(.failure(NSError(domain: "GameSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server error"])))
                return
            }
            
            do {
                let plan = try JSONDecoder().decode(ReconciliationPlan.self, from: data)
                completion(.success(plan))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Plan Execution
    
    private func executeReconciliationPlan(_ plan: ReconciliationPlan, token: String, completion: @escaping (Bool, String?) -> Void) {
        print("📋 Executing reconciliation plan: \(plan.summary)")
        
        let group = DispatchGroup()
        var errors: [String] = []
        
        // Download server games that are newer
        for gameId in plan.downloadFromServer {
            group.enter()
            downloadGame(gameId: gameId, token: token) { success, error in
                if !success, let error = error {
                    errors.append("Download \(gameId): \(error)")
                }
                group.leave()
            }
        }
        
        // Upload local games to server
        for gameId in plan.uploadToServer {
            group.enter()
            uploadGame(gameId: gameId, token: token) { success, error in
                if !success, let error = error {
                    errors.append("Upload \(gameId): \(error)")
                }
                group.leave()
            }
        }
        
        // Handle conflicts (use server version by default)
        for conflict in plan.conflicts {
            group.enter()
            resolveConflict(conflict, token: token) { success, error in
                if !success, let error = error {
                    errors.append("Conflict \(conflict.gameId): \(error)")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if errors.isEmpty {
                // Update last sync timestamp
                UserDefaults.standard.set(Date(), forKey: "lastGameSyncTimestamp")
                print("✅ Game reconciliation completed successfully")
                completion(true, nil)
            } else {
                let errorMessage = "Reconciliation completed with errors: \(errors.joined(separator: ", "))"
                print("⚠️ \(errorMessage)")
                completion(false, errorMessage)
            }
        }
    }
    
    // MARK: - Individual Game Operations
    
    private func downloadGame(gameId: String, token: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(authCoordinator.baseURL)/api/games/\(gameId)") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                completion(false, "Server error")
                return
            }
            
            do {
                let serverGame = try JSONDecoder().decode(ServerGameData.self, from: data)
                self?.saveServerGameToLocal(serverGame)
                completion(true, nil)
            } catch {
                completion(false, "Failed to parse game data: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    private func uploadGame(gameId: String, token: String, completion: @escaping (Bool, String?) -> Void) {
        // Get local game
        guard let localGame = getLocalGame(gameId: gameId) else {
            completion(false, "Local game not found")
            return
        }
        
        guard let url = URL(string: "\(authCoordinator.baseURL)/api/games") else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(localGame)
        } catch {
            completion(false, "Failed to encode game: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                completion(false, "Server error")
                return
            }
            
            completion(true, nil)
        }.resume()
    }
    
    private func resolveConflict(_ conflict: GameConflict, token: String, completion: @escaping (Bool, String?) -> Void) {
        // For now, always use server version in conflicts
        downloadGame(gameId: conflict.gameId, token: token, completion: completion)
    }
    
    // MARK: - Helper Methods
    
    private func generateGameChecksum(_ game: GameCD) -> String {
        let content = "\(game.gameId?.uuidString ?? "")\(game.lastUpdateTime?.timeIntervalSince1970 ?? 0)\(game.hasWon)\(game.hasLost)\(game.score)"
        return content.data(using: .utf8)?.base64EncodedString() ?? ""
    }
    
    private func convertToGameData(_ game: GameCD) -> ServerGameData {
        return ServerGameData(
            gameId: game.gameId?.uuidString ?? "",
            userId: UserState.shared.userId,
            encrypted: game.encrypted ?? "",
            solution: game.solution ?? "",
            currentDisplay: game.currentDisplay ?? "",
            mistakes: Int(game.mistakes),
            maxMistakes: Int(game.maxMistakes),
            hasWon: game.hasWon,
            hasLost: game.hasLost,
            difficulty: game.difficulty ?? "medium",
            isDaily: game.isDaily,
            score: Int(game.score),
            timeTaken: Int(game.timeTaken),
            startTime: game.startTime ?? Date(),
            lastUpdateTime: game.lastUpdateTime ?? Date(),
            mapping: decodeMapping(game.mapping),
            correctMappings: decodeMapping(game.correctMappings),
            guessedMappings: decodeMapping(game.guessedMappings)
        )
    }
    
    private func getLocalGame(gameId: String) -> ServerGameData? {
        let context = coreData.mainContext
        
        guard let gameUUID = UUID(uuidString: gameId) else { return nil }
        
        let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
        fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameUUID as CVarArg)
        
        do {
            let games = try context.fetch(fetchRequest)
            guard let game = games.first else { return nil }
            return convertToGameData(game)
        } catch {
            print("Error fetching local game: \(error)")
            return nil
        }
    }
    
    private func saveServerGameToLocal(_ serverGame: ServerGameData) {
        let context = coreData.newBackgroundContext()
        
        context.perform {
            guard let gameUUID = UUID(uuidString: serverGame.gameId) else { return }
            
            // Check if game already exists
            let fetchRequest = NSFetchRequest<GameCD>(entityName: "GameCD")
            fetchRequest.predicate = NSPredicate(format: "gameId == %@", gameUUID as CVarArg)
            
            do {
                let existingGames = try context.fetch(fetchRequest)
                let game = existingGames.first ?? GameCD(context: context)
                
                // Update game properties
                game.gameId = gameUUID
                game.encrypted = serverGame.encrypted
                game.solution = serverGame.solution
                game.currentDisplay = serverGame.currentDisplay
                game.mistakes = Int16(serverGame.mistakes)
                game.maxMistakes = Int16(serverGame.maxMistakes)
                game.hasWon = serverGame.hasWon
                game.hasLost = serverGame.hasLost
                game.difficulty = serverGame.difficulty
                game.isDaily = serverGame.isDaily
                game.score = Int32(serverGame.score)
                game.timeTaken = Int32(serverGame.timeTaken)
                game.startTime = serverGame.startTime
                game.lastUpdateTime = serverGame.lastUpdateTime
                
                // Encode mappings
                game.mapping = try? JSONEncoder().encode(serverGame.mapping)
                game.correctMappings = try? JSONEncoder().encode(serverGame.correctMappings)
                game.guessedMappings = try? JSONEncoder().encode(serverGame.guessedMappings)
                
                // Set user relationship
                let userFetchRequest = NSFetchRequest<UserCD>(entityName: "UserCD")
                userFetchRequest.predicate = NSPredicate(format: "userId == %@", serverGame.userId)
                
                if let users = try? context.fetch(userFetchRequest), let user = users.first {
                    game.user = user
                }
                
                try context.save()
            } catch {
                print("Error saving server game to local: \(error)")
            }
        }
    }
    
    private func decodeMapping(_ data: Data?) -> [String: String] {
        guard let data = data,
              let mapping = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return mapping
    }
}

// MARK: - Data Models

struct ReconciliationRequest: Codable {
    let type: String // "full" or "incremental"
    let userId: String
    let sinceTimestamp: Double?
    let localSummary: LocalGamesSummary?
    let localChanges: [GameChange]?
}

struct LocalGamesSummary: Codable {
    let totalGames: Int
    let completedGames: Int
    let lastModified: Date?
    let games: [GameSummary]
}

struct GameSummary: Codable {
    let gameId: String
    let lastModified: Date
    let isCompleted: Bool
    let score: Int?
    let checksum: String
}

struct GameChange: Codable {
    let gameId: String
    let changeType: GameChangeType
    let lastModified: Date
    let data: ServerGameData? // Full data for completed games
}

enum GameChangeType: String, Codable {
    case created
    case updated
    case deleted
}

struct ReconciliationPlan: Codable {
    let summary: String
    let downloadFromServer: [String] // Game IDs to download
    let uploadToServer: [String] // Game IDs to upload
    let conflicts: [GameConflict] // Games with conflicts
    let deleteFromLocal: [String] // Game IDs to delete locally
}

struct GameConflict: Codable {
    let gameId: String
    let reason: String
    let localTimestamp: Date
    let serverTimestamp: Date
}

struct ServerGameData: Codable {
    let gameId: String
    let userId: String
    let encrypted: String
    let solution: String
    let currentDisplay: String
    let mistakes: Int
    let maxMistakes: Int
    let hasWon: Bool
    let hasLost: Bool
    let difficulty: String
    let isDaily: Bool
    let score: Int
    let timeTaken: Int
    let startTime: Date
    let lastUpdateTime: Date
    let mapping: [String: String]
    let correctMappings: [String: String]
    let guessedMappings: [String: String]
}


extension GameReconciliationManager {
    
    /// Enhanced reconciliation with intelligent timing
    func smartReconcileGames(trigger: ReconciliationTrigger, completion: @escaping (Bool, String?) -> Void) {
        guard let token = authCoordinator.getAccessToken() else {
            completion(false, "Authentication required")
            return
        }
        
        let strategy = determineReconciliationStrategy(for: trigger)
        
        switch strategy {
        case .skip(let reason):
            print("🔄 Skipping reconciliation: \(reason)")
            completion(true, nil)
            
        case .incremental:
            performIncrementalReconciliation(token: token, completion: completion)
            
        case .full:
            performFullReconciliation(token: token, completion: completion)
            
        case .deferred(let delay):
            print("🔄 Deferring reconciliation for \(delay) seconds")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.performIncrementalReconciliation(token: token, completion: completion)
            }
        }
    }
    
    private func determineReconciliationStrategy(for trigger: ReconciliationTrigger) -> ReconciliationStrategy {
        let lastSyncKey = "lastGameSyncTimestamp"
        let lastFullSyncKey = "lastFullGameSync"
        let appLaunchCountKey = "appLaunchCount"
        
        let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        let lastFullSync = UserDefaults.standard.object(forKey: lastFullSyncKey) as? Date
        let launchCount = UserDefaults.standard.integer(forKey: appLaunchCountKey)
        
        let now = Date()
        
        switch trigger {
        case .appLaunch:
            // Increment launch count
            UserDefaults.standard.set(launchCount + 1, forKey: appLaunchCountKey)
            
            // Full sync on first launch or every 10th launch
            if lastFullSync == nil || launchCount % 10 == 0 {
                return .full
            }
            
            // Skip if synced recently (within 30 minutes)
            if let lastSync = lastSync, now.timeIntervalSince(lastSync) < 1800 {
                return .skip("Recently synced")
            }
            
            // Defer sync for 3 seconds to let UI settle
            return .deferred(3.0)
            
        case .userLogin:
            // Always sync on login, but defer to let auth complete
            if let lastSync = lastSync, now.timeIntervalSince(lastSync) < 300 {
                return .deferred(2.0) // Short delay if recent sync
            } else {
                return .deferred(5.0) // Longer delay for full sync
            }
            
        case .gameCompletion:
            // Quick incremental sync after game completion
            if let lastSync = lastSync, now.timeIntervalSince(lastSync) < 60 {
                return .skip("Very recent sync")
            }
            return .incremental
            
        case .manual:
            // Always honor manual sync requests
            if let lastSync = lastSync, now.timeIntervalSince(lastSync) < 60 {
                return .incremental
            } else {
                return .full
            }
            
        case .background:
            // Background sync only if it's been a while
            if let lastSync = lastSync, now.timeIntervalSince(lastSync) < 3600 {
                return .skip("Recent background sync")
            }
            return .incremental
        }
    }
    
    private func performFullReconciliation(token: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔄 Starting FULL game reconciliation...")
        
        fullReconciliation(token: token) { [weak self] success, error in
            if success {
                UserDefaults.standard.set(Date(), forKey: "lastFullGameSync")
                print("✅ Full reconciliation completed")
            }
            completion(success, error)
        }
    }
    
    private func performIncrementalReconciliation(token: String, completion: @escaping (Bool, String?) -> Void) {
        let lastSyncKey = "lastGameSyncTimestamp"
        let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date ?? Date.distantPast
        
        print("🔄 Starting INCREMENTAL game reconciliation since \(lastSync)...")
        
        incrementalReconciliation(since: lastSync, token: token, completion: completion)
    }
}

// MARK: - Reconciliation Types

enum ReconciliationTrigger {
    case appLaunch
    case userLogin
    case gameCompletion
    case manual
    case background
}

enum ReconciliationStrategy {
    case skip(String)
    case incremental
    case full
    case deferred(TimeInterval)
}

// MARK: - Background Sync Manager

class BackgroundSyncManager {
    static let shared = BackgroundSyncManager()
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let syncInterval: TimeInterval = 300 // 5 minutes
    
    func startBackgroundSync() {
        #if os(iOS)
        // Register for background app refresh
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }
    
    #if os(iOS)
    @objc private func appDidEnterBackground() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Perform a quick sync before going to background
        GameReconciliationManager.shared.smartReconcileGames(trigger: .background) { [weak self] _, _ in
            self?.endBackgroundTask()
        }
    }
    
    @objc private func appWillEnterForeground() {
        endBackgroundTask()
        
        // Sync when coming back to foreground
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            GameReconciliationManager.shared.smartReconcileGames(trigger: .appLaunch) { _, _ in
                // Update UI if needed
            }
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    #endif
}

// MARK: - Smart Sync Status Indicator

struct SmartSyncStatusView: View {
    @StateObject private var syncMonitor = SmartSyncMonitor()
    
    var body: some View {
        HStack(spacing: 8) {
            // Connection status
            Circle()
                .fill(syncMonitor.connectionStatus.color)
                .frame(width: 8, height: 8)
            
            // Sync status text
            Text(syncMonitor.statusText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Progress indicator when syncing
            if syncMonitor.isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .onTapGesture {
            syncMonitor.showDetails = true
        }
        .sheet(isPresented: $syncMonitor.showDetails) {
            SyncDetailsView(monitor: syncMonitor)
        }
    }
}

class SmartSyncMonitor: ObservableObject {
    @Published var isSyncing = false
    @Published var connectionStatus: ConnectionStatus = .unknown
    @Published var lastSyncDate: Date?
    @Published var showDetails = false
    @Published var syncProgress: Double = 0.0
    
    enum ConnectionStatus {
        case online, offline, syncing, unknown
        
        var color: Color {
            switch self {
            case .online: return .green
            case .offline: return .red
            case .syncing: return .blue
            case .unknown: return .gray
            }
        }
    }
    
    var statusText: String {
        if isSyncing {
            return "Syncing..."
        } else if let lastSync = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            return formatter.localizedString(for: lastSync, relativeTo: Date())
        } else {
            return "Never synced"
        }
    }
    
    init() {
        loadLastSyncDate()
        checkConnectionStatus()
    }
    
    private func loadLastSyncDate() {
        lastSyncDate = UserDefaults.standard.object(forKey: "lastGameSyncTimestamp") as? Date
    }
    
    private func checkConnectionStatus() {
        // Simple connectivity check
        connectionStatus = .unknown
        // Implement actual connectivity check here
    }
}

struct SyncDetailsView: View {
    @ObservedObject var monitor: SmartSyncMonitor
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sync Details")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Manual sync button
                    Button(action: {
                        GameReconciliationManager.shared.smartReconcileGames(trigger: .manual) { _, _ in
                            monitor.loadLastSyncDate()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Sync Now")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(monitor.isSyncing)
                    
                    // Sync statistics
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sync Statistics")
                            .font(.headline)
                        
                        if let lastSync = monitor.lastSyncDate {
                            Text("Last sync: \(lastSync, style: .relative)")
                        } else {
                            Text("Never synced")
                        }
                        
                        Text("Connection: \(monitor.connectionStatus)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding()
            }
        }
    }
}

extension SmartSyncMonitor.ConnectionStatus: CustomStringConvertible {
    var description: String {
        switch self {
        case .online: return "Online"
        case .offline: return "Offline"
        case .syncing: return "Syncing"
        case .unknown: return "Unknown"
        }
    }
}
//
//  GameReconciliationManager.swift
//  loginboy
//
//  Created by Daniel Horsley on 26/05/2025.
//

