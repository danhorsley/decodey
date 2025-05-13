import SwiftUI
import Combine

// MARK: - Matrix Text Wall Background Effect with Katakana Characters
struct MatrixTextWallEffect: View {
    // Configuration
    let active: Bool
    let density: MatrixDensity
    let performanceMode: Bool
    let includeKatakana: Bool
    
    // Matrix character sets
    private var matrixCharset: String {
        var charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$#@&%*+=_<>[]()!?/\\|"
        
        // Add katakana characters for more authentic matrix effect
        if includeKatakana {
            // Add katakana unicode range
            for i in 0x30A0...0x30FF {
                if let unicodeScalar = UnicodeScalar(i) {
                    charset.append(Character(unicodeScalar))
                }
            }
            
            // Add additional special Japanese characters
            charset += "・ー「」＋－※×÷＝≠≦≧∞∴♂♀★☆♠♣♥♦♪†‡§¶"
        }
        
        return charset
    }
    
    // Density options (for different device capabilities)
    enum MatrixDensity {
        case light    // Fewer characters, better performance
        case medium   // Balanced option
        case dense    // Most visually impressive, may affect performance
        
        var columns: Int {
            switch self {
            case .light: return 15
            case .medium: return 25
            case .dense: return 35
            }
        }
        
        var rows: Int {
            switch self {
            case .light: return 10
            case .medium: return 15
            case .dense: return 20
            }
        }
    }
    
    // State for matrix characters
    @State private var matrixChars: [[MatrixChar]] = []
    @State private var timer: AnyCancellable?
    @State private var isPaused = false
    
    // Main view
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black
                
