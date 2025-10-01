// OptimizedHomeScreen.swift
// Keep all the beautiful effects but make them FAST
// UPDATED: Centered Decodey title to avoid GameCenter overlap

import SwiftUI
import Combine

struct OptimizedHomeScreen: View {
    let onBegin: () -> Void
    var onShowLogin: (() -> Void)? = nil
    
    @EnvironmentObject var userState: UserState
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var gameCenterManager = GameCenterManager.shared
    
    // Animation states - EXACTLY like original
    @State private var showTitle = false
    @State private var decryptedChars: [Bool] = Array(repeating: false, count: "decodey".count)
    @State private var showSubtitle = false
    @State private var showButtons = false
    @State private var codeRain = true
    @State private var pulseEffect = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var showingPlayWithoutSignInAlert = false
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.displayScale) var displayScale
    
    // Timer for pulse - but optimized
    @State private var timerCancellable: AnyCancellable?
    
    private var displayName: String {
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
                
                // OPTIMIZED Code rain effect
                if codeRain {
                    FastCodeRainView(screenWidth: geometry.size.width, screenHeight: geometry.size.height)
                        .opacity(0.4)
                }
                
                // CHANGED: Main content centered vertically
                VStack {
                    Spacer()
                    
                    // Logo area with glitch effects - NOW CENTERED
                    VStack(spacing: 20) {
                        // Main title with decryption effect
                        HStack(spacing: 0) {
                            ForEach(Array("decodey".enumerated()), id: \.offset) { index, char in
                                Text(decryptedChars[index] ?
                                    String(char) :
                                    randomCryptoChar())
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
                            .animation(.easeIn(duration: 0.8), value: showSubtitle)
                    }
                    
                    Spacer()
                        .frame(height: 80) // Add some space between title and buttons
                    
                    // Action buttons and user info
                    VStack(spacing: 20) {
                        // Begin button
                        Button(action: onBegin) {
                            HStack {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 20))
                                Text("BEGIN DECRYPTION")
                                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                                    .tracking(2)
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            )
                            .shadow(color: .cyan.opacity(0.5), radius: 15, x: 0, y: 5)
                            .scaleEffect(buttonScale)
                            .opacity(showButtons ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1), value: showButtons)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // User info and sign-in
                        VStack(spacing: 12) {
                            if gameCenterManager.isAuthenticated || authManager.isAuthenticated {
                                // User signed in
                                HStack(spacing: 8) {
                                    Image(systemName: gameCenterManager.isAuthenticated ? "gamecontroller.fill" : "person.crop.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                    
                                    Text("Welcome, \(displayName)")
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                                .opacity(showButtons ? 1 : 0)
                                .animation(.easeIn(duration: 0.5).delay(0.2), value: showButtons)
                            } else {
                                // Not signed in
                                Button(action: {
                                    if let showLogin = onShowLogin {
                                        showLogin()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .font(.system(size: 14))
                                        Text("Sign In for Leaderboards")
                                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    }
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .opacity(showButtons ? 1 : 0)
                                .animation(.easeIn(duration: 0.5).delay(0.2), value: showButtons)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .onAppear {
            animateTitle()
            startPulseAnimation()
        }
        .onDisappear {
            timerCancellable?.cancel()
        }
        .alert("Continue Without Sign In?", isPresented: $showingPlayWithoutSignInAlert) {
            Button("Sign In") {
                if let showLogin = onShowLogin {
                    showLogin()
                }
            }
            Button("Continue") {
                onBegin()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Sign in with Apple or Game Center to save your progress and compete on leaderboards.")
        }
    }
    
    // MARK: - Animation Functions
    
    private func animateTitle() {
        withAnimation(.easeOut(duration: 0.5)) {
            showTitle = true
        }
        
        // Decrypt each letter sequentially
        for i in 0..<decryptedChars.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1 + 0.5) {
                decryptedChars[i] = true
            }
        }
        
        // Show subtitle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSubtitle = true
        }
        
        // Show buttons
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showButtons = true
        }
    }
    
    private func startPulseAnimation() {
        timerCancellable = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    buttonScale = 1.05
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        buttonScale = 1.0
                    }
                }
            }
    }
    
    // MARK: - Helper Functions
    
    private func randomCryptoChar() -> String {
        let cryptoChars = "!@#$%^&*()[]{}|<>?/~"
        return String(cryptoChars.randomElement() ?? "?")
    }
    
    private func titleColor(for index: Int) -> Color {
        if decryptedChars[index] {
            return .cyan
        } else {
            return Color(red: 0.0, green: Double.random(in: 0.7...1.0), blue: Double.random(in: 0.8...1.0))
        }
    }
}

// MARK: - Fast Code Rain View (unchanged)
struct FastCodeRainView: View {
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    
    // Create fewer columns for better performance
    private let columnCount = 12
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<columnCount, id: \.self) { column in
                FastCodeColumn(
                    columnIndex: column,
                    screenHeight: screenHeight,
                    columnWidth: screenWidth / CGFloat(columnCount)
                )
            }
        }
    }
}

struct FastCodeColumn: View {
    let columnIndex: Int
    let screenHeight: CGFloat
    let columnWidth: CGFloat
    
    @State private var offset: CGFloat = 0
    
    private let characters = "01"
    private let characterCount = 20
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<characterCount, id: \.self) { index in
                Text(String(characters.randomElement()!))
                    .font(.system(size: 14, weight: .thin, design: .monospaced))
                    .foregroundColor(Color.green.opacity(Double(characterCount - index) / Double(characterCount)))
            }
        }
        .frame(width: columnWidth)
        .offset(y: offset)
        .onAppear {
            withAnimation(
                .linear(duration: Double.random(in: 8...15))
                .repeatForever(autoreverses: false)
                .delay(Double(columnIndex) * 0.3)
            ) {
                offset = screenHeight + 200
            }
        }
    }
}
