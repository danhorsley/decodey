// TerminalCrashModal.swift - Fixed version with proper two-button layout
// Preserving all the cool visual effects while fixing button logic

import SwiftUI

struct TerminalCrashModal: View {
    @EnvironmentObject var gameState: GameState
    @State private var showSolutionOverlay = false
    
    // Simplified animation states (keeping all the cool effects)
    @State private var animationPhase = 0
    @State private var glitchOffset: CGFloat = 0
    @State private var terminalText = ""
    @State private var matrixOpacity = 0.0
    
    // Pre-computed messages
    private let errorMessage = "CRITICAL: Decryption Failed"
    private let terminalMessage = "> Permission denied: Try sudo decrypt"
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with simple opacity animation
                Color.black
                    .ignoresSafeArea()
                
                // Simplified matrix effect (fewer columns)
                if matrixOpacity > 0 {
                    MatrixRainOptimized()
                        .opacity(matrixOpacity)
                }
                
                // Main content
                VStack(spacing: 32) {
                    // Error display with single animation
                    if animationPhase >= 1 {
                        errorDisplay
                            .transition(.scale.combined(with: .opacity))
                            .offset(x: glitchOffset)
                    }
                    
                    // Terminal output
                    if animationPhase >= 2 {
                        terminalDisplay
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Buttons - ONLY TWO BUTTONS
                    if animationPhase >= 3 {
                        actionButtons
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(32)
                .frame(maxWidth: 600)
            }
            .onAppear {
                startOptimizedSequence()
            }
            // Solution overlay sheet - matches GameLossModal
            .sheet(isPresented: $showSolutionOverlay) {
                TerminalSolutionOverlay()
                    .environmentObject(gameState)
            }
        }
    }
    
    // MARK: - Optimized Animation Sequence (keeping all the cool effects)
    
    private func startOptimizedSequence() {
        // Play sound once
        SoundManager.shared.play(.lose)
        
        // Single animation timeline using withAnimation
        withAnimation(.easeOut(duration: 0.3)) {
            matrixOpacity = 0.3
            animationPhase = 1
        }
        
        // Use fewer dispatch calls
        withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
            animationPhase = 2
            startGlitchEffect()
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(1.0)) {
            animationPhase = 3
        }
        
        // Type terminal text with optimized approach
        animateTerminalText()
    }
    
    // Optimized glitch - use SwiftUI animation instead of Timer
    private func startGlitchEffect() {
        withAnimation(.easeInOut(duration: 0.1).repeatCount(5)) {
            glitchOffset = 2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            glitchOffset = 0
        }
    }
    
    // Optimized terminal typing - batch updates
    private func animateTerminalText() {
        let text = terminalMessage
        var currentIndex = 0
        
        // Use single timer with batch updates
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            if currentIndex < text.count {
                // Batch update multiple characters at once
                let batchSize = min(3, text.count - currentIndex)
                let endIndex = text.index(text.startIndex, offsetBy: currentIndex + batchSize)
                let startIndex = text.index(text.startIndex, offsetBy: currentIndex)
                terminalText += String(text[startIndex..<endIndex])
                currentIndex += batchSize
                
                // Play sound less frequently (every 5th character)
                if currentIndex % 5 == 0 {
                    SoundManager.shared.play(.letterClick)
                }
            } else {
                timer.invalidate()
            }
        }
    }
    
    // MARK: - View Components (keeping all the cool visual effects)
    
    private var errorDisplay: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text(errorMessage)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.red)
        }
    }
    
    private var terminalDisplay: some View {
        HStack {
            Text(terminalText)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.green.opacity(0.9))
            
            // Simple blinking cursor
            Text("█")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.green)
                .opacity(animationPhase >= 3 ? 0 : 1)
                .animation(.easeInOut(duration: 0.5).repeatForever(), value: animationPhase)
            
            Spacer()
        }
        .frame(maxWidth: 500)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    // FIXED: Only TWO buttons matching GameLossModal structure
    private var actionButtons: some View {
        HStack(spacing: 20) {
            // See Solution button (matches GameLossModal)
            Button(action: {
                SoundManager.shared.play(.letterClick)
                showSolutionOverlay = true
            }) {
                Text("[SEE SOLUTION]")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.cyan, lineWidth: 2)
                            )
                    )
                    .shadow(color: .cyan.opacity(0.5), radius: 4)
            }
            .buttonStyle(.plain)
            
            // Keep Trying button with infinite mode (matches GameLossModal)
            Button(action: {
                SoundManager.shared.play(.correctGuess)
                gameState.enableInfiniteMode()  // Enable infinite mode
                gameState.showLoseMessage = false  // Dismiss the modal
            }) {
                Text("[KEEP TRYING]")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.green, lineWidth: 2)
                            )
                    )
                    .shadow(color: .green.opacity(0.6), radius: 6)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Terminal Solution Overlay (matches SolutionOverlay from GameLossModal)

