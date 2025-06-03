import Foundation
import CoreData
import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Game Reconciliation Manager with Detailed Logging
class GameReconciliationManager {
    static let shared = GameReconciliationManager()
    
    private let coreData = CoreDataStack.shared
    private let authCoordinator = UserState.shared.authCoordinator
    
    // MARK: - Enhanced Reconciliation with Detailed Logging
    
    /// Main reconciliation method - decides which strategy to use
    func reconcileGames(completion: @escaping (Bool, String?) -> Void) {
        print("🔄 [GameSync] Starting game reconciliation...")
        print("🔄 [GameSync] User: \(UserState.shared.userId)")
        print("🔄 [GameSync] Base URL: \(authCoordinator.baseURL)")
        
        guard let token = authCoordinator.getAccessToken() else {
            let error = "Authentication required - no access token available"
            print("❌ [GameSync] \(error)")
            completion(false, error)
            return
        }
        
        print("✅ [GameSync] Access token available (length: \(token.count))")
        
        // Get last sync timestamp
        let lastSyncKey = "lastGameSyncTimestamp"
        let lastSync = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
        
        if let lastSync = lastSync {
            print("🔄 [GameSync] Last sync: \(lastSync)")
            // Incremental sync - only games modified since last sync
            incrementalReconciliation(since: lastSync, token: token, completion: completion)
        } else {
            print("🔄 [GameSync] No previous sync found - performing full reconciliation")
            // Full reconciliation for first-time sync
            fullReconciliation(token: token, completion: completion)
        }
    }
    
    // MARK: - Full Reconciliation with Detailed Logging
    
    private func fullReconciliation(token: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔄 [GameSync] Starting FULL game reconciliation...")
        
        // Get local games summary
        let localSummary = getLocalGamesSummary()
        print("📊 [GameSync] Local summary: \(localSummary.totalGames) total, \(localSummary.completedGames) completed")
        
        if !localSummary.games.isEmpty {
            print("📊 [GameSync] Local games:")
            for (index, game) in localSummary.games.prefix(5).enumerated() {
                print("   \(index + 1). ID: \(game.gameId.prefix(8))... | Completed: \(game.isCompleted) | Score: \(game.score ?? 0)")
            }
            if localSummary.games.count > 5 {
                print("   ... and \(localSummary.games.count - 5) more")
            }
        }
        
        // Send to server and get reconciliation plan
        sendReconciliationRequest(
            type: "full",
            localSummary: localSummary,
            sinceTimestamp: nil,
            token: token
        ) { [weak self] result in
            switch result {
            case .success(let plan):
                print("✅ [GameSync] Received reconciliation plan: \(plan.summary)")
                print("📋 [GameSync] Plan details:")
                print("   - Download from server: \(plan.downloadFromServer.count) games")
                print("   - Upload to server: \(plan.uploadToServer.count) games")
                print("   - Conflicts: \(plan.conflicts.count) games")
                print("   - Delete locally: \(plan.deleteFromLocal.count) games")
                
                self?.executeReconciliationPlan(plan, token: token, completion: completion)
            case .failure(let error):
                let errorMsg = "Failed to get reconciliation plan: \(error.localizedDescription)"
                print("❌ [GameSync] \(errorMsg)")
                completion(false, errorMsg)
            }
        }
    }
    
    // MARK: - Server Communication with Detailed Logging
    
    private func sendReconciliationRequest(
        type: String,
        localSummary: LocalGamesSummary? = nil,
        localChanges: [GameChange]? = nil,
        sinceTimestamp: Date? = nil,
        token: String,
        completion: @escaping (Result<ReconciliationPlan, Error>) -> Void
    ) {
        let urlString = "\(authCoordinator.baseURL)/api/games/reconcile"
        print("🌐 [GameSync] Sending \(type) reconciliation request to: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            let error = NSError(domain: "GameSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])
            print("❌ [GameSync] Invalid URL: \(urlString)")
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        let requestBody = ReconciliationRequest(
            type: type,
            userId: UserState.shared.userId,
            sinceTimestamp: sinceTimestamp?.timeIntervalSince1970,
            localSummary: localSummary,
            localChanges: localChanges
        )
        
