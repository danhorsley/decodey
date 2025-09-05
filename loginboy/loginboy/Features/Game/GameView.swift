//
//  GameView.swift - WITH COMPATIBILITY WRAPPERS
//  loginboy
//

import SwiftUI
import Foundation

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
    
    var gameMode: GameMode = .random
    
    @State private var showSettings = false
    @State private var selectedEncryptedLetter: Character?
    @State private var isHintAnimating = false
    
    private let colors = ColorSystem.shared
    private let fonts = FontSystem.shared
    
    var body: some View {
        ZStack {
            colors.primaryBackground(for: colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                gameHeader
                
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
            performSetupGameMode()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
    
    private var gameHeader: some View {
        VStack(spacing: 12) {
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
            
            if !gameState.quoteAuthor.isEmpty {
                VStack(spacing: 4) {
                    Text("Quote by")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(gameState.quoteAuthor)
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
    
    private func gameContent(for game: GameModel) -> some View {
        VStack(spacing: 20) {
            quoteDisplay(for: game)
            gameStatus(for: game)
            letterSubstitutionGrid(for: game)
            
            if !game.hasWon && !game.hasLost {
                actionButtons(for: game)
            }
        }
    }
    
    private func gameStatus(for game: GameModel) -> some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
                
                Text("\(game.mistakes)/\(game.maxMistakes)")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
            }
            
            Spacer()
            
            if game.hasWon {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    
                    Text("Solved!")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            } else if game.hasLost {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    
                    Text("Game Over")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    
                    Text("In Progress")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.thinMaterial)
        )
    }
    
    private func quoteDisplay(for game: GameModel) -> some View {
        VStack(spacing: 16) {
            // Encrypted text block (top block - what the cipher shows)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("ENCRYPTED")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .tracking(1)
                    Spacer()
                    Text("\(game.encrypted.filter { $0.isLetter }.count) letters")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(game.encrypted)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.orange)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            }
            
            // Current solving progress (bottom block - what's been decoded)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SOLVING")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .tracking(1)
                    Spacer()
                    let progress = Double(game.guessedMappings.count) / Double(Set(game.encrypted.filter { $0.isLetter }).count)
                    Text("\(Int(progress * 100))% complete")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(generateDisplayText(for: game))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            }
            
            // NO AUTHOR DISPLAY HERE - it's shown in the win modal instead!
        }
        .padding(.horizontal, 16)
    }
    
    private func letterSubstitutionGrid(for game: GameModel) -> some View {
        GameGridsView(showTextHelpers: settingsState.showTextHelpers)
            .environmentObject(gameState)
            .environmentObject(settingsState)
    }
    
    private func actionButtons(for game: GameModel) -> some View {
        HStack(spacing: 16) {
            Button(action: performRequestHint) {
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
            
            Button(action: performResetGame) {
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
                performSetupGameMode()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
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
    
    // MARK: - COMPATIBILITY WRAPPERS - Bypass Swift 5.0 @EnvironmentObject binding conflicts
    
    private func performSetupGameMode() {
        let state = gameState  // Create explicit reference
        switch gameMode {
        case .daily:
            state.setupDailyChallenge()
        case .random, .custom:
            state.setupCustomGame()
        }
    }
    
    private func performRequestHint() {
        let state = gameState  // Create explicit reference
        
        guard let game = state.currentGame,
              !game.hasWon,
              !game.hasLost,
              !isHintAnimating else { return }
        
        isHintAnimating = true
        SoundManager.shared.play(.hint)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Use explicit reference to bypass dynamic member lookup
            state.getHint()  // ✅ This bypasses the binding syntax conflict
            isHintAnimating = false
        }
    }
    
    private func performResetGame() {
        let state = gameState  // Create explicit reference
        state.resetGame()      // ✅ This bypasses the binding syntax conflict
    }
    
    private func generateDisplayText(for game: GameModel) -> String {
        return game.solution.map { char in
            if char.isLetter {
                // For letters, show the guessed letter or a block
                if let encryptedChar = game.correctMappings.first(where: { $0.value == char })?.key,
                   let guessedChar = game.guessedMappings[encryptedChar] {
                    return String(guessedChar)
                } else {
                    return "█"  // Block for unguessed letters
                }
            } else {
                // For spaces, punctuation, etc. - show as-is
                return String(char)
            }
        }.joined()
    }
}

// MARK: - Game Win/Loss Overlays

struct GameWinOverlay: View {
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { }
            
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
                .onTapGesture { }
            
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
