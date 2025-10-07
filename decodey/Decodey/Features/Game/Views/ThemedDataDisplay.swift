import SwiftUI

// MARK: - Main Theme Container
struct ThemedDataDisplay<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if colorScheme == .dark {
            TerminalContainer(title: title, content: content)
        } else {
            TypewriterContainer(title: title, content: content)
        }
    }
}

// MARK: - Terminal Theme (Dark Mode)
struct TerminalContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    @State private var scanlineOffset: CGFloat = -100
    @State private var showContent = false
    @State private var terminalText = ""
    
    private let terminalGreen = Color(hex: "4cc9f0")
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with scanlines
                Color.black
                    .overlay(
                        // Scanline effect
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        terminalGreen.opacity(0.05),
                                        terminalGreen.opacity(0.1),
                                        terminalGreen.opacity(0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 100)
                            .offset(y: scanlineOffset)
                            .blur(radius: 20)
                    )
                
                // CRT monitor curve effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.black,
                                Color.black.opacity(0.95)
                            ],
                            center: .center,
                            startRadius: 200,
                            endRadius: 600
                        )
                    )
                    .ignoresSafeArea()
                
                // Main content
                VStack(spacing: 0) {
                    // Terminal header
                    TerminalHeader(title: title, text: $terminalText)
                        .padding(.bottom, 20)
                    
                    if showContent {
                        content()
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding()
            }
            .onAppear {
                startTerminalAnimation(height: geometry.size.height)
            }
        }
    }
    
    private func startTerminalAnimation(height: CGFloat) {
        // Scanline animation
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            scanlineOffset = height + 100
        }
        
        // Terminal typing effect
        let fullTitle = "> \(title.uppercased()).TXT"
        terminalText = ""
        
        for (index, char) in fullTitle.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                terminalText.append(char)
                if char != " " {
                    SoundManager.shared.play(.letterClick)
                }
            }
        }
        
        // Show content after typing
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(fullTitle.count) * 0.05 + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }
}

struct TerminalHeader: View {
    let title: String
    @Binding var text: String
    @State private var cursorVisible = true
    
    private let terminalGreen = Color(hex: "4cc9f0")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ASCII border top
            Text("╔════════════════════════════════════════════════════════════╗")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(terminalGreen.opacity(0.6))
            
            HStack {
                Text("║")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(terminalGreen.opacity(0.6))
                
                Text(text)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(terminalGreen)
                
                // Blinking cursor
                Text("█")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(terminalGreen)
                    .opacity(cursorVisible ? 1 : 0)
                    .onAppear {
                        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                            cursorVisible.toggle()
                        }
                    }
                
                Spacer()
                
                Text("║")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(terminalGreen.opacity(0.6))
            }
            
            Text("╚════════════════════════════════════════════════════════════╝")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(terminalGreen.opacity(0.6))
        }
    }
}

// MARK: - Typewriter Theme (Light Mode)
struct TypewriterContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    @State private var showContent = false
    @State private var typewriterText = ""
    @State private var paperSlideOffset: CGFloat = 50
    
    var body: some View {
        ZStack {
            // Paper texture background
            Color(hex: "F5F2E8")
                .overlay(
                    Image(systemName: "doc.text")
                        .font(.system(size: 500))
                        .foregroundColor(.black.opacity(0.02))
                        .blur(radius: 3)
                )
            
            // Main paper sheet
            VStack(spacing: 0) {
                // Paper header with title
                VStack(spacing: 16) {
                    // Three-hole punch marks
                    HStack(spacing: 80) {
                        ForEach(0..<3) { _ in
                            Circle()
                                .fill(Color.black.opacity(0.1))
                                .frame(width: 20, height: 20)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Typewritten title
                    Text(typewriterText)
                        .font(.custom("American Typewriter", size: 24))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .tracking(2)
                    
                    // Red underline
                    Rectangle()
                        .fill(Color.red.opacity(0.8))
                        .frame(height: 3)
                        .frame(maxWidth: 200)
                        .offset(y: -8)
                }
                
                // Content area
                if showContent {
                    content()
                        .padding(.top, 20)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 20)
            .offset(y: paperSlideOffset)
        }
        .onAppear {
            startTypewriterAnimation()
        }
    }
    
    private func startTypewriterAnimation() {
        // Slide paper up
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            paperSlideOffset = 0
        }
        
        // Typewriter effect
        let fullTitle = title.uppercased()
        typewriterText = ""
        
        for (index, char) in fullTitle.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(index) * 0.08) {
                typewriterText.append(char)
                if char != " " {
                    SoundManager.shared.play(.letterClick)
                }
            }
        }
        
        // Show content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(fullTitle.count) * 0.08 + 0.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showContent = true
            }
        }
    }
}

