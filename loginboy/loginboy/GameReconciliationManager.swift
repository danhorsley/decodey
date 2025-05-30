import Foundation
import CoreData

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

//
//  GameReconciliationManager.swift
//  loginboy
//
//  Created by Daniel Horsley on 26/05/2025.
//

