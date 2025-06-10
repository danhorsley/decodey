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
                decodedContentCard
            }
        }
        .onAppear {
            startRevealAnimation()
        }
    }
    
    // MARK: - Background Layer
    private var backgroundLayer: some View {
        ZStack {
            // Base color - warm sepia
            Color(red: 0.96, green: 0.93, blue: 0.88)
                .ignoresSafeArea()
            
            // Subtle paper texture overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.94, green: 0.90, blue: 0.84).opacity(0.3),
                    Color(red: 0.92, green: 0.88, blue: 0.82).opacity(0.5),
                    Color(red: 0.94, green: 0.90, blue: 0.84).opacity(0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Vignette effect
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color(red: 0.85, green: 0.80, blue: 0.73).opacity(0.2),
                    Color(red: 0.80, green: 0.74, blue: 0.66).opacity(0.4)
                ]),
                center: .center,
                startRadius: 200,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Undeciphered Text Layer
    private var undecipheredTextLayer: some View {
        GeometryReader { geometry in
            ForEach(0..<15, id: \.self) { index in
                Text(archiveTexts[index % archiveTexts.count])
                    .font(.system(size: 14, weight: .light, design: .serif))
                    .foregroundColor(Color(red: 0.55, green: 0.50, blue: 0.45))
                    .opacity(glitchOpacity * Double.random(in: 0.3...0.7))
                    .blur(radius: Double.random(in: 0.5...2.0))
                    .rotationEffect(.degrees(Double.random(in: -2...2)))
                    .position(
                        x: edgePosition(for: index, in: geometry.size).x,
                        y: edgePosition(for: index, in: geometry.size).y
                    )
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...4))
                            .repeatForever(autoreverses: true),
                        value: glitchOpacity
                    )
            }
        }
    }
    
    // Calculate positions around the edges
    private func edgePosition(for index: Int, in size: CGSize) -> CGPoint {
        let margin: CGFloat = 100
        let side = index % 4
        
        switch side {
        case 0: // Top edge
            return CGPoint(
                x: CGFloat.random(in: margin...(size.width - margin)),
                y: CGFloat.random(in: 20...100)
            )
        case 1: // Right edge
            return CGPoint(
                x: CGFloat.random(in: (size.width - 100)...size.width),
                y: CGFloat.random(in: margin...(size.height - margin))
            )
        case 2: // Bottom edge
            return CGPoint(
                x: CGFloat.random(in: margin...(size.width - margin)),
                y: CGFloat.random(in: (size.height - 100)...size.height)
            )
        default: // Left edge
            return CGPoint(
                x: CGFloat.random(in: 0...100),
                y: CGFloat.random(in: margin...(size.height - margin))
            )
        }
    }
    
    // MARK: - Decoded Content Card
    private var decodedContentCard: some View {
        VStack(spacing: 32) {
            // Classification stamp
            classificationStamp
                .opacity(showScore ? 1 : 0)
                .scaleEffect(showScore ? 1 : 0.8)
            
            // Decoded quote
            VStack(spacing: 16) {
                Text("DECRYPTED TRANSCRIPT")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .tracking(2)
                    .foregroundColor(Color(red: 0.55, green: 0.50, blue: 0.45))
                
                // Solution text with typewriter effect
                Text(gameState.currentGame?.solution.prefix(typewriterIndex) ?? "")
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
    
    // MARK: - Stats Section
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
            
            if gameState.isDailyChallenge {
                StatItem(
                    label: "Streak",
                    value: "\(userState.stats?.currentStreak ?? 0)",
                    isHighlighted: (userState.stats?.currentStreak ?? 0) > 0
                )
            }
        }
    }
    
    // MARK: - Button Section
    private var buttonSection: some View {
        HStack(spacing: 20) {
            // Share button
            Button(action: {
                SoundManager.shared.play(.win)
                // Share action
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color(red: 0.45, green: 0.40, blue: 0.35))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 0.65, green: 0.60, blue: 0.55), lineWidth: 1)
                    )
            }
            
            // Play again button
            Button(action: {
                SoundManager.shared.play(.letterClick)
                gameState.showWinMessage = false
                gameState.resetGame()
            }) {
                Text("NEW CIPHER")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(Color(red: 0.98, green: 0.96, blue: 0.92))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.35, green: 0.30, blue: 0.25))
                    )
            }
        }
    }
    
    // MARK: - Animation Sequence
    private func startRevealAnimation() {
        // Fade in undeciphered text
        withAnimation(.easeIn(duration: 0.8)) {
            glitchOpacity = 1.0
        }
        
        // Show decoded content
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                showDecrypted = true
            }
            
            // Start typewriter effect
            startTypewriterEffect()
        }
        
        // Show score
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showScore = true
            }
        }
        
        // Show stats
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                showStats = true
            }
        }
        
        // Show buttons
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showButtons = true
            }
        }
        
        // Fade out undeciphered text
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeOut(duration: 1.5)) {
                glitchOpacity = 0.3
            }
        }
    }
    
    // Typewriter effect for solution text
    private func startTypewriterEffect() {
        let solutionLength = gameState.currentGame?.solution.count ?? 0
        let delay = 0.03 // Delay between characters
        
        for i in 0...solutionLength {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * delay) {
                typewriterIndex = i
                
                // Play subtle sound every few characters
                if i % 3 == 0 && i > 0 {
                    SoundManager.shared.play(.letterClick)
                }
            }
        }
    }
    
    // Helper function to format time
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Stat Item Component
private struct StatItem: View {
    let label: String
    let value: String
    let isHighlighted: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1)
                .foregroundColor(Color(red: 0.55, green: 0.50, blue: 0.45))
            
            Text(value)
                .font(.system(size: 18, weight: isHighlighted ? .semibold : .regular, design: .serif))
                .foregroundColor(
                    isHighlighted ?
                    Color(red: 0.65, green: 0.50, blue: 0.30) :
                    Color(red: 0.35, green: 0.30, blue: 0.25)
                )
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ArchiveWinModal_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock game state
        let gameState = GameState.shared
        let mockQuote = QuoteModel(
            text: "THE ONLY WAY TO DO GREAT WORK IS TO LOVE WHAT YOU DO",
            author: "Steve Jobs",
            attribution: nil,
            difficulty: 2.0
        )
        var mockGame = GameModel(quote: mockQuote)
        mockGame.hasWon = true
        mockGame.mistakes = 2
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
