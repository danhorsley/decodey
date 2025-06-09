import SwiftUI
import CoreData

struct PromoResponse: Codable {
    let success: Bool
    let type: String
    let message: String?
    let error: String?
    let data: PromoData?
    
    struct PromoData: Codable {
        // For XP Boost
        let multiplier: Double?
        let expiresAt: String?
        let durationHours: Int?
        
        // For Legacy Import
        let imported: ImportedStats?
        let streakPreserved: Bool?
        
        private enum CodingKeys: String, CodingKey {
            case multiplier
            case expiresAt = "expires_at"
            case durationHours = "duration_hours"
            case imported
            case streakPreserved = "streak_preserved"
        }
    }
    
    struct ImportedStats: Codable {
        let legacyUsername: String
        let gamesPlayed: Int
        let gamesWon: Int
        let dailyStreak: Int
        let cumulativeScore: Int
        let lastPlayed: String?
        
        private enum CodingKeys: String, CodingKey {
            case legacyUsername = "legacy_username"
            case gamesPlayed = "games_played"
            case gamesWon = "games_won"
            case dailyStreak = "daily_streak"
            case cumulativeScore = "cumulative_score"
            case lastPlayed = "last_played"
        }
    }
}

// MARK: - Promo Manager
class PromoManager: ObservableObject {
    static let shared = PromoManager()
    
    @Published var activeXPBoost: XPBoost?
    @Published var isRedeeming = false
    
    struct XPBoost {
        let multiplier: Double
        let expiresAt: Date
        
        var isActive: Bool {
            expiresAt > Date()
        }
        
        var remainingTime: TimeInterval {
            max(0, expiresAt.timeIntervalSinceNow)
        }
        
        var remainingTimeString: String {
            let hours = Int(remainingTime / 3600)
            let minutes = Int((remainingTime.truncatingRemainder(dividingBy: 3600)) / 60)
            
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
    }
    
    init() {
        checkActiveBoosts()
        
        // Set up timer to check boost expiry
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.checkActiveBoosts()
        }
    }
    
    // MARK: - Redeem Promo Code
    func redeemCode(_ code: String) async throws -> PromoResult {
        guard let token = UserState.shared.authCoordinator.getAccessToken() else {
            throw PromoError.notAuthenticated
        }
        
        // Update UI on main thread
        await MainActor.run {
            isRedeeming = true
        }
        
        defer {
            Task { @MainActor in
                isRedeeming = false
            }
        }
        
        let response = try await NetworkService.shared.redeemPromo(
            baseURL: UserState.shared.authCoordinator.baseURL,
            code: code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines),
            token: token
        )
        
