import Foundation
import CoreData
import SwiftUI

// MARK: - Simple Game Sync Manager
class GameSyncManager {
    static let shared = GameSyncManager()
    
    private let maxBatchSize = 10
    private let uploadQueueKey = "pendingGameUploads"
    
    // MARK: - Queue Management
    
    func addGameToQueue(_ game: GameModel) {
        guard let gameData = createGameUploadData(from: game) else { return }
        
        var queue = getPendingQueue()
        queue.append(gameData)
        savePendingQueue(queue)
        
        // Try to upload immediately
        processPendingUploads()
    }
    
    func processPendingUploads() {
        let queue = getPendingQueue()
        guard !queue.isEmpty else { return }
        guard let token = UserState.shared.authCoordinator.getAccessToken() else { return }
        
        // Take first batch
        let batch = Array(queue.prefix(maxBatchSize))
        
        uploadBatch(batch, token: token) { [weak self] success in
            if success {
                // Remove uploaded games from queue
                var updatedQueue = self?.getPendingQueue() ?? []
                updatedQueue.removeFirst(min(batch.count, updatedQueue.count))
                self?.savePendingQueue(updatedQueue)
                
                // Process next batch if any remain
                if !updatedQueue.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.processPendingUploads()
                    }
                }
            }
        }
    }
    
    // MARK: - Network
    
    private func uploadBatch(_ games: [GameUploadData], token: String, completion: @escaping (Bool) -> Void) {
        let urlString = "\(UserState.shared.authCoordinator.baseURL)/api/games/record"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = GameBatchUpload(games: games)
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("Failed to encode games: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    print("✅ Successfully uploaded \(games.count) games")
                    completion(true)
                } else {
                    print("❌ Failed to upload games: \(error?.localizedDescription ?? "Unknown error")")
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Legacy User Migration
    
    func performInitialStatsSync(completion: @escaping (Bool) -> Void) {
        guard let token = UserState.shared.authCoordinator.getAccessToken() else {
            completion(false)
            return
        }
        
        let urlString = "\(UserState.shared.authCoordinator.baseURL)/api/user/stats"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            do {
                let stats = try JSONDecoder().decode(LegacyUserStats.self, from: data)
                
                DispatchQueue.main.async {
                    // Update UserState with legacy stats
                    self.updateLocalStats(from: stats)
                    completion(true)
                }
            } catch {
                print("Failed to decode stats: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    
    private func createGameUploadData(from game: GameModel) -> GameUploadData? {
        guard game.hasWon || game.hasLost else { return nil }
        
        return GameUploadData(
            gameId: constructBackendGameId(for: game), // Use the formatted ID
            score: game.calculateScore(),
            won: game.hasWon,
            mistakes: game.mistakes,
            timeSeconds: Int(game.lastUpdateTime.timeIntervalSince(game.startTime)),
            difficulty: game.difficulty,
            isDaily: game.gameId?.contains("daily") ?? false,
            completedAt: game.lastUpdateTime
        )
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
        }
    }
    
    private func updateLocalStats(from legacy: LegacyUserStats) {
        // Update Core Data with legacy stats
        let context = CoreDataStack.shared.mainContext
        
        // Find or create user
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", UserState.shared.userId)
        
        do {
            let users = try context.fetch(fetchRequest)
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
            
            // Update with legacy values
            stats.totalScore = Int32(legacy.totalScore)
            stats.gamesPlayed = Int32(legacy.totalGamesPlayed)
            stats.gamesWon = Int32(legacy.gamesWon)
            stats.currentStreak = Int32(legacy.currentDailyStreak)
            stats.bestStreak = Int32(legacy.bestDailyStreak)
            
            try context.save()
            
            // Refresh UserState
            UserState.shared.refreshStats()
        } catch {
            print("Error updating stats from legacy: \(error)")
        }
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

extension GameSyncManager {
    
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
//
//  GameSyncManager.swift
//  loginboy
//
//  Created by Daniel Horsley on 06/06/2025.
//

