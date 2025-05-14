import SwiftUI

// Main container that manages the data and performance settings
struct MatrixEffect: View {
    // Configuration
    let density: MatrixDensity
    let includeKatakana: Bool
    let isPaused: Bool
    
    // Performance settings
    let useSimplifiedRendering: Bool
    
    // Density options
    enum MatrixDensity: String, CaseIterable {
        case light = "Light"
        case medium = "Medium"
        case dense = "Dense"
        
        var columnsCount: Int {
            switch self {
            case .light: return 15
            case .medium: return 25
            case .dense: return 35
            }
        }
        
        var rowsCount: Int {
            switch self {
            case .light: return 10
            case .medium: return 15
            case .dense: return 20
            }
        }
    }
    
    // Default initializer with sensible defaults
    init(
        density: MatrixDensity = .medium,
        includeKatakana: Bool = true,
        isPaused: Bool = false,
        useSimplifiedRendering: Bool = false
    ) {
        self.density = density
        self.includeKatakana = includeKatakana
        self.isPaused = isPaused
        self.useSimplifiedRendering = useSimplifiedRendering
    }
    
    var body: some View {
        GeometryReader { geometry in
            if useSimplifiedRendering {
                SimpleMatrixEffectView(
                    size: geometry.size,
                    density: density,
                    isPaused: isPaused
                )
            } else {
                FullMatrixEffectView(
                    size: geometry.size,
                    density: density,
                    includeKatakana: includeKatakana,
                    isPaused: isPaused
                )
            }
        }
        .background(Color.black)
    }
}

// Simplified version for lower-end devices
private struct SimpleMatrixEffectView: View {
    let size: CGSize
    let density: MatrixEffect.MatrixDensity
    let isPaused: Bool
    
    @State private var characters = Array(repeating: Array(repeating: " ", count: 15), count: 15)
    @State private var timer: Timer?
    
    var body: some View {
        Canvas { context, size in
            // Draw the matrix characters with minimal effects
            for row in 0..<characters.count {
                for col in 0..<characters[row].count {
                    let x = size.width / CGFloat(characters[row].count) * CGFloat(col)
                    let y = size.height / CGFloat(characters.count) * CGFloat(row)
                    
                    // Vary opacity by row (more depth effect)
                    let opacity = 1.0 - (Double(row) / Double(characters.count)) * 0.5
                    
                    // Draw character
                    let text = Text(characters[row][col])
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.green.opacity(opacity))
                    
                    context.draw(text, at: CGPoint(x: x, y: y))
                }
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: isPaused) { isPaused in
            if isPaused {
                timer?.invalidate()
            } else {
                startAnimation()
            }
        }
    }
    
    private func startAnimation() {
        guard timer == nil else { return }
        
        // Create initial random characters
        updateRandomCharacters()
        
        // Create timer to update characters
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            updateRandomCharacters()
        }
    }
    
    private func updateRandomCharacters() {
        // Make a copy of current state
        var newChars = characters
        
        // Update a few random characters
        for _ in 0..<10 {
            let row = Int.random(in: 0..<characters.count)
            let col = Int.random(in: 0..<characters[0].count)
            newChars[row][col] = randomMatrixChar()
        }
        
        // Update state with new characters
        characters = newChars
    }
    
    private func randomMatrixChar() -> String {
        let charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-*/=!?><$"
        return String(charset.randomElement() ?? "X")
    }
}

// Full version with all effects
private struct FullMatrixEffectView: View {
    let size: CGSize
    let density: MatrixEffect.MatrixDensity
    let includeKatakana: Bool
    let isPaused: Bool
    
    // Matrix state - would normally be in a view model
    @State private var matrixColumns: [MatrixColumn] = []
    @State private var timer: Timer?
    
    // Matrix character set
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
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                // Draw background
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
                