        print("📤 [GameSync] Request body:")
        print("   - Type: \(type)")
        print("   - User ID: \(UserState.shared.userId)")
        if let summary = localSummary {
            print("   - Local games: \(summary.totalGames)")
        }
        if let changes = localChanges {
            print("   - Local changes: \(changes.count)")
        }
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📤 [GameSync] Request JSON (first 500 chars):")
                print("   \(String(jsonString.prefix(500)))")
                if jsonString.count > 500 {
                    print("   ... (truncated)")
                }
            }
        } catch {
            print("❌ [GameSync] Failed to encode request: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        print("🌐 [GameSync] Making network request...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [GameSync] Network error: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("❌ [GameSync] Error details: Domain=\(nsError.domain), Code=\(nsError.code)")
                    print("❌ [GameSync] User info: \(nsError.userInfo)")
                }
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(domain: "GameSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
                print("❌ [GameSync] Invalid response type")
                completion(.failure(error))
                return
            }
            
            print("📥 [GameSync] Response received:")
            print("   - Status Code: \(httpResponse.statusCode)")
            print("   - Headers: \(httpResponse.allHeaderFields)")
            
            guard let data = data else {
                let error = NSError(domain: "GameSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response data"])
                print("❌ [GameSync] No response data")
                completion(.failure(error))
                return
            }
            
            print("📥 [GameSync] Response data length: \(data.count) bytes")
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 [GameSync] Response body (first 1000 chars):")
                print("   \(String(responseString.prefix(1000)))")
                if responseString.count > 1000 {
                    print("   ... (truncated)")
                }
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    let plan = try JSONDecoder().decode(ReconciliationPlan.self, from: data)
                    print("✅ [GameSync] Successfully decoded reconciliation plan")
                    completion(.success(plan))
                } catch {
                    print("❌ [GameSync] Failed to decode response: \(error.localizedDescription)")
                    if let decodingError = error as? DecodingError {
                        print("❌ [GameSync] Decoding error details: \(decodingError)")
                    }
                    completion(.failure(error))
                }
            } else {
                // Parse error response
                var errorMessage = "Server returned status \(httpResponse.statusCode)"
                
                if let responseString = String(data: data, encoding: .utf8) {
                    // Try to parse as JSON error
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let message = errorData["message"] as? String {
                            errorMessage += ": \(message)"
                        } else if let error = errorData["error"] as? String {
                            errorMessage += ": \(error)"
                        } else {
                            errorMessage += ": \(responseString)"
                        }
                    } else {
                        errorMessage += ": \(responseString)"
                    }
                }
                
                print("❌ [GameSync] Server error: \(errorMessage)")
                let error = NSError(domain: "GameSync", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Plan Execution with Detailed Logging
    
    private func executeReconciliationPlan(_ plan: ReconciliationPlan, token: String, completion: @escaping (Bool, String?) -> Void) {
        print("📋 [GameSync] Executing reconciliation plan: \(plan.summary)")
        print("📋 [GameSync] Operations to perform:")
        print("   - Downloads: \(plan.downloadFromServer.count)")
        print("   - Uploads: \(plan.uploadToServer.count)")
        print("   - Conflicts: \(plan.conflicts.count)")
        print("   - Deletions: \(plan.deleteFromLocal.count)")
        
        let group = DispatchGroup()
        var errors: [String] = []
        var successCount = 0
        
        // Download server games that are newer
        for (index, gameId) in plan.downloadFromServer.enumerated() {
            group.enter()
            print("⬇️ [GameSync] Downloading game \(index + 1)/\(plan.downloadFromServer.count): \(gameId.prefix(8))...")
            
            downloadGame(gameId: gameId, token: token) { success, error in
                if success {
                    print("✅ [GameSync] Downloaded game \(gameId.prefix(8))...")
                    successCount += 1
                } else {
                    let errorMsg = "Download \(gameId.prefix(8))...: \(error ?? "Unknown error")"
                    print("❌ [GameSync] \(errorMsg)")
                    errors.append(errorMsg)
                }
                group.leave()
            }
        }
        
        // Upload local games to server
        for (index, gameId) in plan.uploadToServer.enumerated() {
            group.enter()
            print("⬆️ [GameSync] Uploading game \(index + 1)/\(plan.uploadToServer.count): \(gameId.prefix(8))...")
            
            uploadGame(gameId: gameId, token: token) { success, error in
                if success {
                    print("✅ [GameSync] Uploaded game \(gameId.prefix(8))...")
                    successCount += 1
                } else {
                    let errorMsg = "Upload \(gameId.prefix(8))...: \(error ?? "Unknown error")"
                    print("❌ [GameSync] \(errorMsg)")
                    errors.append(errorMsg)
                }
                group.leave()
            }
        }
        
        // Handle conflicts (use server version by default)
        for (index, conflict) in plan.conflicts.enumerated() {
            group.enter()
            print("⚠️ [GameSync] Resolving conflict \(index + 1)/\(plan.conflicts.count): \(conflict.gameId.prefix(8))... (\(conflict.reason))")
            
            resolveConflict(conflict, token: token) { success, error in
                if success {
                    print("✅ [GameSync] Resolved conflict for \(conflict.gameId.prefix(8))...")
                    successCount += 1
                } else {
                    let errorMsg = "Conflict \(conflict.gameId.prefix(8))...: \(error ?? "Unknown error")"
                    print("❌ [GameSync] \(errorMsg)")
                    errors.append(errorMsg)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let totalOperations = plan.downloadFromServer.count + plan.uploadToServer.count + plan.conflicts.count
            
            if errors.isEmpty {
                // Update last sync timestamp
                UserDefaults.standard.set(Date(), forKey: "lastGameSyncTimestamp")
                print("✅ [GameSync] Game reconciliation completed successfully!")
                print("✅ [GameSync] Successfully completed \(successCount)/\(totalOperations) operations")
                completion(true, nil)
            } else {
                let errorMessage = "Reconciliation completed with \(errors.count) errors out of \(totalOperations) operations:\n" + errors.joined(separator: "\n")
                print("⚠️ [GameSync] \(errorMessage)")
                completion(false, errorMessage)
            }
        }
    }
    
    // MARK: - Individual Game Operations with Detailed Logging
    
    private func downloadGame(gameId: String, token: String, completion: @escaping (Bool, String?) -> Void) {
            let urlString = "\(authCoordinator.baseURL)/api/games/\(gameId)"
            print("⬇️ [GameSync] Downloading from: \(urlString)")
            
            guard let url = URL(string: urlString) else {
                let error = "Invalid download URL: \(urlString)"
                print("❌ [GameSync] \(error)")
                completion(false, error)
                return
            }
            
            var request = URLRequest(url: url)
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 30.0
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                if let error = error {
                    print("❌ [GameSync] Download network error for \(gameId.prefix(8))...: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = "Invalid response type for download"
                    print("❌ [GameSync] \(error)")
                    completion(false, error)
                    return
                }
                
                print("📥 [GameSync] Download response status: \(httpResponse.statusCode)")
                
                guard let data = data else {
                    let error = "No data in download response"
                    print("❌ [GameSync] \(error)")
                    completion(false, error)
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    do {
                        // Debug: Print raw JSON
                        if let jsonString = String(data: data, encoding: .utf8) {
                            print("📥 [GameSync] Raw JSON for \(gameId.prefix(8))...: \(String(jsonString.prefix(500)))")
                        }
                        
                        // Use the custom decoder that handles dates properly
                        let serverGame = try JSONDecoder.apiDecoder.decode(ServerGameData.self, from: data)
                        print("✅ [GameSync] Successfully decoded game data for \(gameId.prefix(8))...")
                        print("✅ [GameSync] Start time: \(serverGame.startTime)")
                        print("✅ [GameSync] Last update: \(serverGame.lastUpdateTime)")
                        
                        self?.saveServerGameToLocal(serverGame)
                        completion(true, nil)
                    } catch {
                        let errorMsg = "Failed to parse downloaded game data: \(error.localizedDescription)"
                        print("❌ [GameSync] \(errorMsg)")
                        
                        // Enhanced error logging for debugging
                        if let decodingError = error as? DecodingError {
                            switch decodingError {
                            case .dataCorrupted(let context):
                                print("❌ [GameSync] Data corrupted: \(context.debugDescription)")
                            case .keyNotFound(let key, let context):
                                print("❌ [GameSync] Key '\(key.stringValue)' not found: \(context.debugDescription)")
                            case .typeMismatch(let type, let context):
                                print("❌ [GameSync] Type mismatch for \(type): \(context.debugDescription)")
                            case .valueNotFound(let type, let context):
                                print("❌ [GameSync] Value not found for \(type): \(context.debugDescription)")
                            @unknown default:
                                print("❌ [GameSync] Unknown decoding error")
                            }
                        }
                        
                        completion(false, errorMsg)
                    }
                } else {
                    var errorMessage = "Download failed with status \(httpResponse.statusCode)"
                    if let responseString = String(data: data, encoding: .utf8) {
                        errorMessage += ": \(responseString)"
                    }
                    print("❌ [GameSync] \(errorMessage)")
                    completion(false, errorMessage)
                }
            }.resume()
        }
    
    private func uploadGame(gameId: String, token: String, completion: @escaping (Bool, String?) -> Void) {
        print("⬆️ [GameSync] Preparing upload for game \(gameId.prefix(8))...")
        
        // Get local game
        guard let localGame = getLocalGame(gameId: gameId) else {
            let error = "Local game not found for upload: \(gameId.prefix(8))..."
            print("❌ [GameSync] \(error)")
            completion(false, error)
            return
        }
        
        print("📊 [GameSync] Local game data for \(gameId.prefix(8))...: Won=\(localGame.hasWon), Score=\(localGame.score)")
        
        let urlString = "\(authCoordinator.baseURL)/api/games"
        guard let url = URL(string: urlString) else {
            let error = "Invalid upload URL: \(urlString)"
            print("❌ [GameSync] \(error)")
            completion(false, error)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        do {
            let jsonData = try JSONEncoder().encode(localGame)
            request.httpBody = jsonData
            
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📤 [GameSync] Upload data (first 300 chars): \(String(jsonString.prefix(300)))")
            }
        } catch {
            let errorMsg = "Failed to encode game for upload: \(error.localizedDescription)"
            print("❌ [GameSync] \(errorMsg)")
            completion(false, errorMsg)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [GameSync] Upload network error for \(gameId.prefix(8))...: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = "Invalid response type for upload"
                print("❌ [GameSync] \(error)")
                completion(false, error)
                return
            }
            
            print("📥 [GameSync] Upload response status: \(httpResponse.statusCode)")
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("📥 [GameSync] Upload response: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                print("✅ [GameSync] Successfully uploaded game \(gameId.prefix(8))...")
                completion(true, nil)
            } else {
                var errorMessage = "Upload failed with status \(httpResponse.statusCode)"
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    errorMessage += ": \(responseString)"
                }
                print("❌ [GameSync] \(errorMessage)")
                completion(false, errorMessage)
            }
        }.resume()
    }
    
    // MARK: - Rest of the methods remain the same but with added logging...
    
    private func incrementalReconciliation(since: Date, token: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔄 [GameSync] Starting INCREMENTAL game reconciliation since \(since)...")
        
        // Get local games modified since last sync
        let localChanges = getLocalChanges(since: since)
        print("📊 [GameSync] Found \(localChanges.count) local changes since last sync")
        
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
    
    // All the helper methods from the original implementation...
    // (getLocalGamesSummary, getLocalChanges, etc. - keeping these the same for brevity)
    
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
            print("❌ [GameSync] Error getting local games summary: \(error)")
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
            print("❌ [GameSync] Error getting local changes: \(error)")
            return []
        }
    }
    
    private func determineChangeType(_ game: GameCD, since: Date) -> GameChangeType {
        guard let created = game.startTime else { return .updated }
        return created > since ? .created : .updated
    }
    
    private func resolveConflict(_ conflict: GameConflict, token: String, completion: @escaping (Bool, String?) -> Void) {
        // For now, always use server version in conflicts
        print("⚠️ [GameSync] Resolving conflict by using server version for \(conflict.gameId.prefix(8))...")
        downloadGame(gameId: conflict.gameId, token: token, completion: completion)
    }
    
    // ... rest of helper methods remain the same ...
    
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
            print("❌ [GameSync] Error fetching local game: \(error)")
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
                print("✅ [GameSync] Saved server game \(serverGame.gameId.prefix(8))... to local storage")
            } catch {
                print("❌ [GameSync] Error saving server game to local: \(error)")
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

// MARK: - Data Models (same as before)
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
    let startTime: Date        // ✅ Now using Date
    let lastUpdateTime: Date   // ✅ Now using Date
    let mapping: [String: String]
    let correctMappings: [String: String]
    let guessedMappings: [String: String]
    
    // MARK: - Custom Coding (for robust date handling)
    
    enum CodingKeys: String, CodingKey {
        case gameId, userId, encrypted, solution, currentDisplay
        case mistakes, maxMistakes, hasWon, hasLost, difficulty
        case isDaily, score, timeTaken, startTime, lastUpdateTime
        case mapping, correctMappings, guessedMappings
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all the regular fields
        gameId = try container.decode(String.self, forKey: .gameId)
        userId = try container.decode(String.self, forKey: .userId)
        encrypted = try container.decode(String.self, forKey: .encrypted)
        solution = try container.decode(String.self, forKey: .solution)
        currentDisplay = try container.decode(String.self, forKey: .currentDisplay)
        mistakes = try container.decode(Int.self, forKey: .mistakes)
        maxMistakes = try container.decode(Int.self, forKey: .maxMistakes)
        hasWon = try container.decode(Bool.self, forKey: .hasWon)
        hasLost = try container.decode(Bool.self, forKey: .hasLost)
        difficulty = try container.decode(String.self, forKey: .difficulty)
        isDaily = try container.decode(Bool.self, forKey: .isDaily)
        score = try container.decode(Int.self, forKey: .score)
        timeTaken = try container.decode(Int.self, forKey: .timeTaken)
        mapping = try container.decode([String: String].self, forKey: .mapping)
        correctMappings = try container.decode([String: String].self, forKey: .correctMappings)
        guessedMappings = try container.decode([String: String].self, forKey: .guessedMappings)
        
        // Custom date decoding with detailed error handling
        let startTimeString = try container.decode(String.self, forKey: .startTime)
        guard let parsedStartTime = APIDateFormatter.shared.date(from: startTimeString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .startTime,
                in: container,
                debugDescription: "Cannot decode startTime from: '\(startTimeString)'"
            )
        }
        startTime = parsedStartTime
        
        let lastUpdateString = try container.decode(String.self, forKey: .lastUpdateTime)
        guard let parsedUpdateTime = APIDateFormatter.shared.date(from: lastUpdateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .lastUpdateTime,
                in: container,
                debugDescription: "Cannot decode lastUpdateTime from: '\(lastUpdateString)'"
            )
        }
        lastUpdateTime = parsedUpdateTime
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Encode all regular fields
        try container.encode(gameId, forKey: .gameId)
        try container.encode(userId, forKey: .userId)
        try container.encode(encrypted, forKey: .encrypted)
        try container.encode(solution, forKey: .solution)
        try container.encode(currentDisplay, forKey: .currentDisplay)
        try container.encode(mistakes, forKey: .mistakes)
        try container.encode(maxMistakes, forKey: .maxMistakes)
        try container.encode(hasWon, forKey: .hasWon)
        try container.encode(hasLost, forKey: .hasLost)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(isDaily, forKey: .isDaily)
        try container.encode(score, forKey: .score)
        try container.encode(timeTaken, forKey: .timeTaken)
        try container.encode(mapping, forKey: .mapping)
        try container.encode(correctMappings, forKey: .correctMappings)
        try container.encode(guessedMappings, forKey: .guessedMappings)
        
        // Custom date encoding
        try container.encode(APIDateFormatter.shared.string(from: startTime), forKey: .startTime)
        try container.encode(APIDateFormatter.shared.string(from: lastUpdateTime), forKey: .lastUpdateTime)
    }
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
    
    #if os(iOS)
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif
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
    
    // Changed from private to internal so it can be accessed
    func loadLastSyncDate() {
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