// MARK: - Themed Table Components
struct ThemedTableHeader: View {
    let columns: [String]
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if colorScheme == .dark {
            TerminalTableHeader(columns: columns)
        } else {
            CrosswordTableHeader(columns: columns)
        }
    }
}

struct TerminalTableHeader: View {
    let columns: [String]
    private let terminalGreen = Color(hex: "4cc9f0")
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(columns, id: \.self) { column in
                    Text(column.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(terminalGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            
            // ASCII divider
            Text(String(repeating: "═", count: 60))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(terminalGreen.opacity(0.6))
        }
    }
}

struct CrosswordTableHeader: View {
    let columns: [String]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                ZStack {
                    // Crossword cell background
                    Rectangle()
                        .fill(Color.black)
                        .overlay(
                            Rectangle()
                                .stroke(Color.black, lineWidth: 2)
                        )
                    
                    // Column number (like crossword clues)
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(2)
                    
                    // Column text
                    Text(column)
                        .font(.custom("American Typewriter", size: 14))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .frame(height: 40)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Themed Row Components
struct ThemedDataRow: View {
    let data: [String]
    let isHighlighted: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if colorScheme == .dark {
            TerminalDataRow(data: data, isHighlighted: isHighlighted)
        } else {
            CrosswordDataRow(data: data, isHighlighted: isHighlighted)
        }
    }
}

struct TerminalDataRow: View {
    let data: [String]
    let isHighlighted: Bool
    private let terminalGreen = Color(hex: "4cc9f0")
    
