// SoundManager.swift - Fixed version with debouncing and rate limiting

import AVFoundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Sound Manager with Full Cross-Platform Support
/// Manages all sound effects and haptic feedback for the game
class SoundManager: ObservableObject {
    // Singleton
    static let shared = SoundManager()
    
    // Sound types matching your M4A file names (with underscores)
    enum SoundType: String, CaseIterable {
        case letterClick = "letter_click"        // UI feedback
        case correctGuess = "correct_guess"      // Correct guess
        case incorrectGuess = "incorrect_guess"  // Wrong guess
        case win = "win"                         // Game won
        case lose = "lose"                       // Game lost
        case hint = "hint"                       // Hint used
        
        // Minimum delay between plays (in seconds)
        var minimumDelay: TimeInterval {
            switch self {
            case .letterClick:
                return 0.05  // Very short delay for responsiveness
            case .hint:
                return 0.5   // Longer delay to prevent double-play
            case .correctGuess, .incorrectGuess:
                return 0.2
            case .win, .lose:
                return 1.0
            }
        }
        
        // Map to sensory feedback for iOS 17+
        @available(iOS 17.0, *)
        var sensoryFeedback: SensoryFeedback {
            switch self {
            case .letterClick:
                return .selection
            case .correctGuess:
                return .success
            case .incorrectGuess:
                return .warning
            case .win:
                return .levelChange
            case .lose:
                return .error
            case .hint:
                return .impact(weight: .light, intensity: 0.7)
            }
        }
    }
    
    // Properties
    @Published var isSoundEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isSoundEnabled, forKey: "soundEnabled")
            if !isSoundEnabled {
                stopAllSounds()
            }
        }
    }
    
    @Published var isHapticEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isHapticEnabled, forKey: "hapticEnabled")
        }
    }
    
    @Published var volume: Float = 0.7 {
        didSet {
            UserDefaults.standard.set(volume, forKey: "soundVolume")
            updateVolume()
        }
    }
    
    // Track haptic triggers for SwiftUI's sensoryFeedback
    @Published var hapticTriggerID = UUID()
    @Published var lastTriggeredSound: SoundType? = nil
    
    // AVPlayer-based sound system (cross-platform)
    private var audioPlayers: [SoundType: AVPlayer] = [:]
    private var audioAssets: [SoundType: AVAsset] = [:]
    
    // Track playing state and debouncing
    private var isPlaying: [SoundType: Bool] = [:]
    private var lastPlayTime: [SoundType: TimeInterval] = [:]
    
    // Rate limiting for letter clicks
    private var letterClickCount = 0
    private var letterClickResetTimer: Timer?
    private let maxLetterClicksPerSecond = 5
    
    // Platform-specific haptic support
    #if os(iOS)