struct TerminalSolutionOverlay: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Animation states
    @State private var displayedSolution = ""
    @State private var showAuthor = false
    @State private var showButtons = false
    @State private var glitchText = ""
    @State private var isGlitching = false
    
    var body: some View {
        ZStack {
            // Terminal-style background
            Color.black
                .ignoresSafeArea()
            
            // Scanlines effect
            GeometryReader { geometry in
                ForEach(0..<50) { index in
                    Rectangle()
                        .fill(Color.green.opacity(0.02))
                        .frame(height: 2)
                        .offset(y: CGFloat(index * 20))
                }
            }
            .blendMode(.plusLighter)
            
            VStack(spacing: 32) {
                // Header
                Text("// DECRYPTED OUTPUT //")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.green.opacity(0.7))
                
                // Solution display with terminal styling
                VStack(spacing: 20) {
                    // Solution text with typewriter effect
                    Text(displayedSolution)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                        .overlay(
                            // Glitch effect overlay
                            isGlitching ?
                            Text(glitchText)
                                .font(.system(size: 18, weight: .medium, design: .monospaced))
                                .foregroundColor(.green.opacity(0.5))
                                .offset(x: 2, y: 0)
                                .blendMode(.plusLighter)
                            : nil
                        )
                    
                    // Author attribution
                    if showAuthor {
                        HStack {
                            Text("> Author: ")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.green.opacity(0.5))
                            Text(gameState.quoteAuthor)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.green.opacity(0.8))
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    
                    // Attribution if available
                    if let attribution = gameState.quoteAttribution, !attribution.isEmpty, showAuthor {
                        Text("[\(attribution)]")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.green.opacity(0.4))
                            .italic()
                    }
                }
                
                // TWO buttons: Start New Game and Enable Infinite Mode
                if showButtons {
                    VStack(spacing: 16) {
                        // Primary: Start New Game button
                        Button(action: {
                            SoundManager.shared.play(.letterClick)
                            dismiss()  // Dismiss the solution overlay
                            gameState.showLoseMessage = false  // Hide the loss modal
                            
                            // Start a new game after a small delay for animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if gameState.isDailyChallenge {
                                    // If it was a daily, start a new random game
                                    gameState.setupCustomGame()
                                } else {
                                    // If it was random, start another random game
                                    gameState.setupCustomGame()
                                }
                            }
                        }) {
                            Text("[START NEW CIPHER]")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.green.opacity(0.8), lineWidth: 2)
                                        )
                                )
                                .shadow(color: .green.opacity(0.8), radius: 8)
                        }
                        .buttonStyle(.plain)
                        
                        // Secondary: Enable Infinite Mode
                        Button(action: {
                            SoundManager.shared.play(.correctGuess)
                            dismiss()  // Dismiss the solution overlay
                            gameState.enableInfiniteMode()  // Enable infinite mode
                            gameState.showLoseMessage = false  // Hide the loss modal
                        }) {
                            Text("[ENABLE GOD MODE]")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.black.opacity(0.6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.yellow.opacity(0.6), lineWidth: 1)
                                        )
                                )
                                .shadow(color: .yellow.opacity(0.3), radius: 3)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(40)
            .frame(maxWidth: 700)
        }
        .onAppear {
            animateSolution()
        }
    }
    
    // MARK: - Animation Functions
    
    private func animateSolution() {
        let solution = gameState.currentGame?.solution ?? ""
        
        // Typewriter effect for solution
        for (index, char) in solution.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.01) {
                displayedSolution.append(char)
                
                // Play sound every 10 characters
                if index % 10 == 0 {
                    SoundManager.shared.play(.letterClick)
                }
            }
        }
        
        // Show author after solution
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(solution.count) * 0.01 + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showAuthor = true
            }
        }
        
        // Show buttons
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(solution.count) * 0.01 + 1.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showButtons = true
            }
        }
        
        // Add subtle glitch effect
        startGlitchEffect()
    }
    
    private func startGlitchEffect() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            glitchText = String((gameState.currentGame?.solution ?? "").shuffled())
            
            withAnimation(.easeInOut(duration: 0.1)) {
                isGlitching = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.05)) {
                    isGlitching = false
                }
            }
        }
    }
}

// Note: MatrixRainOptimized view should remain unchanged from your original implementation
// Note: MatrixRainOptimized view should remain unchanged from your original implementation

// MARK: - Optimized Matrix Rain

struct MatrixRainOptimized: View {
    // Use fewer columns for better performance
    private let columns = 8 // Reduced from potentially 20+
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<columns, id: \.self) { column in
                MatrixColumnOptimized(columnIndex: column)
            }
        }
    }
}

// Replace UIScreen.main.bounds.height with GeometryReader approach
struct MatrixColumnOptimized: View {
    let columnIndex: Int
    @State private var offset: CGFloat = 0
    
    private let characters = "01"
    private let characterCount = 15
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 2) {
                ForEach(0..<characterCount, id: \.self) { index in
                    Text(String(characters.randomElement()!))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color.green.opacity(Double(characterCount - index) / Double(characterCount)))
                }
            }
            .offset(y: offset)
            .onAppear {
                withAnimation(
                    .linear(duration: Double.random(in: 8...12))
                    .repeatForever(autoreverses: false)
                    .delay(Double(columnIndex) * 0.2)
                ) {
                    offset = geometry.size.height + 100
                }
            }
        }
    }
}
