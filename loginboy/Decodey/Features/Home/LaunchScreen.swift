//
//  LaunchScreen.swift
//  Decodey
//


import SwiftUI

struct LaunchScreen: View {
    @State private var isAnimating = false
    @State private var showLogo = false
    @State private var letterAnimations = Array(repeating: false, count: 7) // DECODEY has 7 letters
    
    // Use your app's color scheme
    @Environment(\.colorScheme) var colorScheme
    
    // The title split into characters for animation
    private let titleLetters = Array("decodey")
    
    var body: some View {
        ZStack {
            // Background gradient matching your app theme
            backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main Logo/Title Section
                VStack(spacing: 20) {
                    // App Icon or Logo Symbol
                    iconSection
                        .scaleEffect(showLogo ? 1.0 : 0.5)
                        .opacity(showLogo ? 1.0 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: showLogo)
                    
                    // Animated Title
                    HStack(spacing: 4) {
                        ForEach(0..<titleLetters.count, id: \.self) { index in
                            Text(String(titleLetters[index]))
                                .font(.system(size: 42, weight: .bold, design: .monospaced))
                                .foregroundColor(letterColor(for: index))
                                .opacity(letterAnimations[index] ? 1.0 : 0)
                                .offset(y: letterAnimations[index] ? 0 : 20)
                                .scaleEffect(letterAnimations[index] ? 1.0 : 0.8)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.05),
                                    value: letterAnimations[index]
                                )
                        }
                    }
                    .overlay(
                        // Subtle glow effect
                        HStack(spacing: 4) {
                            ForEach(0..<titleLetters.count, id: \.self) { index in
                                Text(String(titleLetters[index]))
                                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                                    .opacity(letterAnimations[index] ? 0.3 : 0)
                                    .blur(radius: 8)
                                    .animation(
                                        .easeIn(duration: 0.6)
                                        .delay(Double(index) * 0.05),
                                        value: letterAnimations[index]
                                    )
                            }
                        }
                    )
                    
                    // Tagline
                    Text("CRACK THE CODE")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .tracking(6)
                        .foregroundColor(.gray.opacity(0.8))
                        .opacity(isAnimating ? 1.0 : 0)
                        .animation(.easeIn(duration: 0.8).delay(0.8), value: isAnimating)
                }
                
                Spacer()
                
                // Loading indicator (subtle)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan.opacity(0.8)))
                    .scaleEffect(0.8)
                    .opacity(isAnimating ? 1.0 : 0)
                    .animation(.easeIn(duration: 0.5).delay(1.0), value: isAnimating)
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private var iconSection: some View {
        ZStack {
            // Outer cipher ring effect
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.cyan.opacity(0.3), .blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 20)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            // Inner cipher ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.2), .cyan.opacity(0.3)],
                        startPoint: .bottomTrailing,
                        endPoint: .topLeading
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(isAnimating ? -360 : 0))
                .animation(
                    .linear(duration: 15)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            // Center icon - puzzle piece or lock symbol
            Image(systemName: "puzzlepiece.fill")
                .font(.system(size: 45, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .cyan.opacity(0.5), radius: 10, x: 0, y: 0)
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark ?
                [Color.black, Color.black.opacity(0.95), Color.blue.opacity(0.1)] :
                [Color.white, Color.gray.opacity(0.1), Color.blue.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Helper Methods
    
    private func letterColor(for index: Int) -> Color {
        // Create a gradient effect across the letters
        let colors: [Color] = [.cyan, .blue, .cyan, .blue, .cyan, .blue, .cyan]
        return colors[index % colors.count]
    }
    
    private func startAnimations() {
        // Start logo animation immediately
        withAnimation {
            showLogo = true
        }
        
        // Animate letters with cascade effect
        for index in 0..<titleLetters.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08 + 0.3) {
                letterAnimations[index] = true
            }
        }
        
        // Set general animation flag
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAnimating = true
        }
    }
}

// MARK: - Launch Screen Manager
// This manages the transition from launch screen to main app

class LaunchScreenManager: ObservableObject {
    @Published var isShowingLaunch = true
    
    func dismissLaunchScreen() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isShowingLaunch = false
        }
    }
}

// MARK: - Root View Wrapper
// Use this in your DecodeyApp.swift file

struct LaunchScreenWrapper: View {
    @StateObject private var launchManager = LaunchScreenManager()
    @State private var hasInitialized = false
    
    var body: some View {
        ZStack {
            // Your main app content
            MainView() // or whatever your root view is
                .opacity(launchManager.isShowingLaunch ? 0 : 1)
                .scaleEffect(launchManager.isShowingLaunch ? 0.95 : 1.0)
            
            // Launch screen overlay
            if launchManager.isShowingLaunch {
                LaunchScreen()
                    .transition(.opacity)
            }
        }
        .onAppear {
            if !hasInitialized {
                hasInitialized = true
                // Dismiss launch screen after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    launchManager.dismissLaunchScreen()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Launch Screen - Light") {
    LaunchScreen()
        .preferredColorScheme(.light)
}

#Preview("Launch Screen - Dark") {
    LaunchScreen()
        .preferredColorScheme(.dark)
}

#Preview("Full App Launch") {
    LaunchScreenWrapper()
}
