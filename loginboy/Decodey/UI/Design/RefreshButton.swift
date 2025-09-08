import SwiftUI

struct RefreshButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false
    @State private var rotation: Double = 0
    
    private var iconColor: Color {
        colorScheme == .dark ? Color(hex: "4cc9f0") : Color.black.opacity(0.7)
    }
    
    private var glowColor: Color {
        Color(hex: "4cc9f0").opacity(0.6)
    }
    
    var body: some View {
        Button(action: {
            // Trigger rotation animation
            withAnimation(.easeInOut(duration: 0.5)) {
                rotation += 360
            }
            
            // Play subtle click sound
            SoundManager.shared.play(.letterClick)
            
            // Execute action after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action()
            }
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(iconColor)
                .rotationEffect(.degrees(rotation))
                .scaleEffect(isPressed ? 0.85 : 1.0)
                .opacity(isPressed ? 0.6 : 1.0)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            Circle()
                                .stroke(iconColor.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(
                    color: colorScheme == .dark ? glowColor : Color.black.opacity(0.1),
                    radius: colorScheme == .dark ? 3 : 2,
                    x: 0,
                    y: 1
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - Integration Helper

struct GameViewHeader: View {
    let isDailyChallenge: Bool
    let dateString: String?
    let onRefresh: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Centered title
            AnimatedGameHeader(
                isDailyChallenge: isDailyChallenge,
                dateString: dateString
            )
            
            // Refresh button positioned top-right
            if !isDailyChallenge, let onRefresh = onRefresh {
                VStack {
                    HStack {
                        Spacer()
                        RefreshButton(action: onRefresh)
                            .padding(.trailing, 16)
                            .padding(.top, 8)
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Preview

struct RefreshButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Light mode
            GameViewHeader(
                isDailyChallenge: false,
                dateString: nil,
                onRefresh: { print("Refresh tapped") }
            )
            .frame(height: 100)
            .preferredColorScheme(.light)
            
            // Dark mode
            GameViewHeader(
                isDailyChallenge: false,
                dateString: nil,
                onRefresh: { print("Refresh tapped") }
            )
            .frame(height: 100)
            .preferredColorScheme(.dark)
            .background(Color.black)
            
            // Daily challenge (no refresh button)
            GameViewHeader(
                isDailyChallenge: true,
                dateString: "November 5, 2024",
                onRefresh: nil
            )
            .frame(height: 100)
            .preferredColorScheme(.dark)
            .background(Color.black)
        }
        .padding()
    }
}

//
//  RefreshButton.swift
//  loginboy
//
//  Created by Daniel Horsley on 05/06/2025.
//

