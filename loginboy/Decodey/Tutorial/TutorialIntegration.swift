import SwiftUI

// MARK: - Tutorial Target View Modifier
struct TutorialTarget: ViewModifier {
    let targetType: TutorialStep.TutorialTarget
    @StateObject private var tutorialManager = TutorialManager.shared
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: TutorialFramePreferenceKey.self,
                            value: [targetType: geometry.frame(in: .global)]
                        )
                }
            )
    }
}

// MARK: - Preference Key for Tutorial Frames
struct TutorialFramePreferenceKey: PreferenceKey {
    typealias Value = [TutorialStep.TutorialTarget: CGRect]
    
    static var defaultValue: [TutorialStep.TutorialTarget: CGRect] = [:]
    
    static func reduce(value: inout [TutorialStep.TutorialTarget: CGRect], nextValue: () -> [TutorialStep.TutorialTarget: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - View Extension for Tutorial
extension View {
    func tutorialTarget(_ target: TutorialStep.TutorialTarget) -> some View {
        self.modifier(TutorialTarget(targetType: target))
    }
    
    func withTutorialOverlay() -> some View {
        self.overlay(TutorialOverlay())
    }
}

// MARK: - Enhanced Tutorial Overlay with Frame Tracking
struct EnhancedTutorialOverlay: View {
    @StateObject private var tutorialManager = TutorialManager.shared
    @State private var targetFrames: [TutorialStep.TutorialTarget: CGRect] = [:]
    @State private var modalOffset: CGSize = .zero
    @State private var modalOpacity: Double = 1.0
    @State private var showHighlight: Bool = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isSmallScreen: Bool {
        horizontalSizeClass == .compact || UIScreen.main.bounds.height < 700
    }
    
    private var highlightFrame: CGRect {
        guard let step = tutorialManager.currentStep,
              let frame = targetFrames[step.targetView] else {
            return .zero
        }
        return frame
    }
    
    var body: some View {
        GeometryReader { geometry in
            if tutorialManager.isShowingTutorial, let step = tutorialManager.currentStep {
                ZStack {
                    // Dark overlay with cutout
                    if step.targetView != .welcome {
                        TutorialBackgroundOverlay(highlightFrame: highlightFrame)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .opacity(showHighlight ? 1 : 0)
                            .animation(.easeIn(duration: 0.3), value: showHighlight)
                    } else {
                        Color.black.opacity(0.75)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                    
                    // Highlight border
                    if step.targetView != .welcome && showHighlight {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: highlightFrame.width, height: highlightFrame.height)
                            .position(x: highlightFrame.midX, y: highlightFrame.midY)
                            .allowsHitTesting(false)
                            .shadow(color: .white.opacity(0.5), radius: 10)
                            .animation(.easeInOut(duration: 0.3), value: highlightFrame)
                    }
                    
                    // Tutorial modal
                    TutorialModalEnhanced(
                        step: step,
                        isLastStep: tutorialManager.isLastStep,
                        onNext: {
                            showHighlight = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                tutorialManager.nextStep()
                                if tutorialManager.isShowingTutorial {
                                    showHighlight = true
                                }
                            }
                        },
                        onSkip: tutorialManager.skipTutorial
                    )
                    .position(modalPosition(for: step, in: geometry))
                    .opacity(modalOpacity)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: modalOffset)
                }
                .onAppear {
                    screenSize = geometry.size
                }
                .onChange(of: geometry.size) { newSize in
                    screenSize = newSize
                }
                .onPreferenceChange(TutorialFramePreferenceKey.self) { frames in
                    targetFrames = frames
                    if step.targetView != .welcome {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showHighlight = true
                        }
                    }
                }
                .onChange(of: tutorialManager.currentStepIndex) { _ in
                    updateModalPosition(for: step, in: geometry)
                }
            }
        }
    }
    
