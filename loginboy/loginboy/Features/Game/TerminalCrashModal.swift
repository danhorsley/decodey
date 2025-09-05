import SwiftUI

struct TerminalCrashModal: View {
    @EnvironmentObject var gameState: GameState
    @State private var showSolutionOverlay = false
    
    // Animation states
    @State private var glitchOffset: CGFloat = 0
    @State private var showErrorText = false
    @State private var errorMessages: [String] = []
    @State private var showMainError = false
    @State private var terminalOutput = ""
    @State private var showButtons = false
    @State private var scanlineOffset: CGFloat = -200
    
    // Design system
    private let fonts = FontSystem.shared
    
    // Error messages that cascade
    private let cascadingErrors = [
        "ERROR: Buffer overflow at 0x7FF8",
        "CRITICAL: Cipher key corrupted",
        "WARNING: Decryption timeout exceeded",
        "FATAL: Security breach detected",
        "PANIC: Invalid memory access at 0x0000",
        "ERROR: Stack trace corrupted"
    ]
    
    // Sarcastic terminal messages
    private let terminalMessages = [
        "> Permission denied: Try sudo decrypt",
        "> Segmentation fault: Brain core dumped",
        "> 404: Decryption skills not found",
        "> Connection refused: Try turning your brain off and on again",
        "> 418: I'm a teapot, not a code breaker",
        "> Kernel panic: User incompetence detected",
        "> /dev/null has rejected your output"
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background with scan lines
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        // Scan line effect
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.05),
                                        Color.green.opacity(0.1),
                                        Color.green.opacity(0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 100)
                            .offset(y: scanlineOffset)
                            .blur(radius: 20)
                    )
            
            // Matrix rain effect in background
            MatrixRainBackground()
                .opacity(0.3)
            
            // Cascading error messages
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(errorMessages.enumerated()), id: \.offset) { index, message in
                    Text(message)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.red.opacity(0.8))
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            
            // Main content
            VStack(spacing: 32) {
                // SYSTEM FAILURE text with glitch
                if showMainError {
                    ZStack {
                        // Glitch copies
                        Text("DECRYPTION FAILED")
                            .font(.system(size: 48, weight: .black, design: .monospaced))
                            .foregroundColor(.red.opacity(0.5))
                            .offset(x: glitchOffset, y: 2)
                            .blur(radius: 1)
                        
                        Text("DECRYPTION FAILED")
                            .font(.system(size: 48, weight: .black, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.5))
                            .offset(x: -glitchOffset, y: -2)
                            .blur(radius: 1)
                        
                        Text("DECRYPTION FAILED")
                            .font(.system(size: 48, weight: .black, design: .monospaced))
                            .foregroundColor(.red)
                    }
                    .shadow(color: .red.opacity(0.8), radius: 20)
                    .scaleEffect(showMainError ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showMainError)
                }
                
                // Current game state with corruption
                VStack(spacing: 16) {
                    Text("LAST KNOWN STATE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                        .tracking(2)
                    
                    // Game display with glitch effect
                    ZStack {
                        // Corruption layer
                        Text(corruptedDisplay())
                            .font(fonts.solutionDisplayText())
                            .foregroundColor(.red.opacity(0.3))
                            .blur(radius: 0.5)
                        
                        // Actual display
                        Text(gameState.currentGame?.currentDisplay ?? "")
                            .font(fonts.solutionDisplayText())
                            .foregroundColor(.green)
                            .shadow(color: .green.opacity(0.5), radius: 2)
                    }
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        // Static noise overlay
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.05),
                                        Color.clear,
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .allowsHitTesting(false)
                    )
                }
                .offset(x: glitchOffset)
                
                // Terminal output
                HStack {
                    Text(terminalOutput)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.green.opacity(0.9))
                    
                    // Blinking cursor
                    Text("█")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.green)
                        .opacity(showButtons ? 0 : 1)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: showButtons)
                    
                    Spacer()
                }
                .frame(maxWidth: 500)
                .padding(.horizontal)
                
                // Action buttons (terminal style)
                if showButtons {
                    HStack(spacing: 20) {
                        // New cipher button
                        TerminalButton(
                            label: "[NEW CIPHER]",
                            color: .cyan,
                            action: {
                                SoundManager.shared.play(.letterClick)
                                showSolutionOverlay = true
                            }
                        )
                        
                        // Continue button
                        TerminalButton(
                            label: "[CONTINUE]",
                            color: .green,
                            isPrimary: true,
                            action: {
                                SoundManager.shared.play(.correctGuess)
                                let state = gameState
                                state.enableInfiniteMode()
                                gameState.showLoseMessage = false
                            }
                        )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(32)
            .frame(maxWidth: 600)
        }
        .onAppear {
            startCrashSequence(height: geometry.size.height)
        }
        .sheet(isPresented: $showSolutionOverlay) {
            TerminalSolutionOverlay()
                .environmentObject(gameState)
        }
        }
    }
    
    // MARK: - Animation Sequence
    
    private func startCrashSequence(height: CGFloat) {
        // Play crash sound
        SoundManager.shared.play(.lose)
        
        // Start scanline animation
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            scanlineOffset = height + 200
        }
        
        // Start glitch animation
        startGlitchEffect()
        
        // Cascade error messages
        for (index, error) in cascadingErrors.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                withAnimation {
                    errorMessages.append(error)
                }
            }
        }
        
        // Show main error
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                showMainError = true
            }
        }
        
        // Start terminal typing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            startTerminalTyping()
        }
        
        // Show buttons
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation {
                showButtons = true
            }
        }
    }
    
    private func startGlitchEffect() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            withAnimation(.linear(duration: 0.1)) {
                glitchOffset = CGFloat.random(in: -3...3)
            }
            
            // Stop after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                timer.invalidate()
                glitchOffset = 0
            }
        }
    }
    
    private func startTerminalTyping() {
        let message = terminalMessages.randomElement() ?? terminalMessages[0]
        terminalOutput = ""
        
        for (index, character) in message.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                terminalOutput.append(character)
                
                // Terminal beep sounds
                if character != " " && Bool.random() {
                    SoundManager.shared.play(.letterClick)
                }
            }
        }
    }
    
    private func corruptedDisplay() -> String {
        // Create a corrupted version of the display
        guard let display = gameState.currentGame?.currentDisplay else { return "" }
        
        var corrupted = ""
        for char in display {
            if char == "█" && Bool.random() {
                // Randomly corrupt some blocks
                corrupted.append(["▓", "▒", "░", "▪", "▫"].randomElement()!)
            } else {
                corrupted.append(char)
            }
        }
        return corrupted
    }
}

