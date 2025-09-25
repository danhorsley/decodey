import SwiftUI

struct TypewriterTerminalTitle: View {
    let text: String
    let isTerminalMode: Bool // true for dark mode (terminal), false for light mode (typewriter)
    
    @State private var displayedText = ""
    @State private var currentIndex = 0
    @State private var showCursor = true
    @State private var glitchOffset: CGFloat = 0
    @State private var glitchOpacity: Double = 0
    @State private var inkBleed: CGFloat = 0
    @State private var strikeOpacity: Double = 0
    
    // Timer for typing effect
    @State private var typingTimer: Timer?
    @State private var cursorTimer: Timer?
    @State private var glitchTimer: Timer?
    
    var body: some View {
        ZStack {
            if isTerminalMode {
                // Terminal mode (dark theme)
                terminalView
            } else {
                // Typewriter mode (light theme)
                typewriterView
            }
        }
        .onAppear {
            startTypingAnimation()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    // MARK: - Terminal View (Dark Mode)
    
    private var terminalView: some View {
        ZStack {
            // Main text with phosphor glow
            Text(displayedText)
                .font(.custom("Courier New", size: 36).weight(.bold))
                .foregroundColor(Color(hex: "4cc9f0"))
                .shadow(color: Color(hex: "4cc9f0").opacity(0.8), radius: 4)
                .shadow(color: Color(hex: "4cc9f0").opacity(0.4), radius: 8)
                .shadow(color: Color(hex: "4cc9f0").opacity(0.2), radius: 16)
                .overlay(
                    // Scan line effect
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.03),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 3)
                        .offset(y: glitchOffset)
                        .allowsHitTesting(false)
                )
            
            // Glitch duplicate (occasional)
            Text(displayedText)
                .font(.custom("Courier New", size: 36).weight(.bold))
                .foregroundColor(Color(hex: "4cc9f0"))
                .opacity(glitchOpacity)
                .offset(x: 2, y: -1)
                .blur(radius: 0.5)
            
            // Blinking cursor
            if showCursor && currentIndex < text.count {
                Text("_")
                    .font(.custom("Courier New", size: 36).weight(.bold))
                    .foregroundColor(Color(hex: "4cc9f0"))
                    .shadow(color: Color(hex: "4cc9f0").opacity(0.8), radius: 4)
                    .offset(x: cursorOffset())
                    .opacity(showCursor ? 1 : 0)
            }
        }
    }
    
    // MARK: - Typewriter View (Light Mode)
    
