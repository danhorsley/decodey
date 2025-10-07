// Tutorial.swift - Fixed version with improved frame tracking

import SwiftUI

// MARK: - Tutorial Step
struct TutorialStep {
    let id: String
    let title: String
    let description: String
    let target: Target
    let icon: String
    
    enum Target: CaseIterable {
        case welcome, textDisplay, encryptedGrid, guessGrid, hintButton, tabBar
        
        var preferredPosition: Position {
            switch self {
            case .welcome: return .center
            case .textDisplay: return .bottom
            case .encryptedGrid: return .bottom  // Changed from .right
            case .guessGrid: return .top         // Changed from .left
            case .hintButton: return .bottom     // Changed from .left
            case .tabBar: return .top
            }
        }
    }
    
    enum Position {
        case center, top, bottom, left, right
    }
}

// MARK: - Tutorial Manager
class TutorialManager: ObservableObject {
    static let shared = TutorialManager()
    
    @Published var isActive = false
    @Published var currentIndex = 0
    @Published var hasCompleted = UserDefaults.standard.bool(forKey: "tutorial-completed")
    @Published var frames: [TutorialStep.Target: CGRect] = [:]  // Make frames observable
    
    // Compatibility aliases
    var isShowingTutorial: Bool { isActive }
    var hasCompletedTutorial: Bool { hasCompleted }
    
    let steps = [
        TutorialStep(id: "welcome", title: "Welcome to Decodey!",
                    description: "Ready to become a master cryptanalyst? Follow this quick tutorial to learn how to play.",
                    target: .welcome, icon: "sparkles"),
        TutorialStep(id: "text", title: "Encrypted Text",
                    description: "This shows the encrypted quote you need to decrypt.",
                    target: .textDisplay, icon: "doc.text"),
        TutorialStep(id: "encrypted", title: "Encrypted Letters",
                    description: "Click a letter here to select it for decoding.",
                    target: .encryptedGrid, icon: "lock.fill"),
        TutorialStep(id: "guess", title: "Original Letters",
                    description: "And then click here to choose the real letter you think it represents.",
                    target: .guessGrid, icon: "key.fill"),
        TutorialStep(id: "hint", title: "Hint Button",
                    description: "Stuck? Use a hint to reveal a letter. Each hint or mistake costs one token.",
                    target: .hintButton, icon: "lightbulb.fill"),
        TutorialStep(id: "menu", title: "Navigation Menu",
                    description: "Start new games, change difficulty and other settings. Create a free account to save scores and compete on leaderboards.",
                    target: .tabBar, icon: "square.grid.2x2")
    ]
    
    var currentStep: TutorialStep? {
        guard currentIndex < steps.count else { return nil }
        return steps[currentIndex]
    }
    
    var progress: Double {
        Double(currentIndex + 1) / Double(steps.count)
    }
    
    func start() {
        currentIndex = 0
        isActive = true
        frames = [:]  // Clear frames when starting
    }
    
    func startTutorial() {
        start()
    }
    
    func next() {
        if currentIndex < steps.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentIndex += 1
            }
        } else {
            complete()
        }
    }
    
    func skip() {
        complete()
    }
    
    private func complete() {
        UserDefaults.standard.set(true, forKey: "tutorial-completed")
        hasCompleted = true
        withAnimation(.easeOut(duration: 0.3)) {
            isActive = false
        }
        currentIndex = 0
        frames = [:]  // Clear frames when completing
    }
    
    func reset() {
        UserDefaults.standard.set(false, forKey: "tutorial-completed")
        hasCompleted = false
        currentIndex = 0
        frames = [:]
    }
    
    func resetTutorial() {
        reset()
    }
    
    // New method to update frame for a target
    func updateFrame(for target: TutorialStep.Target, frame: CGRect) {
        DispatchQueue.main.async {
            self.frames[target] = frame
        }
    }
}