// MARK: - Terminal Button Component

struct TerminalButton: View {
    let label: String
    let color: Color
    var isPrimary: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color) // This should already be explicit
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isPrimary ? color.opacity(0.2) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(color, lineWidth: 2)
                        )
                )
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .shadow(color: color.opacity(0.5), radius: isHovered ? 10 : 5)
        }
        .buttonStyle(PlainButtonStyle()) // Add explicit button style
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Matrix Rain Background

struct MatrixRainBackground: View {
    @State private var offset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<20) { column in
                    MatrixColumnLoss(
                        columnIndex: column,
                        totalColumns: 20,
                        height: geometry.size.height,
                        width: geometry.size.width
                    )
                }
            }
        }
    }
}

struct MatrixColumnLoss: View {
    let columnIndex: Int
    let totalColumns: Int
    let height: CGFloat
    let width: CGFloat
    
    @State private var offset: CGFloat = 0
    
    private let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()_+-=[]{}|;:,.<>?"
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<30) { row in
                Text(String(characters.randomElement()!))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.green.opacity(Double(30 - row) / 30.0))
            }
        }
        .offset(y: offset)
        .onAppear {
            withAnimation(.linear(duration: Double.random(in: 5...10)).repeatForever(autoreverses: false)) {
                offset = height
            }
        }
        .position(
            x: CGFloat(columnIndex) * (width / CGFloat(totalColumns)),
            y: -height / 2
        )
    }
}

// MARK: - Terminal Solution Overlay

struct TerminalSolutionOverlay: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Terminal background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Terminal header
                HStack {
                    Circle().fill(Color.red).frame(width: 12, height: 12)
                    Circle().fill(Color.yellow).frame(width: 12, height: 12)
                    Circle().fill(Color.green).frame(width: 12, height: 12)
                    Spacer()
                    Text("SOLUTION.txt")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                    Spacer()
                }
                .padding(.horizontal)
                
                // Solution display
                VStack(alignment: .leading, spacing: 16) {
                    Text("$ cat solution.txt")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.green.opacity(0.7))
                    
                    Text(gameState.currentGame?.solution ?? "")
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding()
                    
                    if !gameState.quoteAuthor.isEmpty {
                        Text("# Author: \(gameState.quoteAuthor)")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.green.opacity(0.7))
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
                
                // Action
                TerminalButton(
                    label: "[EXECUTE NEW_GAME]",
                    color: .green,
                    isPrimary: true,
                    action: {
                        SoundManager.shared.play(.letterClick)
                        dismiss()
                        gameState.showLoseMessage = false
                        gameState.resetGame()
                    }
                )
            }
            .padding(32)
            .frame(maxWidth: 600)
        }
    }
}
