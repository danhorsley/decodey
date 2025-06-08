import Foundation
import CoreData
import SwiftUI

// MARK: - Enhanced Game Sync Manager with Detailed Logging
class GameSyncManager {
    static let shared = GameSyncManager()
    
    private let maxBatchSize = 10
    private let uploadQueueKey = "pendingGameUploads"
    
    // MARK: - Queue Management
    
    func addGameToQueue(_ game: GameModel) {
        print("🎮 [GameSync] Attempting to add game to queue")
        print("   Game ID: \(game.gameId ?? "nil")")
        print("   Has Won: \(game.hasWon)")
        print("   Has Lost: \(game.hasLost)")
        print("   Score: \(game.calculateScore())")
        
        guard let gameData = createGameUploadData(from: game) else {
            print("❌ [GameSync] Failed to create upload data for game")
            return
        }
        
        var queue = getPendingQueue()
        queue.append(gameData)
        savePendingQueue(queue)
        
        print("✅ [GameSync] Game added to queue. Queue size: \(queue.count)")
        
        // Try to upload immediately
        processPendingUploads()
    }
    
    func processPendingUploads() {
        let queue = getPendingQueue()
        print("📤 [GameSync] Processing pending uploads. Queue size: \(queue.count)")
        
        guard !queue.isEmpty else {
            print("ℹ️ [GameSync] No pending uploads")
            return
        }
        
        guard let token = UserState.shared.authCoordinator.getAccessToken() else {
            print("❌ [GameSync] No auth token available")
            return
        }
        
        // Take first batch
        let batch = Array(queue.prefix(maxBatchSize))
        print("📦 [GameSync] Processing batch of \(batch.count) games")
        
        uploadBatch(batch, token: token) { [weak self] success in
            if success {
                // Remove uploaded games from queue
                var updatedQueue = self?.getPendingQueue() ?? []
                updatedQueue.removeFirst(min(batch.count, updatedQueue.count))
                self?.savePendingQueue(updatedQueue)
                
                print("✅ [GameSync] Batch upload successful. Remaining: \(updatedQueue.count)")
                
                // Process next batch if any remain
                if !updatedQueue.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.processPendingUploads()
                    }
                }
            } else {
                print("❌ [GameSync] Batch upload failed")
            }
        }
    }
    
    // MARK: - Network
    
    private func uploadBatch(_ games: [GameUploadData], token: String, completion: @escaping (Bool) -> Void) {
        let urlString = "\(UserState.shared.authCoordinator.baseURL)/api/games/record"
        print("🌐 [GameSync] Uploading to: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ [GameSync] Invalid URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = GameBatchUpload(games: games)
        
        do {
            let jsonData = try JSONEncoder().encode(payload)
            request.httpBody = jsonData
            
            // Log the payload
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📋 [GameSync] Payload: \(jsonString)")
            }
        } catch {
            print("❌ [GameSync] Failed to encode games: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [GameSync] Network error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 [GameSync] Response status: \(httpResponse.statusCode)")
                    
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("📋 [GameSync] Response body: \(responseString)")
                    }
                    
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                        print("✅ [GameSync] Successfully uploaded \(games.count) games")
                        completion(true)
                    } else {
                        print("❌ [GameSync] Server returned error status: \(httpResponse.statusCode)")
                        completion(false)
                    }
                } else {
                    print("❌ [GameSync] Invalid response")
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Legacy User Migration with Enhanced Logging
    
    func performInitialStatsSync(completion: @escaping (Bool) -> Void) {
        print("🔄 [GameSync] Starting initial stats sync")
        
        guard let token = UserState.shared.authCoordinator.getAccessToken() else {
            print("❌ [GameSync] No auth token for stats sync")
            completion(false)
            return
        }
        
        let urlString = "\(UserState.shared.authCoordinator.baseURL)/api/user/stats"
        print("🌐 [GameSync] Fetching stats from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ [GameSync] Invalid stats URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [GameSync] Stats network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            guard let data = data else {
                print("❌ [GameSync] No data received for stats")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [GameSync] Stats response status: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📋 [GameSync] Stats response: \(responseString)")
                }
                
                if httpResponse.statusCode != 200 {
                    print("❌ [GameSync] Stats server error: \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
            }
            
            do {
                // First try the expected format
                let decoder = JSONDecoder()
                
                // Try to decode as the Python model structure
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📊 [GameSync] Raw stats JSON: \(json)")
                    
                    // Process the stats based on your Python model
                    DispatchQueue.main.async {
                        self.processRawStatsResponse(json)
                        completion(true)
                    }
                } else {
                    // Fallback to structured decoding
                    let stats = try decoder.decode(UserStatsResponse.self, from: data)
                    print("✅ [GameSync] Decoded stats successfully")
                    
                    DispatchQueue.main.async {
                        self.updateLocalStats(from: stats)
                        completion(true)
                    }
                }
            } catch {
                print("❌ [GameSync] Failed to decode stats: \(error)")
                print("   Error details: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // Process raw JSON response based on Python model
    private func processRawStatsResponse(_ json: [String: Any]) {
        print("🔧 [GameSync] Processing raw stats response")
        
        // Extract values from the Python response format
        let totalScore = json["cumulative_score"] as? Int ?? 0
        let totalGamesPlayed = json["total_games_played"] as? Int ?? 0
        let gamesWon = json["games_won"] as? Int ?? 0
        let currentStreak = json["current_streak"] as? Int ?? 0
        let maxStreak = json["max_streak"] as? Int ?? 0
        let currentDailyStreak = json["current_daily_streak"] as? Int ?? 0
        let maxDailyStreak = json["max_daily_streak"] as? Int ?? 0
        
        print("📊 Stats extracted:")
        print("   Total Score: \(totalScore)")
        print("   Games Played: \(totalGamesPlayed)")
        print("   Games Won: \(gamesWon)")
        print("   Current Streak: \(currentStreak)")
        print("   Max Streak: \(maxStreak)")
        
        // Update Core Data
        updateCoreDataStats(
            totalScore: totalScore,
            gamesPlayed: totalGamesPlayed,
            gamesWon: gamesWon,
            currentStreak: currentDailyStreak > 0 ? currentDailyStreak : currentStreak,
            bestStreak: maxDailyStreak > 0 ? maxDailyStreak : maxStreak
        )
    }
    
    private func updateCoreDataStats(totalScore: Int, gamesPlayed: Int, gamesWon: Int, currentStreak: Int, bestStreak: Int) {
        print("💾 [GameSync] Updating Core Data with server stats")
        
        let context = CoreDataStack.shared.mainContext
        
        // Find or create user
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", UserState.shared.userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first else {
                print("❌ [GameSync] User not found in Core Data")
                return
            }
            
            // Get or create stats
            let stats: UserStatsCD
            if let existingStats = user.stats {
                stats = existingStats
                print("📊 [GameSync] Updating existing stats")
            } else {
                stats = UserStatsCD(context: context)
                user.stats = stats
                stats.user = user
                print("📊 [GameSync] Creating new stats object")
            }
            
            // Log current vs new values
            print("📊 Current local stats:")
            print("   Games Played: \(stats.gamesPlayed) → \(gamesPlayed)")
            print("   Games Won: \(stats.gamesWon) → \(gamesWon)")
            print("   Total Score: \(stats.totalScore) → \(totalScore)")
            print("   Current Streak: \(stats.currentStreak) → \(currentStreak)")
            print("   Best Streak: \(stats.bestStreak) → \(bestStreak)")
            
            // Update with server values
            stats.totalScore = Int32(totalScore)
            stats.gamesPlayed = Int32(gamesPlayed)
            stats.gamesWon = Int32(gamesWon)
            stats.currentStreak = Int32(currentStreak)
            stats.bestStreak = Int32(bestStreak)
            stats.lastPlayedDate = Date()
            
            // Calculate averages
            if gamesPlayed > 0 {
                stats.averageTime = 180.0 // Default 3 minutes if not provided
                stats.averageMistakes = 2.0 // Default if not provided
            }
            
            try context.save()
            print("✅ [GameSync] Core Data stats updated successfully")
            
            // Refresh UserState
            UserState.shared.refreshStats()
        } catch {
            print("❌ [GameSync] Error updating stats in Core Data: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createGameUploadData(from game: GameModel) -> GameUploadData? {
        guard game.hasWon || game.hasLost else {
            print("⚠️ [GameSync] Game not completed, skipping upload")
            return nil
        }
        
        let gameId = constructBackendGameId(for: game)
        let uploadData = GameUploadData(
            gameId: gameId,
            score: game.calculateScore(),
            won: game.hasWon,
            mistakes: game.mistakes,
            timeSeconds: Int(game.lastUpdateTime.timeIntervalSince(game.startTime)),
            difficulty: game.difficulty,
            isDaily: game.gameId?.contains("daily") ?? false,
            completedAt: game.lastUpdateTime
        )
        
        print("📦 [GameSync] Created upload data:")
        print("   Game ID: \(gameId)")
        print("   Score: \(uploadData.score)")
        print("   Won: \(uploadData.won)")
        print("   Time: \(uploadData.timeSeconds)s")
        
        return uploadData
    }
    
    func getPendingQueue() -> [GameUploadData] {
        guard let data = UserDefaults.standard.data(forKey: uploadQueueKey),
              let queue = try? JSONDecoder().decode([GameUploadData].self, from: data) else {
            return []
        }
        return queue
    }
    
    private func savePendingQueue(_ queue: [GameUploadData]) {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: uploadQueueKey)
            print("💾 [GameSync] Saved queue with \(queue.count) items")
        }
    }
    
    private func updateLocalStats(from legacy: UserStatsResponse) {
        updateCoreDataStats(
            totalScore: legacy.totalScore,
            gamesPlayed: legacy.totalGamesPlayed,
            gamesWon: legacy.gamesWon,
            currentStreak: legacy.currentDailyStreak,
            bestStreak: legacy.bestDailyStreak
        )
    }
    
    /// Constructs the backend-compatible game ID format
    private func constructBackendGameId(for game: GameModel) -> String {
        // Generate a UUID if the game doesn't have one
        let uuid = game.gameId ?? UUID().uuidString
        
        if game.gameId?.contains("daily") == true {
            // Daily games: easy-daily-2025-04-19-[UUID]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: game.startTime)
            return "easy-daily-\(dateString)-\(uuid.lowercased())"
        } else {
            // Regular games: difficulty-[UUID]
            let difficulty = game.difficulty.lowercased()
            return "\(difficulty)-\(uuid.lowercased())"
        }
    }
}

// MARK: - Response Models

struct UserStatsResponse: Codable {
    let totalScore: Int
    let totalGamesPlayed: Int
    let gamesWon: Int
    let currentDailyStreak: Int
    let bestDailyStreak: Int
    let lastDailyCompleted: String?
    
    enum CodingKeys: String, CodingKey {
        case totalScore = "cumulative_score"
        case totalGamesPlayed = "total_games_played"
        case gamesWon = "games_won"
        case currentDailyStreak = "current_daily_streak"
        case bestDailyStreak = "max_daily_streak"
        case lastDailyCompleted = "last_daily_completed"
    }
}

// MARK: - Data Models

struct GameUploadData: Codable {
    let gameId: String
    let score: Int
    let won: Bool
    let mistakes: Int
    let timeSeconds: Int
    let difficulty: String
    let isDaily: Bool
    let completedAt: Date
}

struct GameBatchUpload: Codable {
    let games: [GameUploadData]
}

struct LegacyUserStats: Codable {
    let totalScore: Int
    let totalGamesPlayed: Int
    let gamesWon: Int
    let currentDailyStreak: Int
    let bestDailyStreak: Int
    let lastDailyCompleted: String?
}

// MARK: - UI Component for Sync Status

struct SyncStatusIndicator: View {
    @State private var pendingCount = 0
    @State private var timer: Timer?
    
    var body: some View {
        HStack {
            Image(systemName: pendingCount > 0 ? "icloud.and.arrow.up" : "icloud.fill")
                .foregroundColor(pendingCount > 0 ? .orange : .green)
            
            if pendingCount > 0 {
                Text("\(pendingCount) pending")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Text("Synced")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .onAppear {
            updateCount()
            // Check every 5 seconds
            timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                updateCount()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func updateCount() {
        pendingCount = GameSyncManager.shared.getPendingQueue().count
    }
}


//
//  GameSyncManager.swift
//  loginboy
//
//  Created by Daniel Horsley on 06/06/2025.
//

