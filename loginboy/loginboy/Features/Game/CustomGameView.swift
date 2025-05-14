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

//
//  CustomGameView.swift
//  loginboy
//
//  Created by Daniel Horsley on 14/05/2025.
//

//
//  CustomGameView.swift
//  loginboy
//
//  Created by Daniel Horsley on 14/05/2025.
//

