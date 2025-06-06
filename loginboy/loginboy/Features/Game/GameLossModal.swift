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
    
    // Design system
    private let colors = ColorSystem.shared
    private let fonts = FontSystem.shared
    
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
                            .font(fonts.solutionDisplayText())
                            .foregroundColor(colors.guessColor(for: colorScheme))
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
                            .scaleEffect(showStamp ? 1.0 : 3.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showStamp)
                    }
                    
                    // Ink splatters
                    ForEach(inkDrops) { drop in
                        InkSplatterView(drop: drop)
                    }
                }
                .frame(maxWidth: 500)
                
                // Editorial comment with typewriter effect
                Text(typewriterText)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundColor(editorialTextColor)
                    .italic()
                    .frame(height: 24)
                    .padding(.top, 8)
                
                // Action buttons
                if showButtons {
                    HStack(spacing: 16) {
                        // Secondary button - Show Solution
                        Button(action: {
                            SoundManager.shared.play(.letterClick)
                            showSolutionOverlay = true
                        }) {
                            Text("Show Solution")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.black) // Force explicit color
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
                        .buttonStyle(PlainButtonStyle()) // Add explicit button style
                        
                        // Primary button - Keep Trying
                        Button(action: {
                            SoundManager.shared.play(.correctGuess)
                            gameState.enableInfiniteMode()
                            gameState.showLoseMessage = false
                        }) {
                            Text("Keep Trying")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.black) // Force explicit color
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(primaryButtonColor)
                                )
                        }
                        .buttonStyle(PlainButtonStyle()) // Add explicit button style
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
            .scaleEffect(showStamp ? 1.0 : 0.9)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showStamp)
        }
        .onAppear {
            startAnimationSequence()
        }
        .sheet(isPresented: $showSolutionOverlay) {
            SolutionOverlay()
                .environmentObject(gameState)
        }
    }
    
    // MARK: - Animation Sequence
    
    private func startAnimationSequence() {
        // Play lose sound
        SoundManager.shared.play(.lose)
        
        // Show stamp after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                showStamp = true
            }
            
            // Generate ink splatters
            generateInkSplatters()
            
            // Start typewriter effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startTypewriterEffect()
            }
            
            // Show buttons
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    showButtons = true
                }
            }
        }
    }
    
    private func generateInkSplatters() {
        // Create 5-8 random ink drops around the stamp
        let dropCount = Int.random(in: 5...8)
        
        for i in 0..<dropCount {
            let drop = InkDrop(
                id: i,
                x: CGFloat.random(in: -100...100),
                y: CGFloat.random(in: -80...80),
                size: CGFloat.random(in: 8...24),
                opacity: Double.random(in: 0.6...0.9),
                delay: Double.random(in: 0...0.3)
            )
            
            DispatchQueue.main.asyncAfter(deadline: .now() + drop.delay) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    inkDrops.append(drop)
                }
            }
        }
    }
    
    private func startTypewriterEffect() {
        let comment = editorialComments.randomElement() ?? editorialComments[0]
        typewriterText = ""
        
        for (index, character) in comment.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                typewriterText.append(character)
                
                // Play subtle typewriter sound for each character
                if character != " " {
                    SoundManager.shared.play(.letterClick)
                }
            }
        }
    }
    
    // MARK: - Color Helpers
    
    private var backgroundColor: Color {
        colorScheme == .dark ?
            Color(hex: "1C1C1E") :
            Color(hex: "F5F2E8") // Cream paper color
    }
    
    private var modalBackground: Color {
        colorScheme == .dark ?
            Color.black.opacity(0.9) :
            Color.white
    }
    
    private var borderColor: Color {
        colorScheme == .dark ?
            Color.white.opacity(0.1) :
            Color.black.opacity(0.1)
    }
    
    private var stampColor: Color {
        colorScheme == .dark ?
            Color(hex: "FF453A") : // Bright red for dark mode
            Color(hex: "C41E3A")   // Deep red for light mode
    }
    
    private var editorialTextColor: Color {
        colorScheme == .dark ?
            Color.white.opacity(0.7) :
            Color.black.opacity(0.7)
    }
    
    private var primaryButtonColor: Color {
        colorScheme == .dark ?
            Color(hex: "4cc9f0") :
            Color.blue
    }
    
    private var secondaryButtonBackground: Color {
        colorScheme == .dark ?
            Color.white.opacity(0.1) :
            Color.black.opacity(0.05)
    }
    
    private var secondaryButtonBorder: Color {
        colorScheme == .dark ?
            Color.white.opacity(0.2) :
            Color.black.opacity(0.2)
    }
    
    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ?
            Color.white.opacity(0.8) :
            Color.black.opacity(0.7)
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
    @Environment(\.colorScheme) var colorScheme
    
    private let colors = ColorSystem.shared
    private let fonts = FontSystem.shared
    
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
                        .font(.system(size: 20, weight: .medium, design: .serif))
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    if !gameState.quoteAuthor.isEmpty {
                        Text("— \(gameState.quoteAuthor)")
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: 500)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(cardBackground)
                )
                
                Button(action: {
                    SoundManager.shared.play(.letterClick)
//                    showSolutionOverlay = false
                    gameState.showLoseMessage = false
                    gameState.resetGame()
                }) {
                    Text("New Game")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(buttonColor)
                        )
                }
            }
            .padding(32)
        }
    }
    
    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ?
            Color(hex: "1C1C1E") :
            Color(hex: "F5F2E8")
    }
    
    private var buttonColor: Color {
        colorScheme == .dark ?
            Color(hex: "4cc9f0") :
            Color.blue
    }
}

//
//  GameLossModal.swift
//  loginboy
//
//  Created by Daniel Horsley on 06/06/2025.
//

