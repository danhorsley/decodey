import SwiftUI

struct VaultWinModal: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var userState: UserState
    @Environment(\.colorScheme) var colorScheme
    
    // Animation states
    @State private var showCodeRain = true
    @State private var showVaultInterface = false
    @State private var showScore = false
    @State private var showStats = false
    @State private var showButtons = false
    @State private var typewriterIndex = 0
    
    // Vault code columns
    @State private var columns: [VaultCodeColumn] = []
    
    // NEW: Computed properties for display stats
    private var displayStats: GameState.CompletedGameStats? {
        gameState.isDailyChallenge ? gameState.lastDailyGameStats : gameState.lastCustomGameStats
    }
    
    private var solution: String {
        displayStats?.solution ?? gameState.currentGame?.solution ?? ""
    }
    
    private var author: String {
        displayStats?.author ?? gameState.quoteAuthor
    }
    
    private var score: Int {
        displayStats?.score ?? gameState.currentGame?.calculateScore() ?? 0
    }
    
    private var mistakes: Int {
        displayStats?.mistakes ?? gameState.currentGame?.mistakes ?? 0
    }
    
    private var maxMistakes: Int {
        displayStats?.maxMistakes ?? gameState.currentGame?.maxMistakes ?? 5
    }
    
    private var timeElapsed: Int {
        if let stats = displayStats {
            return stats.timeElapsed
        } else if let game = gameState.currentGame {
            return Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
        }
        return 0
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Matrix code rain background
            if showCodeRain {
                codeRainBackground
                    .transition(.opacity)
            }
            
            // Central vault interface
            if showVaultInterface {
                vaultInterface
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            setupVaultAnimation()
        }
    }
    
    // MARK: - Code Rain Background
    private var codeRainBackground: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(columns) { column in
                    VaultCodeColumnView(
                        column: column,
                        height: geometry.size.height,
                        characters: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                    )
                }
            }
            .onAppear {
                setupCodeColumns(screenWidth: geometry.size.width)
            }
        }
        .opacity(showVaultInterface ? 0.1 : 1.0)
        .animation(.easeOut(duration: 1.0), value: showVaultInterface)
    }
    
    // MARK: - Vault Interface
    private var vaultInterface: some View {
        VStack(spacing: 24) {
            // Vault header
            vaultHeader
            
            // Decrypted quote display
            if typewriterIndex > 0 {
                quoteDisplay
                    .transition(.opacity)
            }
            
            // Score section
            if showScore {
                scoreSection
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Stats grid
            if showStats {
                statsGrid
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Action buttons
            if showButtons {
                buttonSection
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(32)
        .frame(maxWidth: 500)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.green.opacity(0.5), lineWidth: 2)
                )
        )
        .shadow(color: .green.opacity(0.3), radius: 20)
    }
    
    // MARK: - Vault Header
    private var vaultHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("VAULT")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                Text("BREACHED")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            }
            
            Text("SECURITY PROTOCOL BYPASSED")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.green.opacity(0.6))
                .tracking(2)
        }
    }
    
    // MARK: - Quote Display
    private var quoteDisplay: some View {
        VStack(spacing: 12) {
            HStack {
                Text("EXTRACTED_DATA:")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.green.opacity(0.7))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                let displayText = String(solution.prefix(typewriterIndex))
                
                Text(displayText)
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                
                // Blinking cursor
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 2, height: 20)
                    .opacity(showScore ? 0 : 1)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: showScore)
            }
            .padding(.horizontal, 24)
            
            if !author.isEmpty {
                Text("ORIGIN: \(author.uppercased())")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.green.opacity(0.7))
                
                // Add attribution if available
                if let attribution = displayStats?.attribution ?? gameState.quoteAttribution,
                   !attribution.isEmpty {
                    Text("[\(attribution)]")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(.green.opacity(0.5))
                        .italic()
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                .background(Color.black.opacity(0.5))
        )
    }
    
    // streak boost text for modal
    private var streakBoostText: String? {
        guard gameState.isDailyChallenge else { return nil }
        return StreakBoost.shared.getBoostDisplayText()
    }
    
    // MARK: - Score Section
    private var scoreSection: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HACK_SCORE")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.green.opacity(0.6))
                
                Text("\(score)")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.5), radius: 5)
                
                // Add streak boost display
                if let boostText = streakBoostText {
                    Text(boostText)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.8))
                }
            }
            
            // Rest of the section remains the same...
            Rectangle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 1)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("CIPHER CRACKED")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                }
                
                HStack {
                    Image(systemName: "lock.open.fill")
                        .foregroundColor(.green)
                    Text("VAULT ACCESSED")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.green.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Stats Grid
    private var statsGrid: some View {
        HStack(spacing: 32) {
            StatBlock(
                label: "ERRORS",
                value: "\(mistakes)/\(maxMistakes)",
                icon: "exclamationmark.triangle",
                isOptimal: mistakes == 0
            )
            
            StatBlock(
                label: "TIME",
                value: formatTime(timeElapsed),
                icon: "clock",
                isOptimal: timeElapsed < 60
            )
            
            // Use simplified UserState properties instead of stats object
            if gameState.isDailyChallenge {
                StatBlock(
                    label: "TOTAL",
                    value: "\(userState.gamesPlayed)",
                    icon: "gamecontroller",
                    isOptimal: userState.gamesPlayed >= 10
                )
            } else {
                StatBlock(
                    label: "WIN_RATE",
                    value: String(format: "%.0f%%", userState.winPercentage),
                    icon: "target",
                    isOptimal: userState.winPercentage > 75
                )
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Button Section
    private var buttonSection: some View {
        Button(action: {
            gameState.resetGame()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                Text("HACK_AGAIN")
            }
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.green)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Animation Setup
    private func setupVaultAnimation() {
        // Start code animation
        startCodeAnimation()
        
        // Show vault interface after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.8)) {
                showVaultInterface = true
            }
            
            // Start typewriter effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startTypewriterEffect()
            }
        }
        
        // Show score
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showScore = true
            }
            SoundManager.shared.play(.win)
        }
        
        // Show stats
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.4)) {
                showStats = true
            }
        }
        
        // Show buttons
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showButtons = true
            }
        }
    }
    
    private func setupCodeColumns(screenWidth: CGFloat) {
        let columnWidth: CGFloat = 20
        let columnCount = Int(screenWidth / columnWidth)
        
        columns = (0..<columnCount).map { index in
            VaultCodeColumn(
                id: index,
                x: CGFloat(index) * columnWidth,
                characters: generateRandomCharacters(),
                offset: CGFloat.random(in: -200...0),
                speed: CGFloat.random(in: 0.5...2.0)
            )
        }
    }
    
    private func generateRandomCharacters() -> [String] {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return (0...20).map { _ in String(chars.randomElement()!) }
    }
    
    private func startCodeAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard showCodeRain else {
                timer.invalidate()
                return
            }
            
            for index in columns.indices {
                columns[index].offset += columns[index].speed * 10
                
                // Use a reasonable screen height fallback
                let screenHeight: CGFloat = 1000
                if columns[index].offset > screenHeight + 200 {
                    columns[index].offset = -200
                    columns[index].characters = generateRandomCharacters()
                }
            }
        }
    }
    
    private func startTypewriterEffect() {
        let totalLength = solution.count
        
        guard totalLength > 0 else { return }
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if typewriterIndex < totalLength {
                typewriterIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    // Helper function to format time
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Stat Block Component
private struct StatBlock: View {
    let label: String
    let value: String
    let icon: String
    let isOptimal: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isOptimal ? .green : .green.opacity(0.6))
            
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.green.opacity(0.6))
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(isOptimal ? .green : .green.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Vault Code Column Model
struct VaultCodeColumn: Identifiable {
    let id: Int
    let x: CGFloat
    var characters: [String]
    var offset: CGFloat
    var speed: CGFloat
}

// MARK: - Vault Code Column View
struct VaultCodeColumnView: View {
    let column: VaultCodeColumn
    let height: CGFloat
    let characters: String
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<column.characters.count, id: \.self) { index in
                Text(column.characters[index])
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(
                        Color.green.opacity(
                            index == column.characters.count - 1 ? 1.0 :
                            index == column.characters.count - 2 ? 0.8 :
                            Double(column.characters.count - index) / Double(column.characters.count) * 0.5
                        )
                    )
                    .frame(width: 20, height: 20)
            }
        }
        .offset(y: column.offset)
        .position(x: column.x, y: height / 2)
    }
}