// MARK: - Frame Tracking
struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: [TutorialStep.Target: CGRect] = [:]
    static func reduce(value: inout [TutorialStep.Target: CGRect], nextValue: () -> [TutorialStep.Target: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Tutorial Overlay
struct TutorialOverlay: View {
    @StateObject private var manager = TutorialManager.shared
    @State private var modalPos = CGPoint.zero
    @State private var modalOpacity = 0.0
    @State private var showModal = false
    @State private var highlightOpacity = 0.0
    
    var highlightFrame: CGRect {
        guard let step = manager.currentStep,
              let frame = manager.frames[step.target] else { return .zero }
        return frame.insetBy(dx: -5, dy: -5)
    }
    
    var body: some View {
        GeometryReader { geo in
            if manager.isActive, let step = manager.currentStep {
                ZStack {
                    // Overlay with cutout
                    if step.target != .welcome {
                        Canvas { context, size in
                            var path = Path()
                            path.addRect(CGRect(origin: .zero, size: size))
                            if highlightFrame != .zero {
                                path.addRoundedRect(in: highlightFrame, cornerSize: CGSize(width: 8, height: 8))
                            }
                            context.fill(path, with: .color(.black.opacity(0.4)), style: FillStyle(eoFill: true))
                        }
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .animation(.easeInOut(duration: 0.3), value: highlightFrame)
                        
                        // Highlight border with animation
                        if highlightFrame != .zero {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: highlightFrame.width, height: highlightFrame.height)
                                .position(x: highlightFrame.midX, y: highlightFrame.midY)
                                .shadow(color: .white.opacity(0.3), radius: 8)
                                .opacity(highlightOpacity)
                                .allowsHitTesting(false)
                                .animation(.easeInOut(duration: 0.3), value: highlightFrame)
                        }
                    } else {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                    
                    // Modal
                    if showModal {
                        ModalView(step: step, onNext: manager.next, onSkip: manager.skip)
                            .position(modalPos)
                            .opacity(modalOpacity)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: modalPos)
                    }
                }
                .onAppear {
                    // Wait for frames to be collected
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        calculatePosition(for: step, in: geo)
                        showModal = true
                        withAnimation(.easeIn(duration: 0.3)) {
                            modalOpacity = 1
                            highlightOpacity = 1
                        }
                    }
                }
                .onPreferenceChange(FramePreferenceKey.self) { newFrames in
                    // Update manager's frames
                    for (target, frame) in newFrames {
                        manager.updateFrame(for: target, frame: frame)
                    }
                    
                    // Recalculate position when frames update
                    if let step = manager.currentStep {
                        calculatePosition(for: step, in: geo)
                    }
                }
                .onChange(of: manager.currentIndex) { _ in
                    modalOpacity = 0
                    highlightOpacity = 0
                    showModal = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let newStep = manager.currentStep {
                            // Wait a bit for new frames to be collected
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                calculatePosition(for: newStep, in: geo)
                                showModal = true
                                withAnimation(.easeIn(duration: 0.3)) {
                                    modalOpacity = 1
                                    highlightOpacity = 1
                                }
                            }
                        }
                    }
                }
                .onChange(of: manager.frames) { _ in
                    // Recalculate when frames change
                    if let step = manager.currentStep {
                        calculatePosition(for: step, in: geo)
                    }
                }
            }
        }
    }
    
    private func calculatePosition(for step: TutorialStep, in geo: GeometryProxy) {
        let modalSize = CGSize(width: 300, height: 220)
        let padding: CGFloat = 30
        let bounds = geo.frame(in: .global)
        
        // Center for welcome
        if step.target == .welcome {
            modalPos = CGPoint(x: bounds.midX, y: bounds.midY)
            return
        }
        
        // Get the actual frame from tracked frames
        guard let targetFrame = manager.frames[step.target], targetFrame != .zero else {
            // If no frame yet, position based on expected location
            switch step.target {
            case .textDisplay:
                modalPos = CGPoint(x: bounds.midX, y: bounds.height * 0.3)
            case .encryptedGrid:
                modalPos = CGPoint(x: bounds.midX, y: bounds.height * 0.5)
            case .guessGrid:
                modalPos = CGPoint(x: bounds.midX, y: bounds.height * 0.7)
            case .hintButton:
                modalPos = CGPoint(x: bounds.midX, y: bounds.height * 0.6)
            case .tabBar:
                modalPos = CGPoint(x: bounds.midX, y: bounds.height - 150)
            default:
                modalPos = CGPoint(x: bounds.midX, y: bounds.midY)
            }
            return
        }
        
        // Calculate position relative to target
        var pos = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        
        switch step.target.preferredPosition {
        case .top:
            pos.y = max(modalSize.height/2 + 50, targetFrame.minY - modalSize.height/2 - padding)
        case .bottom:
            pos.y = min(bounds.height - modalSize.height/2 - 50, targetFrame.maxY + modalSize.height/2 + padding)
        case .left:
            pos.x = max(modalSize.width/2 + padding, targetFrame.minX - modalSize.width/2 - padding)
        case .right:
            pos.x = min(bounds.width - modalSize.width/2 - padding, targetFrame.maxX + modalSize.width/2 + padding)
        case .center:
            break // Already centered on target
        }
        
        // Keep in bounds
        pos.x = max(modalSize.width/2 + 10, min(bounds.width - modalSize.width/2 - 10, pos.x))
        pos.y = max(modalSize.height/2 + 10, min(bounds.height - modalSize.height/2 - 10, pos.y))
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            modalPos = pos
        }
    }
}

// MARK: - Modal View
private struct ModalView: View {
    let step: TutorialStep
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: step.icon)
                    .font(.title2)
                    .foregroundColor(.cyan)
                Text(step.title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
            
            // Description
            Text(step.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // Buttons
            HStack(spacing: 16) {
                Button("Skip", action: onSkip)
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                
                Button(action: onNext) {
                    HStack(spacing: 4) {
                        Text(step.target == .tabBar ? "Finish" : "Continue")
                        if step.target != .tabBar {
                            Image(systemName: "arrow.right")
                                .font(.caption.bold())
                        }
                    }
                }
                .font(.subheadline.bold())
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.cyan))
                .shadow(color: .cyan.opacity(0.3), radius: 8)
            }
            
            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<TutorialManager.shared.steps.count, id: \.self) { i in
                    Circle()
                        .fill(i <= TutorialManager.shared.currentIndex ? Color.cyan : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(24)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.15))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
        )
        .shadow(radius: 10)
    }
}

// MARK: - Improved View Extension
extension View {
    func tutorialTarget(_ target: TutorialStep.Target) -> some View {
        self.overlay(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: FramePreferenceKey.self,
                        value: [target: geo.frame(in: .global)]
                    )
                    .onAppear {
                        // Also update the frame immediately when view appears
                        TutorialManager.shared.updateFrame(for: target, frame: geo.frame(in: .global))
                    }
                    .onChange(of: geo.frame(in: .global)) { newFrame in
                        // Update frame when it changes
                        TutorialManager.shared.updateFrame(for: target, frame: newFrame)
                    }
            }
        )
    }
    
    func withTutorialOverlay() -> some View {
        self.overlay(TutorialOverlay())
    }
}
