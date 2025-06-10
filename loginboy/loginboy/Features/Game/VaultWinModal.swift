import SwiftUI
import Combine

// MARK: - Vault Win Modal (Dark Mode)
struct VaultWinModal: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var userState: UserState
    @Environment(\.colorScheme) var colorScheme
    
    // Animation states
    @State private var showContent = false
    @State private var decryptionProgress: CGFloat = 0
    @State private var showScore = false
    @State private var showStats = false
    @State private var showButtons = false
    @State private var glitchOffset: CGFloat = 0
    @State private var scanlineOffset: CGFloat = 0
    
    // Design system
    private let colors = ColorSystem.shared
    private let fonts = FontSystem.shared
    
    var body: some View {
        ZStack {
            // Background with scrolling code
            CodeRainBackground()
                .ignoresSafeArea()
            
            // Scanline effect
            scanlineOverlay
            
            // Main content
            if showContent {
                vaultContent
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .onAppear {
            startHackSequence()
        }
    }
    
    // MARK: - Scanline Effect
    private var scanlineOverlay: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.green.opacity(0.1),
                            Color.green.opacity(0.05),
                            Color.clear,
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 4)
                .offset(y: scanlineOffset)
                .onAppear {
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                        scanlineOffset = geometry.size.height
                    }
                }
        }
    }
    
    // MARK: - Vault Content
    private var vaultContent: some View {
        VStack(spacing: 32) {
            // Terminal header
            terminalHeader
            
            // Decryption progress bar
            if decryptionProgress < 1.0 {
                decryptionProgressView
            }
            
            // Decoded content with glitch effect
            if decryptionProgress >= 1.0 {
                decodedSection
                    .offset(x: glitchOffset)
                    .animation(.interpolatingSpring(stiffness: 1000, damping: 10), value: glitchOffset)
            }
            
            // Score section
            if showScore {
                scoreSection
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            
            // Stats grid
            if showStats {
                statsGrid
                    .transition(.opacity)
            }
            
            // Action buttons
            if showButtons {
                buttonSection
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(32)
        .frame(maxWidth: 700)
        .background(
            ZStack {
                // Dark background with subtle transparency
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.black.opacity(0.85))
                
                // Green border glow
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.green.opacity(0.8), lineWidth: 2)
                    .shadow(color: .green.opacity(0.6), radius: 10)
            }
        )
    }
    
    // MARK: - Terminal Header
    private var terminalHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("VAULT://SECURE/DECRYPTED")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.green)
                
                Spacer()
                
                Text("[\(Date().formatted(date: .abbreviated, time: .standard))]")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.green.opacity(0.7))
            }
            
            Text("ACCESS GRANTED - LEVEL 9 CLEARANCE")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(.green.opacity(0.6))
        }
    }
    
    // MARK: - Decryption Progress
    private var decryptionProgressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DECRYPTING...")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.green)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.green.opacity(0.1))
                        .frame(height: 4)
                    
                    // Progress
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * decryptionProgress, height: 4)
                }
            }
            .frame(height: 4)
            
            Text("\(Int(decryptionProgress * 100))%")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(.green.opacity(0.7))
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Decoded Section
    private var decodedSection: some View {
        VStack(spacing: 20) {
            Text("// DECODED TRANSMISSION")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.green.opacity(0.7))
            
            // Solution with typing cursor effect
            HStack(alignment: .top, spacing: 4) {
                Text(gameState.currentGame?.solution ?? "")
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
            
            if !gameState.quoteAuthor.isEmpty {
                Text("ORIGIN: \(gameState.quoteAuthor.uppercased())")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.green.opacity(0.7))
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
    
    // MARK: - Score Section
    private var scoreSection: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HACK_SCORE")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.green.opacity(0.6))
                
                Text("\(gameState.currentGame?.calculateScore() ?? 0)")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.5), radius: 5)
            }
            
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
                value: "\(gameState.currentGame?.mistakes ?? 0)/\(gameState.currentGame?.maxMistakes ?? 0)",
                icon: "exclamationmark.triangle",
                isOptimal: gameState.currentGame?.mistakes == 0
            )
            
            StatBlock(
                label: "TIME",
                value: formatTime(Int(gameState.currentGame?.lastUpdateTime.timeIntervalSince(gameState.currentGame?.startTime ?? Date()) ?? 0)),
                icon: "clock",
                isOptimal: Int(gameState.currentGame?.lastUpdateTime.timeIntervalSince(gameState.currentGame?.startTime ?? Date()) ?? 0) < 60
            )
            
            if gameState.isDailyChallenge {
                StatBlock(
                    label: "STREAK",
                    value: "\(userState.stats?.currentStreak ?? 0)",
                    icon: "flame",
                    isOptimal: (userState.stats?.currentStreak ?? 0) > 5
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
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("EXPORT")
                }
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.green)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.green, lineWidth: 1)
                )
            }
            
            // New cipher button
            Button(action: {
                SoundManager.shared.play(.letterClick)
                gameState.showWinMessage = false
                gameState.resetGame()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("NEW CIPHER")
                }
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.green)
                        .shadow(color: .green.opacity(0.5), radius: 10)
                )
            }
        }
    }
    
    // MARK: - Animation Sequence
    private func startHackSequence() {
        // Show content
        withAnimation(.easeOut(duration: 0.3)) {
            showContent = true
        }
        
        // Decryption animation
        withAnimation(.easeInOut(duration: 1.5)) {
            decryptionProgress = 1.0
        }
        
        // Glitch effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            glitchOffset = -5
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                glitchOffset = 5
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    glitchOffset = 0
                }
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
        .frame(minWidth: 80)
    }
}

// MARK: - Code Rain Background
struct CodeRainBackground: View {
    @State private var columns: [VaultCodeColumn] = []
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    // Character sets
    private let codeCharacters = "01アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン"
    private let matrixKatakana = "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝ"
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                // Code columns
                HStack(spacing: 0) {
                    ForEach(columns) { column in
                        VaultCodeColumnView(
                            column: column,
                            height: geometry.size.height,
                            characters: codeCharacters + matrixKatakana
                        )
                    }
                }
            }
            .onAppear {
                setupColumns(width: geometry.size.width)
            }
            .onReceive(timer) { _ in
                updateColumns()
            }
        }
    }
    
    private func setupColumns(width: CGFloat) {
        let columnWidth: CGFloat = 20
        let columnCount = Int(width / columnWidth)
        
        columns = (0..<columnCount).map { index in
            VaultCodeColumn(
                id: index,
                x: CGFloat(index) * columnWidth,
                characters: generateRandomCharacters(),
                offset: CGFloat.random(in: -500...0),
                speed: CGFloat.random(in: 5...15)
            )
        }
    }
    
    private func updateColumns() {
        for i in 0..<columns.count {
            columns[i].offset += columns[i].speed
            
            // Reset column when it goes off screen
            if columns[i].offset > 800 {
                columns[i].offset = CGFloat.random(in: -500...0)
                columns[i].characters = generateRandomCharacters()
                columns[i].speed = CGFloat.random(in: 5...15)
            }
        }
    }
    
    private func generateRandomCharacters() -> [String] {
        let allChars = Array(codeCharacters + matrixKatakana)
        return (0..<30).map { _ in
            String(allChars.randomElement() ?? "0")
        }
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
    }
}

// MARK: - Preview
#if DEBUG
struct VaultWinModal_Previews: PreviewProvider {
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
        
        return VaultWinModal()
            .environmentObject(gameState)
            .environmentObject(UserState.shared)
            .preferredColorScheme(.dark)
    }
}
#endif
