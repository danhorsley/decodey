import SwiftUI

struct CustomGameView: View {
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        VStack {
            if gameState.isLoading {
                ProgressView("Loading game...")
            } else {
                GameView()
            }
        }
        .onAppear {
            gameState.setupCustomGame()
        }
        .navigationTitle("Custom Game")
    }
}



