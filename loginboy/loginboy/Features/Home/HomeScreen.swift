import SwiftUI
import Combine

struct HomeScreen: View {
    // Callback for when the welcome animation completes
    let onBegin: () -> Void
    var onShowLogin: (() -> Void)? = nil
    
    // Use UserState instead of AuthenticationCoordinator
    @EnvironmentObject var userState: UserState
    
    // Animation states
    @State private var showTitle = false
    @State private var decryptedChars: [Bool] = Array(repeating: false, count: "DECODEY".count)
    @State private var showSubtitle = false
    @State private var showButtons = false
    @State private var codeRain = true
    @State private var pulseEffect = false
    @State private var buttonScale: CGFloat = 1.0
    
    // For the code rain effect
    @State private var columns: [CodeColumn] = []
    
    // Environment values
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.displayScale) var displayScale
    
    // Timer publisher for continuous animations
    @State private var timerCancellable: AnyCancellable?
    
    // Simple login sheet
    @State private var showNameEntry = false
    @State private var playerName = ""
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - dark with code rain
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                // Code rain effect (The Matrix-style falling characters)
                if codeRain {
                    CodeRainView(columns: $columns)
                        .opacity(0.4)
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
                            .animation(.easeIn(duration: 0.8).delay(1.5), value: showSubtitle)
                    }
                    .padding(.top, 80)
                    
                    Spacer()
                    
                    // Buttons section
                    VStack(spacing: 20) {
                        // Main play button
                        Button(action: {
                            SoundManager.shared.play(.letterClick)
                            
                            // If not signed in, show name entry
                            if !userState.isSignedIn {
                                showNameEntry = true
                            } else {
                                onBegin()
                            }
                        }) {
                            HStack {
                                Text(userState.isSignedIn ? "START DECODING" : "ENTER GAME")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .tracking(2)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.cyan, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .cyan.opacity(0.5), radius: 8, x: 0, y: 4)
                        }
                        .scaleEffect(buttonScale)
                        .opacity(showButtons ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showButtons)
                        
                        // If already signed in, show user info and sign out option
                        if userState.isSignedIn {
                            VStack(spacing: 8) {
                                Text("Welcome back, \(userState.playerName)!")
                                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                                    .foregroundColor(.green)
                                
                                Button(action: {
                                    userState.signOut()
                                }) {
                                    Text("Sign Out")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                            .opacity(showButtons ? 0.8 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showButtons)
                        }
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
        .sheet(isPresented: $showNameEntry) {
            SimpleNameEntryView(
                playerName: $playerName,
                onSave: {
                    userState.setPlayerName(playerName)
                    showNameEntry = false
                    onBegin()
                }
            )
        }
    }
    
    // MARK: - Helper Methods (keep existing animation code)
    
    private func randomCryptoChar() -> String {
        let chars = "!@#$%^&*(){}[]|\\:;\"'<>,.?/~`0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        return String(chars.randomElement() ?? "X")
    }
    
    private func titleColor(for index: Int) -> Color {
        if decryptedChars[index] {
            return .cyan
        } else {
            return Color.white.opacity(0.3)
        }
    }
    
    private func setupCodeColumns(screenWidth: CGFloat) {
        let columnCount = Int(screenWidth / 20)
        columns = (0..<columnCount).map { index in
            CodeColumn(
                position: CGFloat(index) * 20.0,           // x position
                speed: Double.random(in: 0.5...2.0),       // animation speed
                chars: generateRandomChars(),               // array of characters
                hue: CGFloat.random(in: 0.0...1.0)         // color hue
            )
        }
    }
    
    private func startAnimationSequence() {
        // Show title first
        withAnimation(.easeOut(duration: 0.6)) {
            showTitle = true
        }
        
        // Start decrypting characters with staggered timing
        for i in 0..<decryptedChars.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15 + 0.8) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    decryptedChars[i] = true
                }
            }
        }
        
        // Show subtitle after title decryption
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeIn(duration: 0.8)) {
                showSubtitle = true
            }
        }
        
        // Show buttons last
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showButtons = true
            }
        }
    }
    private func generateRandomChars() -> [String] {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return (0..<10).map { _ in
            String(characters.randomElement() ?? "X")
        }
    }
    private func setupContinuousAnimations() {
        // Pulse effect for buttons
        timerCancellable = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                withAnimation(.easeInOut(duration: 0.8)) {
                    pulseEffect.toggle()
                    buttonScale = pulseEffect ? 1.05 : 1.0
                }
            }
    }
}

// Simple name entry view
struct SimpleNameEntryView: View {
    @Binding var playerName: String
    let onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 10) {
                Text("Enter Your Name")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                Text("This will be your player name")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            TextField("Player Name", text: $playerName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button("Start Playing") {
                if !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onSave()
                }
            }
            .disabled(playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
