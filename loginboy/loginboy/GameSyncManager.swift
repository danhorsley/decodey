import Foundation
import CoreData
import SwiftUI

/// Handles uploading completed games to the backend for leaderboards
class GameSyncManager {
    static let shared = GameSyncManager()
    
    private let uploadQueueKey = "pendingGameUploads"
    private let maxRetries = 3
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Upload a completed game to the backend
    func uploadCompletedGame(_ game: GameModel) {
        guard game.hasWon || game.hasLost else {
            print("⚠️ [GameSync] Game not completed, skipping upload")
            return
        }
        
        guard let uploadData = createGameUploadData(from: game) else {
            print("❌ [GameSync] Failed to create upload data")
            return
        }
        
        // Add to pending queue
        var queue = getPendingQueue()
        queue.append(uploadData)
        savePendingQueue(queue)
        
        print("📤 [GameSync] Added game to upload queue. Queue size: \(queue.count)")
        
        // Try to upload immediately
        processPendingUploads()
    }
    
    /// Process all pending game uploads
    func processPendingUploads() {
        let queue = getPendingQueue()
        guard !queue.isEmpty else { return }
        
        print("🔄 [GameSync] Processing \(queue.count) pending uploads")
        
        // Upload in batches
        uploadGames(queue) { [weak self] success in
            if success {
                // Clear the queue on success
                self?.savePendingQueue([])
                print("✅ [GameSync] Successfully uploaded all pending games")
            } else {
                print("❌ [GameSync] Failed to upload games, will retry later")
            }
        }
    }
    
    /// Get count of pending uploads
    func getPendingCount() -> Int {
        return getPendingQueue().count
    }
    
    // MARK: - Private Methods
    
    private func createGameUploadData(from game: GameModel) -> GameUploadData? {
        guard game.hasWon || game.hasLost else { return nil }
        
        let gameId = constructBackendGameId(for: game)
        
        return GameUploadData(
            gameId: gameId,
            score: game.calculateScore(),
            won: game.hasWon,
            mistakes: game.mistakes,
            timeSeconds: Int(game.lastUpdateTime.timeIntervalSince(game.startTime)),
            difficulty: game.difficulty,
            isDaily: game.gameId?.contains("daily") ?? false,
            completedAt: game.lastUpdateTime
        )
    }
    
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
    
    private func uploadGames(_ games: [GameUploadData], completion: @escaping (Bool) -> Void) {
        guard !games.isEmpty else {
            completion(true)
            return
        }
        
        guard let token = UserState.shared.authCoordinator.getAccessToken() else {
            print("❌ [GameSync] No auth token available")
            completion(false)
            return
        }
        
        let urlString = "\(UserState.shared.authCoordinator.baseURL)/api/games/batch"
        guard let url = URL(string: urlString) else {
            print("❌ [GameSync] Invalid URL")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let batchUpload = GameBatchUpload(games: games)
        
        do {
            let jsonData = try JSONEncoder().encode(batchUpload)
            request.httpBody = jsonData
            
            print("📡 [GameSync] Uploading \(games.count) games to server")
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
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                        print("✅ [GameSync] Successfully uploaded \(games.count) games")
                        completion(true)
                    } else {
                        print("❌ [GameSync] Server error: \(httpResponse.statusCode)")
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // MARK: - Queue Management
    
    private func getPendingQueue() -> [GameUploadData] {
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

// MARK: - Sync Status View

struct SyncStatusIndicator: View {
    @State private var pendingCount = 0
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: pendingCount > 0 ? "icloud.and.arrow.up" : "icloud.fill")
                .foregroundColor(pendingCount > 0 ? .orange : .green)
                .font(.system(size: 14))
            
            if pendingCount > 0 {
                Text("\(pendingCount)")
                    .font(.caption2)
                    .foregroundColor(.orange)
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
        pendingCount = GameSyncManager.shared.getPendingCount()
    }
}
