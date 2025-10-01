// GameOverlays.swift
// Decodey
//
// Handles all game overlay states (win, lose, tutorial, etc.)

import SwiftUI

struct GameOverlays: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var userState: UserState
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Win overlay
            if gameState.showWinMessage {
                winModal
            }
            
            // Lose overlay
            if gameState.showLoseMessage {
                loseModal
            }
            
            // Tutorial overlay (if needed)
            if gameState.showTutorial {
                TutorialOverlay()
                    .environmentObject(gameState)
            }
        }
    }
    
    // MARK: - Win Modal
    
    @ViewBuilder
    private var winModal: some View {

            // Regular game win - use theme-appropriate modal
            if colorScheme == .light {
                ArchiveWinModal()
                    .environmentObject(gameState)
                    .environmentObject(userState)
                    .zIndex(10)
            } else {
                VaultWinModal()
                    .environmentObject(gameState)
                    .environmentObject(userState)
                    .zIndex(10)
            
        }
    }
    
    // MARK: - Lose Modal
    
    @ViewBuilder
    private var loseModal: some View {
        if colorScheme == .dark {
            TerminalCrashModal()
                .environmentObject(gameState)
                .zIndex(10)
        } else {
            GameLossModal()
                .environmentObject(gameState)
                .zIndex(10)
        }
    }
}
