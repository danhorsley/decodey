import SwiftUI

struct GameView: View {
    @ObservedObject var gameController: GameController
    @EnvironmentObject var settings: UserSettings
    
    @Environment(\.colorScheme) var colorScheme
    
    init(gameController: GameController) {
        self.gameController = gameController
    }
    
    var body: some View {
        ZStack {
            // Background color
            ColorSystem.shared.primaryBackground(for: colorScheme)
                .ignoresSafeArea()
            
            if gameController.isLoading {
                loadingView
            } else if let error = gameController.errorMessage {
                errorView(message: error)
            } else {
                gameContentView
            }
            
            // Win message overlay
            if gameController.showWinMessage {
                winMessageOverlay
            }
            
            // Lose message overlay
            if gameController.showLoseMessage {
                loseMessageOverlay
            }
        }
        .navigationTitle(gameController.isDailyChallenge ? "Daily Challenge" : "Custom Game")
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
            
            Text(gameController.isDailyChallenge ? "Loading daily challenge..." : "Loading game...")
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
            
            Button(action: gameController.resetGame) {
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
            if gameController.isDailyChallenge, let dateString = gameController.quoteDate {
                Text(dateString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            
            // Display area
            displayTextArea
            
            // Game grid with letters
            GameGridsView(
                game: $gameController.game,
                showWinMessage: $gameController.showWinMessage,
                showLoseMessage: $gameController.showLoseMessage,
                showTextHelpers: settings.showTextHelpers
            )
            
            Spacer()
            
            // Controls for custom game
            if !gameController.isDailyChallenge {
                HStack {
                    Button(action: gameController.resetGame) {
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
                if settings.showTextHelpers {
                    Text("Encrypted:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(gameController.game.encrypted)
                    .font(.system(size: DesignSystem.shared.displayFontSize, design: .monospaced))
                    .foregroundColor(ColorSystem.shared.encryptedColor(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Solution with blocks
            VStack(alignment: .leading) {
                if settings.showTextHelpers {
                    Text("Your solution:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(gameController.game.currentDisplay)
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
                Text(gameController.isDailyChallenge ? "DAILY CHALLENGE COMPLETE!" : "YOU WIN!")
                    .font(.system(size: gameController.isDailyChallenge ? 28 : 36, weight: .bold))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.7), radius: 5)
                    .multilineTextAlignment(.center)
                
                // Solution with author
                VStack(spacing: 10) {
                    Text(gameController.game.solution)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    if !gameController.quoteAuthor.isEmpty {
                        Text("— \(gameController.quoteAuthor)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    if let attribution = gameController.quoteAttribution, !attribution.isEmpty {
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
                    
                    Text("\(gameController.game.calculateScore())")
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
                        
                        Text("\(gameController.game.mistakes)/\(gameController.game.maxMistakes)")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    VStack {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(gameController.formatTime(Int(gameController.game.lastUpdateTime.timeIntervalSince(gameController.game.startTime))))
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
                
                // Different buttons based on mode
                if gameController.isDailyChallenge {
                    Button(action: {
                        gameController.submitDailyScore()
                        gameController.onGameComplete?()
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
                    Button(action: gameController.resetGame) {
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
            
            LoseOverlayView(
                solution: gameController.game.solution,
                mistakes: gameController.game.mistakes,
                maxMistakes: gameController.game.maxMistakes,
                timeTaken: Int(gameController.game.lastUpdateTime.timeIntervalSince(gameController.game.startTime)),
                isDarkMode: colorScheme == .dark,
                onTryAgain: gameController.resetGame
            )
            .frame(width: DesignSystem.shared.overlayWidth)
            .cornerRadius(DesignSystem.shared.overlayCornerRadius)
        }
    }
}
