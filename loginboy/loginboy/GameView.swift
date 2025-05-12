import SwiftUI

struct GameView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var settings: UserSettings
    
    // Game state
    @State private var game = Game()
    @State private var showWinMessage = false
    @State private var showLoseMessage = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Quote metadata
    @State private var quoteAuthor: String = ""
    @State private var quoteAttribution: String? = nil
    @State private var quoteDate: String? = nil
    
    // Mode configuration
    var isDailyChallenge: Bool = false
    var dailyQuote: DailyQuote? = nil
    var onGameComplete: (() -> Void)? = nil
    
    // Use DesignSystem for consistent sizing and colors
    private let design = DesignSystem.shared
    private let colors = ColorSystem.shared
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
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
            if let dailyQuote = dailyQuote {
                loadDailyGame(quote: dailyQuote)
            } else {
                loadNewGame()
            }
        }
        .navigationTitle(isDailyChallenge ? "Daily Challenge" : "Custom Game")
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
            
            Text(isDailyChallenge ? "Loading daily challenge..." : "Loading game...")
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
            
            Button(action: isDailyChallenge ? { loadDailyGame(quote: dailyQuote!) } : loadNewGame) {
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
            // Header - only shown for daily challenge
            if isDailyChallenge, let dateString = quoteDate {
                Text(dateString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            
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
            
            // Show difficulty indicator for daily challenge
            if isDailyChallenge, let quote = dailyQuote {
                // Create a custom difficulty indicator instead of using DifficultyIndicator
                VStack(spacing: 4) {
                    Text("Difficulty")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: "star.fill")
                                .foregroundColor(index < Int(quote.difficulty.rounded()) ? .yellow : .gray.opacity(0.3))
                                .font(.system(size: 14))
                        }
                    }
                    
                    Text(difficultyText(quote.difficulty))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(difficultyColor(quote.difficulty))
                }
                .padding(.vertical) // Use vertical padding instead of bottom
            }
            
            // Controls for custom game
            if !isDailyChallenge {
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
            .ignoresSafeArea()
            .zIndex(1)
            
            // Semi-transparent overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .zIndex(2)
            
            // Content
            VStack(spacing: 20) {
                // Win message - different for daily vs custom
                Text(isDailyChallenge ? "DAILY CHALLENGE COMPLETE!" : "YOU WIN!")
                    .font(.system(size: isDailyChallenge ? 28 : 36, weight: .bold))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.7), radius: 5)
                    .multilineTextAlignment(.center)
                
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
                
                // Different buttons based on mode and auth status
                if isDailyChallenge {
                    if authService.isAuthenticated {
                        Button(action: {
                            submitDailyScore()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if let onComplete = onGameComplete {
                                    onComplete()
                                } else {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                        }) {
                            Text("Submit Score & Close")
                                .font(.headline)
                                .foregroundColor(.black)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 15)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        .padding(.top, 20)
                    } else {
                        Button(action: {
                            if let onComplete = onGameComplete {
                                onComplete()
                            } else {
                                presentationMode.wrappedValue.dismiss()
                            }
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
                    }
                } else {
                    // Play again button for custom game
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
    
    private func loadDailyGame(quote: DailyQuote) {
        isLoading = true
        errorMessage = nil
        
        // Set up game with the quote from DailyQuote
        DispatchQueue.main.async {
            // Store quote metadata
            self.quoteAuthor = quote.author
            self.quoteAttribution = quote.minor_attribution
            self.quoteDate = quote.formattedDate
            
            // Create a new game with the daily quote
            var newGame = Game()
            newGame.solution = quote.text.uppercased()
            newGame.setupGameWithSolution(quote.text.uppercased())
            
            // Update game difficulty based on quote difficulty
            let difficulty = self.getDifficultyString(from: quote.difficulty)
            newGame.difficulty = difficulty
            newGame.maxMistakes = self.difficultyToMaxMistakes(difficulty)
            
            // Update state
            self.game = newGame
            self.showWinMessage = false
            self.showLoseMessage = false
            self.isLoading = false
        }
    }
    
    private func resetGame() {
        if isDailyChallenge, let quote = dailyQuote {
            loadDailyGame(quote: quote)
        } else {
            loadNewGame()
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Helper to convert difficulty value to text
    private func difficultyText(_ difficulty: Double) -> String {
        switch difficulty {
        case 0..<1:
            return "Very Easy"
        case 1..<2:
            return "Easy"
        case 2..<3:
            return "Medium"
        case 3..<4:
            return "Hard"
        default:
            return "Very Hard"
        }
    }
    
    // Helper to get color based on difficulty
    private func difficultyColor(_ difficulty: Double) -> Color {
        switch difficulty {
        case 0..<1:
            return .green
        case 1..<2:
            return .blue
        case 2..<3:
            return .orange
        case 3..<4:
            return .red
        default:
            return .purple
        }
    }
    
    // Submit score to leaderboard (API call would go here)
    private func submitDailyScore() {
        guard authService.isAuthenticated,
              let token = authService.getAccessToken(),
              let quote = dailyQuote else {
            return
        }
        
        // Calculate final score
        let finalScore = game.calculateScore()
        let timeTaken = Int(game.lastUpdateTime.timeIntervalSince(game.startTime))
        
        // In a real implementation, you would make an API call here to submit the score
        print("Submitting daily challenge score: \(finalScore) for user \(authService.username)")
        
        // Example API call (commented out as the endpoint might not exist)
        /*
        guard let url = URL(string: "\(authService.baseURL)/api/submit_daily_score") else {
            return
        }
        
        // Score data
        let scoreData: [String: Any] = [
            "quote_id": quote.id,
            "score": finalScore,
            "mistakes": game.mistakes,
            "time_taken": timeTaken,
            "date": quote.date
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: scoreData)
        } catch {
            print("Error serializing score data: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error submitting score: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Score submitted successfully")
            } else {
                print("Failed to submit score with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
        }.resume()
        */
        
        // For now, just update local stats in the database
        do {
            try DatabaseManager.shared.updateStatistics(
                userId: authService.userId,
                gameWon: true,
                mistakes: game.mistakes,
                timeTaken: timeTaken,
                score: finalScore
            )
            print("Updated local statistics for daily challenge")
        } catch {
            print("Error updating local stats: \(error)")
        }
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


// Helper to convert difficulty value to game difficulty string
private func getDifficultyString(from value: Double) -> String {
    switch value {
    case 0..<1:
        return "easy"
    case 1..<3:
        return "medium"
    default:
        return "hard"
    }
}

// Convert difficulty string to max mistakes
private func difficultyToMaxMistakes(_ difficulty: String) -> Int {
    switch difficulty {
    case "easy":
        return 8
    case "medium":
        return 5
    case "hard":
        return 3
    default:
        return 5
    }
}
