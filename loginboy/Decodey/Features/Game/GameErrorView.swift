// GameErrorView.swift
// Decodey
//
// Error state view for the game
// MIGRATED TO USE GAMETHEME

import SwiftUI

struct GameErrorView: View {
    let message: String
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        VStack(spacing: GameLayout.paddingLarge) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            // Error title
            Text("Something went wrong")
                .font(.gameTitle)
                .foregroundColor(.primary)
            
            // Error message
            Text(message)
                .font(.gameSection)  // Using actual font from GameTheme
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, GameLayout.paddingLarge)
            
            // Try again button
            Button(action: {
                gameState.resetGame()
            }) {
                Text("Try Again")
                    .font(.gameButton)
                    .foregroundColor(.white)
                    .padding(.horizontal, GameLayout.paddingLarge)
                    .padding(.vertical, GameLayout.padding)
                    .background(Color.accentColor)
                    .cornerRadius(GameLayout.cornerRadiusLarge)
            }
            .buttonStyle(PlainButtonStyle())  // Remove default button styling
        }
        .padding(GameLayout.paddingLarge)
        .background(Color("GameSurface"))
        .cornerRadius(GameLayout.cornerRadiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: GameLayout.cornerRadiusLarge)
                .stroke(Color("GameBorder"), lineWidth: 1)
        )
        .shadow(radius: 10)
        .padding(GameLayout.paddingLarge)
    }
}

// MARK: - Preview
struct GameErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GameErrorView(message: "Unable to load game data. Please check your internet connection and try again.")
                .environmentObject(GameState.shared)
                .previewDisplayName("Light Mode")
            
            GameErrorView(message: "Unable to load game data. Please check your internet connection and try again.")
                .environmentObject(GameState.shared)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
