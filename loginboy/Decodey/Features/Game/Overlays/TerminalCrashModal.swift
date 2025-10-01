// OptimizedTerminalCrashModal.swift
// Decodey
//
// Performance-optimized version with same cool effects but less latency

import SwiftUI

struct TerminalCrashModal: View {
    @EnvironmentObject var gameState: GameState
    @State private var showSolutionOverlay = false
    
    // Simplified animation states
    @State private var animationPhase = 0
    @State private var glitchOffset: CGFloat = 0
    @State private var terminalText = ""
    @State private var matrixOpacity = 0.0
    
    // Design system
    private let fonts = FontSystem.shared
    
    // Pre-computed messages (avoid array lookups)
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
                    
                    // Buttons
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
        }
    }
    
    // MARK: - Optimized Animation Sequence
    
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
    
    // MARK: - View Components
    
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
    
    private var actionButtons: some View {
        HStack(spacing: 20) {
            Button(action: {
                SoundManager.shared.play(.letterClick)
                showSolutionOverlay = true
            }) {
                Text("[NEW CIPHER]")
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
            .buttonStyle(.plain)  // This prevents the default gray tint!
            
            Button(action: {
                SoundManager.shared.play(.correctGuess)
                gameState.enableInfiniteMode()
                gameState.showLoseMessage = false
            }) {
                Text("[CONTINUE]")
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
            .buttonStyle(.plain)  // This prevents the default gray tint!
        }
    }
}

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