                // Matrix character grid
                VStack(spacing: 0) {
                    ForEach(0..<matrixChars.count, id: \.self) { rowIndex in
                        HStack(spacing: 1) {
                            ForEach(0..<matrixChars[rowIndex].count, id: \.self) { colIndex in
                                let matrixChar = matrixChars[rowIndex][colIndex]
                                
                                Text(String(matrixChar.displayChar))
                                    .font(.system(size: performanceMode ? 14 : 16, weight: .medium, design: .monospaced))
                                    .foregroundColor(
                                        Color(
                                            red: 0,
                                            green: matrixChar.intensity,
                                            blue: matrixChar.intensity * 0.4
                                        )
                                    )
                                    .opacity(matrixChar.opacity)
                                    .frame(width: geometry.size.width / CGFloat(density.columns))
                                    .blur(radius: performanceMode ? 0 : getBlurRadius(row: rowIndex, totalRows: matrixChars.count))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
                if active {
                    initializeMatrix(size: geometry.size)
                    startAnimation()
                }
            }
            .onChange(of: active) { _, newValue in
                if newValue {
                    initializeMatrix(size: geometry.size)
                    startAnimation()
                } else {
                    stopAnimation()
                }
            }
            .onChange(of: geometry.size) { _, newSize in
                if active {
                    initializeMatrix(size: newSize)
                }
            }
        }
    }
    
    // Initialize the matrix characters
    private func initializeMatrix(size: CGSize) {
        // Create empty matrix with the right dimensions
        matrixChars = Array(
            repeating: Array(
                repeating: MatrixChar(
                    displayChar: " ",
                    state: .cycling,
                    cycleSpeed: 1.0,
                    cyclePosition: 0,
                    maxCycles: Int.random(in: 3...10),
                    settleDelay: Double.random(in: 0.1...5.0),
                    intensity: 0.9,
                    opacity: Double.random(in: 0.7...1.0)
                ),
                count: density.columns
            ),
            count: density.rows
        )
        
        // Initialize each character
        for row in 0..<matrixChars.count {
            for col in 0..<matrixChars[row].count {
                matrixChars[row][col] = createRandomMatrixChar(row: row, col: col)
            }
        }
    }
    
    // Create a random matrix character
    private func createRandomMatrixChar(row: Int, col: Int) -> MatrixChar {
        let charset = matrixCharset
        let randomChar = charset.randomElement() ?? "X"
        let randomState: MatrixCharState = Bool.random() ? .cycling : .settled
        let randomSpeed = Double.random(in: 0.5...2.0)
        let randomMaxCycles = Int.random(in: 3...15)
        let baseDelay = Double(row + col) * 0.05 // Delay based on position
        let randomDelay = Double.random(in: 0...3.0)
        let delay = baseDelay + randomDelay
        
        // Create depth effect by varying the intensity and opacity
        let depthFactor = 1.0 - (Double(row) / Double(density.rows)) * 0.5
        
        return MatrixChar(
            displayChar: randomChar,
            state: randomState,
            cycleSpeed: randomSpeed,
            cyclePosition: 0,
            maxCycles: randomMaxCycles,
            settleDelay: delay,
            intensity: depthFactor, // Brighter at front, dimmer at back
            opacity: depthFactor * Double.random(in: 0.7...1.0)
        )
    }
    
    // Calculate blur radius for depth effect
    private func getBlurRadius(row: Int, totalRows: Int) -> CGFloat {
        // More blur for "deeper" rows to create illusion of depth
        let depthFactor = Double(row) / Double(totalRows)
        return CGFloat(depthFactor * 1.5) // Max blur of 1.5
    }
    
    // Start animation
    private func startAnimation() {
        stopAnimation() // Clear any existing timer
        
        // Calculate the update interval based on performance mode
        let updateInterval = performanceMode ? 0.2 : 0.1
        
        // Create a new timer
        timer = Timer.publish(every: updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                updateMatrix()
            }
    }
    
    // Stop animation
    private func stopAnimation() {
        timer?.cancel()
        timer = nil
    }
    
    // Update the matrix characters
    private func updateMatrix() {
        guard !isPaused else { return }
        
        // Create a temporary copy to modify
        var updatedMatrix = matrixChars
        
        for row in 0..<updatedMatrix.count {
            for col in 0..<updatedMatrix[row].count {
                var charInfo = updatedMatrix[row][col]
                
                // Process different character states
                switch charInfo.state {
                case .cycling:
                    // Update cycle position
                    charInfo.cyclePosition += 1
                    
                    // Change the displayed character
                    charInfo.displayChar = matrixCharset.randomElement() ?? "X"
                    
                    // Check if it's time to settle
                    if charInfo.cyclePosition >= charInfo.maxCycles && charInfo.settleDelay <= 0 {
                        charInfo.state = .settled
                    } else {
                        // Decrease settle delay
                        charInfo.settleDelay -= 0.1
                    }
                    
                case .settled:
                    // Small chance to start cycling again
                    if Bool.random(withProbability: 0.005) {
                        charInfo.state = .cycling
                        charInfo.cyclePosition = 0
                        charInfo.maxCycles = Int.random(in: 3...15)
                        charInfo.settleDelay = Double.random(in: 0.1...1.0)
                    }
                }
                
                // Update in the matrix
                updatedMatrix[row][col] = charInfo
            }
        }
        
        // Update the main matrix
        matrixChars = updatedMatrix
    }
}

// Matrix character structure
struct MatrixChar {
    var displayChar: Character
    var state: MatrixCharState
    var cycleSpeed: Double
    var cyclePosition: Int
    var maxCycles: Int
    var settleDelay: Double
    var intensity: Double // For color intensity
    var opacity: Double
}

// Matrix character states
enum MatrixCharState {
    case cycling
    case settled
}
// MARK: - Win Overlay With Matrix Background
struct MatrixWinOverlayView: View {
    let solution: String
    let mistakes: Int
    let maxMistakes: Int
    let timeTaken: Int
    let score: Int
    let isDarkMode: Bool
    let onPlayAgain: () -> Void
    
    @State private var showRevealEffect = true
    @State private var showScore = false
    @State private var showStats = false
    @State private var showButton = false
    @State private var isOldDevice = false
    
    @Environment(\.colorScheme) var colorScheme
    
