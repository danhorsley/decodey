import SwiftUI

struct GameView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var settingsState: SettingsState
    
    @Environment(\.colorScheme) var colorScheme
    private let fonts = FontSystem.shared
    private let colors = ColorSystem.shared
    
    // Layout constants
    private let maxContentWidth: CGFloat = 600
    private let headerToContentGap: CGFloat = 24
    private let sectionSpacing: CGFloat = 32
    
    var body: some View {
                ZStack {
            // Background
//            let currentColorScheme: ColorScheme = settingsState.isDarkMode ? .dark : .light
            let _ = print("GameView colorScheme: \(colorScheme)") // Debug line

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
                Group {
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
            }

            
            // Lose overlay
            if gameState.showLoseMessage {
                Group {
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
                    
                    
        }
        .sheet(isPresented: $gameState.showContinueGameModal) {
            ContinueGameSheet(isDailyChallenge: gameState.isDailyChallenge)
                .presentationDetents([.medium])
        }
        .onAppear {
            gameState.validateModalState()  // Make sure we're not showing wrong modal
            gameState.checkForInProgressGame(isDailyChallenge: false)
        }
    }
    
    private var enhancedSolutionDisplay: String {
        guard let game = gameState.currentGame else { return "" }
        
        return game.encrypted.map { char in
            if char.isLetter {
                if let decrypted = game.guessedMappings[char] {
                    // Show the correctly guessed letter
                    return String(decrypted)
                } else {
                    // Show a monospace block instead of the encrypted letter
                    return "█"
                }
            } else {
                // Preserve spaces and punctuation
                return String(char)
            }
        }.joined()
    }
    
    private var gameContentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header - stays at top
                GameViewHeader(
                    isDailyChallenge: gameState.isDailyChallenge,
                    dateString: gameState.quoteDate,
                    onRefresh: gameState.isDailyChallenge ? nil : gameState.resetGame
                )
                
                // Game content card - centered with max width
                VStack(spacing: sectionSpacing) {
                    // Text display section - matching GameGridsView styling
                    textDisplaySection
                        .padding(.top, headerToContentGap)
                    
                    // Game grids section
                    GameGridsView(showTextHelpers: settingsState.showTextHelpers)
                        .padding(.bottom, 20) // Extra bottom padding for mobile
                }
                .frame(maxWidth: maxContentWidth)
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 0, maxHeight: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize) // iOS 16.4+ - graceful fallback
    }
    
    // MARK: - Text Display Section (Matching GameGridsView Style)
    
    private var textDisplaySection: some View {
        VStack(spacing: 24) {
            // Encrypted text section - matching GameGridsView exactly
            VStack(alignment: .center, spacing: 8) {
                if settingsState.showTextHelpers {
                    Text("ENCRYPTED")
                        .font(.custom("Courier New", size: 10).weight(.medium))
                        .tracking(1.5)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                Text(gameState.currentGame?.encrypted ?? "")
                    .font(fonts.encryptedDisplayText())
                    .foregroundColor(colors.encryptedColor(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
            }
            
            // Solution text section - matching GameGridsView exactly
            VStack(alignment: .center, spacing: 8) {
                if settingsState.showTextHelpers {
                    Text("YOUR SOLUTION")
                        .font(.custom("Courier New", size: 10).weight(.medium))
                        .tracking(1.5)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                Text(enhancedSolutionDisplay)
                    .font(fonts.solutionDisplayText())
                    .foregroundColor(colors.guessColor(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // Loading view - simplified, no "progress" container
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(colors.accent)
            
            Text("LOADING...")
                .font(.custom("Courier New", size: 14).weight(.medium))
                .tracking(1.5)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Error view - simplified styling
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(colors.warning)
            
            Text("ERROR")
                .font(.custom("Courier New", size: 18).weight(.bold))
                .tracking(1.5)
                .foregroundColor(colors.primaryText(for: colorScheme))
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(colors.secondaryText(for: colorScheme))
                .padding(.horizontal, 40)
            
            Button(action: {
                SoundManager.shared.play(.letterClick)
                gameState.resetGame()
            }) {
                Text("TRY AGAIN")
                    .font(.custom("Courier New", size: 14).weight(.semibold))
                    .tracking(1)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colors.warning)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