                // Draw each column
                for column in matrixColumns {
                    drawColumn(context: context, size: size, column: column, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .onAppear {
            initializeMatrix()
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: isPaused) { isPaused in
            if isPaused {
                timer?.invalidate()
            } else {
                startAnimation()
            }
        }
    }
    
    private func initializeMatrix() {
        // Calculate number of columns based on size and density
        let columnCount = density.columnsCount
        let columnWidth = size.width / CGFloat(columnCount)
        
        // Create columns
        matrixColumns = (0..<columnCount).map { i in
            let x = CGFloat(i) * columnWidth
            let speed = Double.random(in: 0.5...2.0)
            let length = Int.random(in: 5...30)
            
            return MatrixColumn(
                x: x,
                speed: speed,
                characters: (0..<length).map { _ in
                    MatrixCharacter(
                        char: String(matrixCharset.randomElement() ?? "X"),
                        state: Bool.random() ? .cycling : .settled,
                        brightness: Double.random(in: 0.7...1.0),
                        cycleSpeed: Double.random(in: 0.5...2.0)
                    )
                }
            )
        }
    }
    
    private func startAnimation() {
        timer?.invalidate()
        
        // Update at 10 FPS - adjust based on performance
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateMatrix()
        }
    }
    
    private func updateMatrix() {
        var updatedColumns = matrixColumns
        
        for columnIndex in 0..<updatedColumns.count {
            var column = updatedColumns[columnIndex]
            
            // Update characters in the column
            for charIndex in 0..<column.characters.count {
                var character = column.characters[charIndex]
                
                // Process different character states
                switch character.state {
                case .cycling:
                    // Change the character
                    character.char = String(matrixCharset.randomElement() ?? "X")
                    
                    // Increment cycle position
                    character.cyclePosition += 1
                    
                    // Check if it's time to settle
                    if character.cyclePosition >= character.maxCycles {
                        character.state = .settled
                    }
                    
                case .settled:
                    // Small chance to start cycling again
                    if Bool.random() && Double.random(in: 0...1) < 0.02 {
                        character.state = .cycling
                        character.cyclePosition = 0
                        character.maxCycles = Int.random(in: 3...15)
                    }
                }
                
                column.characters[charIndex] = character
            }
            
            // Occasionally add a new character
            if Double.random(in: 0...1) < 0.1 {
                column.characters.append(MatrixCharacter(
                    char: String(matrixCharset.randomElement() ?? "X"),
                    state: .cycling,
                    brightness: Double.random(in: 0.7...1.0),
                    cyclePosition: 0
                ))
                
                // Keep columns from getting too long
                if column.characters.count > 40 {
                    column.characters.removeFirst()
                }
            }
            
            updatedColumns[columnIndex] = column
        }
        
        matrixColumns = updatedColumns
    }
    
    private func drawColumn(context: GraphicsContext, size: CGSize, column: MatrixColumn, time: TimeInterval) {
        // Calculate vertical position with animation
        let yOffset = (time * column.speed * 20).truncatingRemainder(dividingBy: size.height * 2)
        
        // Draw each character in the column
        for (index, char) in column.characters.enumerated() {
            let fontSize: CGFloat = 16
            let verticalSpacing: CGFloat = fontSize * 1.2
            
            // Calculate y position with flow effect
            let y = (CGFloat(index) * verticalSpacing + CGFloat(yOffset)).truncatingRemainder(dividingBy: size.height + 100) - 50
            let position = CGPoint(x: column.x, y: y)
            
            // Calculate color with brightness
            let baseColor = Color.green
            let colorWithBrightness = baseColor.opacity(char.brightness)
            
            // Create text view
            let text = Text(char.char)
                .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                .foregroundColor(colorWithBrightness)
            
            // Draw character
            context.draw(text, at: position)
        }
    }
}

// MARK: - Data Structures

// Matrix character
struct MatrixCharacter {
    var char: String
    var state: MatrixCharState
    var brightness: Double = 1.0
    var cyclePosition: Int = 0
    var maxCycles: Int = Int.random(in: 3...12)
    var cycleSpeed: Double = 1.0
}

// Matrix character states
enum MatrixCharState {
    case cycling
    case settled
}

// Matrix column
struct MatrixColumn {
    var x: CGFloat
    var speed: Double
    var characters: [MatrixCharacter]
}

//
//  MatrixEffectComponents.swift
//  loginboy
//
//  Created by Daniel Horsley on 13/05/2025.
//