    // Detect if running on older hardware
    private func detectOldDevice() -> Bool {
        #if os(iOS)
        // iOS detection logic - could be enhanced for better detection
        let modelIdentifier = UIDevice.current.model
        // Check for older iPads and iPhones
        if modelIdentifier.contains("iPad") && UIDevice.current.systemVersion.compare("15.0", options: .numeric) == .orderedAscending {
            return true
        }
        // Add more sophisticated detection here if needed
        return false
        #else
        // macOS doesn't need this check as much
        return false
        #endif
    }
    
    var body: some View {
        ZStack {
            // Matrix background effect
            MatrixTextWallEffect(
                active: true,
                density: isOldDevice ? .light : .medium,
                performanceMode: isOldDevice,
                includeKatakana: true // Enable katakana characters for authentic matrix effect
            )
            .ignoresSafeArea()
            .opacity(0.6) // Reduce opacity to avoid distracting from content
            
            // Semi-transparent overlay to improve contrast
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 24) {
                // Win message
                Text("YOU WIN!")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.7), radius: 5, x: 0, y: 0)
                
                // Solution with holographic reveal effect
                HolographicRevealEffect(text: solution, active: showRevealEffect)
                    .frame(height: 50)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                
                // Score display
                VStack(spacing: 8) {
                    Text("SCORE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                    
                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .shadow(color: .green.opacity(0.7), radius: 3, x: 0, y: 0)
                }
                .padding()
                .frame(width: 200)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .opacity(showScore ? 1 : 0)
                .scaleEffect(showScore ? 1 : 0.8)
                
                // Game stats
                HStack(spacing: 30) {
                    VStack {
                        Text("Mistakes")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("\(mistakes)/\(maxMistakes)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    VStack {
                        Text("Time")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(formatTime(timeTaken))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical)
                .opacity(showStats ? 1 : 0)
                .offset(y: showStats ? 0 : 20)
                
                // Play again button
                Button(action: {
                    // Reset animations
                    showRevealEffect = false
                    showScore = false
                    showStats = false
                    showButton = false
                    
                    // Small delay before calling onPlayAgain
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onPlayAgain()
                    }
                }) {
                    Text("Play Again")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .green.opacity(0.5), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(BorderlessButtonStyle())
                .opacity(showButton ? 1 : 0)
                .scaleEffect(showButton ? 1 : 0.8)
            }
            .padding(40)
            .background(Color.black.opacity(0.7))
            .cornerRadius(20)
            .onAppear {
                // Detect device capabilities
                isOldDevice = detectOldDevice()
                
                // Staggered animations for each element
                // The reveal effect starts immediately
                
                // Show score after the reveal effect has started
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.spring()) {
                        showScore = true
                    }
                }
                
                // Show stats after score
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showStats = true
                    }
                }
                
                // Show button last
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.spring()) {
                        showButton = true
                    }
                }
            }
        }
    }
    
    // Format time in seconds to MM:SS
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview Provider
#if DEBUG
struct MatrixTextWallEffect_Previews: PreviewProvider {
    static var previews: some View {
        MatrixTextWallEffect(
            active: true,
            density: .medium,
            performanceMode: false,
            includeKatakana: true
        )
        .frame(height: 300)
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
        .previewDisplayName("Matrix Text Wall with Katakana")
    }
}
#endif


struct LoseOverlayView: View {
    let solution: String
    let mistakes: Int
    let maxMistakes: Int
    let timeTaken: Int
    let isDarkMode: Bool
    let onTryAgain: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Game Over")
                .font(.largeTitle.bold())
                .foregroundColor(.red)
            
            Text("The solution was:")
                .foregroundColor(.white)
                .padding(.top)
            
            Text(solution)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
                .padding(.horizontal)
            
            // Game stats
            HStack(spacing: 20) {
                VStack {
                    Text("Mistakes")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("\(mistakes)/\(maxMistakes)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                
                VStack {
                    Text("Time")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(formatTime(timeTaken))
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
            .padding(.vertical)
            
            Button(action: onTryAgain) {
                Text("Try Again")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(40)
        .background(Color.black.opacity(0.85))
        .cornerRadius(20)
    }
    
    // Format time in seconds to MM:SS
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        
        return String(format: "%d:%02d", minutes, seconds)
    }
}
