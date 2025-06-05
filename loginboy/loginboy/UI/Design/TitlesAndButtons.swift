import SwiftUI

// Stylish app title component
struct DecodeyTitleView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var animateLetters = false
    
    private let title = "decodey"
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(title.enumerated()), id: \.offset) { index, letter in
                Text(String(letter))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colorScheme == .dark ?
                                [Color(hex: "4cc9f0"), Color(hex: "00ed99")] :
                                [Color.blue, Color.purple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: shadowColor.opacity(0.3), radius: 2, x: 0, y: 2)
                    .scaleEffect(animateLetters ? 1.0 : 0.9)
                    .opacity(animateLetters ? 1.0 : 0.7)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.6)
                        .delay(Double(index) * 0.05),
                        value: animateLetters
                    )
            }
        }
        .onAppear {
            animateLetters = true
        }
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

// Redesigned New Game Button - Option 1: Floating Action Button style
struct NewGameButton: View {
    let action: () -> Void
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            SoundManager.shared.play(.letterClick)
            action()
        }) {
            ZStack {
                // Background circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "4cc9f0"),
                                Color(hex: "00ed99")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.black.opacity(0.2), radius: isPressed ? 2 : 8, x: 0, y: isPressed ? 1 : 4)
                
                // Icon
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isPressed ? 360 : 0))
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// Alternative: Sleek horizontal button
struct NewGameButtonAlt: View {
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            SoundManager.shared.play(.letterClick)
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: "shuffle")
                    .font(.system(size: 18, weight: .semibold))
                    .rotationEffect(.degrees(isHovered ? 180 : 0))
                
                Text("NEW PUZZLE")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(1.2)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    // Gradient background
                    RoundedRectangle(cornerRadius: 30)
                        .fill(
                            LinearGradient(
                                colors: colorScheme == .dark ?
                                    [Color(hex: "4cc9f0"), Color(hex: "00ed99")] :
                                    [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    // Shimmer effect
                    RoundedRectangle(cornerRadius: 30)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: isHovered ? 200 : -200)
                        .mask(RoundedRectangle(cornerRadius: 30))
                }
            )
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.6)) {
                isHovered = hovering
            }
        }
    }
}

// Updated game content view section
struct UpdatedGameHeader: View {
    let isDailyChallenge: Bool
    let dateString: String?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            if isDailyChallenge {
                // Daily challenge header
                VStack(spacing: 4) {
                    Text("DAILY CHALLENGE")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(.secondary)
                    
                    if let dateString = dateString {
                        Text(dateString.uppercased())
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            } else {
                // Custom game with decodey title
                VStack(spacing: 8) {
                    DecodeyTitleView()
                    
                    Text("CLASSIC MODE")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}

// Example of how to integrate into GameView
struct GameViewBottomControls: View {
    let isDailyChallenge: Bool
    let onNewGame: () -> Void
    
    var body: some View {
        Group {
            if !isDailyChallenge {
                // Option 1: Floating button in corner
                HStack {
                    Spacer()
                    NewGameButton(action: onNewGame)
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                }
                
                // OR Option 2: Centered sleek button
                // NewGameButtonAlt(action: onNewGame)
                //     .padding(.bottom, 30)
            }
        }
    }
}

//
//  TitlesAndButtons.swift
//  loginboy
//
//  Created by Daniel Horsley on 05/06/2025.
//

