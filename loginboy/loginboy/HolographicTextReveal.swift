import SwiftUI

// Safe HolographicRevealEffect that won't crash
struct HolographicRevealEffect: View {
    let text: String
    let active: Bool
    
    // State variables
    @State private var revealProgress: Double = 0.0
    @State private var shimmerPosition: Double = 0.0
    @State private var displayText: String = ""
    @State private var glitchActive: Bool = false
    
    var body: some View {
        ZStack {
            // Background grid
            GridBackgroundView()
                .opacity(0.3)
            
            // Text display
            Text(displayText)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                // Add shimmer effect
                .overlay(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: shimmerPosition - 0.2),
                            .init(color: .white.opacity(0.5), location: shimmerPosition),
                            .init(color: .clear, location: shimmerPosition + 0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.overlay)
                )
                // Apply glitch effect randomly
                .offset(x: glitchActive ? CGFloat.random(in: -3...3) : 0)
        }
        .onAppear {
            setupEffect()
        }
        .onChange(of: active) { isActive in
            if isActive {
                setupEffect()
            } else {
                // Reset the effect
                displayText = ""
                revealProgress = 0.0
            }
        }
    }
    
    // Setup the effect
    private func setupEffect() {
        // Initialize with spaces
        displayText = String(repeating: " ", count: text.count)
        
        // Start shimmer animation
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            shimmerPosition = 1.0
        }
        
        // Start character reveal animation
        startRevealSequence()
    }
    
    // Safe character array modification
    private func safeReplaceCharacter(at index: Int, with character: Character) {
        guard index >= 0 && index < displayText.count else { return }
        
        var characters = Array(displayText)
        characters[index] = character
        displayText = String(characters)
    }
    
    // Start the reveal sequence
    private func startRevealSequence() {
        // Start with empty display
        let textArray = Array(text)
        let totalChars = textArray.count
        
        // Schedule gradual reveal
        let totalRevealTime = 3.0 // seconds
        let charRevealInterval = totalRevealTime / Double(totalChars)
        
        // Random glitch effect
        let glitchTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            // Random chance of glitch
            if Bool.random() && revealProgress < 1.0 {
                glitchActive = true
                
                // Reset after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    glitchActive = false
                }
                
                // Add random character glitches if not fully revealed
                if revealProgress < 0.9 {
                    // Choose a random position to glitch
                    let randomIndex = Int.random(in: 0..<totalChars)
                    let randomChar = randomGlitchChar()
                    
                    // Only glitch if character not yet revealed
                    let revealedIndex = Int(Double(totalChars) * revealProgress)
                    if randomIndex > revealedIndex {
                        safeReplaceCharacter(at: randomIndex, with: randomChar)
                        
                        // Reset to space after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            safeReplaceCharacter(at: randomIndex, with: " ")
                        }
                    }
                }
            }
        }
        
        // Reveal each character sequentially with a slight delay
        for (index, char) in textArray.enumerated() {
            // Calculate delay for this character
            let delay = charRevealInterval * Double(index)
            
            // Schedule reveal
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Only proceed if index is still valid
                guard index < totalChars else { return }
                
                // Update progress
                revealProgress = Double(index) / Double(totalChars)
                
                // Reveal the character with small random chance to delay
                if Bool.random() {
                    safeReplaceCharacter(at: index, with: char)
                } else {
                    // Slight additional delay for some characters
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        safeReplaceCharacter(at: index, with: char)
                    }
                }
                
                // If we're at the last character, schedule cleanup
                if index == totalChars - 1 {
                    // Final progress
                    revealProgress = 1.0
                    
                    // Ensure the final text is correct
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        displayText = text
                        
                        // Stop the glitch timer
                        glitchTimer.invalidate()
                    }
                }
            }
        }
    }
    
    // Generate a random character for glitch effect
    private func randomGlitchChar() -> Character {
        let glitchChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-=_+[]{}|;:'\",.<>/?\\`~"
        return glitchChars.randomElement() ?? "X"
    }
}