        // Handle based on type
        switch response.type {
        case "xp_boost":
            return try await handleXPBoost(response)
        case "legacy_import":
            return try await handleLegacyImport(response)
        default:
            throw PromoError.unknownType
        }
    }
    
    // MARK: - Handle XP Boost
    private func handleXPBoost(_ response: PromoResponse) async throws -> PromoResult {
        guard let data = response.data,
              let multiplier = data.multiplier,
              let expiresAtString = data.expiresAt,
              let expiresAt = ISO8601DateFormatter().date(from: expiresAtString) else {
            throw PromoError.invalidResponse
        }
        
        // Update Core Data
        let context = CoreDataStack.shared.mainContext
        let userId = UserState.shared.userId
        
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first else {
                throw PromoError.userNotFound
            }
            
            // Update boost
            user.xpBoostMultiplier = multiplier
            user.xpBoostExpires = expiresAt
            
            try context.save()
            
            // Update local state
            await MainActor.run {
                self.activeXPBoost = XPBoost(multiplier: multiplier, expiresAt: expiresAt)
            }
            
            return .xpBoost(multiplier: multiplier, hours: data.durationHours ?? 24)
            
        } catch {
            throw PromoError.databaseError
        }
    }
    
    // MARK: - Handle Legacy Import
    private func handleLegacyImport(_ response: PromoResponse) async throws -> PromoResult {
        guard let data = response.data,
              let imported = data.imported else {
            throw PromoError.invalidResponse
        }
        
        // Update Core Data with imported stats
        let context = CoreDataStack.shared.mainContext
        let userId = UserState.shared.userId
        let username = UserState.shared.username
        
        // Ensure we have valid user info
        guard !userId.isEmpty, !username.isEmpty else {
            throw PromoError.notAuthenticated
        }
        
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            
            // Find or create user
            let user: UserCD
            if let existingUser = users.first {
                user = existingUser
            } else {
                // Create new user - this is the missing logic!
                user = UserCD(context: context)
                user.id = UUID()
                user.userId = userId
                user.username = username
                user.email = "\(username)@example.com" // Placeholder
                user.registrationDate = Date()
                user.lastLoginDate = Date()
                user.isActive = true
                user.isVerified = false
                user.isSubadmin = false
                
                print("📱 Created new UserCD for legacy import: \(username)")
            }
            
            // Get or create stats
            let stats: UserStatsCD
            if let existingStats = user.stats {
                stats = existingStats
            } else {
                stats = UserStatsCD(context: context)
                user.stats = stats
                stats.user = user
            }
            
            // Merge imported stats
            stats.gamesPlayed += Int32(imported.gamesPlayed)
            stats.gamesWon += Int32(imported.gamesWon)
            stats.totalScore += Int32(imported.cumulativeScore)
            
            // Handle streak preservation
            if data.streakPreserved == true && imported.dailyStreak > 0 {
                stats.currentStreak = max(stats.currentStreak, Int32(imported.dailyStreak))
            }
            
            // Update best streak if needed
            if stats.currentStreak > stats.bestStreak {
                stats.bestStreak = stats.currentStreak
            }
            
            // Update last played date if provided
            if let lastPlayedString = imported.lastPlayed,
               let lastPlayedDate = ISO8601DateFormatter().date(from: lastPlayedString) {
                stats.lastPlayedDate = lastPlayedDate
            }
            
            try context.save()
            
            // Refresh user stats
            UserState.shared.refreshStats()
            
            print("✅ Successfully imported legacy stats: \(imported.gamesPlayed) games, \(imported.gamesWon) wins")
            
            return .legacyImport(
                username: imported.legacyUsername,
                gamesImported: imported.gamesPlayed,
                streakPreserved: data.streakPreserved ?? false
            )
            
        } catch {
            print("Error importing legacy stats: \(error)")
            throw PromoError.importFailed
        }
    }
    
    // MARK: - Check Active Boosts
    func checkActiveBoosts() {
        let context = CoreDataStack.shared.mainContext
        let userId = UserState.shared.userId
        
        guard !userId.isEmpty else { return }
        
        let fetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        do {
            let users = try context.fetch(fetchRequest)
            guard let user = users.first else { return }
            
            // Check XP boost
            if let expires = user.xpBoostExpires, expires > Date() {
                activeXPBoost = XPBoost(
                    multiplier: user.xpBoostMultiplier,
                    expiresAt: expires
                )
            } else {
                // Clean up expired boost
                if user.xpBoostMultiplier > 1.0 {
                    user.xpBoostMultiplier = 1.0
                    user.xpBoostExpires = nil
                    try? context.save()
                }
                activeXPBoost = nil
            }
        } catch {
            print("Error checking boosts: \(error)")
        }
    }
    
    // MARK: - Calculate Score with Boosts
    func calculateBoostedScore(baseScore: Int, includeDaily: Bool = true) -> Int {
        var multiplier = 1.0
        
        // Apply XP boost if active
        if let boost = activeXPBoost, boost.isActive {
            multiplier *= boost.multiplier
        }
        
        // Apply daily boost if applicable
//        if includeDaily && GameState.shared.isDailyMode {
//            multiplier *= 1.5 // Daily mode gets 1.5x
//        }
        
        return Int(Double(baseScore) * multiplier)
    }
}

// MARK: - Promo Types
enum PromoResult {
    case xpBoost(multiplier: Double, hours: Int)
    case legacyImport(username: String, gamesImported: Int, streakPreserved: Bool)
    
    var title: String {
        switch self {
        case .xpBoost(let multiplier, _):
            return "\(Int(multiplier))x XP Boost Activated!"
        case .legacyImport:
            return "Stats Imported Successfully!"
        }
    }
    
    var message: String {
        switch self {
        case .xpBoost(let multiplier, let hours):
            return "Earn \(Int(multiplier))x points for the next \(hours) hours!"
        case .legacyImport(let username, let games, let preserved):
            var msg = "Imported \(games) games from \(username)."
            if preserved {
                msg += "\n\n🔥 Your daily streak was preserved!"
            }
            return msg
        }
    }
    
