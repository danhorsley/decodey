// GameLoadingView.swift
// Decodey
//
// Loading state for game initialization

import SwiftUI

struct GameLoadingView: View {
    @State private var loadingProgress = 0.0
    @State private var loadingText = "INITIALIZING"
    
    private let colors = ColorSystem.shared
    @Environment(\.colorScheme) var colorScheme
    
    private let loadingMessages = [
        "INITIALIZING",
        "LOADING CIPHER",
        "ENCRYPTING DATA",
        "PREPARING VAULT"
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // Loading indicator
            ProgressView()
                .scaleEffect(1.5)
                .tint(colors.accent)
                .progressViewStyle(CircularProgressViewStyle())
            
            // Loading text
            Text(loadingText)
                .font(.custom("Courier New", size: 14).weight(.medium))
                .tracking(1.5)
                .foregroundColor(.secondary)
            
            // Progress bar (optional)
            if loadingProgress > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(colors.accent)
                            .frame(width: geometry.size.width * CGFloat(loadingProgress), height: 4)
                    }
                }
                .frame(height: 4)
                .frame(maxWidth: 200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            animateLoading()
        }
    }
    
    private func animateLoading() {
        // Cycle through loading messages
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.3)) {
                loadingProgress += 0.25
                
                let messageIndex = Int(loadingProgress * 3) % loadingMessages.count
                loadingText = loadingMessages[messageIndex]
                
                if loadingProgress >= 1.0 {
                    timer.invalidate()
                }
            }
        }
    }
}