// Grid background
struct GridBackgroundView: View {
    var body: some View {
        Canvas { context, size in
            // Draw horizontal grid lines
            for y in stride(from: 0, to: size.height, by: 10) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.cyan.opacity(0.2)), lineWidth: 0.5)
            }
            
            // Draw vertical grid lines
            for x in stride(from: 0, to: size.width, by: 10) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.cyan.opacity(0.2)), lineWidth: 0.5)
            }
        }
    }
}

// Bool random with probability
extension Bool {
    static func random(withProbability probability: Double = 0.5) -> Bool {
        return Double.random(in: 0...1) < probability
    }
}

// Safe Win Overlay with Matrix Background and Holographic Effect
struct SafeWinOverlayView: View {
    let solution: String
    let mistakes: Int
    let maxMistakes: Int
    let timeTaken: Int
    let score: Int
    let isDarkMode: Bool
    let onPlayAgain: () -> Void
    
    @State private var showRevealEffect = true
    @State private var showScore = false
    @State private var showStats = false
    @State private var showButton = false
    
    var body: some View {
        ZStack {
            // Matrix effect background - First layer
            SimpleMatrixEffect()
                .edgesIgnoringSafeArea(.all)
            
            // Semi-transparent overlay for better contrast
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            // Content
            VStack(spacing: 24) {
                // Win message
                Text("YOU WIN!")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.7), radius: 5)
                
                // Solution with holographic reveal effect
                HolographicRevealEffect(text: solution, active: showRevealEffect)
                    .frame(height: 50)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                
                // Score display
                VStack(spacing: 8) {
                    Text("SCORE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    
                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .shadow(color: .green.opacity(0.7), radius: 3)
                }
                .padding()
                .frame(width: 200)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .opacity(showScore ? 1 : 0)
                .scaleEffect(showScore ? 1 : 0.8)
                
                // Game stats
                HStack(spacing: 30) {
                    VStack {
                        Text("Mistakes")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("\(mistakes)/\(maxMistakes)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    VStack {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(formatTime(timeTaken))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical)
                .opacity(showStats ? 1 : 0)
                .offset(y: showStats ? 0 : 20)
                
                // Play again button
                Button(action: onPlayAgain) {
                    Text("Play Again")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .green.opacity(0.5), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(showButton ? 1 : 0)
                .scaleEffect(showButton ? 1 : 0.8)
            }
            .padding(40)
            .background(Color.black.opacity(0.7))
            .cornerRadius(20)
            .onAppear {
                // Staggered animations for each element
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.spring()) {
                        showScore = true
                    }
                }
                
                // Show stats after score
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showStats = true
                    }
                }
                
                // Show button last
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.spring()) {
                        showButton = true
                    }
                }
            }
        }
    }
    
    // Format time in seconds to MM:SS
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Simplified Matrix Effect for better performance
struct SimpleMatrixEffect: View {
    @State private var characters = Array(repeating: Array(repeating: " ", count: 15), count: 15)
    @State private var timer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 2) {
                    ForEach(0..<characters.count, id: \.self) { row in
                        HStack(spacing: 4) {
                            ForEach(0..<characters[row].count, id: \.self) { col in
                                Text(characters[row][col])
                                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                                    .foregroundColor(matrixColor(row: row))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func matrixColor(row: Int) -> Color {
        let intensity = 1.0 - (Double(row) / Double(characters.count)) * 0.6
        return Color.green.opacity(intensity)
    }
    
    private func startAnimation() {
        // Initialize with random characters
        updateRandomCharacters()
        
        // Create timer to update characters
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateRandomCharacters()
        }
    }
    
    private func updateRandomCharacters() {
        // Make a copy of current state
        var newChars = characters
        
        // Update a few random characters
        for _ in 0..<10 {
            let row = Int.random(in: 0..<characters.count)
            let col = Int.random(in: 0..<characters[0].count)
            newChars[row][col] = randomMatrixChar()
        }
        
        // Update state with new characters
        characters = newChars
    }
    
    private func randomMatrixChar() -> String {
        let charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-*/=!?><$"
        return String(charset.randomElement() ?? "X")
    }
}
