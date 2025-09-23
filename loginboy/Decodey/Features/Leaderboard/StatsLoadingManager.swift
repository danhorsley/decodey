//// StatsLoadingManager.swift
//// Handles stats preloading and caching to prevent empty state flashes
//
//import SwiftUI
//import CoreData
//import Combine
//
//// MARK: - Stats Cache Manager
//class StatsLoadingManager: ObservableObject {
//    static let shared = StatsLoadingManager()
//    
//    @Published var cachedStats: DetailedUserStats?
//    @Published var isPreloading = false
//    @Published var lastRefreshTime: Date?
//    
//    private var cancellables = Set<AnyCancellable>()
//    private let coreData = CoreDataStack.shared
//    
//    // Cache duration - refresh if older than 5 minutes
//    private let cacheValidityDuration: TimeInterval = 300
//    
//    private init() {
//        // Preload stats when UserState changes
//        NotificationCenter.default.publisher(for: Notification.Name("UserStateChanged"))
//            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
//            .sink { [weak self] _ in
//                self?.preloadStatsIfNeeded()
//            }
//            .store(in: &cancellables)
//    }
//    
//    // MARK: - Public Methods
//    
//    /// Check if cached stats are still valid
//    var isCacheValid: Bool {
//        guard let lastRefresh = lastRefreshTime else { return false }
//        return Date().timeIntervalSince(lastRefresh) < cacheValidityDuration
//    }
//    
//    /// Preload stats in background
//    func preloadStatsIfNeeded() {
//        guard !isPreloading else { return }
//        
//        // Skip if cache is still valid
//        if isCacheValid, cachedStats != nil {
//            return
//        }
//        
//        Task {
//            await loadStats()
//        }
//    }
//    
//    /// Force refresh stats
//    func forceRefresh() async -> DetailedUserStats? {
//        lastRefreshTime = nil // Invalidate cache
//        return await loadStats()
//    }
//    
//    /// Get stats with loading state
//    func getStats() async -> DetailedUserStats? {
//        // Return cached if valid
//        if isCacheValid, let cached = cachedStats {
//            return cached
//        }
//        
//        // Otherwise load fresh
//        return await loadStats()
//    }
//    
//    // MARK: - Private Loading
//    
//    @MainActor
//    private func loadStats() async -> DetailedUserStats? {
//        isPreloading = true
//        
//        do {
//            // Simulate minimum loading time for smooth transition
//            async let stats = calculateDetailedStats()
//            async let minDelay = Task.sleep(nanoseconds: 200_000_000) // 0.2s
//            
//            let (loadedStats, _) = await (try stats, try minDelay)
//            
//            // Update cache
//            cachedStats = loadedStats
//            lastRefreshTime = Date()
//            isPreloading = false
//            
//            return loadedStats
//        } catch {
//            print("Failed to load stats: \(error)")
//            isPreloading = false
//            return nil
//        }
//    }
//    
//    private func calculateDetailedStats() async throws -> DetailedUserStats {
//        let context = coreData.mainContext
//        let userState = UserState.shared
//        
//        return try await context.perform {
//            // Your existing calculateDetailedStats logic here
//            // This is a simplified version - replace with your actual logic
//            
//            let userFetchRequest: NSFetchRequest<UserCD> = UserCD.fetchRequest()
//            
//            if !userState.userId.isEmpty {
//                userFetchRequest.predicate = NSPredicate(format: "primaryIdentifier == %@", userState.userId)
//            } else if !userState.playerName.isEmpty {
//                userFetchRequest.predicate = NSPredicate(format: "username == %@", userState.playerName)
//            } else {
//                userFetchRequest.predicate = NSPredicate(format: "primaryIdentifier == %@", "anonymous-user")
//            }
//            
//            let users = try context.fetch(userFetchRequest)
//            guard let user = users.first else {
//                // Return empty stats
//                return DetailedUserStats(
//                    totalGamesPlayed: 0,
//                    gamesWon: 0,
//                    totalScore: 0,
//                    winPercentage: 0,
//                    averageScore: 0,
//                    averageTime: 0,
//                    currentStreak: 0,
//                    bestStreak: 0,
//                    lastPlayedDate: nil,
//                    weeklyStats: WeeklyStats(gamesPlayed: 0, totalScore: 0),
//                    topScores: [],
//                    dailyGamesCompleted: 0,
//                    customGamesCompleted: 0
//                )
//            }
//            
//            let stats = user.stats
//            let totalGamesPlayed = Int(stats?.gamesPlayed ?? 0)
//            let gamesWon = Int(stats?.gamesWon ?? 0)
//            let totalScore = Int(stats?.totalScore ?? 0)
//            let currentStreak = Int(stats?.currentStreak ?? 0)
//            let bestStreak = Int(stats?.bestStreak ?? 0)
//            
//            // Calculate derived stats
//            let winPercentage = totalGamesPlayed > 0 ? (Double(gamesWon) / Double(totalGamesPlayed)) * 100 : 0
//            let averageScore = totalGamesPlayed > 0 ? Double(totalScore) / Double(totalGamesPlayed) : 0
//            
//            return DetailedUserStats(
//                totalGamesPlayed: totalGamesPlayed,
//                gamesWon: gamesWon,
//                totalScore: totalScore,
//                winPercentage: winPercentage,
//                averageScore: averageScore,
//                averageTime: stats?.averageTime ?? 0,
//                currentStreak: currentStreak,
//                bestStreak: bestStreak,
//                lastPlayedDate: stats?.lastPlayedDate,
//                weeklyStats: WeeklyStats(gamesPlayed: 0, totalScore: 0), // Calculate properly
//                topScores: [], // Fetch top scores
//                dailyGamesCompleted: 0, // Calculate
//                customGamesCompleted: 0 // Calculate
//            )
//        }
//    }
//}
//
//// MARK: - Skeleton Loading View
//struct StatsSkeletonView: View {
//    @State private var isAnimating = false
//    
//    var body: some View {
//        VStack(spacing: 24) {
//            // Overview Cards Grid
//            LazyVGrid(columns: [
//                GridItem(.flexible()),
//                GridItem(.flexible())
//            ], spacing: 16) {
//                ForEach(0..<4) { _ in
//                    skeletonCard
//                }
//            }
//            
//            // Streaks Section
//            skeletonSection
//            
//            // Top Scores Section
//            skeletonSection
//        }
//        .padding()
//        .onAppear {
//            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever()) {
//                isAnimating = true
//            }
//        }
//    }
//    
//    private var skeletonCard: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            RoundedRectangle(cornerRadius: 4)
//                .fill(Color.gray.opacity(isAnimating ? 0.3 : 0.1))
//                .frame(width: 60, height: 12)
//            
//            RoundedRectangle(cornerRadius: 4)
//                .fill(Color.gray.opacity(isAnimating ? 0.3 : 0.1))
//                .frame(width: 40, height: 24)
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(Color.gray.opacity(0.1))
//        )
//    }
//    
//    private var skeletonSection: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            RoundedRectangle(cornerRadius: 4)
//                .fill(Color.gray.opacity(isAnimating ? 0.3 : 0.1))
//                .frame(width: 100, height: 16)
//            
//            ForEach(0..<3) { _ in
//                RoundedRectangle(cornerRadius: 4)
//                    .fill(Color.gray.opacity(isAnimating ? 0.3 : 0.1))
//                    .frame(height: 40)
//            }
//        }
//    }
//}
//
//// MARK: - Updated UserStatsView
//struct ImprovedUserStatsView: View {
//    @EnvironmentObject var userState: UserState
//    @StateObject private var statsManager = StatsLoadingManager.shared
//    @State private var loadState: LoadState = .loading
//    @State private var hasAppeared = false
//    
//    enum LoadState {
//        case loading
//        case loaded(DetailedUserStats)
//        case error(String)
//    }
//    
//    var body: some View {
//        ThemedDataDisplay(title: "Your Statistics") {
//            Group {
//                switch loadState {
//                case .loading:
//                    StatsSkeletonView()
//                        .transition(.opacity)
//                    
//                case .loaded(let stats):
//                    StatsContentView(stats: stats)
//                        .transition(.asymmetric(
//                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
//                            removal: .opacity
//                        ))
//                    
//                case .error(let message):
//                    ErrorStateView(
//                        message: message,
//                        retry: { Task { await loadStats() } }
//                    )
//                }
//            }
//            .animation(.easeOut(duration: 0.25))  // Remove value parameter
//        }
//        .task {
//            if !hasAppeared {
//                hasAppeared = true
//                await loadStats()
//            }
//        }
//        .refreshable {
//            await forceRefreshStats()
//        }
//    }
//    
//    private func loadStats() async {
//        // Check cache first
//        if statsManager.isCacheValid, let cached = statsManager.cachedStats {
//            loadState = .loaded(cached)
//            return
//        }
//        
//        // Show loading state
//        loadState = .loading
//        
//        // Load stats
//        if let stats = await statsManager.getStats() {
//            loadState = .loaded(stats)
//        } else {
//            loadState = .error("Failed to load statistics")
//        }
//    }
//    
//    private func forceRefreshStats() async {
//        if let stats = await statsManager.forceRefresh() {
//            withAnimation {
//                loadState = .loaded(stats)
//            }
//        }
//    }
//}
//
//// MARK: - Stats Content View (your existing display)
//struct StatsContentView: View {
//    let stats: DetailedUserStats
//    
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 24) {
//                // Your existing stats display code
//                LazyVGrid(columns: [
//                    GridItem(.flexible()),
//                    GridItem(.flexible())
//                ], spacing: 16) {
//                    ThemedStatCard(
//                        title: "Games Played",
//                        value: "\(stats.totalGamesPlayed)",
//                        icon: "gamecontroller.fill",
//                        trend: nil
//                    )
//                    
//                    ThemedStatCard(
//                        title: "Games Won",
//                        value: "\(stats.gamesWon)",
//                        icon: "trophy.fill",
//                        trend: nil
//                    )
//                    
//                    ThemedStatCard(
//                        title: "Win Rate",
//                        value: String(format: "%.1f%%", stats.winPercentage),
//                        icon: "percent",
//                        trend: nil  // Remove trend for now
//                    )
//                    
//                    ThemedStatCard(
//                        title: "Avg Score",
//                        value: String(format: "%.0f", stats.averageScore),
//                        icon: "star.fill",
//                        trend: nil
//                    )
//                }
//                
//                // Add more sections as needed...
//            }
//            .padding()
//        }
//    }
//}
//
//// MARK: - Error State View
//struct ErrorStateView: View {
//    let message: String
//    let retry: () -> Void
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            Image(systemName: "exclamationmark.triangle")
//                .font(.system(size: 50))
//                .foregroundColor(.orange)
//            
//            Text("Error loading statistics")
//                .font(.title2)
//                .fontWeight(.bold)
//            
//            Text(message)
//                .foregroundColor(.secondary)
//                .multilineTextAlignment(.center)
//            
//            Button("Try Again", action: retry)
//                .buttonStyle(.bordered)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//}
