import SwiftUI

struct GameView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var settings: UserSettings
    
    @State private var game = Game()
    @State private var showWinMessage = false
    @State private var showLoseMessage = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Store quote metadata
    @State private var quoteAuthor: String = ""
    @State private var quoteAttribution: String? = nil
    
    // Use DesignSystem for consistent sizing and colors
    private let design = DesignSystem.shared
    private let colors = ColorSystem.shared
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Background color
            colors.primaryBackground(for: colorScheme)
                .ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(message: error)
            } else {
                gameContentView
            }
            
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
            loadNewGame()
        }
    }
    
    // MARK: - Content Views
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Loading game...")
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
            
            Button(action: loadNewGame) {
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
            
            // Controls
            HStack {
                Button(action: resetGame) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("New Game")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(colors.accent)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                if authService.isAuthenticated {
                    // User info
                    VStack(alignment: .trailing) {
                        Text("Playing as \(authService.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(design.displayAreaPadding)
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
                    .foregroundColor(colors.encryptedColor(for: colorScheme))
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
                    .foregroundColor(colors.guessColor(for: colorScheme))
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
            .edgesIgnoringSafeArea(.all)
            .zIndex(1)
            
            // Semi-transparent overlay
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .zIndex(2)
            
            // Content
            VStack(spacing: 20) {
                // Win message
                Text("YOU WIN!")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.7), radius: 5)
                
                // Solution with author
                VStack(spacing: 10) {
                    Text(game.solution)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    if !quoteAuthor.isEmpty {
                        Text("— \(quoteAuthor)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    if let attribution = quoteAttribution, !attribution.isEmpty {
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
            .zIndex(3)
        }
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
    
    // MARK: - Helper Functions
    
    private func loadNewGame() {
        isLoading = true
        errorMessage = nil
        
        // Use a background thread for database operations
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Try to get a random quote from the database
                let (quoteText, author, attribution) = try DatabaseManager.shared.getRandomQuote()
                
                // Create a new game on the main thread
                DispatchQueue.main.async {
                    // Store quote metadata for win screen
                    self.quoteAuthor = author
                    self.quoteAttribution = attribution
                    
                    // Create a new game with the retrieved quote
                    var newGame = Game()
                    
                    // Ensure solution is properly set
                    newGame.solution = quoteText.uppercased()
                    newGame.setupGameWithSolution(quoteText.uppercased())
                    
                    // Update state
                    self.game = newGame
                    self.showWinMessage = false
                    self.showLoseMessage = false
                    self.isLoading = false
                }
            } catch {
                // Handle error on the main thread
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load a quote: \(error.localizedDescription)"
                    self.isLoading = false
                    
                    // Create a fallback game with a predefined quote if database fails
                    var fallbackGame = Game()
                    self.quoteAuthor = "Anonymous"
                    self.quoteAttribution = nil
                    fallbackGame.setupGameWithSolution("THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG")
                    self.game = fallbackGame
                }
            }
        }
    }
    
    private func resetGame() {
        loadNewGame()
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview Provider
#if DEBUG
struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        GameView()
            .environmentObject(AuthService())
            .environmentObject(UserSettings(authService: AuthService()))
    }
}
#endif
