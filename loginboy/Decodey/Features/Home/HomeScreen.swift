// HomeScreen.swift - Modified to add Apple Sign In while keeping all your effects
import SwiftUI
import Combine
import AuthenticationServices

struct HomeScreen: View {
    // Callback for when the welcome animation completes
    let onBegin: () -> Void
    var onShowLogin: (() -> Void)? = nil
    
    // Use UserState and AuthenticationManager
    @EnvironmentObject var userState: UserState
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var gameCenterManager = GameCenterManager.shared
    
    
    // Animation states
    @State private var showTitle = false
    @State private var decryptedChars: [Bool] = Array(repeating: false, count: "DECODEY".count)
    @State private var showSubtitle = false
    @State private var showButtons = false
    @State private var codeRain = true
    @State private var pulseEffect = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var showingPlayWithoutSignInAlert = false
    
    // For the code rain effect
    @State private var columns: [CodeColumn] = []
    
    // Environment values
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.displayScale) var displayScale
    
    // Timer publisher for continuous animations
    @State private var timerCancellable: AnyCancellable?
    
    // Simple login sheet - REMOVED, using Apple Sign In instead
    // @State private var showNameEntry = false
    
    // @State private var playerName = ""
    private var displayName: String {
            // Priority order:
            // 1. Game Center name (if authenticated)
            // 2. Apple Sign In name
            // 3. Default "Player"
            
            if gameCenterManager.isAuthenticated && !gameCenterManager.playerDisplayName.isEmpty {
                return gameCenterManager.playerDisplayName
            } else if authManager.isAuthenticated && !authManager.userName.isEmpty {
                return authManager.userName
            } else {
                return "Player"
            }
        }
    
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
                        // Check if authenticated
                        if authManager.isAuthenticated {
                            // User is signed in - show START button
                            VStack(spacing: 20) {
                                // Main play button
                                Button(action: {
                                    SoundManager.shared.play(.letterClick)
                                    onBegin()
                                }) {
                                    HStack {
                                        Text("START DECODING")
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
                                .buttonStyle(PlainButtonStyle())  // ADD THIS - removes default button styling
                                .scaleEffect(buttonScale)
                                .opacity(showButtons ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showButtons)
                                
                                // Show user info
                                
                                VStack(spacing: 8) {
                                    Text("Welcome back, \(displayName)!")
                                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                                        .foregroundColor(.green)
                                    
                                    Button(action: {
                                        authManager.signOut()
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
                                .opacity(showButtons ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showButtons)
                            }
                            
                        } else {
                            // User is NOT signed in - show Apple Sign In
                            VStack(spacing: 16) {
                                // Info text
                                Text("Sign in to save your progress")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                    .opacity(showButtons ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showButtons)
                                
                                // Apple Sign In Button with your styling
                                SignInWithAppleButtonStyled()
                                    .frame(height: 50)
                                    .frame(maxWidth: 280)
                                    .scaleEffect(buttonScale)
                                    .opacity(showButtons ? 1 : 0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showButtons)
                                
                                // Optional: Play without signing in
                                Button(action: {
                                    showingPlayWithoutSignInAlert = true
                                }) {
                                    Text("Continue without account")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.3))
                                        .underline()
                                }
                                .opacity(showButtons ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: showButtons)
                                .confirmationDialog("Authentication Required", isPresented: $showingPlayWithoutSignInAlert, titleVisibility: .visible) {
                                    Button("Sign in with Apple") {
                                        authManager.signInWithApple()
                                    }
                                    Button("Continue without saving", role: .destructive) {
                                        onBegin()
                                    }
                                    Button("Cancel", role: .cancel) { }
                                } message: {
                                    Text("Sign in to save your progress and track achievements")
                                }
                                .opacity(showButtons ? 1 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: showButtons)
                            }
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
    }
    
    // MARK: - Keep all your existing helper methods unchanged
    
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

// MARK: - Styled Sign In with Apple Button that matches your theme
struct SignInWithAppleButtonStyled: View {
    @StateObject private var authManager = AuthenticationManager.shared
    
    var body: some View {
        Button(action: {
            authManager.signInWithApple()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "applelogo")
                    .font(.system(size: 18, weight: .medium))
                
                Text("Sign in with Apple")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

// Alternative: Use the native Apple button if you prefer
struct NativeAppleSignInButton: View {
    var body: some View {
        SignInWithAppleButton()
            .signInWithAppleButtonStyle(.white)  // or .black based on your theme
            .frame(height: 50)
            .frame(maxWidth: 280)
    }
}
