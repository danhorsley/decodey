import SwiftUI

struct GameView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var settingsState: SettingsState
    
    @Environment(\.colorScheme) var colorScheme
    private let fonts = FontSystem.shared
    private let colors = ColorSystem.shared
    
    var body: some View {
        ZStack {
            // Background
            colors.primaryBackground(for: colorScheme)
                .ignoresSafeArea()
            
            if gameState.isLoading {
                loadingView
            } else if let error = gameState.errorMessage {
                errorView(message: error)
            } else {
                gameContentView
            }
            
            // Win overlay
            if gameState.showWinMessage {
                winMessageOverlay
            }
            
            // Lose overlay
            if gameState.showLoseMessage {
                loseMessageOverlay
            }
        }
        .sheet(isPresented: $gameState.showContinueGameModal) {
            ContinueGameSheet(isDailyChallenge: gameState.isDailyChallenge)
                .presentationDetents([.medium])
        }
        .onAppear {
            gameState.checkForInProgressGame()
        }
    }
    
    private var gameContentView: some View {
        VStack(spacing: 0) {
            // Top content grouped together
            VStack(spacing: 0) {
                // Header with styled title
                GameViewHeader(
                    isDailyChallenge: gameState.isDailyChallenge,
                    dateString: gameState.quoteDate,
                    onRefresh: gameState.isDailyChallenge ? nil : gameState.resetGame
                )
                
                // Text display area
                VStack(spacing: 1) {
                    // Encrypted text
                    VStack(spacing: 1) {
                        if settingsState.showTextHelpers {
                            Text("ENCRYPTED")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .tracking(1.2)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        
                        Text(gameState.currentGame?.encrypted ?? "")
                            .font(fonts.encryptedDisplayText())
                            .foregroundColor(colors.encryptedColor(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 1)
                            .frame(maxWidth: .infinity)
                            .background(Color.clear)
                    }
                    
                    // Solution display
                    VStack(spacing: 1) {
                        if settingsState.showTextHelpers {
                            Text("YOUR SOLUTION")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .tracking(1.2)
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        
                        Text(gameState.currentGame?.currentDisplay ?? "")
                            .font(fonts.solutionDisplayText())
                            .foregroundColor(colors.guessColor(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 1)
                            .frame(maxWidth: .infinity)
                            .background(Color.clear)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                // Game grids
                GameGridsView(showTextHelpers: settingsState.showTextHelpers)
            }
            
            // This spacer pushes everything else down
            Spacer(minLength: 0)
            
        }
    }
    
    // Loading view
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("LOADING...")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .tracking(1.5)
                .foregroundColor(.secondary)
        }
    }
    
    // Error view
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("ERROR")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .tracking(1.5)
            
            Text(message)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button(action: {
                SoundManager.shared.play(.letterClick)
                gameState.resetGame()
            }) {
                Text("TRY AGAIN")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange)
                    )
            }
        }
    }
    
    // Win overlay
    private var winMessageOverlay: some View {
        ZStack {
            // Background with matrix effect
            MatrixTextWallEffect(
                active: true,
                density: .medium,
                performanceMode: false,
                includeKatakana: true
            )
            .ignoresSafeArea()
            .zIndex(1)
            
            // Semi-transparent overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .zIndex(2)
            
            // Win content
            VStack(spacing: 24) {
                Text(gameState.isDailyChallenge ? "DAILY COMPLETE!" : "YOU WIN!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.7), radius: 10)
                
                // Solution display
                VStack(spacing: 12) {
                    Text(gameState.currentGame?.solution ?? "")
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    if !gameState.quoteAuthor.isEmpty {
                        Text("— \(gameState.quoteAuthor)")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.7))
                )
                
                // Score
                VStack(spacing: 8) {
                    Text("SCORE")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(.gray)
                    
                    Text("\(gameState.currentGame?.calculateScore() ?? 0)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                
                // Stats row
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("MISTAKES")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .tracking(1)
                            .foregroundColor(.gray)
                        
                        Text("\(gameState.currentGame?.mistakes ?? 0)/\(gameState.currentGame?.maxMistakes ?? 0)")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 4) {
                        Text("TIME")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .tracking(1)
                            .foregroundColor(.gray)
                        
                        if let game = gameState.currentGame {
                            Text(gameState.formatTime(Int(game.lastUpdateTime.timeIntervalSince(game.startTime))))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // Action button
                Button(action: {
                    if gameState.isDailyChallenge {
                        gameState.submitDailyScore(userId: userState.userId)
                    }
                    SoundManager.shared.play(.letterClick)
                    gameState.showWinMessage = false
                    if !gameState.isDailyChallenge {
                        gameState.resetGame()
                    }
                }) {
                    Text(gameState.isDailyChallenge ? "CLOSE" : "PLAY AGAIN")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green)
                        )
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
            .zIndex(3)
        }
    }
    
    // Lose overlay
    private var loseMessageOverlay: some View {
        ZStack {
            colors.overlayBackground()
                .ignoresSafeArea()
            
            if let game = gameState.currentGame {
                VStack(spacing: 24) {
                    Text("GAME OVER")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(.red)
                    
                    Text("The solution was:")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text(game.solution)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Button(action: {
                        SoundManager.shared.play(.letterClick)
                        gameState.showLoseMessage = false
                        gameState.resetGame()
                    }) {
                        Text("TRY AGAIN")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .tracking(1.5)
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red)
                            )
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}
