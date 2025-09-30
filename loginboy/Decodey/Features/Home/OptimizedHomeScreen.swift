// OptimizedHomeScreen.swift
// Keep all the beautiful effects but make them FAST

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
                  
                  // Content container - EXACTLY as original
                  VStack(spacing: 40) {
                      // Logo area with glitch effects
                      VStack(spacing: 5) {
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
                      
                      // Action buttons and user info - EXACTLY as original
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
                                  .clipShape(RoundedRectangle(cornerRadius: 12)) // Clip the gradient itself
                              )
                              .shadow(color: .cyan.opacity(0.5), radius: 15, x: 0, y: 5)
                              .scaleEffect(buttonScale)
                              .opacity(showButtons ? 1 : 0)
                              .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showButtons)
                          }
                          .buttonStyle(PlainButtonStyle())
                          
                          // User authentication status
                          if authManager.isAuthenticated || gameCenterManager.isAuthenticated {
                              VStack(spacing: 8) {
                                  Text("AGENT: \(displayName.uppercased())")
                                      .font(.system(size: 14, weight: .medium, design: .monospaced))
                                      .foregroundColor(.green)
                                      .opacity(showButtons ? 1 : 0)
                                      .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: showButtons)
                                  
                                  Text("STATUS: AUTHENTICATED")
                                      .font(.system(size: 12, weight: .regular, design: .monospaced))
                                      .foregroundColor(.green.opacity(0.7))
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
                  // Start animations - optimized timing
                  startAnimationSequence()
                  setupContinuousAnimations()
              }
              .onDisappear {
                  timerCancellable?.cancel()
              }
          }
      }
      
      // MARK: - Helper Methods (Keep original styling)
      
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

  // MARK: - OPTIMIZED Code Rain View
  // This is the KEY optimization - batch rendering with Metal acceleration

  struct FastCodeRainView: View {
      let screenWidth: CGFloat
      let screenHeight: CGFloat
      
      // Reduce state updates by using a display link
      @State private var rainAnimation = RainAnimationController()
      
      var body: some View {
          TimelineView(.animation(minimumInterval: 1.0/30.0)) { context in
              Canvas { canvasContext, size in
                  // Update animation state
                  let time = context.date.timeIntervalSinceReferenceDate
                  
                  // Batch draw all columns in a single pass
                  drawOptimizedRain(
                      context: canvasContext,
                      size: size,
                      time: time
                  )
              }
          }
          .onAppear {
              rainAnimation.setup(width: screenWidth, height: screenHeight)
          }
      }
      
      private func drawOptimizedRain(context: GraphicsContext, size: CGSize, time: TimeInterval) {
          // Pre-calculate common values
          let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
          let charArray = Array(characters)
          let columnWidth: CGFloat = 20
          let charHeight: CGFloat = 20
          let columnCount = Int(size.width / columnWidth)
          
          // Batch render all columns
          for col in 0..<columnCount {
              let x = CGFloat(col) * columnWidth
              
              // Use sine wave for smooth vertical movement
              let baseY = (time * 50 * (1.0 + Double(col % 3) * 0.3))
                  .truncatingRemainder(dividingBy: Double(size.height + 200)) - 100
              
              // Draw column characters
              for row in 0..<15 { // Limit chars per column
                  let y = baseY + Double(row) * Double(charHeight)
                  
                  // Skip if off screen
                  if y < -charHeight || y > Double(size.height) {
                      continue
                  }
                  
                  // Calculate fade based on position
                  let opacity = max(0, min(1, (1.0 - Double(row) / 15.0) * 0.8))
                  
                  // Pick a "random" character based on position
                  let charIndex = (col * 7 + row * 13 + Int(time)) % charArray.count
                  let char = String(charArray[charIndex])
                  
                  // Use cyan color with calculated opacity
                  let color = Color.cyan.opacity(opacity)
                  
                  // Draw the character
                  context.draw(
                      Text(char)
                          .font(.system(size: 14, weight: .light, design: .monospaced))
                          .foregroundColor(color),
                      at: CGPoint(x: x, y: y)
                  )
              }
          }
      }
  }

  // Helper class to manage rain state efficiently
  class RainAnimationController: ObservableObject {
      struct Column {
          let x: CGFloat
          let speed: CGFloat
          let offset: CGFloat
      }
      
      private var columns: [Column] = []
      
      func setup(width: CGFloat, height: CGFloat) {
          let columnCount = Int(width / 20)
          columns = (0..<columnCount).map { i in
              Column(
                  x: CGFloat(i) * 20,
                  speed: CGFloat.random(in: 0.5...1.5),
                  offset: CGFloat.random(in: 0...height)
              )
          }
      }
  }


