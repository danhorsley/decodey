import SwiftUI

// MARK: - Archive Win Modal (Light Mode)
struct ArchiveWinModal: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var userState: UserState
    @Environment(\.colorScheme) var colorScheme
    
    // Animation states
    @State private var showUndeciphered = true
    @State private var showDecrypted = false
    @State private var showScore = false
    @State private var showStats = false
    @State private var showButtons = false
    @State private var typewriterIndex = 0
    @State private var glitchOpacity = 1.0
    
    // Design system
    private let colors = ColorSystem.shared
    private let fonts = FontSystem.shared
    
    // Archive text samples (for background)
    private let archiveTexts = [
        "...fragment 47B recovered from site delta...",
        "...carbon dating confirms authenticity...",
        "...translation pending verification...",
        "...cross-reference with Alexandria codex...",
        "...linguistic patterns match proto-semitic...",
        "...damaged sections reconstructed using...",
        "...archaeological survey report #1947...",
        "...preservation grade: exceptional...",
        "...contextual analysis suggests origin...",
        "...paleographic evidence indicates...",
        "...chemical composition of ink suggests...",
        "...comparative mythology database entry...",
        "...spectral imaging reveals hidden text...",
        "...provenance chain documented since...",
        "...correlates with manuscript MS-408..."
    ]
    
    var body: some View {
        ZStack {
            // Background - faded sepia overlay
            backgroundLayer
            
            // Undeciphered text edges
            if showUndeciphered {
                undecipheredTextLayer
            }
            
            // Central decoded content
            if showDecrypted {
                centralContentLayer
            }
        }
        .onAppear {
            startAnimationSequence()
        }
        .onTapGesture {
            gameState.showWinMessage = false
        }
    }
    
    // MARK: - Background Layer
    private var backgroundLayer: some View {
        ZStack {
            // Base sepia background
            Color(red: 0.92, green: 0.88, blue: 0.80)
                .ignoresSafeArea()
            
            // Scattered archive text fragments
            ForEach(0..<8, id: \.self) { index in
                Text(archiveTexts[index % archiveTexts.count])
                    .font(.system(size: 12, weight: .light, design: .monospaced))
                    .foregroundColor(Color(red: 0.75, green: 0.70, blue: 0.65).opacity(0.3))
                    .rotationEffect(.degrees(Double.random(in: -15...15)))
                    .position(
                        x: CGFloat.random(in: 50...350),
                        y: CGFloat.random(in: 100...700)
                    )
            }
        }
    }
    
    // MARK: - Undeciphered Text Layer
    private var undecipheredTextLayer: some View {
        VStack(spacing: 20) {
            ForEach(0..<5, id: \.self) { _ in
                HStack {
                    ForEach(0..<Int.random(in: 8...15), id: \.self) { _ in
                        Text(String("ABCDEFGHIJKLMNOPQRSTUVWXYZ".randomElement()!))
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(red: 0.45, green: 0.40, blue: 0.35))
                            .opacity(glitchOpacity)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.15).repeatForever(autoreverses: true), value: glitchOpacity)
        .onAppear {
            withAnimation {
                glitchOpacity = 0.6
            }
        }
    }
    
    // MARK: - Central Content Layer
    private var centralContentLayer: some View {
        VStack(spacing: 32) {
            // Classification stamp
            classificationStamp
            
            // Decoded quote with typewriter effect
            VStack(spacing: 16) {
                let displayText = String((gameState.currentGame?.solution ?? "").prefix(typewriterIndex))
                
                Text(displayText)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .foregroundColor(Color(red: 0.25, green: 0.22, blue: 0.20))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 24)
                
                if !gameState.quoteAuthor.isEmpty && typewriterIndex >= (gameState.currentGame?.solution.count ?? 0) {
                    Text("— \(gameState.quoteAuthor)")
                        .font(.system(size: 16, weight: .light, design: .serif))
                        .italic()
                        .foregroundColor(Color(red: 0.45, green: 0.40, blue: 0.35))
                        .transition(.opacity)
                }
            }
            
            // Score section
            if showScore {
                scoreSection
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            
            // Stats section
            if showStats {
                statsSection
                    .transition(.opacity)
            }
            
            // Action buttons
            if showButtons {
                buttonSection
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(40)
        .frame(maxWidth: 600)
        .background(
            ZStack {
                // Aged paper background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.98, green: 0.96, blue: 0.92))
                
                // Subtle border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(red: 0.75, green: 0.70, blue: 0.65).opacity(0.3), lineWidth: 1)
            }
        )
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scaleEffect(showDecrypted ? 1 : 0.95)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showDecrypted)
    }
    
    // MARK: - Classification Stamp
    private var classificationStamp: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color(red: 0.75, green: 0.70, blue: 0.65))
                .frame(width: 40, height: 1)
            
            Text("CLASSIFIED DOCUMENT")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundColor(Color(red: 0.65, green: 0.60, blue: 0.55))
            
            Rectangle()
                .fill(Color(red: 0.75, green: 0.70, blue: 0.65))
                .frame(width: 40, height: 1)
        }
    }
    
    // MARK: - Score Section
    private var scoreSection: some View {
        VStack(spacing: 8) {
            Text("DECRYPTION SCORE")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .tracking(1.5)
                .foregroundColor(Color(red: 0.55, green: 0.50, blue: 0.45))
            
            Text("\(gameState.currentGame?.calculateScore() ?? 0)")
                .font(.system(size: 48, weight: .light, design: .serif))
                .foregroundColor(Color(red: 0.35, green: 0.30, blue: 0.25))
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Stats Section (FIXED FOR SIMPLIFIED UserState)
    private var statsSection: some View {
        HStack(spacing: 40) {
            StatItem(
                label: "Mistakes",
                value: "\(gameState.currentGame?.mistakes ?? 0)/\(gameState.currentGame?.maxMistakes ?? 0)",
                isHighlighted: gameState.currentGame?.mistakes == 0
            )
            
            StatItem(
                label: "Time",
                value: formatTime(Int(gameState.currentGame?.lastUpdateTime.timeIntervalSince(gameState.currentGame?.startTime ?? Date()) ?? 0)),
                isHighlighted: Int(gameState.currentGame?.lastUpdateTime.timeIntervalSince(gameState.currentGame?.startTime ?? Date()) ?? 0) < 60
            )
            
            // Use simplified UserState properties instead of stats object
            if gameState.isDailyChallenge {
                StatItem(
                    label: "Total Games",
                    value: "\(userState.gamesPlayed)",
                    isHighlighted: userState.gamesPlayed > 0
                )
            } else {
                StatItem(
                    label: "Win Rate",
                    value: String(format: "%.0f%%", userState.winPercentage),
                    isHighlighted: userState.winPercentage > 75
                )
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Button Section
    private var buttonSection: some View {
        HStack(spacing: 20) {
            Button(action: {
                gameState.showWinMessage = false
                gameState.setupCustomGame()
            }) {
                Text("NEW GAME")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1.0)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.35, green: 0.30, blue: 0.25))
                    )
                    .foregroundColor(Color(red: 0.98, green: 0.96, blue: 0.92))
            }
            
            Button(action: {
                gameState.showWinMessage = false
            }) {
                Text("CLOSE")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1.0)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(red: 0.35, green: 0.30, blue: 0.25), lineWidth: 1)
                    )
                    .foregroundColor(Color(red: 0.35, green: 0.30, blue: 0.25))
            }
        }
    }
    
    // MARK: - Animation Sequence
    private func startAnimationSequence() {
        // Step 1: Show undeciphered text with glitch effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                showUndeciphered = false
                showDecrypted = true
            }
        }
        
        // Step 2: Start typewriter effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            startTypewriterEffect()
        }
        
        // Step 3: Show score
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showScore = true
            }
        }
        
        // Step 4: Show stats
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showStats = true
            }
        }
        
        // Step 5: Show buttons
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showButtons = true
            }
        }
    }
    
    private func startTypewriterEffect() {
        let solution = gameState.currentGame?.solution ?? ""
        let totalLength = solution.count
        
        guard totalLength > 0 else { return }
        
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if typewriterIndex < totalLength {
                typewriterIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Stat Item Component
struct StatItem: View {
    let label: String
    let value: String
    let isHighlighted: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .tracking(1.0)
                .foregroundColor(Color(red: 0.55, green: 0.50, blue: 0.45))
            
            Text(value)
                .font(.system(size: 20, weight: isHighlighted ? .semibold : .regular, design: .serif))
                .foregroundColor(
                    isHighlighted ?
                    Color(red: 0.65, green: 0.50, blue: 0.30) :
                    Color(red: 0.35, green: 0.30, blue: 0.25)
                )
        }
    }
}

// MARK: - Preview (FIXED)
#if DEBUG
struct ArchiveWinModal_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock game state with CORRECT GameModel initializer
        let gameState = GameState.shared
        
        // Use the correct GameModel initializer with all required parameters
        let mockGame = GameModel(
            gameId: UUID().uuidString,
            encrypted: "XQZ DGRT VRPH XGTFH",
            solution: "THE ONLY WAY TO DO GREAT WORK IS TO LOVE WHAT YOU DO",
            currentDisplay: "THE ONLY WAY TO DO GREAT WORK IS TO LOVE WHAT YOU DO",
            mapping: [:],
            correctMappings: [:],
            guessedMappings: [:],
            incorrectGuesses: [:],
            mistakes: 2,
            maxMistakes: 5,
            hasWon: true,
            hasLost: false,
            difficulty: "medium",
            startTime: Date().addingTimeInterval(-120), // 2 minutes ago
            lastUpdateTime: Date()
        )
        
        gameState.currentGame = mockGame
        gameState.quoteAuthor = "Steve Jobs"
        gameState.showWinMessage = true
        
        return ArchiveWinModal()
            .environmentObject(gameState)
            .environmentObject(UserState.shared)
            .preferredColorScheme(.light)
    }
}
#endif