    private func modalPosition(for step: TutorialStep, in geometry: GeometryProxy) -> CGPoint {
        let screenBounds = geometry.frame(in: .global)
        
        // Special case for welcome - always center
        if step.targetView == .welcome {
            return CGPoint(x: screenBounds.midX, y: screenBounds.midY)
        }
        
        guard highlightFrame != .zero else {
            return CGPoint(x: screenBounds.midX, y: screenBounds.midY)
        }
        
        let modalSize = CGSize(width: 280, height: 180) // Approximate modal size
        let position = isSmallScreen ? (step.smallScreenPosition ?? step.preferredPosition) : step.preferredPosition
        
        var point = CGPoint(x: highlightFrame.midX, y: highlightFrame.midY)
        
        // Calculate position based on preference and available space
        switch position {
        case .top:
            point.y = max(modalSize.height/2 + 50, highlightFrame.minY - modalSize.height/2 - 20)
        case .bottom:
            point.y = min(screenBounds.height - modalSize.height/2 - 50, highlightFrame.maxY + modalSize.height/2 + 20)
        case .left:
            point.x = max(modalSize.width/2 + 20, highlightFrame.minX - modalSize.width/2 - 20)
            point.y = highlightFrame.midY
        case .right:
            point.x = min(screenBounds.width - modalSize.width/2 - 20, highlightFrame.maxX + modalSize.width/2 + 20)
            point.y = highlightFrame.midY
        case .center:
            point = CGPoint(x: screenBounds.midX, y: screenBounds.midY)
        }
        
        // Ensure modal stays within screen bounds
        point.x = max(modalSize.width/2 + 10, min(screenBounds.width - modalSize.width/2 - 10, point.x))
        point.y = max(modalSize.height/2 + 10, min(screenBounds.height - modalSize.height/2 - 10, point.y))
        
        // Check for overlap and adjust opacity if needed
        let modalRect = CGRect(x: point.x - modalSize.width/2, y: point.y - modalSize.height/2, width: modalSize.width, height: modalSize.height)
        if modalRect.intersects(highlightFrame) && step.targetView != .welcome {
            modalOpacity = 0.85
        } else {
            modalOpacity = 1.0
        }
        
        return point
    }
    
    private func updateModalPosition(for step: TutorialStep, in geometry: GeometryProxy) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            _ = modalPosition(for: step, in: geometry)
        }
    }
}

// MARK: - Enhanced Tutorial Modal with Better Styling
struct TutorialModalEnhanced: View {
    let step: TutorialStep
    let isLastStep: Bool
    let onNext: () -> Void
    let onSkip: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // Title with icon based on step
            HStack(spacing: 8) {
                Image(systemName: iconForStep)
                    .font(.title2)
                    .foregroundColor(.cyan)
                
                Text(step.title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
            
            Text(step.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
            
            HStack(spacing: 16) {
                Button(action: onSkip) {
                    Text("Skip Tutorial")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                }
                
                Button(action: onNext) {
                    HStack(spacing: 4) {
                        Text(isLastStep ? "Finish" : "Continue")
                            .font(.subheadline.bold())
                        
                        if !isLastStep {
                            Image(systemName: "arrow.right")
                                .font(.caption.bold())
                        }
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.cyan)
                            .shadow(color: .cyan.opacity(0.5), radius: 8)
                    )
                }
            }
            
            // Progress indicator
            HStack(spacing: 6) {
                ForEach(0..<TutorialManager.shared.tutorialSteps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= TutorialManager.shared.currentStepIndex ? Color.cyan : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [
                        Color(white: 0.15),
                        Color(white: 0.25)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.5),
                                    Color.cyan.opacity(0.2)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        )
    }
    
    private var iconForStep: String {
        switch step.targetView {
        case .welcome:
            return "hand.wave.fill"
        case .textDisplay:
            return "text.quote"
        case .encryptedGrid:
            return "lock.fill"
        case .guessGrid:
            return "key.fill"
        case .hintButton:
            return "lightbulb.fill"
        case .tabBar:
            return "square.grid.2x2.fill"
        }
    }
}

// MARK: - Tutorial Trigger Button (For Settings or Debug)
struct TutorialTriggerButton: View {
    @StateObject private var tutorialManager = TutorialManager.shared
    
    var body: some View {
        Button(action: {
            tutorialManager.resetTutorial()
            tutorialManager.startTutorial()
        }) {
            HStack {
                Image(systemName: "questionmark.circle")
                Text("Show Tutorial")
            }
        }
    }
}

// MARK: - Tutorial Auto-Start Modifier
struct TutorialAutoStart: ViewModifier {
    @StateObject private var tutorialManager = TutorialManager.shared
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Check if this is the first launch and tutorial hasn't been completed
                if !tutorialManager.hasCompletedTutorial && !UserDefaults.standard.bool(forKey: "tutorial-started") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        tutorialManager.startTutorial()
                    }
                }
            }
    }
}

extension View {
    func tutorialAutoStart() -> some View {
        self.modifier(TutorialAutoStart())
    }
}
