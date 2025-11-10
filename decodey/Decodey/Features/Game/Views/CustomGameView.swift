import SwiftUI

struct CustomGameView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState
    
    var body: some View {
        VStack {
            if gameState.isLoading {
                ProgressView("Loading game...")
            } else {
//                GameView()
                GameModeWrapper()
                                    .environmentObject(gameState)
                                    .environmentObject(settingsState)
            }
        }
        .onAppear {
            gameState.setupCustomGame()
        }
        .navigationTitle("Custom Game")
    }
}