    var icon: String {
        switch self {
        case .xpBoost:
            return "flame.fill"
        case .legacyImport:
            return "checkmark.circle.fill"
        }
    }
}

enum PromoError: LocalizedError {
    case notAuthenticated
    case invalidCode
    case alreadyRedeemed
    case expired
    case invalidResponse
    case unknownType
    case userNotFound
    case databaseError
    case importFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to redeem codes"
        case .invalidCode:
            return "Invalid promo code"
        case .alreadyRedeemed:
            return "You've already redeemed this code"
        case .expired:
            return "This code has expired"
        case .invalidResponse:
            return "Invalid server response"
        case .unknownType:
            return "Unknown promo type"
        case .userNotFound:
            return "User data not found"
        case .databaseError:
            return "Database error"
        case .importFailed:
            return "Failed to import stats"
        case .networkError:
            return "Network error"
        }
    }
}

// MARK: - UI Components
struct PromoCodeView: View {
    @State private var promoCode = ""
    @State private var result: PromoResult?
    @State private var error: PromoError?
    @State private var showingAlert = false
    @ObservedObject private var manager = PromoManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Redeem Promo Code", systemImage: "gift.fill")
                            .font(.headline)
                        
                        Text("Enter a code to unlock rewards, import stats, or activate boosts!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    VStack(spacing: 16) {
                        Text("ENTER CODE")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        TextField("PROMO-CODE", text: $promoCode)
                            .textFieldStyle(.plain)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .textCase(.uppercase)
                            .autocorrectionDisabled()
                            .disabled(manager.isRedeeming)
                            .padding(.vertical, 20)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.vertical, 8)
                }
                
                if let boost = manager.activeXPBoost, boost.isActive {
                    Section("Active Boost") {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(Int(boost.multiplier))x XP Boost")
                                .font(.headline)
                            Spacer()
                            Text(boost.remainingTimeString)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section {
                    Button(action: redeemCode) {
                        HStack {
                            Spacer()
                            if manager.isRedeeming {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                                Text("Redeeming...")
                            } else {
                                Image(systemName: "gift.fill")
                                    .padding(.trailing, 4)
                                Text("Redeem Code")
                            }
                            Spacer()
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(promoCode.isEmpty || manager.isRedeeming ? Color.gray : Color.blue)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(promoCode.isEmpty || manager.isRedeeming)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .navigationTitle("Promo Code")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.medium))
                }
            }
            .alert(
                result?.title ?? error?.localizedDescription ?? "Error",
                isPresented: $showingAlert
            ) {
                Button("OK") {
                    if result != nil {
                        dismiss()
                    }
                }
            } message: {
                if let result = result {
                    Text(result.message)
                } else if let error = error {
                    Text(error.localizedDescription)
                }
            }
        }
        .interactiveDismissDisabled(manager.isRedeeming)
    }
    
    private func redeemCode() {
        // Hide keyboard
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        
        Task {
            do {
                let result = try await PromoManager.shared.redeemCode(promoCode)
                await MainActor.run {
                    self.result = result
                    self.error = nil
                    self.showingAlert = true
                }
            } catch let promoError as PromoError {
                await MainActor.run {
                    self.error = promoError
                    self.result = nil
                    self.showingAlert = true
                }
            } catch {
                await MainActor.run {
                    self.error = .networkError
                    self.result = nil
                    self.showingAlert = true
                }
            }
        }
    }
}


// MARK: - Display Active Boost in Game
struct ActiveBoostIndicator: View {
    @ObservedObject private var manager = PromoManager.shared
    
    var body: some View {
        if let boost = manager.activeXPBoost, boost.isActive {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text("\(Int(boost.multiplier))x")
                    .fontWeight(.bold)
                Text(boost.remainingTimeString)
                    .font(.caption)
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.2))
            .cornerRadius(12)
        }
    }
}

// MARK: - Network Extension
extension NetworkService {
    func redeemPromo(baseURL: String, code: String, token: String) async throws -> PromoResponse {
        let body = ["code": code]
        
        return try await post(
            baseURL: baseURL,
            path: "/api/promo",
            body: body,
            token: token,
            responseType: PromoResponse.self
        )
    }
}