    private var typewriterView: some View {
        ZStack {
            // Ink bleed/smudge layer
            Text(displayedText)
                .font(.custom("Courier New", size: 36).weight(.bold))
                .foregroundColor(Color.black.opacity(0.1))
                .blur(radius: inkBleed)
                .offset(x: 0.5, y: 0.5)
            
            // Main typed text
            Text(displayedText)
                .font(.custom("Courier New", size: 36).weight(.bold))
                .foregroundColor(Color.black.opacity(0.85))
                .overlay(
                    // Strike effect for current letter
                    GeometryReader { geometry in
                        if currentIndex > 0 && currentIndex <= text.count {
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: 20, height: 40)
                                .opacity(strikeOpacity)
                                .offset(x: strikeOffset(in: geometry.size.width))
                                .blur(radius: 1)
                        }
                    }
                )
            
            // Type bar animation (the little blocks you mentioned)
            if currentIndex < text.count {
                Text("█")
                    .font(.custom("Courier New", size: 36))
                    .foregroundColor(Color.black.opacity(0.3))
                    .offset(x: cursorOffset())
                    .scaleEffect(strikeOpacity > 0 ? 1.2 : 1.0)
            }
        }
    }
    
    // MARK: - Animation Logic
    
    private func startTypingAnimation() {
        // Reset state
        displayedText = ""
        currentIndex = 0
        
        // Start cursor blink
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            showCursor.toggle()
        }
        
        // Start typing
        typingTimer = Timer.scheduledTimer(withTimeInterval: isTerminalMode ? 0.08 : 0.12, repeats: true) { timer in
            if currentIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: currentIndex)
                displayedText.append(text[index])
                currentIndex += 1
                
                // Trigger effects
                if isTerminalMode {
                    // Terminal effects
                    if Bool.random() && Double.random(in: 0...1) < 0.1 { // 10% chance
                        triggerGlitch()
                    }
                } else {
                    // Typewriter effects
                    triggerStrike()
                    
                    // Play typewriter sound if enabled
                    SoundManager.shared.play(.letterClick)
                }
            } else {
                timer.invalidate()
                cursorTimer?.invalidate()
                showCursor = false
            }
        }
        
        // Terminal-specific animations
        if isTerminalMode {
            startScanLineAnimation()
            startOccasionalGlitch()
        }
    }
    
    private func triggerStrike() {
        withAnimation(.easeOut(duration: 0.1)) {
            strikeOpacity = 0.3
            inkBleed = 1.5
        }
        
        withAnimation(.easeIn(duration: 0.3).delay(0.1)) {
            strikeOpacity = 0
            inkBleed = 0.8
        }
    }
    
    private func triggerGlitch() {
        withAnimation(.easeInOut(duration: 0.1)) {
            glitchOpacity = 0.4
        }
        
        withAnimation(.easeInOut(duration: 0.1).delay(0.05)) {
            glitchOpacity = 0
        }
    }
    
    private func startScanLineAnimation() {
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            glitchOffset = 300
        }
    }
    
    private func startOccasionalGlitch() {
        glitchTimer = Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { _ in
            if Bool.random() { // 50% chance every 4.5 seconds
                triggerGlitch()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func cursorOffset() -> CGFloat {
        // Calculate approximate offset based on character count
        let charWidth: CGFloat = 21.6 // Approximate width of Courier New at size 36
        let offset = CGFloat(displayedText.count) * charWidth / 2
        return offset
    }
    
    private func strikeOffset(in totalWidth: CGFloat) -> CGFloat {
        // Position the strike effect at the last typed character
        let charWidth: CGFloat = 21.6
        let textWidth = CGFloat(displayedText.count) * charWidth
        let startX = (totalWidth - textWidth) / 2
        return startX + CGFloat(max(0, currentIndex - 1)) * charWidth
    }
    
    private func cleanup() {
        typingTimer?.invalidate()
        cursorTimer?.invalidate()
        glitchTimer?.invalidate()
    }
}

// MARK: - Updated Game Header

struct AnimatedGameHeader: View {
    let isDailyChallenge: Bool
    let dateString: String?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            if isDailyChallenge {
                // Daily challenge header
                VStack(spacing: 8) {
                    TypewriterTerminalTitle(
                        text: "decodey daily",
                        isTerminalMode: colorScheme == .dark
                    )
                    .frame(height: 44)
                    
                    if let dateString = dateString {
                        Text(dateString.uppercased())
                            .font(.custom("Courier New", size: 14).weight(.medium))
                            .tracking(1.5)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            } else {
                // Custom game with animated decodey title
                VStack(spacing: 8) {
                    TypewriterTerminalTitle(
                        text: "decodey",
                        isTerminalMode: colorScheme == .dark
                    )
                    .frame(height: 44)
                    
                    Text("CLASSIC MODE")
                        .font(.custom("Courier New", size: 12).weight(.medium))
                        .tracking(1.5)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}

// MARK: - Preview

struct TypewriterTerminalTitle_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Light mode preview
            AnimatedGameHeader(isDailyChallenge: false, dateString: nil)
                .preferredColorScheme(.light)
                .background(Color.primary.opacity(0.05))
            
            // Dark mode preview
            AnimatedGameHeader(isDailyChallenge: true, dateString: "November 5, 2024")
                .preferredColorScheme(.dark)
                .background(Color.primary.opacity(0.05))
        }
        .padding()
    }
}
