// GameModeWrapper.swift
// Decodey
//
// Wrapper view that automatically selects GameView or TimedGameView based on settings

import SwiftUI

/// A wrapper view that displays the appropriate game view based on the current game mode setting
struct GameModeWrapper: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState
    @EnvironmentObject var userState: UserState
    
    var body: some View {
        Group {
            switch settingsState.gameMode {
            case .timePressure:
                TimedGameView()
                    .environmentObject(gameState)
                    .environmentObject(settingsState)
            case .classic:
                GameView()
                    .environmentObject(gameState)
                    .environmentObject(settingsState)
            }
        }
    }
}

// MARK: - Preview
struct GameModeWrapper_Previews: PreviewProvider {
    static var previews: some View {
        GameModeWrapper()
            .environmentObject(GameState.shared)
            .environmentObject(SettingsState.shared)
            .environmentObject(UserState.shared)
    }
}