//    import UIKit
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    #endif
    
    // Debug mode
    private let debugMode = false
    
    // Track if sounds have been loaded
    private var soundsLoaded = false
    
    // MARK: - Initialization
    
    private init() {
        // Load preferences
        self.isSoundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.isHapticEnabled = UserDefaults.standard.object(forKey: "hapticEnabled") as? Bool ?? true
        self.volume = UserDefaults.standard.object(forKey: "soundVolume") as? Float ?? 0.7
        
        // Setup audio and haptics
        setupCrossPlatformAudio()
        loadSounds()
        prepareHapticGenerators()
    }
    
    // MARK: - Cross-Platform Audio Setup
    
    private func setupCrossPlatformAudio() {
        // Platform-specific audio session setup
        #if os(iOS)
        do {
            // iOS: Configure audio session for game audio
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,  // Respects silent switch
                mode: .default,
                options: [.mixWithOthers]  // Play nicely with other apps
            )
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ iOS Audio session configured")
        } catch {
            print("⚠️ iOS Audio session setup failed: \(error)")
        }
        #elseif os(macOS)
        // macOS doesn't need audio session configuration
        print("✅ macOS Audio ready")
        #endif
    }
    
    // MARK: - Sound Loading
    
    private func loadSounds() {
        for soundType in SoundType.allCases {
            if let soundURL = Bundle.main.url(forResource: soundType.rawValue, withExtension: "m4a") {
                // Create AVAsset for loading
                let asset = AVAsset(url: soundURL)
                audioAssets[soundType] = asset
                
                // Create AVPlayer for each sound
                let playerItem = AVPlayerItem(asset: asset)
                let player = AVPlayer(playerItem: playerItem)
                player.volume = volume
                
                // Pre-load the asset
                Task {
                    do {
                        _ = try await asset.load(.duration, .tracks)
                        if debugMode {
                            print("✅ Loaded sound: \(soundType.rawValue)")
                        }
                    } catch {
                        print("⚠️ Failed to preload \(soundType.rawValue): \(error)")
                    }
                }
                
                audioPlayers[soundType] = player
            } else {
                print("⚠️ Sound file not found: \(soundType.rawValue).m4a")
            }
        }
        
        soundsLoaded = true
        print("✅ All sounds loaded: \(audioPlayers.count) sounds ready")
    }
    
    // MARK: - Haptic Setup
    
    private func prepareHapticGenerators() {
        #if os(iOS)
        // Prepare all generators for immediate use
        selectionGenerator.prepare()
        notificationGenerator.prepare()
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
        
        print("📳 Haptic generators prepared")
        #endif
    }
    
    // MARK: - Playback with Debouncing and Rate Limiting
    
    func play(_ type: SoundType) {
        // Check debouncing
        let now = Date().timeIntervalSince1970
        if let lastTime = lastPlayTime[type] {
            let timeSinceLastPlay = now - lastTime
            if timeSinceLastPlay < type.minimumDelay {
                if debugMode {
                    print("⏸️ Debounced \(type.rawValue): too soon")
                }
                return
            }
        }
        
        // Special rate limiting for letter clicks
        if type == .letterClick {
            letterClickCount += 1
            
            // Reset counter after 1 second
            letterClickResetTimer?.invalidate()
            letterClickResetTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                self.letterClickCount = 0
            }
            
            // Skip if we've hit the rate limit
            if letterClickCount > maxLetterClicksPerSecond {
                if debugMode {
                    print("⏸️ Rate limited letterClick: \(letterClickCount) clicks")
                }
                return
            }
        }
        
        // Update last play time
        lastPlayTime[type] = now
        
        // Trigger haptic feedback first (even if sound is disabled)
        if isHapticEnabled {
            triggerHaptic(for: type)
        }
        
        guard isSoundEnabled else { return }
        
        // Don't play the same sound if it's already playing (except letterClick)
        if isPlaying[type] == true && type != .letterClick {
            return
        }
        
        // Play the sound using AVPlayer
        playWithAVPlayer(type)
    }
    
    private func playWithAVPlayer(_ type: SoundType) {
        guard let player = audioPlayers[type],
              let asset = audioAssets[type] else {
            if debugMode {
                print("⚠️ No player for: \(type.rawValue)")
            }
            return
        }
        
        isPlaying[type] = true
        
        // Create new player item and replace current one
        let playerItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: playerItem)
        player.volume = volume
        
        // Seek to beginning and play
        player.seek(to: .zero) { [weak self] _ in
            player.play()
            
            if self?.debugMode == true {
                print("🔊 Playing: \(type.rawValue)")
            }
            
            // Mark as not playing after expected duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.isPlaying[type] = false
            }
        }
    }
    
    private func triggerHaptic(for type: SoundType) {
        // iOS 17+ SwiftUI approach
        if #available(iOS 17.0, *) {
            // Update published properties to trigger SwiftUI sensoryFeedback
            DispatchQueue.main.async { [weak self] in
                self?.lastTriggeredSound = type
                self?.hapticTriggerID = UUID()
            }
        }
        
        // iOS 16 and below - direct UIKit approach
        #if os(iOS)
        DispatchQueue.main.async { [weak self] in
            guard self?.isHapticEnabled == true else { return }
            
            switch type {
            case .letterClick:
                self?.selectionGenerator.selectionChanged()
            case .correctGuess:
                self?.notificationGenerator.notificationOccurred(.success)
            case .incorrectGuess:
                self?.notificationGenerator.notificationOccurred(.warning)
            case .win:
                self?.notificationGenerator.notificationOccurred(.success)
            case .lose:
                self?.notificationGenerator.notificationOccurred(.error)
            case .hint:
                self?.lightImpactGenerator.impactOccurred(intensity: 0.7)
            }
            
            // Re-prepare for next use
            switch type {
            case .letterClick:
                self?.selectionGenerator.prepare()
            case .correctGuess, .incorrectGuess, .win, .lose:
                self?.notificationGenerator.prepare()
            case .hint:
                self?.lightImpactGenerator.prepare()
            }
        }
        #endif
    }
    
    // MARK: - Volume Control
    
    func updateVolume() {
        // Update all AVPlayer volumes
        for (_, player) in audioPlayers {
            player.volume = volume
        }
        
        if debugMode {
            print("🔊 Volume updated to: \(volume)")
        }
    }
    
    // MARK: - Stop Functions
    
    func stopAllSounds() {
        // Pause all AVPlayers
        for (_, player) in audioPlayers {
            player.pause()
            player.seek(to: .zero)
        }
        
        // Clear playing states
        isPlaying.removeAll()
        
        print("🛑 All sounds stopped")
    }
    
    func stopSound(_ type: SoundType) {
        if let player = audioPlayers[type] {
            player.pause()
            player.seek(to: .zero)
        }
        
        isPlaying[type] = false
    }
}

// MARK: - Modern SwiftUI View Modifier
@available(iOS 17.0, macOS 14.0, *)
struct ModernSoundAndHapticModifier: ViewModifier {
    @EnvironmentObject var soundManager: SoundManager
    
    func body(content: Content) -> some View {
        content
            .sensoryFeedback(
                trigger: soundManager.hapticTriggerID
            ) { _, _ in
                guard let soundType = soundManager.lastTriggeredSound,
                      soundManager.isHapticEnabled else {
                    return nil
                }
                return soundType.sensoryFeedback
            }
    }
}

// MARK: - Legacy Support
struct LegacySoundModifier: ViewModifier {
    func body(content: Content) -> some View {
        // For iOS 16 and below, haptics are handled directly in triggerHaptic
        content
    }
}

// MARK: - View Extension
extension View {
    func withSoundAndHaptics() -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            return self.modifier(ModernSoundAndHapticModifier())
        } else {
            return self.modifier(LegacySoundModifier())
        }
    }
}

// MARK: - Sound Button Helper
struct SoundButton<Label: View>: View {
    let soundType: SoundManager.SoundType
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    
    var body: some View {
        Button(action: {
            SoundManager.shared.play(soundType)
            action()
        }) {
            label()
        }
    }
}

// Make SoundType Identifiable for SwiftUI
extension SoundManager.SoundType: Identifiable {
    var id: String {
        return self.rawValue
    }
}