    var body: some View {
        HStack(spacing: 0) {
            Text("│")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(terminalGreen.opacity(0.4))
            
            ForEach(data, id: \.self) { item in
                Text(item)
                    .font(.system(size: 14, weight: isHighlighted ? .bold : .regular, design: .monospaced))
                    .foregroundColor(isHighlighted ? Color(hex: "FFD700") : terminalGreen.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                
                Text("│")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(terminalGreen.opacity(0.4))
            }
        }
        .background(
            isHighlighted ?
            terminalGreen.opacity(0.1) :
            Color.clear
        )
        .overlay(
            isHighlighted ?
            Rectangle()
                .stroke(terminalGreen.opacity(0.5), lineWidth: 1)
                .shadow(color: terminalGreen, radius: 5) :
            nil
        )
    }
}

struct CrosswordDataRow: View {
    let data: [String]
    let isHighlighted: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(data, id: \.self) { item in
                ZStack {
                    // Crossword cell
                    Rectangle()
                        .fill(isHighlighted ? Color.yellow.opacity(0.3) : Color.white)
                        .overlay(
                            Rectangle()
                                .stroke(Color.black.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Red circle for highlighted (like marking correct answer)
                    if isHighlighted {
                        Circle()
                            .stroke(Color.red, lineWidth: 2)
                            .padding(4)
                    }
                    
                    Text(item)
                        .font(.custom("American Typewriter", size: 14))
                        .fontWeight(isHighlighted ? .bold : .regular)
                        .foregroundColor(.black)
                }
                .frame(height: 36)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Stat Card Components
struct ThemedStatCard: View {
    let title: String
    let value: String
    let icon: String
    let trend: Double? // For showing up/down trends
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if colorScheme == .dark {
            TerminalStatCard(title: title, value: value, icon: icon, trend: trend)
        } else {
            TypewriterStatCard(title: title, value: value, icon: icon, trend: trend)
        }
    }
}

struct TerminalStatCard: View {
    let title: String
    let value: String
    let icon: String
    let trend: Double?
    
    private let terminalGreen = Color(hex: "4cc9f0")
    
    var body: some View {
        VStack(spacing: 8) {
            // ASCII art border
            Text("┌─────────────┐")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(terminalGreen.opacity(0.6))
            
            // Icon with glow effect
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(terminalGreen)
                .shadow(color: terminalGreen, radius: 10)
            
            // Value
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(terminalGreen)
                .shadow(color: terminalGreen.opacity(0.5), radius: 5)
            
            // Title
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(terminalGreen.opacity(0.8))
            
            // Trend indicator
            if let trend = trend {
                HStack(spacing: 2) {
                    Image(systemName: trend > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10))
                    Text("\(abs(Int(trend)))%")
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundColor(trend > 0 ? Color.green : Color.red)
            }
            
            Text("└─────────────┘")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(terminalGreen.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct TypewriterStatCard: View {
    let title: String
    let value: String
    let icon: String
    let trend: Double?
    
    var body: some View {
        VStack(spacing: 12) {
            // Crossword-style numbered box
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.black, lineWidth: 2)
                    )
                
                // Small number in corner
                Text("1")
                    .font(.system(size: 8, weight: .bold))
                    .padding(2)
                
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                    
                    Text(value)
                        .font(.custom("American Typewriter", size: 28))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Text(title)
                        .font(.custom("American Typewriter", size: 12))
                        .foregroundColor(.black.opacity(0.7))
                    
                    // Red pen annotation for trend
                    if let trend = trend {
                        Text("\(trend > 0 ? "+" : "")\(Int(trend))%")
                            .font(.custom("Marker Felt", size: 14))
                            .foregroundColor(.red)
                            .rotationEffect(.degrees(-5))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
            .frame(height: 140)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 1)
        }
    }
}

// MARK: - Loading States
struct ThemedLoadingView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if colorScheme == .dark {
            TerminalLoadingView()
        } else {
            TypewriterLoadingView()
        }
    }
}

struct TerminalLoadingView: View {
    @State private var dots = ""
    private let terminalGreen = Color(hex: "4cc9f0")
    
    var body: some View {
        VStack(spacing: 16) {
            Text("LOADING\(dots)")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(terminalGreen)
                .shadow(color: terminalGreen, radius: 10)
                .onAppear {
                    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                        if dots.count >= 3 {
                            dots = ""
                        } else {
                            dots.append(".")
                        }
                    }
                }
            
            // ASCII spinner
            Text("[ ████████░░ ]")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(terminalGreen.opacity(0.7))
        }
    }
}

struct TypewriterLoadingView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        VStack(spacing: 16) {
            // Typewriter roller animation
            Image(systemName: "circle.grid.2x2")
                .font(.system(size: 40))
                .foregroundColor(.black.opacity(0.6))
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            
            Text("Typing...")
                .font(.custom("American Typewriter", size: 18))
                .foregroundColor(.black.opacity(0.7))
        }
    }
}

// MARK: - Empty State
struct ThemedEmptyState: View {
    let message: String
    let icon: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if colorScheme == .dark {
            TerminalEmptyState(message: message, icon: icon)
        } else {
            TypewriterEmptyState(message: message, icon: icon)
        }
    }
}

struct TerminalEmptyState: View {
    let message: String
    let icon: String
    private let terminalGreen = Color(hex: "4cc9f0")
    
    var body: some View {
        VStack(spacing: 16) {
            Text("ERROR 404")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.red)
                .shadow(color: .red, radius: 10)
            
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(terminalGreen.opacity(0.5))
            
            Text(message.uppercased())
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(terminalGreen.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

struct TypewriterEmptyState: View {
    let message: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 16) {  // ← Keep this as 16!
            // Blank crossword grid
            VStack(spacing: 2) {  // ← This is the Grid replacement with spacing 2
                ForEach(0..<3) { row in
                    HStack(spacing: 2) {  // ← This matches the Grid's horizontalSpacing: 2
                        ForEach(0..<3) { col in
                            Rectangle()
                                .fill(row == 1 && col == 1 ? Color.black : Color.white)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.black, lineWidth: 1)
                                )
                                .frame(width: 30, height: 30)
                        }
                    }
                }
            }
            
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.black.opacity(0.3))
            
            Text(message)
                .font(.custom("American Typewriter", size: 16))
                .foregroundColor(.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}
