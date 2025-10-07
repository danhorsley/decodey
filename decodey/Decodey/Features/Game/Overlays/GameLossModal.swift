import SwiftUI

struct GameLossModal: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.colorScheme) var colorScheme
    @State private var showSolutionOverlay = false
    
    // Animation states
    @State private var showStamp = false
    @State private var showInkSplatters = false
    @State private var typewriterText = ""
    @State private var showButtons = false
    @State private var inkDrops: [InkDrop] = []
    
    // Editorial comments
    private let editorialComments = [
        "Not quite ready for publication...",
        "Needs more work, junior.",
        "Almost had it, rookie!",
        "Back to the drawing board.",
        "Close, but no Pulitzer.",
        "The editor won't be pleased.",
        "Try again, cub reporter."
    ]
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { } // Prevent dismissal by tapping outside
            
            // Main content
            VStack(spacing: 24) {
                // Game display area with stamp overlay
                ZStack {
                    // Current game state
                    VStack(spacing: 16) {
                        Text("YOUR ATTEMPT")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .tracking(1.5)
                            .foregroundColor(.secondary)
                        
                        Text(gameState.currentGame?.currentDisplay ?? "")
                            .font(.gameDisplay)
                            .foregroundColor(Color("GameGuess"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(backgroundColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(borderColor, lineWidth: 1)
                                    )
                            )
                    }
                    .blur(radius: showStamp ? 0.5 : 0)
                    
                    // REJECTED stamp
                    if showStamp {
                        Text("REJECTED")
                            .font(.system(size: 60, weight: .black, design: .serif))
                            .foregroundColor(stampColor)
                            .rotationEffect(.degrees(-15))
                            .opacity(0.8)
                            .scaleEffect(showStamp ? 1.0 : 0.1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.3), value: showStamp)
                    }
                }
                
                // Ink splatters
                if showInkSplatters {
                    ZStack {
                        ForEach(inkDrops) { drop in
                            InkSplatterView(drop: drop)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(drop.delay), value: showInkSplatters)
                        }
                    }
                    .frame(width: 300, height: 100)
                }
                
                // Editorial comment
                if !typewriterText.isEmpty {
                    Text(typewriterText)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .italic()
                        .foregroundColor(editorialTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                }
                
                // Action buttons - FIXED to enable infinite mode
                if showButtons {
                    HStack(spacing: 16) {
                        // See Solution button
                        Button(action: {
                            SoundManager.shared.play(.letterClick)
                            showSolutionOverlay = true
                        }) {
                            Text("See Solution")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(secondaryButtonTextColor)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(secondaryButtonBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(secondaryButtonBorder, lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // FIXED: Keep Trying button now enables infinite mode
                        Button(action: {
                            SoundManager.shared.play(.letterClick)
                            gameState.enableInfiniteMode()  // Enable infinite mode!
                            gameState.showLoseMessage = false  // Dismiss modal
                        }) {
                            Text("Keep Trying")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.black)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(primaryButtonColor)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(32)
            .frame(maxWidth: 600)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(modalBackground)
                    .shadow(radius: 20)
            )
            .scaleEffect(showStamp ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: showStamp)
        }
        .onAppear {
            animateReveal()
        }
        .sheet(isPresented: $showSolutionOverlay) {
            SolutionOverlay()
                .environmentObject(gameState)  // Pass gameState to solution overlay
        }
    }
    
    // MARK: - Animation Functions
    
    private func animateReveal() {
        // Generate ink drops
        for i in 0..<8 {
            inkDrops.append(InkDrop(
                id: i,
                x: CGFloat.random(in: -150...150),
                y: CGFloat.random(in: -50...50),
                size: CGFloat.random(in: 8...24),
                opacity: Double.random(in: 0.3...0.7),
                delay: Double(i) * 0.05
            ))
        }
        
        // Stamp animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                showStamp = true
                SoundManager.shared.play(.letterClick) // Stamp sound
            }
        }
        
        // Ink splatter
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showInkSplatters = true
        }
        
        // Typewriter effect for editorial comment
        let comment = editorialComments.randomElement() ?? "Try again, junior."
        for (index, char) in comment.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2 + Double(index) * 0.05) {
                typewriterText.append(char)
                if index % 5 == 0 {
                    SoundManager.shared.play(.letterClick)
                }
            }
        }
        
        // Show buttons
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showButtons = true
            }
        }
    }
    
    // MARK: - Color Computed Properties
    
    private var backgroundColor: Color {
        colorScheme == .dark ?
            Color(hex: "1C1C1E") :
            Color(hex: "F2F2F7")
    }
    
    private var borderColor: Color {
        colorScheme == .dark ?
            Color.white.opacity(0.1) :
            Color.black.opacity(0.1)
    }
    
    private var stampColor: Color {
        colorScheme == .dark ?
            Color(hex: "FF453A") :
            Color(hex: "FF3B30")
    }
    
    private var modalBackground: Color {
        colorScheme == .dark ?
            Color(hex: "2C2C2E") :
            Color.white
    }
    
    private var editorialTextColor: Color {
        colorScheme == .dark ?
            Color.white.opacity(0.6) :
            Color.black.opacity(0.5)
    }
    
    private var secondaryButtonBackground: Color {
        colorScheme == .dark ?
            Color.white.opacity(0.1) :
            Color.black.opacity(0.05)
    }
    
    private var secondaryButtonBorder: Color {
        colorScheme == .dark ?
            Color.white.opacity(0.2) :
            Color.black.opacity(0.1)
    }
    
    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ?
            Color.white.opacity(0.9) :
            Color.black.opacity(0.6)
    }
    
    private var primaryButtonColor: Color {
        colorScheme == .dark ?
            Color(hex: "0A84FF") :
            Color(hex: "007AFF")
    }
}

