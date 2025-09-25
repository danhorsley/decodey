// GameView.swift
// Decodey
//
// Main game container - coordinates all game components

import SwiftUI

struct GameView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var settingsState: SettingsState
    @Environment(\.colorScheme) var colorScheme
    
    private let colors = ColorSystem.shared
    
    var body: some View {
        ZStack {
            // Background
            colors.primaryBackground(for: colorScheme)
                .ignoresSafeArea()
            
            // Main content
            if gameState.isLoading {
                GameLoadingView()
            } else if let error = gameState.errorMessage {
                GameErrorView(message: error)
            } else {
                GamePlayView()
            }
            
            // Overlays
            GameOverlays()
        }
    }
}

// MARK: - Preview
struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView()
            .environmentObject(GameState.shared)
            .environmentObject(UserState.shared)
            .environmentObject(SettingsState.shared)
    }
}
