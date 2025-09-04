import SwiftUI

enum GameMode {
    case daily
    case random
}

struct GameView: View {
    let gameMode: GameMode
    
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var userState: UserState
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            if isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Loading Quote...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let game = gameState.currentGame {
                // Show the actual game
                ActiveGameView(game: game)
            } else {
                // Show start screen
                VStack(spacing: 20) {
                    Text(gameMode == .daily ? "Daily Challenge" : "Random Quote")
                        .font(.title.bold())
                    
                    Text(gameMode == .daily ?
                         "Crack today's quote challenge" :
                         "Practice with a random quote")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(gameMode == .daily ? "Start Daily Challenge" : "Start Random Game") {
                        startGame()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.headline)
                    .padding()
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
    }
    
    private func startGame() {
        isLoading = true
        
        Task {
            if gameMode == .daily {
                await gameState.setupDailyChallenge()
            } else {
                await gameState.setupRandomGame()
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct ActiveGameView: View {
    @ObservedObject var game: GameModel
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var gameState: GameState
    
    var body: some View {
        VStack(spacing: 20) {
            // Game header
            HStack {
                VStack(alignment: .leading) {
                    Text("Score: \(game.calculateScore())")
                        .font(.headline)
                    
                    Text("Mistakes: \(game.mistakes)/\(game.maxMistakes)")
                        .font(.caption)
                        .foregroundColor(game.mistakes >= game.maxMistakes ? .red : .secondary)
                }
                
                Spacer()
                
                Button("New Game") {
                    gameState.currentGame = nil
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            // Quote display area
            VStack(spacing: 15) {
                // Encoded quote
                Text(game.encodedQuote)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                
                // Current guess
                if !game.currentGuess.isEmpty {
                    Text("Your guess: \(game.currentGuess)")
                        .font(.body)
                        .foregroundColor(.blue)
                }
                
                // Input field
                if !game.hasWon && !game.hasLost {
                    TextField("Enter your guess...", text: Binding(
                        get: { game.currentGuess },
                        set: { game.currentGuess = $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        submitGuess()
                    }
                    
                    Button("Submit Guess") {
                        submitGuess()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(game.currentGuess.isEmpty)
                }
            }
            .padding()
            
            // Game over messages
            if game.hasWon {
                VStack {
                    Text("🎉 Congratulations!")
                        .font(.title.bold())
                        .foregroundColor(.green)
                    
                    Text("You cracked the code!")
                        .font(.body)
                    
                    Text("Final Score: \(game.calculateScore())")
                        .font(.headline)
                        .padding(.top)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else if game.hasLost {
                VStack {
                    Text("💥 Game Over")
                        .font(.title.bold())
                        .foregroundColor(.red)
                    
                    Text("The quote was:")
                        .font(.body)
                    
                    Text(game.decodedQuote)
                        .font(.body.italic())
                        .multilineTextAlignment(.center)
                        .padding(.top, 5)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
            
            Spacer()
        }
    }
    
    private func submitGuess() {
        let guess = game.currentGuess.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !guess.isEmpty else { return }
        
        let isCorrect = guess.lowercased() == game.decodedQuote.lowercased()
        
        if isCorrect {
            game.hasWon = true
            game.lastUpdateTime = Date()
            
            // Update user stats
            userState.updateStats(won: true, score: game.calculateScore())
            
            SoundManager.shared.play(.correctGuess)
        } else {
            game.mistakes += 1
            if game.mistakes >= game.maxMistakes {
                game.hasLost = true
                game.lastUpdateTime = Date()
                
                // Update user stats
                userState.updateStats(won: false, score: game.calculateScore())
                
                SoundManager.shared.play(.incorrectGuess)
            } else {
                SoundManager.shared.play(.incorrectGuess)
            }
        }
        
        game.currentGuess = ""
    }
}
