import SwiftUI
import Combine

struct HomeScreen: View {
    // Callback for when the welcome animation completes
    let onBegin: () -> Void
    var onShowLogin: (() -> Void)? = nil
    
    // Animation states
    @State private var showTitle = false
    @State private var decryptedChars: [Bool] = Array(repeating: false, count: "DECODEY".count)
    @State private var showSubtitle = false
    @State private var showButtons = false
    @State private var codeRain = true
    @State private var pulseEffect = false
    @State private var buttonScale: CGFloat = 1.0
    // Removed showLoginSheet as we're now using a callback approach
    
    // For the code rain effect
    @State private var columns: [CodeColumn] = []
    
    // Environment values
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.displayScale) var displayScale
    
    // Timer publisher for continuous animations
    @State private var timerCancellable: AnyCancellable?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - dark with code rain
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                // Code rain effect (The Matrix-style falling characters)
                if codeRain {
                    CodeRainView(columns: $columns)
                        .opacity(0.5)
                }
                
                // Content container
                VStack(spacing: 40) {
                    // Logo area with glitch effects
                    VStack(spacing: 5) {
                        // Main title with decryption effect
                        HStack(spacing: 0) {
                            ForEach(Array("decodey".enumerated()), id: \.offset) { index, char in
                                Text(decryptedChars[index] ? String(char) : randomCryptoChar())
                                    .font(.system(size: 50, weight: .bold, design: .monospaced))
                                    .foregroundColor(titleColor(for: index))
                                    .opacity(showTitle ? 1 : 0)
                                    .scaleEffect(decryptedChars[index] ? 1.0 : 0.8)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: decryptedChars[index])
                            }
                        }
                        .shadow(color: .cyan.opacity(0.6), radius: 10, x: 0, y: 0)
                        
                        // Subtitle with fade-in
                        Text("CRACK THE CODE")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .tracking(8)
                            .foregroundColor(.gray)
                            .opacity(showSubtitle ? 1 : 0)
                            .padding(.top, 10)
                    }
                    .padding(.top, 80)
                    
                    Spacer()
                    
                    // Animated circuit board design
                    CircuitBoardView()
                        .frame(height: 160)
                        .opacity(showSubtitle ? 0.6 : 0)
                    
                    Spacer()
                    
                    // Buttons container
                    VStack(spacing: 16) {
                        // Play button
                        Button(action: {
                            // Play button sound
                            SoundManager.shared.play(.correctGuess)
                            
                            // Tap animation
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                buttonScale = 0.9
                            }
                            
                            // Return to normal scale
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.1)) {
                                buttonScale = 1.0
                            }
                            
                            // Short delay before completing
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation {
                                    // Trigger onBegin callback instead of onComplete
                                    onBegin()
                                }
                            }
                        }) {
                            Text("BEGIN DECRYPTION")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 40)
                                .padding(.vertical, 20)
                                .background(
                                    ZStack {
                                        // Button background with scanner line
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.black)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.cyan.opacity(0.8), lineWidth: 2)
                                            )
                                        
                                        // Scanner line effect
                                        Rectangle()
                                            .fill(Color.cyan.opacity(0.7))
                                            .frame(height: 2)
                                            .offset(y: pulseEffect ? 25 : -25)
                                            .blur(radius: 2)
                                            .mask(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.white, lineWidth: 42)
                                            )
                                    }
                                )
                                .foregroundColor(.cyan)
                                .shadow(color: .cyan.opacity(0.6), radius: 10, x: 0, y: 0)
                        }
                        .scaleEffect(buttonScale)
                        .opacity(showButtons ? 1 : 0)
                        
                        // Login button (styled more subtly)
                        Button(action: {
                            // Play a subtle click sound
                            SoundManager.shared.play(.letterClick)
                            
                            // Call the login callback if provided
                            if let onShowLogin = onShowLogin {
                                // Short delay for animation to complete
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onShowLogin()
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 16))
                                Text("Log In")
                                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
                            )
                        }
                        .opacity(showButtons ? 1 : 0)
                    }
                    .padding(.bottom, 60)
                }
                .padding()
            }
            .onAppear {
                // Wrap the setup in a Task to avoid modifying state during view update
                Task {
                    // Setup the code columns
                    setupCodeColumns(screenWidth: geometry.size.width)
                    
                    // Start animations after a very short delay to avoid state modification during render
                    DispatchQueue.main.async {
                        // Start the welcome animation sequence
                        startAnimationSequence()
                        
                        // Setup continuous animations
                        setupContinuousAnimations()
                    }
                }
            }
            .onDisappear {
                // Clean up timer
                timerCancellable?.cancel()
            }
        }
    }
    
    // MARK: - Animations and Setup
    
    private func setupCodeColumns(screenWidth: CGFloat) {
        // Create columns of varying height and speed for the code rain effect
        let columnCount = Int(screenWidth / 30) // Approximate column width
        
        columns = (0..<columnCount).map { _ in
            CodeColumn(
                position: CGFloat.random(in: 0...screenWidth),
                speed: Double.random(in: 0.5...2.0),
                chars: generateRandomChars(count: Int.random(in: 5...20)),
                hue: CGFloat.random(in: 0...0.3) // Mostly blue-green hues
            )
        }
    }
    
    private func startAnimationSequence() {
        // Animate title appearance
        withAnimation(.easeIn(duration: 0.6)) {
            showTitle = true
        }
        
        // Decrypt characters one by one
        for (index, _) in "DECODEY".enumerated() {
            let delay = 0.6 + Double(index) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Play sound for each character decryption
                SoundManager.shared.play(.letterClick)
                
                withAnimation {
                    decryptedChars[index] = true
                }
            }
        }
        
        // Show subtitle after title is decrypted
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.8)) {
                showSubtitle = true
            }
        }
        
        // Finally show the buttons
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showButtons = true
            }
        }
    }
    
    private func setupContinuousAnimations() {
        // Create continuous animations for effects like pulsing and scanner
        timerCancellable = Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                // Toggle pulse effect
                withAnimation(Animation.easeInOut(duration: 2)) {
                    pulseEffect.toggle()
                }
                
                // Update some random code columns
                for _ in 0..<min(3, columns.count) {
                    if Bool.random() {
                        let randomIndex = Int.random(in: 0..<columns.count)
                        columns[randomIndex].chars = generateRandomChars(count: Int.random(in: 5...20))
                    }
                }
            }
    }
    
    // MARK: - Helper Functions
    
    private func titleColor(for index: Int) -> Color {
        if !decryptedChars[index] {
            // Random colors for undecrypted characters
            return [Color.cyan, Color.blue, Color.green].randomElement()!
        } else {
            // For decrypted characters, use a gradient effect based on position
            let hue = 0.5 + (Double(index) * 0.03)
            return Color(hue: hue, saturation: 0.8, brightness: 0.9)
        }
    }
    
    private func randomCryptoChar() -> String {
        let cryptoChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_+=~`|]}[{';:/?.>,<"
        return String(cryptoChars.randomElement()!)
    }
    
    private func generateRandomChars(count: Int) -> [String] {
        let cryptoChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()_+=~`|]}[{';:/?.>,<"
        return (0..<count).map { _ in String(cryptoChars.randomElement()!) }
    }
}







// MARK: - Preview
//#Preview {
//    HomeScreen(onComplete: {
//        print("Welcome complete!")
//    })
//}


//
//  WelcomeScreen.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

