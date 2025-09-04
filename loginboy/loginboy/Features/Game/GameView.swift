//
//  GameView.swift - Complete Fixed Version
//  loginboy
//

import SwiftUI
import Foundation  // CRITICAL: Required for CharacterSet

enum GameMode {
    case daily
    case random
    case custom
}

struct GameView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState
    @EnvironmentObject var userManager: SimpleUserManager
    @Environment(\.colorScheme) var colorScheme
    
    // Game mode for different contexts
    var gameMode: GameMode = .random
    
    // UI state
    @State private var showSettings = false
    @State private var selectedEncryptedLetter: Character?
    @State private var isHintAnimating = false
    
    // Design system
    private let colors = ColorSystem.shared
    private let fonts = FontSystem.shared
    
    var body: some View {
        ZStack {
            // Background
            colors.primaryBackground(for: colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Game header with info
                gameHeader
                
                // Main game content
                if gameState.isLoading {
                    loadingView
                } else if let game = gameState.currentGame {
                    gameContent(for: game)
                } else {
                    emptyGameView
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            // Overlays for win/loss
            if gameState.showWinMessage {
                GameWinOverlay()
                    .zIndex(100)
            }
            
            if gameState.showLoseMessage {
                GameLossOverlay()
                    .zIndex(100)
            }
        }
        .onAppear {
            setupGameMode()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Game Header
    
    private var gameHeader: some View {
        VStack(spacing: 12) {
            // Title and settings
            HStack {
                Text(gameTitle)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button(action: { showSettings = true }) {
                    Image(systemName: "gear")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Quote metadata
            if !gameState.quoteAuthor.isEmpty {
                VStack(spacing: 4) {
                    Text("Quote by")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(gameState.quoteAuthor)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    
                    if let attribution = gameState.quoteAttribution {
                        Text(attribution)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Game Content
    
    private func gameContent(for game: GameModel) -> some View {
        VStack(spacing: 24) {
            // Game stats row
            gameStatsRow(for: game)
            
            // Quote display
            quoteDisplay(for: game)
            
            // Letter substitution grid
            letterSubstitutionGrid(for: game)
            
            // Action buttons
            actionButtons(for: game)
        }
    }
    
    private func gameStatsRow(for game: GameModel) -> some View {
        HStack {
            // Mistakes counter
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(game.mistakes > 0 ? .red : .secondary)
                Text("\(game.mistakes)/\(game.maxMistakes)")
                    .font(.subheadline.bold())
                    .foregroundStyle(game.mistakes > 0 ? .red : .secondary)
            }
            
            Spacer()
            
            // Score display - PROPERLY UNWRAPPED!
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("Score: \(game.calculateScore())")  // ✅ FIXED: No more optional unwrapping error!
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }
            
            Spacer()
            
            // Progress indicator - FIXED METHOD NAME!
            HStack(spacing: 4) {
                Image(systemName: "percent")
                    .foregroundStyle(.blue)
                Text("\(Int(game.getCompletionPercentage() * 100))%")  // ✅ FIXED: Correct method name!
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
    
    private func quoteDisplay(for game: GameModel) -> some View {
        ScrollView {
            Text(game.currentDisplay)
                .font(fonts.encryptedDisplayText())  // ✅ FIXED: Correct method name!
                .foregroundStyle(.primary)
                .lineSpacing(8)
                .multilineTextAlignment(.center)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.secondary.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .frame(maxHeight: 200)
    }
    
    private func letterSubstitutionGrid(for game: GameModel) -> some View {
        GameGridsView(showTextHelpers: settingsState.showTextHelpers)
            .environmentObject(gameState)
            .environmentObject(settingsState)
    }
    
    private func actionButtons(for game: GameModel) -> some View {
        HStack(spacing: 16) {
            // Hint button
            Button(action: requestHint) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.title3)
                    Text("Hint")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .disabled(game.hasWon || game.hasLost || isHintAnimating)
            .scaleEffect(isHintAnimating ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isHintAnimating)
            
            Spacer()
            
            // Reset button
            Button(action: resetGame) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                    Text("Reset")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Supporting Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading game...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyGameView: some View {
        VStack(spacing: 20) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Game Available")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            
            Text("Try starting a new game")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button("New Game") {
                setupGameMode()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var gameTitle: String {
        switch gameMode {
        case .daily:
            return "Daily Challenge"
        case .random:
            return "Random Game"
        case .custom:
            return "Custom Game"
        }
    }
    
    // MARK: - Actions - ALL FIXED!
    
    private func setupGameMode() {
        switch gameMode {
        case .daily:
            gameState.setupDailyChallenge()
        case .random, .custom:
            gameState.setupCustomGame()
        }
    }
    
    private func requestHint() {
        guard let game = gameState.currentGame,
              !game.hasWon,
              !game.hasLost,
              !isHintAnimating else { return }
        
        isHintAnimating = true
        SoundManager.shared.play(.hint)
        
        // ✅ FIXED: Proper method call syntax
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            gameState.getHint()  // This method exists in GameState
            isHintAnimating = false
        }
    }
    
    private func resetGame() {
        gameState.resetGame()  // ✅ FIXED: This method exists in GameState
    }
}

// MARK: - Game Win/Loss Overlays

struct GameWinOverlay: View {
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { } // Prevent dismissal
            
            VaultWinModal()
                .environmentObject(gameState)
        }
    }
}

struct GameLossOverlay: View {
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { } // Prevent dismissal
            
            GameLossModal()
                .environmentObject(gameState)
        }
    }
}

// MARK: - Preview

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView()
            .environmentObject(GameState.shared)
            .environmentObject(SettingsState.shared)
            .environmentObject(SimpleUserManager.shared)
            .preferredColorScheme(.dark)
    }
}
