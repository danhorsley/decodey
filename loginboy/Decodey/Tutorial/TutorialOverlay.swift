import SwiftUI

// MARK: - Tutorial Step Model
struct TutorialStep: Identifiable {
    let id: String
    let title: String
    let description: String
    let targetView: TutorialTarget
    let preferredPosition: TutorialPosition
    let smallScreenPosition: TutorialPosition?
    
    enum TutorialTarget {
        case welcome  // Center of screen
        case textDisplay  // Encrypted text area
        case encryptedGrid  // Encrypted letters grid
        case guessGrid  // Original letters grid
        case hintButton  // Hint button
        case tabBar  // Bottom tab bar for menu/settings
    }
    
    enum TutorialPosition {
        case center
        case top
        case bottom
        case left
        case right
    }
}

// MARK: - Tutorial State Manager
class TutorialManager: ObservableObject {
    static let shared = TutorialManager()
    
    @Published var isShowingTutorial: Bool = false
    @Published var currentStepIndex: Int = 0
    @Published var hasCompletedTutorial: Bool = UserDefaults.standard.bool(forKey: "tutorial-completed")
    
    let tutorialSteps: [TutorialStep] = [
        TutorialStep(
            id: "welcome",
            title: "Welcome to Decodey!",
            description: "Ready to become a master cryptanalyst? Follow this quick tutorial to learn how to play.",
            targetView: .welcome,
            preferredPosition: .center,
            smallScreenPosition: nil
        ),
        TutorialStep(
            id: "text-display",
            title: "Encrypted Text",
            description: "This shows the encrypted quote you need to decrypt.",
            targetView: .textDisplay,
            preferredPosition: .bottom,
            smallScreenPosition: .bottom
        ),
        TutorialStep(
            id: "encrypted-grid",
            title: "Encrypted Letters",
            description: "Click a letter here to select it for decoding.",
            targetView: .encryptedGrid,
            preferredPosition: .right,
            smallScreenPosition: .top
        ),
        TutorialStep(
            id: "guess-grid",
            title: "Original Letters",
            description: "And then click on this grid to choose the real letter you think it represents.",
            targetView: .guessGrid,
            preferredPosition: .left,
            smallScreenPosition: .top
        ),
        TutorialStep(
            id: "hint-button",
            title: "Hint Button",
            description: "Stuck? Use a hint to reveal a letter. Each hint or mistake costs one token.",
            targetView: .hintButton,
            preferredPosition: .left,
            smallScreenPosition: .top
        ),
        TutorialStep(
            id: "menu",
            title: "Navigation Menu",
            description: "Start new games, change difficulty and other settings. Create a free account to save scores and compete on leaderboards.",
            targetView: .tabBar,
            preferredPosition: .bottom,
            smallScreenPosition: .top
        )
    ]
    
    var currentStep: TutorialStep? {
        guard currentStepIndex < tutorialSteps.count else { return nil }
        return tutorialSteps[currentStepIndex]
    }
    
    var isLastStep: Bool {
        currentStepIndex == tutorialSteps.count - 1
    }
    
    private init() {
        // Check if we should show tutorial on first launch
        if !UserDefaults.standard.bool(forKey: "tutorial-started") {
            // Will be triggered after game loads
        }
    }
    
    func startTutorial() {
        UserDefaults.standard.set(true, forKey: "tutorial-started")
        currentStepIndex = 0
        isShowingTutorial = true
    }
    
    func nextStep() {
        if currentStepIndex < tutorialSteps.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStepIndex += 1
            }
        } else {
            completeTutorial()
        }
    }
    
    func skipTutorial() {
        completeTutorial()
    }
    
    private func completeTutorial() {
        UserDefaults.standard.set(true, forKey: "tutorial-completed")
        hasCompletedTutorial = true
        withAnimation(.easeOut(duration: 0.3)) {
            isShowingTutorial = false
        }
        currentStepIndex = 0
    }
    
    func resetTutorial() {
        UserDefaults.standard.set(false, forKey: "tutorial-started")
        UserDefaults.standard.set(false, forKey: "tutorial-completed")
        hasCompletedTutorial = false
        currentStepIndex = 0
    }
}

