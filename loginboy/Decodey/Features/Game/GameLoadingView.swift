// GameLoadingView.swift
// Decodey
//
// Loading state view for the game
// MIGRATED TO USE GAMETHEME

import SwiftUI

struct GameLoadingView: View {
    @State private var dots = ""
    @State private var animationTimer: Timer?
    
    var body: some View {
        VStack(spacing: GameLayout.padding) {
            // Loading indicator
            ProgressView()
                .scaleEffect(1.5)
                .tint(.accentColor)
            
            // Loading text with animated dots
            Text("Loading\(dots)")
                .font(.gameSection)  // Using actual font from GameTheme
                .foregroundColor(.secondary)
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if dots.count >= 3 {
                dots = ""
            } else {
                dots += "."
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

// MARK: - Preview
struct GameLoadingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GameLoadingView()
                .previewDisplayName("Light Mode")
            
            GameLoadingView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
