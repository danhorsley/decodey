import SwiftUI

struct GameView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var settingsState: SettingsState
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background color
            ColorSystem.shared.primaryBackground(for: colorScheme)
                .ignoresSafeArea()
            
            if gameState.isLoading {
                loadingView
            } else if let error = gameState.errorMessage {
                errorView(message: error)
            } else {
                gameContentView
            }
            
            // Win message overlay
            if gameState.showWinMessage {
                winMessageOverlay
            }
            
            // Lose message overlay
            if gameState.showLoseMessage {
                loseMessageOverlay
            }
        }
        .sheet(isPresented: $gameState.showContinueGameModal) {
            ContinueGameSheet(isDailyChallenge: gameState.isDailyChallenge)
                .presentationDetents([.medium])
        }
        .onAppear {
            // Check for in-progress game when the view appears
            gameState.checkForInProgressGame()
        }
        .navigationTitle(gameState.isDailyChallenge ? "Daily Challenge" : "Custom Game")
        
        // Use this modifier only on iOS/iPadOS
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    // MARK: - Content Views
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text(gameState.isDailyChallenge ? "Loading daily challenge..." : "Loading game...")
                .font(.headline)
                .padding()
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error loading game")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: gameState.resetGame) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }
    
    private var gameContentView: some View {
        VStack(spacing: DesignSystem.shared.displayAreaPadding) {
            // Header - only shown for daily challenge
            if gameState.isDailyChallenge, let dateString = gameState.quoteDate {
                Text(dateString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            
            // Display area
            displayTextArea
            
            // Game grid with letters
            GameGridsView(
                showTextHelpers: settingsState.showTextHelpers
            )
            
            Spacer()
            
            // Controls for custom game
            if !gameState.isDailyChallenge {
                HStack {
                    Button(action: gameState.resetGame) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("New Game")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(ColorSystem.shared.accent)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .padding(DesignSystem.shared.displayAreaPadding)
    }
    
    // Display area for the encrypted and solution text
    private var displayTextArea: some View {
        VStack(spacing: 16) {
            // Encrypted text
            VStack(alignment: .leading) {
                if settingsState.showTextHelpers {
                    Text("Encrypted:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(gameState.currentGame?.encrypted ?? "")
                    .font(.system(size: DesignSystem.shared.displayFontSize, design: .monospaced))
                    .foregroundColor(ColorSystem.shared.encryptedColor(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Solution with blocks
            VStack(alignment: .leading) {
                if settingsState.showTextHelpers {
                    Text("Your solution:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(gameState.currentGame?.currentDisplay ?? "")
                    .font(.system(size: DesignSystem.shared.displayFontSize, design: .monospaced))
                    .foregroundColor(ColorSystem.shared.guessColor(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    // Win message overlay
    private var winMessageOverlay: some View {
        ZStack {
            // Matrix effect background
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
            
            // Content
            VStack(spacing: 20) {
                // Win message - different for daily vs custom
                Text(gameState.isDailyChallenge ? "DAILY CHALLENGE COMPLETE!" : "YOU WIN!")
                    .font(.system(size: gameState.isDailyChallenge ? 28 : 36, weight: .bold))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.7), radius: 5)
                    .multilineTextAlignment(.center)
                
                // Solution with author
                VStack(spacing: 10) {
                    Text(gameState.currentGame?.solution ?? "")
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    if !gameState.quoteAuthor.isEmpty {
                        Text("— \(gameState.quoteAuthor)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    if let attribution = gameState.quoteAttribution, !attribution.isEmpty {
                        Text(attribution)
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                
                // Score
                VStack {
                    Text("SCORE")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("\(gameState.currentGame?.calculateScore() ?? 0)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                
                // Stats
                HStack(spacing: 40) {
                    VStack {
                        Text("Mistakes")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("\(gameState.currentGame?.mistakes ?? 0)/\(gameState.currentGame?.maxMistakes ?? 0)")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    VStack {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        if let game = gameState.currentGame {
                            Text(gameState.formatTime(Int(game.lastUpdateTime.timeIntervalSince(game.startTime))))
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // Different buttons based on mode
                if gameState.isDailyChallenge {
                    Button(action: {
                        gameState.submitDailyScore(userId: userState.userId)
                        gameState.showWinMessage = false
                    }) {
                        Text("Close")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .padding(.top, 20)
                } else {
                    // Play again button for custom game
                    Button(action: gameState.resetGame) {
                        Text("Play Again")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .padding(.top, 20)
                }
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .shadow(radius: 10)
            .zIndex(3)
        }
    }
    
    // Lose message overlay
    private var loseMessageOverlay: some View {
        ZStack {
            ColorSystem.shared.overlayBackground()
                .ignoresSafeArea()
            
            if let game = gameState.currentGame {
                LoseOverlayView(
                    solution: game.solution,
                    mistakes: game.mistakes,
                    maxMistakes: game.maxMistakes,
                    timeTaken: Int(game.lastUpdateTime.timeIntervalSince(game.startTime)),
                    isDarkMode: colorScheme == .dark,
                    onTryAgain: gameState.resetGame
                )
                .frame(width: DesignSystem.shared.overlayWidth)
                .cornerRadius(DesignSystem.shared.overlayCornerRadius)
            }
        }
    }
}