// MARK: - Tutorial Overlay View
struct TutorialOverlay: View {
    @StateObject private var tutorialManager = TutorialManager.shared
    @State private var highlightFrame: CGRect = .zero
    @State private var modalOffset: CGSize = .zero
    @State private var modalOpacity: Double = 1.0
    @State private var screenSize: CGSize = .zero
    
    // For tracking screen size using GeometryReader
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var isSmallScreen: Bool {
        horizontalSizeClass == .compact && verticalSizeClass == .compact
    }
    
    private var isVerySmallScreen: Bool {
        screenSize.height < 600
    }
    
    var body: some View {
        GeometryReader { geometry in
            if tutorialManager.isShowingTutorial, let step = tutorialManager.currentStep {
                ZStack {
                    // Dark overlay with cutout
                    TutorialBackgroundOverlay(highlightFrame: highlightFrame)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    
                    // Highlight border
                    if step.targetView != .welcome {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.8), lineWidth: 2)
                            .frame(width: highlightFrame.width, height: highlightFrame.height)
                            .position(x: highlightFrame.midX, y: highlightFrame.midY)
                            .allowsHitTesting(false)
                    }
                    
                    // Tutorial modal
                    TutorialModal(
                        step: step,
                        isLastStep: tutorialManager.isLastStep,
                        onNext: tutorialManager.nextStep,
                        onSkip: tutorialManager.skipTutorial
                    )
                    .opacity(modalOpacity)
                    .background(
                        GeometryReader { modalGeometry in
                            Color.clear
                                .onAppear {
                                    positionModal(for: step, modalSize: modalGeometry.size, screenSize: geometry.size)
                                }
                                .onChange(of: step.id) { _ in
                                    updateHighlight(for: step, screenSize: geometry.size)
                                    positionModal(for: step, modalSize: modalGeometry.size, screenSize: geometry.size)
                                }
                        }
                    )
                    .offset(modalOffset)
                    .animation(.easeInOut(duration: 0.3), value: modalOffset)
                }
                .onAppear {
                    screenSize = geometry.size
                    updateHighlight(for: step, screenSize: geometry.size)
                }
                .onChange(of: geometry.size) { newSize in
                    screenSize = newSize
                    updateHighlight(for: step, screenSize: newSize)
                }
            }
        }
    }
    
    private func updateHighlight(for step: TutorialStep, screenSize: CGSize) {
        // Find the target view and get its frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch step.targetView {
            case .welcome:
                highlightFrame = .zero
            case .textDisplay:
                highlightFrame = getFrameForTextDisplay(screenSize: screenSize)
            case .encryptedGrid:
                highlightFrame = getFrameForEncryptedGrid(screenSize: screenSize)
            case .guessGrid:
                highlightFrame = getFrameForGuessGrid(screenSize: screenSize)
            case .hintButton:
                highlightFrame = getFrameForHintButton(screenSize: screenSize)
            case .tabBar:
                highlightFrame = getFrameForTabBar(screenSize: screenSize)
            }
        }
    }
    
    private func positionModal(for step: TutorialStep, modalSize: CGSize, screenSize: CGSize) {
        let position = isSmallScreen ? (step.smallScreenPosition ?? step.preferredPosition) : step.preferredPosition
        
        // Special case for welcome - always center
        if step.targetView == .welcome {
            modalOffset = .zero
            modalOpacity = 1.0
            return
        }
        
        // Calculate available space
        let spaceAbove = highlightFrame.minY
        let spaceBelow = screenSize.height - highlightFrame.maxY
        let spaceLeft = highlightFrame.minX
        let spaceRight = screenSize.width - highlightFrame.maxX
        
        // Determine best position based on available space
        var calculatedOffset = CGSize.zero
        modalOpacity = 1.0
        
        if isSmallScreen {
            // For small screens, prioritize vertical positioning
            if position == .top && spaceAbove > modalSize.height + 20 {
                calculatedOffset = CGSize(
                    width: highlightFrame.midX - screenSize.width/2,
                    height: highlightFrame.minY - screenSize.height/2 - modalSize.height - 10
                )
            } else if position == .bottom && spaceBelow > modalSize.height + 20 {
                calculatedOffset = CGSize(
                    width: highlightFrame.midX - screenSize.width/2,
                    height: highlightFrame.maxY - screenSize.height/2 + modalSize.height/2 + 10
                )
            } else {
                // Make semi-transparent if overlapping
                modalOpacity = 0.9
                if spaceBelow > spaceAbove {
                    calculatedOffset = CGSize(
                        width: highlightFrame.midX - screenSize.width/2,
                        height: min(highlightFrame.maxY - screenSize.height/2 + modalSize.height/2 + 10, screenSize.height/2 - modalSize.height/2 - 10)
                    )
                } else {
                    calculatedOffset = CGSize(
                        width: highlightFrame.midX - screenSize.width/2,
                        height: max(highlightFrame.minY - screenSize.height/2 - modalSize.height - 10, -screenSize.height/2 + modalSize.height/2 + 10)
                    )
                }
            }
        } else {
            // Regular positioning for larger screens
            switch position {
            case .top:
                calculatedOffset = CGSize(
                    width: highlightFrame.midX - screenSize.width/2,
                    height: highlightFrame.minY - screenSize.height/2 - modalSize.height - 20
                )
            case .bottom:
                calculatedOffset = CGSize(
                    width: highlightFrame.midX - screenSize.width/2,
                    height: highlightFrame.maxY - screenSize.height/2 + modalSize.height/2 + 20
                )
            case .left:
                calculatedOffset = CGSize(
                    width: highlightFrame.minX - screenSize.width/2 - modalSize.width/2 - 20,
                    height: highlightFrame.midY - screenSize.height/2
                )
            case .right:
                calculatedOffset = CGSize(
                    width: highlightFrame.maxX - screenSize.width/2 + modalSize.width/2 + 20,
                    height: highlightFrame.midY - screenSize.height/2
                )
            case .center:
                calculatedOffset = .zero
            }
        }
        
        modalOffset = calculatedOffset
    }
    
    // Helper functions to get frame coordinates
    // These would need to be implemented based on your actual view hierarchy
    private func getFrameForTextDisplay(screenSize: CGSize) -> CGRect {
        // This would need to access the actual text display view
        // For now, returning approximate position
        return CGRect(x: screenSize.width/2 - 150, y: 150, width: 300, height: 100)
    }
    
    private func getFrameForEncryptedGrid(screenSize: CGSize) -> CGRect {
        return CGRect(x: screenSize.width/2 - 140, y: 300, width: 280, height: 200)
    }
    
    private func getFrameForGuessGrid(screenSize: CGSize) -> CGRect {
        return CGRect(x: screenSize.width/2 - 140, y: 550, width: 280, height: 200)
    }
    
    private func getFrameForHintButton(screenSize: CGSize) -> CGRect {
        return CGRect(x: screenSize.width/2 - 70, y: 480, width: 140, height: 80)
    }
    
    private func getFrameForTabBar(screenSize: CGSize) -> CGRect {
        let tabBarHeight: CGFloat = 49
        let bottomPadding: CGFloat = 34 // For devices with home indicator
        return CGRect(x: 0, y: screenSize.height - tabBarHeight - bottomPadding, width: screenSize.width, height: tabBarHeight)
    }
}

// MARK: - Tutorial Background Overlay
struct TutorialBackgroundOverlay: View {
    let highlightFrame: CGRect
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // Add the full screen
                path.addRect(geometry.frame(in: .global))
                
                // Subtract the highlight area if it exists
                if highlightFrame != .zero {
                    path.addRoundedRect(in: highlightFrame, cornerSize: CGSize(width: 8, height: 8))
                }
            }
            .fill(Color.black.opacity(0.75), style: FillStyle(eoFill: true))
        }
    }
}

// MARK: - Tutorial Modal
struct TutorialModal: View {
    let step: TutorialStep
    let isLastStep: Bool
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text(step.title)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(step.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 12) {
                Button(action: onSkip) {
                    Text("Skip Tutorial")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                
                Button(action: onNext) {
                    Text(isLastStep ? "Finish" : "Continue")
                        .font(.subheadline.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.2))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}