// MARK: - Ink Drop Model

struct InkDrop: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let delay: Double
}

// MARK: - Ink Splatter View

struct InkSplatterView: View {
    let drop: InkDrop
    @State private var isVisible = false
    @Environment(\.colorScheme) var colorScheme
    
    private var inkColor: Color {
        colorScheme == .dark ?
            Color(hex: "FF453A") :
            Color(hex: "C41E3A")
    }
    
    var body: some View {
        Circle()
            .fill(inkColor)
            .frame(width: drop.size, height: drop.size)
            .opacity(isVisible ? drop.opacity : 0)
            .scaleEffect(isVisible ? 1.0 : 0.1)
            .offset(x: drop.x, y: drop.y)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Solution Overlay (separate view)

struct SolutionOverlay: View {
    @EnvironmentObject var gameState: GameState
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("THE SOLUTION")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.secondary)
                
                // Solution text
                VStack(spacing: 16) {
                    Text(gameState.currentGame?.solution ?? "")
                        .font(.gameDisplay)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(backgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(borderColor, lineWidth: 1)
                                )
                        )
                    
                    // Author attribution
                    VStack(spacing: 8) {
                        Text("— \(gameState.quoteAuthor)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        if let attribution = gameState.quoteAttribution, !attribution.isEmpty {
                            Text(attribution)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
                
                // Action buttons
                VStack(spacing: 16) {
                    // Primary: Start New Game
                    Button(action: {
                        SoundManager.shared.play(.letterClick)
                        dismiss()
                        gameState.showLoseMessage = false
                        
                        // Start new game after small delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if gameState.isDailyChallenge {
                                gameState.setupCustomGame()  // Switch to random after daily
                            } else {
                                gameState.setupCustomGame()  // New random game
                            }
                        }
                    }) {
                        Text("Start New Game")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(primaryButtonColor)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Secondary: Enable Infinite Mode
                    Button(action: {
                        SoundManager.shared.play(.correctGuess)
                        dismiss()
                        gameState.enableInfiniteMode()  // Enable infinite mode
                        gameState.showLoseMessage = false
                    }) {
                        Text("Enable Infinite Mode")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(infiniteButtonTextColor)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(secondaryButtonBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(infiniteButtonBorder, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(40)
            .frame(maxWidth: 600)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(modalBackground)
                    .shadow(radius: 30)
            )
        }
    }
    
    // MARK: - Computed Color Properties
    
    private var backgroundColor: Color {
        colorScheme == .dark ?
            Color(hex: "2C2C2E") :
            Color(hex: "F2F2F7")
    }
    
    private var borderColor: Color {
        colorScheme == .dark ?
            Color.white.opacity(0.15) :
            Color.black.opacity(0.1)
    }
    
    private var modalBackground: Color {
        colorScheme == .dark ?
            Color(hex: "1C1C1E") :
            Color.white
    }
    
    private var primaryButtonColor: Color {
        colorScheme == .dark ?
            Color(hex: "0A84FF") :
            Color(hex: "007AFF")
    }
    
    private var secondaryButtonBackground: Color {
        colorScheme == .dark ?
            Color.yellow.opacity(0.1) :
            Color.yellow.opacity(0.08)
    }
    
    private var infiniteButtonBorder: Color {
        colorScheme == .dark ?
            Color.yellow.opacity(0.4) :
            Color.orange.opacity(0.3)
    }
    
    private var infiniteButtonTextColor: Color {
        colorScheme == .dark ?
            Color.yellow :
            Color.orange
    }
}


