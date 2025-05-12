import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: UserSettings
    @State private var game = Game()
    @State private var showWinMessage = false
    @State private var showLoseMessage = false
    
    // Use DesignSystem for consistent sizing and colors
    private let design = DesignSystem.shared
    private let colors = ColorSystem.shared
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background color
            colors.primaryBackground(for: colorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: design.displayAreaPadding) {
                // Game title
                Text("decodey")
                    .font(.largeTitle.bold())
                    .padding(.top)
                
                // Display area
                displayTextArea
                
                // Game grid with letters
                GameGridsView(
                    game: $game,
                    showWinMessage: $showWinMessage,
                    showLoseMessage: $showLoseMessage,
                    showTextHelpers: settings.showTextHelpers
                )
                
                Spacer()
            }
            .padding(design.displayAreaPadding)
            
            // Win message overlay
            if showWinMessage {
                winMessageOverlay
            }
            
            // Lose message overlay
            if showLoseMessage {
                loseMessageOverlay
            }
        }
        .onAppear {
            resetGame()
        }
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
                
                Text(game.encrypted)
                    .font(.system(size: design.displayFontSize, design: .monospaced))
                    .foregroundColor(colors.encryptedColor(for: colorScheme)) // Use same color as encrypted grid
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
                
                Text(game.currentDisplay)
                    .font(.system(size: design.displayFontSize, design: .monospaced))
                    .foregroundColor(colors.guessColor(for: colorScheme)) // Use same color as guess grid
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    

    var winMessageOverlay: some View {
        ZStack {
            // 1. Put the matrix effect DIRECTLY in this ZStack, not in a child view
            MatrixTextWallEffect(
                active: true,
                density: .medium,
                performanceMode: false,
                includeKatakana: true
            )
            // 2. Ensure it covers the entire screen
            .edgesIgnoringSafeArea(.all)
            // 3. Set an explicit zIndex to ensure it's behind other content
            .zIndex(1)
            
            // 4. Semi-transparent overlay to ensure content visibility
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .zIndex(2)
            
            // 5. Content
            VStack(spacing: 20) {
                // Win message
                Text("YOU WIN!")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.7), radius: 5)
                
                // Solution
                Text(game.solution)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                
                // Score
                VStack {
                    Text("SCORE")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("\(game.calculateScore())")
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
                        
                        Text("\(game.mistakes)/\(game.maxMistakes)")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    VStack {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(formatTime(Int(game.lastUpdateTime.timeIntervalSince(game.startTime))))
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                }
                
                // Button
                Button(action: resetGame) {
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
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .shadow(radius: 10)
            // 6. Highest zIndex to ensure it's on top
            .zIndex(3)
        }
    }

    // Add this helper function to ContentView if it doesn't already exist
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }


    
    // Lose message overlay
    private var loseMessageOverlay: some View {
        ZStack {
            colors.overlayBackground()
                .ignoresSafeArea()
            
            LoseOverlayView(
                solution: game.solution,
                mistakes: game.mistakes,
                maxMistakes: game.maxMistakes,
                timeTaken: Int(game.lastUpdateTime.timeIntervalSince(game.startTime)),
                isDarkMode: colorScheme == .dark,
                onTryAgain: resetGame
            )
            .frame(width: design.overlayWidth)
            .cornerRadius(design.overlayCornerRadius)
        }
    }
    
    // Reset game function
    private func resetGame() {
        // Create a new game
        game = Game()
        showWinMessage = false
        showLoseMessage = false
    }
}
