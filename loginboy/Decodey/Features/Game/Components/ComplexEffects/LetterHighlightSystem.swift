//
//  LetterHighlightSystem.swift
//  Decodey
//
//  Highlight system for letter selection with shimmer effects
//  Uses modern SwiftUI cross-platform approach
//

import SwiftUI

// MARK: - Highlight State Manager
class HighlightState: ObservableObject {
    @Published var highlightedLetter: Character? = nil
    @Published var isAnimating: Bool = false
    @Published var flashPositions: Set<Int> = []
    
    func highlightLetter(_ letter: Character) {
        highlightedLetter = letter
        isAnimating = true
        
        // Auto-clear after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.isAnimating = false
        }
    }
    
    func clearHighlight() {
        highlightedLetter = nil
        isAnimating = false
        flashPositions.removeAll()
    }
    
    func addFlashPosition(_ index: Int) {
        flashPositions.insert(index)
        
        // Remove after flash animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.flashPositions.remove(index)
        }
    }
}

// MARK: - Highlight Modifier
struct LetterHighlightModifier: ViewModifier {
    let letter: Character
    let highlightState: HighlightState
    let style: HighlightStyle
    
    @State private var shimmerOffset: CGFloat = -100
    @State private var pulseScale: CGFloat = 1.0
    
    enum HighlightStyle {
        case cell
        case text
        case solution
    }
    
    var isHighlighted: Bool {
        highlightState.highlightedLetter == letter && highlightState.isAnimating
    }
    
    func body(content: Content) -> some View {
        content  // IMPORTANT: Keep content as-is
            .background(
                Group {
                    if isHighlighted {
                        highlightBackground
                    }
                }
            )
            .overlay(
                Group {
                    if isHighlighted {
                        highlightOverlay
                    }
                }
            )
            .scaleEffect(style == .cell && isHighlighted ? pulseScale : 1.0)
            .onChange(of: isHighlighted) { _, newValue in
                if newValue {
                    triggerAnimations()
                }
            }
    }
    
    @ViewBuilder
    private var highlightBackground: some View {
        switch style {
        case .cell:
            RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                .fill(Color("HighlightColor").opacity(0.3))
                .animation(.easeInOut(duration: 0.3), value: isHighlighted)
            
        case .text, .solution:
            Color("HighlightColor")
                .opacity(0.2)
                .animation(.easeInOut(duration: 0.3), value: isHighlighted)
        }
    }
    
    @ViewBuilder
    private var highlightOverlay: some View {
        if isHighlighted {
            switch style {
            case .cell:
                // Animated border for cells
                RoundedRectangle(cornerRadius: GameLayout.cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color("HighlightColor"),
                                Color("HighlightColor").opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .shadow(color: Color("HighlightColor").opacity(0.5), radius: 10)
                
            case .text:
                // Shimmer effect for encrypted text
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color("HighlightColor").opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.3)
                    .offset(x: shimmerOffset)
                    .mask(
                        Rectangle()
                            .fill(Color.white)
                    )
                }
                
            case .solution:
                // Flash effect for solution text
                ShimmerFlashView()
            }
        }
    }
    
    private func triggerAnimations() {
        // Shimmer animation for text
        if style == .text {
            shimmerOffset = -100
            withAnimation(.linear(duration: 0.5)) {
                shimmerOffset = 200
            }
        }
        
        // Pulse animation for cells
        if style == .cell {
            pulseScale = 1.0
            withAnimation(.easeInOut(duration: 0.2)) {
                pulseScale = 1.1
            }
            withAnimation(.easeInOut(duration: 0.2).delay(0.2)) {
                pulseScale = 1.0
            }
        }
    }
}

// MARK: - Shimmer Flash View
struct ShimmerFlashView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base glow
                Rectangle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color("HighlightColor").opacity(0.4),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geometry.size.width / 2
                        )
                    )
                
                // Animated shimmer - FIXED VERSION
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Color("HighlightColor").opacity(0.6), location: 0.5),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(
                    LinearGradient(
                        colors: [.clear, .white, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.4)
                    .offset(x: phase * geometry.size.width)
                )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 0.5)) {
                phase = 2
            }
        }
    }
}
// MARK: - Enhanced Letter Cells with Highlighting
extension EncryptedLetterCell {
    func withHighlight(highlightState: HighlightState) -> some View {
        self.modifier(
            LetterHighlightModifier(
                letter: letter,
                highlightState: highlightState,
                style: .cell
            )
        )
    }
}

extension GuessLetterCell {
    func withHighlight(highlightState: HighlightState) -> some View {
        self.modifier(
            LetterHighlightModifier(
                letter: letter,
                highlightState: highlightState,
                style: .cell
            )
        )
    }
}

// MARK: - Text Display with Highlighting
struct HighlightableTextView: View {
    let text: String
    let highlightState: HighlightState
    let textColor: Color
    let isEncrypted: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                CharacterHighlightView(
                    character: char,
                    index: index,
                    highlightState: highlightState,
                    textColor: textColor,
                    style: isEncrypted ? .text : .solution
                )
            }
        }
    }
}

struct CharacterHighlightView: View {
    let character: Character
    let index: Int
    let highlightState: HighlightState
    let textColor: Color
    let style: LetterHighlightModifier.HighlightStyle
    
    @State private var flashIntensity: Double = 0
    
    var isFlashing: Bool {
        highlightState.flashPositions.contains(index)
    }
    
    var body: some View {
        Text(String(character))
            .font(.gameDisplay)
            .foregroundColor(textColor)
            .modifier(
                LetterHighlightModifier(
                    letter: character,
                    highlightState: highlightState,
                    style: style
                )
            )
            .background(
                // Flash background for solution text
                Group {
                    if isFlashing && style == .solution {
                        Color("HighlightColor")
                            .opacity(flashIntensity)
                            .animation(.easeOut(duration: 0.5), value: flashIntensity)
                    }
                }
            )
            .onChange(of: isFlashing) { _, newValue in
                if newValue {
                    flashIntensity = 0.6
                    withAnimation(.easeOut(duration: 0.5)) {
                        flashIntensity = 0
                    }
                }
            }
    }
}

// MARK: - Integration Helper
extension View {
    func highlightable(
        for letter: Character,
        state: HighlightState,
        style: LetterHighlightModifier.HighlightStyle
    ) -> some View {
        self.modifier(
            LetterHighlightModifier(
                letter: letter,
                highlightState: state,
                style: style
            )
        )
    }
}

// MARK: - Usage in GameView
struct HighlightIntegration {
    static func setupHighlighting(in gameView: GamePlayView) {
        // This shows how to integrate the highlight system
        // Add to GamePlayView:
        /*
        @StateObject private var highlightState = HighlightState()
        
        // In encrypted letter cells:
        EncryptedLetterCell(...)
            .withHighlight(highlightState: highlightState)
            .onTapGesture {
                highlightState.highlightLetter(letter)
                // Also highlight matching positions in solution
                findMatchingPositions(for: letter).forEach { index in
                    highlightState.addFlashPosition(index)
                }
            }
        
        // In text displays:
        HighlightableTextView(
            text: displayedEncryptedText,
            highlightState: highlightState,
            textColor: Color("GameEncrypted"),
            isEncrypted: true
        )
        */
    }
}

// MARK: - Color Asset Helper
extension Color {
    /// Helper to ensure HighlightColor asset exists
    static func setupHighlightColor() {
        // Add to Assets.xcassets:
        // HighlightColor
        // Light appearance: #FFD700 (Gold)
        // Dark appearance: #FFA500 (Orange)
        // Or any color that complements your GameEncrypted/GameGuess colors
    }
}
