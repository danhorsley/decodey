// TimedGameView.swift
// Decodey
//
// Time Pressure Mode - Fast-paced gameplay with auto-revealing letters

import SwiftUI
import Combine

struct TimedGameView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState
    @StateObject private var timerState = TimerState()
    
    // Layout constants (reusing from existing)
    private let maxContentWidth: CGFloat = 600
    private let sectionSpacing: CGFloat = 32
    
    var body: some View {
        VStack(spacing: 0) {
            // Modified header with timer
            TimedGameHeaderView(timerState: timerState)
                .padding(.top, GameLayout.paddingSmall)
                .padding(.horizontal, GameLayout.padding)
            
            ScrollView {
                VStack(spacing: sectionSpacing) {
                    // Game display with timer highlighting
                    timedGameDisplaySection
                        .padding(.top, GameLayout.paddingLarge)
                    
                    // Modified grids without hint button
                    TimedGameGridsView(timerState: timerState)
                        .environmentObject(gameState)
                        .environmentObject(settingsState)
                }
                .padding(.horizontal, GameLayout.padding)
                .padding(.bottom, GameLayout.paddingLarge + 8)
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            timerState.startGame(with: gameState)
        }
        .onDisappear {
            timerState.stopTimer()
        }
    }
    
    // MARK: - Timed Game Display Section
    private var timedGameDisplaySection: some View {
        VStack(spacing: 16) {
            // Encrypted text with timer highlighting
            encryptedTextWithTimerHighlight
            
            // Solution text display (reusing existing logic)
            solutionTextView
            
            // Streak and bonus indicators
            if timerState.currentStreak > 0 {
                HStack(spacing: 16) {
                    StreakIndicator(streak: timerState.currentStreak)
                    if timerState.bonusTime > 0 {
                        BonusTimeIndicator(seconds: timerState.bonusTime)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var encryptedTextWithTimerHighlight: some View {
        VStack(alignment: .center, spacing: GameLayout.paddingSmall) {
            if settingsState.showTextHelpers {
                Text("ENCRYPTED")
                    .font(.gameSection)
                    .tracking(1.5)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            // Modified encrypted text with dual highlighting
            if let game = gameState.currentGame {
                Text(game.encrypted.map { char -> AttributedString in
                    var str = AttributedString(String(char))
                    
                    // Timer highlight (next up letter)
                    if char == timerState.nextRevealLetter {
                        str.foregroundColor = timerHighlightColor
                        str.backgroundColor = timerHighlightColor.opacity(0.1)
                    }
                    // Selection highlight (user selected)
                    else if char == game.selectedLetter {
                        str.foregroundColor = Color("HighlightColor")
                        str.backgroundColor = Color("HighlightColor").opacity(0.2)
                    }
                    // Normal encrypted letter
                    else if char.isLetter {
                        str.foregroundColor = .gameEncrypted
                    }
                    
                    return str
                }.reduce(AttributedString(), +))
                .font(.gameDisplay)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .animation(.easeInOut(duration: 0.3), value: timerState.nextRevealLetter)
            }
        }
    }
    
    private var solutionTextView: some View {
        VStack(alignment: .center, spacing: GameLayout.paddingSmall) {
            if settingsState.showTextHelpers {
                Text("SOLUTION")
                    .font(.gameSection)
                    .tracking(1.5)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            if gameState.currentGame != nil {
                Text(displayedSolutionText)
                    .font(.gameDisplay)
                    .foregroundColor(.gameGuess)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }
    
    private var displayedSolutionText: String {
        guard let game = gameState.currentGame else { return "" }
        
        return game.solution.enumerated().map { index, char -> String in
            if !char.isLetter {
                return String(char)
            }
            
            let encryptedChar = game.encrypted[game.encrypted.index(game.encrypted.startIndex, offsetBy: index)]
            
            // Check if auto-revealed
            if timerState.autoRevealedLetters.contains(encryptedChar) {
                return String(char)
            }
            
            // Check if user guessed
            if let guessedChar = game.guessedMappings[encryptedChar] {
                return String(guessedChar)
            }
            
            return "█"
        }.joined()
    }
    
    private var timerHighlightColor: Color {
        // Color changes based on time remaining
        switch timerState.timeRemaining {
        case 6...:
            return Color.green
        case 4..<6:
            return Color.yellow
        case 2..<4:
            return Color.orange
        default:
            return Color.red
        }
    }
}

// MARK: - Timer State Manager
class TimerState: ObservableObject {
    @Published var timeRemaining: Double = 8.0
    @Published var nextRevealLetter: Character?
    @Published var autoRevealedLetters: Set<Character> = []
    @Published var revealOrder: [Character] = []
    @Published var currentStreak: Int = 0
    @Published var bonusTime: Double = 0
    @Published var isGameActive: Bool = false
    @Published var gatewayBonusesCount: Int = 0
    
    private var timer: Timer?
    private weak var gameState: GameState?
    private var currentRevealIndex: Int = 0
    private let baseInterval: Double = 8.0
    
    func startGame(with gameState: GameState) {
        self.gameState = gameState
        generateRevealOrder()
        startTimer()
        isGameActive = true
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isGameActive = false
    }
    
    private func startTimer() {
        timeRemaining = baseInterval
        updateNextRevealLetter()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.tick()
        }
    }
    
    private func tick() {
        guard isGameActive else { return }
        
        timeRemaining -= 0.1
        
        // Apply bonus time smoothly
        if bonusTime > 0 {
            let bonusToAdd = min(0.1, bonusTime)
            timeRemaining += bonusToAdd
            bonusTime -= bonusToAdd
        }
        
        // Check for auto-reveal
        if timeRemaining <= 0 {
            autoRevealCurrentLetter()
        }
    }
    
    private func autoRevealCurrentLetter() {
        guard let letter = nextRevealLetter,
              let gameState = gameState else { return }
        
        // Track auto-revealed letter
        autoRevealedLetters.insert(letter)
        
        // Use GameState's autoRevealLetter method
        // This will properly update the game and call checkWinCondition
        gameState.autoRevealLetter(letter)
        
        // Reset streak on auto-reveal
        currentStreak = 0
        
        // Check if game has ended
        if let game = gameState.currentGame, game.hasWon {
            stopTimer()
            return
        }
        
        // Move to next letter
        moveToNextLetter()
    }
    
    func handleCorrectGuess(for letter: Character, isGateway: Bool) {
        if isGateway {
            // Gateway letter - add bonus time with animation
            addBonusTime(2.0)
            gatewayBonusesCount += 1
        } else {
            // Timer letter - increment streak
            currentStreak += 1
            moveToNextLetter()
        }
        
        // Check if all letters are revealed
        checkForCompletion()
    }
    
    private func addBonusTime(_ seconds: Double) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            bonusTime += seconds
        }
    }
    
    private func moveToNextLetter() {
        currentRevealIndex += 1
        
        if currentRevealIndex >= revealOrder.count {
            // No more letters to reveal
            nextRevealLetter = nil
            checkForCompletion()
        } else {
            // Reset timer for next letter
            timeRemaining = baseInterval
            updateNextRevealLetter()
        }
    }
    
    private func updateNextRevealLetter() {
        guard currentRevealIndex < revealOrder.count,
              let game = gameState?.currentGame else {
            nextRevealLetter = nil
            return
        }
        
        // Find next unguessed letter
        while currentRevealIndex < revealOrder.count {
            let letter = revealOrder[currentRevealIndex]
            
            // Skip if already guessed
            if !game.guessedMappings.keys.contains(letter) {
                nextRevealLetter = letter
                return
            }
            
            currentRevealIndex += 1
        }
        
        // No more letters
        nextRevealLetter = nil
        checkForCompletion()
    }
    
    private func checkForCompletion() {
        guard let game = gameState?.currentGame else { return }
        
        // If all unique letters have been handled (guessed or auto-revealed)
        let uniqueLetters = game.getUniqueEncryptedLetters()
        let allHandled = uniqueLetters.allSatisfy { letter in
            game.guessedMappings.keys.contains(letter)
        }
        
        if allHandled && !game.hasWon {
            // All letters revealed but game didn't register win
            // This shouldn't happen if makeGuess is working correctly
            stopTimer()
        } else if game.hasWon {
            stopTimer()
        }
    }
    
    private func generateRevealOrder() {
        guard let game = gameState?.currentGame else { return }
        
        let encrypted = game.encrypted
        var letterFreq: [Character: Int] = [:]
        
        // Count frequencies
        for char in encrypted where char.isLetter {
            letterFreq[char, default: 0] += 1
        }
        
        // Smart categorization
        var tier1: [Character] = [] // Doubles, THE
        var tier2: [Character] = [] // High frequency
        var tier3: [Character] = [] // Possible A, I
        var tier4: [Character] = [] // Rest
        
        let theLetters: Set<Character> = ["T", "H", "E"]
        let commonDoubles: Set<Character> = ["L", "S", "E", "T", "F", "O"]
        
        for (letter, freq) in letterFreq {
            // Check for doubles or THE letters
            if isDouble(letter, in: encrypted) || theLetters.contains(letter) {
                tier1.append(letter)
            }
            // High frequency letters (4+ occurrences)
            else if freq >= 4 {
                tier2.append(letter)
            }
            // Single occurrences that might be A or I
            else if freq == 1 && couldBeSingleLetterWord(letter, in: encrypted) {
                tier3.append(letter)
            }
            // Everything else
            else {
                tier4.append(letter)
            }
        }
        
        // Build reveal order
        revealOrder = []
        
        // Add tier 1 (easiest to guess)
        revealOrder.append(contentsOf: tier1.shuffled())
        
        // Add tier 2
        revealOrder.append(contentsOf: tier2.shuffled())
        
        // Insert tier 3 at strategic position (after some letters revealed)
        let insertPos = max(2, revealOrder.count / 2)
        tier3.shuffled().forEach { letter in
            revealOrder.insert(letter, at: min(insertPos, revealOrder.count))
        }
        
        // Add remaining letters
        revealOrder.append(contentsOf: tier4.shuffled())
    }
    
    private func isDouble(_ letter: Character, in text: String) -> Bool {
        var prev: Character?
        for char in text {
            if char == letter && prev == letter {
                return true
            }
            prev = char
        }
        return false
    }
    
    private func couldBeSingleLetterWord(_ letter: Character, in text: String) -> Bool {
        // Split by spaces and check for single-letter words
        let words = text.split { !$0.isLetter && $0 != "'" }
        return words.contains { $0.count == 1 && $0.first == letter }
    }
}

// MARK: - Timed Game Header
struct TimedGameHeaderView: View {
    @EnvironmentObject var gameState: GameState
    @ObservedObject var timerState: TimerState
    @State private var showNumericTimer: Bool = false
    
    var body: some View {
        HStack {
            // Back button (reusing existing style)
            BackButton()
            
            Spacer()
            
            // Timer pill display
            TimerPill(
                timeRemaining: timerState.timeRemaining,
                showNumeric: showNumericTimer
            )
            .onTapGesture {
                showNumericTimer.toggle()
            }
            
            Spacer()
            
            // Refresh button for custom games
            if !gameState.isDailyChallenge {
                RefreshButton {
                    gameState.resetGame()
                    timerState.stopTimer()
                    timerState.startGame(with: gameState)
                }
            }
        }
    }
}

// MARK: - Timer Pill Component
struct TimerPill: View {
    let timeRemaining: Double
    let showNumeric: Bool
    
    private var fillPercentage: CGFloat {
        CGFloat(timeRemaining / 8.0)
    }
    
    private var pillColor: Color {
        switch timeRemaining {
        case 6...:
            return .green
        case 4..<6:
            return .yellow
        case 2..<4:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        ZStack {
            // Background pill
            Capsule()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 120, height: 32)
            
            // Animated fill
            GeometryReader { geometry in
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [pillColor, pillColor.opacity(0.7)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * fillPercentage)
                    .animation(.linear(duration: 0.1), value: timeRemaining)
            }
            .frame(width: 120, height: 32)
            
            // Timer text
            if showNumeric {
                Text(String(format: "%.1f", timeRemaining))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "timer")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Timed Game Grids (without hint button)
struct TimedGameGridsView: View {
    @EnvironmentObject var gameState: GameState
    @EnvironmentObject var settingsState: SettingsState
    @ObservedObject var timerState: TimerState
    
    var body: some View {
        VStack(spacing: GameLayout.paddingLarge) {
            // Encrypted letters grid with timer highlighting
            encryptedGrid
            
            // Guess letters grid (unchanged)
            guessGrid
        }
    }
    
    private var encryptedGrid: some View {
        VStack(alignment: .center, spacing: GameLayout.paddingSmall) {
            if settingsState.showTextHelpers {
                Text("SELECT ENCRYPTED LETTER")
                    .font(.gameSection)
                    .tracking(1.5)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            if let game = gameState.currentGame {
                let uniqueLetters = game.getUniqueEncryptedLetters()
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(GameLayout.cellSize), spacing: 8), count: 6),
                    spacing: 8
                ) {
                    ForEach(uniqueLetters, id: \.self) { letter in
                        TimedEncryptedLetterCell(
                            letter: letter,
                            isSelected: game.selectedLetter == letter,
                            isGuessed: game.guessedMappings[letter] != nil,
                            frequency: game.letterFrequency[letter] ?? 0,
                            isNextUp: timerState.nextRevealLetter == letter,
                            timerColor: timerHighlightColor(for: timerState.timeRemaining),
                            action: {
                                gameState.selectLetter(letter)
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var guessGrid: some View {
        VStack(alignment: .center, spacing: GameLayout.paddingSmall) {
            if settingsState.showTextHelpers {
                Text("GUESS SOLUTION LETTER")
                    .font(.gameSection)
                    .tracking(1.5)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            
            if let game = gameState.currentGame {
                let uniqueLetters = game.getUniqueSolutionLetters()
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(GameLayout.cellSize), spacing: 8), count: 6),
                    spacing: 8
                ) {
                    ForEach(uniqueLetters, id: \.self) { letter in
                        let isUsed = game.guessedMappings.values.contains(letter)
                        GuessLetterCell(
                            letter: letter,
                            isUsed: isUsed,
                            isIncorrectForSelected: isIncorrectGuess(letter),
                            action: {
                                handleGuess(letter)
                            }
                        )
                    }
                }
            }
        }
    }
    
    private func handleGuess(_ letter: Character) {
        guard let game = gameState.currentGame,
              let selected = game.selectedLetter else { return }
        
        // Use GameState's makeGuess method
        gameState.makeGuess(for: selected, with: letter)
        
        // Check if correct and update timer state
        if let updatedGame = gameState.currentGame {
            let isCorrect = updatedGame.guessedMappings[selected] == letter
            let isGateway = selected != timerState.nextRevealLetter
            
            if isCorrect {
                timerState.handleCorrectGuess(for: selected, isGateway: isGateway)
            }
        }
    }
    
    private func isIncorrectGuess(_ letter: Character) -> Bool {
        guard let selected = gameState.selectedEncryptedLetter,
              let game = gameState.currentGame else { return false }
        return game.incorrectGuesses[selected]?.contains(letter) ?? false
    }
    
    private func timerHighlightColor(for time: Double) -> Color {
        switch time {
        case 6...:
            return .green
        case 4..<6:
            return .yellow
        case 2..<4:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Timed Encrypted Letter Cell
struct TimedEncryptedLetterCell: View {
    let letter: Character
    let isSelected: Bool
    let isGuessed: Bool
    let frequency: Int
    let isNextUp: Bool
    let timerColor: Color
    let action: () -> Void
    
    @State private var pulseAnimation = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Base cell
                RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
                
                // Pulsing timer border for next-up letter
                if isNextUp {
                    RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                        .stroke(timerColor, lineWidth: 3)
                        .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                        .opacity(pulseAnimation ? 0.6 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                }
                
                // Letter content
                Text(String(letter))
                    .font(.gameCell)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Frequency indicator
                if frequency > 0 && !isGuessed {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(frequency)")
                                .font(.gameFrequency)
                                .foregroundColor(textColor.opacity(0.7))
                                .padding(4)
                        }
                    }
                }
            }
            .frame(width: GameLayout.cellSize, height: GameLayout.cellSize)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isGuessed)
        .onAppear {
            if isNextUp {
                pulseAnimation = true
            }
        }
        .onChange(of: isNextUp) { newValue in
            pulseAnimation = newValue
        }
    }
    
    private var backgroundColor: Color {
        if isGuessed {
            return Color.gray.opacity(0.3)
        } else if isSelected {
            return Color.accentColor.opacity(0.2)
        } else if isNextUp {
            return timerColor.opacity(0.1)
        } else {
            return Color.gameSurface
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.accentColor
        } else if isNextUp {
            return timerColor
        } else {
            return Color.gameBorder
        }
    }
    
    private var borderWidth: CGFloat {
        if isSelected || isNextUp {
            return 2
        } else {
            return 1
        }
    }
    
    private var textColor: Color {
        if isGuessed {
            return .secondary
        } else if isNextUp {
            return timerColor
        } else {
            return .gameEncrypted
        }
    }
}

// MARK: - Streak and Bonus Indicators
struct StreakIndicator: View {
    let streak: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.orange)
            
            Text("STREAK: \(streak)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.2))
        )
    }
}

struct BonusTimeIndicator: View {
    let seconds: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.green)
            
            Text("+\(String(format: "%.1f", seconds))s")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.2))
        )
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Reusable Back Button
struct BackButton: View {
    @Environment(\.dismiss) var dismiss
    @State private var isPressed = false
    
    var body: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.primary)
                .scaleEffect(isPressed ? 0.85 : 1.0)
                .opacity(isPressed ? 0.8 : 1.0)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}
